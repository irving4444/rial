//
//  ProverManager.swift
//  rial
//
//  Created by Sofiane Larbi on 2/17/24.
//

import Foundation

enum ProverError: LocalizedError {
    case invalidURL
    case missingData
    case networkError(Error)
    case serverError(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid backend URL configuration"
        case .missingData:
            return "Missing required image or signature data"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        }
    }
}

struct ProverResponse: Codable {
    let message: String
    let signatureValid: Bool?
    let imageUrl: String?
}

class ProverManager {
    
    static let shared = ProverManager()
    
    // TODO: Move to configuration file or environment variable
    private var baseURL: String {
        // Check if user has set a custom URL in settings
        if let customURL = UserDefaults.standard.string(forKey: "backendURL"), !customURL.isEmpty {
            return customURL
        }
        
        // Default URLs
        #if targetEnvironment(simulator)
        return "http://localhost:3000"
        #else
        return "http://10.0.0.132:3000" // Replace with your Mac's IP
        #endif
    }
    
    private var proveURL: URL? {
        URL(string: "\(baseURL)/prove")
    }
    
    // Public method to get backend URL for other views
    func getBackendURL() -> String {
        return baseURL
    }
    
    func proveImage(
        signature: Data?,
        image: Data?,
        publicKey: Data?,
        c2paClaim: String?,
        croppingHeight: Int32,
        croppingWidth: Int32,
        completion: @escaping (Result<ProverResponse, ProverError>) -> Void
    ) {
        guard let url = proveURL else {
            completion(.failure(.invalidURL))
            return
        }
        
        guard let providedSignature = signature,
              let img_buffer = image,
              let providedPublicKey = publicKey else {
            print("❌ Missing required data")
            completion(.failure(.missingData))
            return
        }
        
        print("✅ Starting proof generation - Image size: \(img_buffer.count) bytes")
        
        let request = MultipartFormDataRequest(url: url)
        request.addDataField(named: "img_buffer", data: img_buffer, mimeType: "image/jpeg")
        
        let croppingX = Int((512 - croppingWidth) / 2)
        let croppingY = Int((512 - croppingHeight) / 2)
        let transformations = """
        [{"Crop":{"x":\(croppingX),"y":\(croppingY),"height":\(croppingHeight),"width":\(croppingWidth)}}]
        """
        
        request.addTextField(named: "transformations", value: transformations)
        request.addTextField(named: "signature", value: providedSignature.base64EncodedString())
        request.addTextField(named: "public_key", value: providedPublicKey.base64EncodedString())
        
        if let claim = c2paClaim {
            request.addTextField(named: "c2pa_claim", value: claim)
        }
        
        // Create URL session with timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30  // 30 second timeout
        config.timeoutIntervalForResource = 60
        let session = URLSession(configuration: config)
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                print("   Error code: \(error._code)")
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.networkError(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))))
                return
            }
            
            print("✅ Response status: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let message = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
                completion(.failure(.serverError(httpResponse.statusCode, message)))
                return
            }
            
            if let data = data {
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(ProverResponse.self, from: data)
                    print("✅ Proof generated successfully")
                    completion(.success(response))
                    
                    // Save to persistent storage
                    DispatchQueue.main.async {
                        PersistenceController.shared.saveItem()
                    }
                } catch {
                    print("❌ Failed to decode response: \(error)")
                    // Still consider it success if we got 200 but couldn't decode
                    let fallbackResponse = ProverResponse(
                        message: "Proof generated",
                        signatureValid: nil,
                        imageUrl: nil
                    )
                    completion(.success(fallbackResponse))
                }
            }
        }.resume()
    }
}

struct MultipartFormDataRequest {
    private let boundary: String = UUID().uuidString
    private var httpBody = NSMutableData()
    let url: URL

    init(url: URL) {
        self.url = url
    }

    func addTextField(named name: String, value: String) {
        httpBody.append(textFormField(named: name, value: value))
    }

    private func textFormField(named name: String, value: String) -> String {
        var fieldString = "--\(boundary)\r\n"
        fieldString += "Content-Disposition: form-data; name=\"\(name)\"\r\n"
        fieldString += "Content-Type: text/plain; charset=ISO-8859-1\r\n"
        fieldString += "Content-Transfer-Encoding: 8bit\r\n"
        fieldString += "\r\n"
        fieldString += "\(value)\r\n"

        return fieldString
    }

    func addDataField(named name: String, data: Data, mimeType: String) {
        httpBody.append(dataFormField(named: name, data: data, mimeType: mimeType))
    }

    private func dataFormField(named name: String,
                               data: Data,
                               mimeType: String) -> Data {
        let fieldData = NSMutableData()

        fieldData.append("--\(boundary)\r\n")
        fieldData.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"image.jpg\"\r\n")
        fieldData.append("Content-Type: \(mimeType)\r\n")
        fieldData.append("\r\n")
        fieldData.append(data)
        fieldData.append("\r\n")

        return fieldData as Data
    }
    
    func asURLRequest() -> URLRequest {
        var request = URLRequest(url: url)

        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        httpBody.append("--\(boundary)--")
        request.httpBody = httpBody as Data
        return request
    }
}

extension NSMutableData {
  func append(_ string: String) {
    if let data = string.data(using: .utf8) {
      self.append(data)
    }
  }
}

extension URLSession {
    func dataTask(with request: MultipartFormDataRequest,
                  completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void)
    -> URLSessionDataTask {
        let urlRequest = request.asURLRequest()
        print("📦 Extension converting request:")
        print("   Method: \(urlRequest.httpMethod ?? "nil")")
        print("   URL: \(urlRequest.url?.absoluteString ?? "nil")")
        print("   Body size: \(urlRequest.httpBody?.count ?? 0) bytes")
        print("   Headers: \(urlRequest.allHTTPHeaderFields ?? [:])")
        return dataTask(with: urlRequest, completionHandler: completionHandler)
    }
}

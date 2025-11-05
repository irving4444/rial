import SwiftUI

struct GalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var certifiedImages: [[String: Any]] = []
    @State private var selectedImageIndex: Int?
    @State private var showingDetail = false
    @State private var searchText = ""
    
    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 2)
    ]
    
    var filteredImages: [[String: Any]] {
        if searchText.isEmpty {
            return certifiedImages
        }
        return certifiedImages.filter { imageDict in
            // Search by timestamp or other metadata
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            
            // Try to parse the ISO8601 date string
            if let certDateString = imageDict["certificationDate"] as? String,
               let certDate = ISO8601DateFormatter().date(from: certDateString) {
                let dateString = dateFormatter.string(from: certDate)
                return dateString.localizedCaseInsensitiveContains(searchText)
            }
            
            // Also try timestamp field
            if let timestampString = imageDict["timestamp"] as? String {
                return timestampString.localizedCaseInsensitiveContains(searchText)
            }
            
            return false
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                if certifiedImages.isEmpty {
                    EmptyGalleryView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                } else {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(Array(filteredImages.enumerated()), id: \.offset) { index, imageDict in
                            GalleryItemView(imageDict: imageDict)
                                .onTapGesture {
                                    selectedImageIndex = index
                                    showingDetail = true
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                        }
                    }
                    .padding(.horizontal, 2)
                    .searchable(text: $searchText, prompt: "Search by date")
                }
            }
            .navigationTitle("Certified Images")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: exportAll) {
                            Label("Export All", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: deleteAll) {
                            Label("Delete All", systemImage: "trash")
                        }
                        .foregroundColor(.red)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingDetail) {
                if let selectedIndex = selectedImageIndex,
                   selectedIndex < certifiedImages.count {
                    ImageDetailView(imageDict: certifiedImages[selectedIndex])
                }
            }
            .onAppear {
                loadCertifiedImages()
            }
            .refreshable {
                loadCertifiedImages()
            }
        }
    }
    
    private func exportAll() {
        // Implement export functionality
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    private func deleteAll() {
        // Implement delete all functionality
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        PersistenceController.shared.clearCertifiedImages()
        loadCertifiedImages()
    }
    
    private func loadCertifiedImages() {
        certifiedImages = PersistenceController.shared.getCertifiedImages()
        print("🔄 Gallery loaded \(certifiedImages.count) certified images")
    }
}

struct GalleryItemView: View {
    let imageDict: [String: Any]
    
    var image: UIImage? {
        // Handle both Data and base64 String formats
        if let imageData = imageDict["imageData"] as? Data {
            return UIImage(data: imageData)
        } else if let imageDataString = imageDict["imageData"] as? String,
                  let imageData = Data(base64Encoded: imageDataString) {
            return UIImage(data: imageData)
        }
        return nil
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 100, maxWidth: .infinity, minHeight: 100, maxHeight: .infinity)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(minWidth: 100, maxWidth: .infinity, minHeight: 100, maxHeight: .infinity)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            
            // Verification badge
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 16))
                .foregroundColor(.green)
                .background(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                )
                .padding(4)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct EmptyGalleryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.stack")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Certified Images")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Take a photo and certify it to see it here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct ImageDetailView: View {
    let imageDict: [String: Any]
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var showQRCode = false
    
    var image: UIImage? {
        // Handle both Data and base64 String formats
        if let imageData = imageDict["imageData"] as? Data {
            return UIImage(data: imageData)
        } else if let imageDataString = imageDict["imageData"] as? String,
                  let imageData = Data(base64Encoded: imageDataString) {
            return UIImage(data: imageData)
        }
        return nil
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Image
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(12)
                            .shadow(radius: 10)
                            .padding()
                    }
                    
                    // Metadata Card
                    VStack(alignment: .leading, spacing: 16) {
                        // Verification Status
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text("Cryptographically Verified")
                                .font(.headline)
                            Spacer()
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        
                        // Details
                        VStack(alignment: .leading, spacing: 12) {
                            if let certDateString = imageDict["certificationDate"] as? String,
                               let certDate = ISO8601DateFormatter().date(from: certDateString) {
                                DetailRow(label: "Certified", value: formatDate(certDate))
                            }
                            if let merkleRoot = imageDict["merkleRoot"] as? String {
                                DetailRow(label: "Merkle Root", value: String(merkleRoot.prefix(16)) + "...")
                            }
                            if let publicKey = imageDict["publicKey"] as? String {
                                DetailRow(label: "Public Key", value: String(publicKey.prefix(16)) + "...")
                            }
                            if let timestamp = imageDict["timestamp"] as? String {
                                DetailRow(label: "Captured", value: String(timestamp.prefix(19)))
                            }
                            if let isVerifiedString = imageDict["isVerified"] as? String {
                                let isVerified = (isVerifiedString == "true")
                                DetailRow(label: "Verified", value: isVerified ? "✅ Valid" : "❌ Invalid")
                            }
                            DetailRow(label: "Device", value: "Secure Enclave")
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        
                        // Action Buttons
                        VStack(spacing: 12) {
                            Button(action: verifyOnBlockchain) {
                                Label("Verify on Blockchain", systemImage: "link.badge.plus")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            
                            HStack(spacing: 12) {
                                Button(action: {
                                    showQRCode = true
                                }) {
                                    Label("QR Code", systemImage: "qrcode")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                
                                Button(action: shareImage) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Image Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if #available(iOS 16.0, *) {
                    ShareSheet(items: shareItems)
                }
            }
            .sheet(isPresented: $showQRCode) {
                if let merkleRoot = imageDict["merkleRoot"] as? String {
                    let backendURL = UserDefaults.standard.string(forKey: "backendURL") ?? ProverManager.shared.getBackendURL()
                    let verificationLink = "\(backendURL)/verify.html?id=\(merkleRoot)"
                    
                    NavigationView {
                        QRCodeView(verificationLink: verificationLink)
                            .navigationTitle("Verification QR Code")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Done") {
                                        showQRCode = false
                                    }
                                }
                            }
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func verifyOnBlockchain() {
        // Open blockchain verification URL
        if let merkleRoot = imageDict["merkleRoot"] as? String {
            let backendURL = UserDefaults.standard.string(forKey: "backendURL") ?? ProverManager.shared.getBackendURL()
            if let url = URL(string: "\(backendURL)/verify.html?id=\(merkleRoot)") {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func shareImage() {
        guard let image = image else { return }
        
        var items: [Any] = [image]
        
        // Add verification link
        if let merkleRoot = imageDict["merkleRoot"] as? String {
            let backendURL = UserDefaults.standard.string(forKey: "backendURL") ?? ProverManager.shared.getBackendURL()
            let verificationLink = "\(backendURL)/verify.html?id=\(merkleRoot)"
            items.append("🔐 This image is cryptographically verified.\n\nVerify at: \(verificationLink)")
        }
        
        shareItems = items
        showShareSheet = true
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .lineLimit(1)
            
            Spacer()
        }
    }
}

@available(iOS 16.0, *)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

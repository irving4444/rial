//
//  ImageEditView.swift
//  rial
//
//  Created by Sofiane Larbi on 2/17/24.
//

import SwiftUI
import Combine
import AVFoundation

struct ImageEditView: View {
    
    @EnvironmentObject private var viewModel: ImageCaptureViewModel
    @Environment(\.presentationMode) var presentation
    @State private var evPointLocation: CGPoint = CGPoint()
    @State private var imageFrame = CGRect()
    
    @State private var croppingHeight: CGFloat = 300
    @State private var croppingWidth: CGFloat = 300
    @State private var showAlert = false
    @State private var isLoading = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        ZStack {
            // Gradient Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.2, green: 0.1, blue: 0.3)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Certify Your Image")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Adjust the crop area and certify")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 20)
                .padding(.bottom, 24)
                
                // Image Preview Card
                VStack(spacing: 16) {
                    // Image with crop overlay
                    ZStack {
                        if let capturedImage = viewModel.capturedImage {
                            Image(uiImage: capturedImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 400)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        
                        CustomDraggableComponent(height: $croppingHeight, width: $croppingWidth)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.1))
                            .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                    )
                    
                    // Crop Info Card
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Crop Size")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.6))
                            Text("\(Int(croppingWidth)) × \(Int(croppingHeight))")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "crop")
                            .font(.system(size: 24))
                            .foregroundColor(.blue.opacity(0.8))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    // Certify Button
                    Button(action: certifyImage) {
                        HStack(spacing: 12) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 20))
                            }
                            
                            Text(isLoading ? "Certifying..." : "Certify Image")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: isLoading ? 
                                    [Color.gray, Color.gray.opacity(0.8)] :
                                    [Color.blue, Color.purple]
                                ),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: isLoading ? Color.clear : Color.blue.opacity(0.5), radius: 15, x: 0, y: 8)
                    }
                    .disabled(isLoading)
                    
                    // Cancel Button
                    Button(action: {
                        presentation.wrappedValue.dismiss()
                    }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                            )
                    }
                    .disabled(isLoading)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK")) {
                        if !isLoading {
                            self.presentation.wrappedValue.dismiss()
                        }
                    }
                )
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    
    private func certifyImage() {
        guard let attestedImage = viewModel.attestedImage else {
            alertTitle = "Error"
            alertMessage = "No image available for certification"
            showAlert = true
            return
        }
        
        isLoading = true
        
        // Convert signature and public key from String? to Data?
        let signatureData = Data(base64Encoded: attestedImage.signature ?? "")
        let publicKeyData = Data(base64Encoded: attestedImage.publicKey ?? "")
        
        // Convert c2paClaim struct to a JSON String
        var c2paClaimString: String?
        if let claim = attestedImage.c2paClaim {
            let encoder = JSONEncoder()
            if let jsonData = try? encoder.encode(claim) {
                c2paClaimString = String(data: jsonData, encoding: .utf8)
            }
        }
        
        ProverManager.shared.proveImage(
            signature: signatureData,
            image: attestedImage.imageData,
            publicKey: publicKeyData,
            c2paClaim: c2paClaimString,
            croppingHeight: Int32(croppingHeight),
            croppingWidth: Int32(croppingWidth)
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let response):
                    alertTitle = "Success! ✅"
                    alertMessage = response.message
                    if let signatureValid = response.signatureValid {
                        alertMessage += "\nSignature: \(signatureValid ? "Valid" : "Invalid")"
                    }
                    showAlert = true
                    
                case .failure(let error):
                    alertTitle = "Certification Failed"
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
}

struct CustomDraggableComponent: View {
    @Binding var height: CGFloat
    @Binding var width: CGFloat

    @State private var cropRect = CGRect(x: 0, y: 0, width: 300, height: 300)
    @State private var activeCorner: Corner? = nil
    @State private var dragStartRect = CGRect.zero
    
    var body: some View {
        GeometryReader { geo in
            let centerX = geo.size.width / 2
            let centerY = geo.size.height / 2
            let minSize: CGFloat = 100
            let maxSize = min(geo.size.width, geo.size.height) * 0.9
            
            ZStack {
                // Dark overlay (dimmed area outside crop)
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .mask(
                        Rectangle()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .overlay(
                                Rectangle()
                                    .frame(width: cropRect.width, height: cropRect.height)
                                    .position(x: centerX + cropRect.origin.x, y: centerY + cropRect.origin.y)
                                    .blendMode(.destinationOut)
                            )
                    )
                    .allowsHitTesting(false)
                
                // Crop rectangle
                ZStack {
                    // Grid lines (rule of thirds)
                    Path { path in
                        let w = cropRect.width
                        let h = cropRect.height
                        
                        // Vertical lines
                        path.move(to: CGPoint(x: w/3, y: 0))
                        path.addLine(to: CGPoint(x: w/3, y: h))
                        path.move(to: CGPoint(x: 2*w/3, y: 0))
                        path.addLine(to: CGPoint(x: 2*w/3, y: h))
                        
                        // Horizontal lines
                        path.move(to: CGPoint(x: 0, y: h/3))
                        path.addLine(to: CGPoint(x: w, y: h/3))
                        path.move(to: CGPoint(x: 0, y: 2*h/3))
                        path.addLine(to: CGPoint(x: w, y: 2*h/3))
                    }
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    
                    // White border
                    Rectangle()
                        .stroke(Color.white, lineWidth: 2)
                    
                    // L-shaped corner handles
                    iPhoneStyleCorners(size: cropRect.width)
                    
                    // Edge handles
                    iPhoneStyleEdges(width: cropRect.width, height: cropRect.height)
                }
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: centerX + cropRect.origin.x, y: centerY + cropRect.origin.y)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Move the entire crop area
                            var newRect = cropRect
                            newRect.origin.x = dragStartRect.origin.x + value.translation.width
                            newRect.origin.y = dragStartRect.origin.y + value.translation.height
                            
                            // Keep within bounds
                            let maxOffsetX = (geo.size.width - cropRect.width) / 2
                            let maxOffsetY = (geo.size.height - cropRect.height) / 2
                            newRect.origin.x = min(max(newRect.origin.x, -maxOffsetX), maxOffsetX)
                            newRect.origin.y = min(max(newRect.origin.y, -maxOffsetY), maxOffsetY)
                            
                            cropRect = newRect
                        }
                        .onEnded { _ in
                            dragStartRect = cropRect
                        }
                )
                
                // Invisible corner resize handles (44x44 touch targets)
                ForEach(Corner.allCases, id: \.self) { corner in
                    let cornerPosition = getCornerPosition(corner: corner, rect: cropRect, center: CGPoint(x: centerX, y: centerY))
                    
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 44, height: 44)
                        .position(cornerPosition)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    var newRect = dragStartRect
                                    
                                    switch corner {
                                    case .topLeft:
                                        let delta = -(value.translation.width + value.translation.height) / 2
                                        newRect.size.width = max(minSize, dragStartRect.width + delta)
                                        newRect.size.height = newRect.size.width
                                        
                                    case .topRight:
                                        let delta = (value.translation.width - value.translation.height) / 2
                                        newRect.size.width = max(minSize, dragStartRect.width + delta)
                                        newRect.size.height = newRect.size.width
                                        
                                    case .bottomLeft:
                                        let delta = -(value.translation.width - value.translation.height) / 2
                                        newRect.size.width = max(minSize, dragStartRect.width + delta)
                                        newRect.size.height = newRect.size.width
                                        
                                    case .bottomRight:
                                        let delta = (value.translation.width + value.translation.height) / 2
                                        newRect.size.width = max(minSize, dragStartRect.width + delta)
                                        newRect.size.height = newRect.size.width
                                    }
                                    
                                    // Clamp size
                                    newRect.size.width = min(newRect.size.width, maxSize)
                                    newRect.size.height = newRect.size.width
                                    
                                    cropRect = newRect
                                    width = newRect.width
                                    height = newRect.height
                                }
                                .onEnded { _ in
                                    dragStartRect = cropRect
                                }
                        )
                }
            }
            .onAppear {
                cropRect = CGRect(x: 0, y: 0, width: 300, height: 300)
                dragStartRect = cropRect
                width = 300
                height = 300
            }
        }
    }
    
    private func getCornerPosition(corner: Corner, rect: CGRect, center: CGPoint) -> CGPoint {
        let rectCenterX = center.x + rect.origin.x
        let rectCenterY = center.y + rect.origin.y
        
        switch corner {
        case .topLeft:
            return CGPoint(x: rectCenterX - rect.width/2, y: rectCenterY - rect.height/2)
        case .topRight:
            return CGPoint(x: rectCenterX + rect.width/2, y: rectCenterY - rect.height/2)
        case .bottomLeft:
            return CGPoint(x: rectCenterX - rect.width/2, y: rectCenterY + rect.height/2)
        case .bottomRight:
            return CGPoint(x: rectCenterX + rect.width/2, y: rectCenterY + rect.height/2)
        }
    }
    
    enum Corner: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
    }
}

// iPhone-style corner L shapes
struct iPhoneStyleCorners: View {
    let size: CGFloat
    let handleLength: CGFloat = 20
    let handleThickness: CGFloat = 4
    
    var body: some View {
        ZStack {
            // Top-left L
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: handleLength, height: handleThickness)
                    Spacer()
                }
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: handleThickness, height: handleLength)
                    Spacer()
                }
                Spacer()
            }
            
            // Top-right L
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: handleLength, height: handleThickness)
                }
                HStack(spacing: 0) {
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: handleThickness, height: handleLength)
                }
                Spacer()
            }
            
            // Bottom-left L
            VStack(spacing: 0) {
                Spacer()
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: handleThickness, height: handleLength)
                    Spacer()
                }
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: handleLength, height: handleThickness)
                    Spacer()
                }
            }
            
            // Bottom-right L
            VStack(spacing: 0) {
                Spacer()
                HStack(spacing: 0) {
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: handleThickness, height: handleLength)
                }
                HStack(spacing: 0) {
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: handleLength, height: handleThickness)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// Edge handles (small bars on each side)
struct iPhoneStyleEdges: View {
    let width: CGFloat
    let height: CGFloat
    let handleSize: CGFloat = 25
    let handleThickness: CGFloat = 4
    
    var body: some View {
        ZStack {
            // Top edge
            VStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: handleSize, height: handleThickness)
                Spacer()
            }
            
            // Bottom edge
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: handleSize, height: handleThickness)
            }
            
            // Left edge
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: handleThickness, height: handleSize)
                Spacer()
            }
            
            // Right edge
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: handleThickness, height: handleSize)
            }
        }
        .frame(width: width, height: height)
    }
}

struct ImageEditView_Previews: PreviewProvider {
    static var previews: some View {
        ImageEditView()
    }
}

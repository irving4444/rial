import SwiftUI
import Combine

class ImageCaptureViewModel: ObservableObject {
    @Published var attestedImage: AttestedImage?
    
    var capturedImage: UIImage? {
        guard let attested = attestedImage,
              let data = attested.imageData else {
            return nil
        }
        return UIImage(data: data)
    }

    let cameraVC = CameraViewController()

    func captureImage() {
        cameraVC.capturePhoto(captureCompletion: { [weak self] image, error in
            DispatchQueue.main.async {
                self?.attestedImage = image
                if image != nil {
                    print("Image captured and attested.")
                }
            }
        })
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ImageCaptureViewModel()
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                // Camera Preview
                HostedCameraViewController(viewModel: viewModel)
                    .edgesIgnoringSafeArea(.all)
                
                // UI Overlay
                VStack {
                    Spacer()
                    
                    // Preview thumbnail (if image captured)
                    if viewModel.capturedImage != nil {
                        Button(action: {
                            path.append("ImageEditView")
                        }) {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: viewModel.capturedImage ?? UIImage())
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white, lineWidth: 3)
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                                
                                // Edit icon badge
                                Image(systemName: "crop.rotate")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [.blue, .purple]),
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                    )
                                    .offset(x: 8, y: -8)
                            }
                        }
                        .padding(.bottom, 16)
                    }
                    
                    // Capture Button
                    Button(action: {
                        viewModel.captureImage()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 70, height: 70)
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 85, height: 85)
                        }
                    }
                    .padding(.bottom, 40)
                }
                .navigationDestination(for: String.self) { destination in
                    switch destination {
                    case "ImageEditView":
                        ImageEditView()
                            .environmentObject(viewModel)
                    default:
                        Text("Unknown destination")
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Rial")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.3), for: .navigationBar)
        }
    }
}


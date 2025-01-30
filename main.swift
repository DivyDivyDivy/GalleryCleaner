import SwiftUI
import Photos

struct ContentView: View {
    @State private var photos: [PHAsset] = []
    @State private var currentIndex = 0
    @State private var showPermissionAlert = false
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1.0
    @State private var isDeleting = false
    
    var body: some View {
        ZStack {
            if photos.isEmpty {
                VStack {
                    Text("Nessuna foto disponibile")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                        .onAppear { loadPhotos() }
                }
            } else {
                backgroundBlur()
                
                ZStack {
                    ImageLoader(asset: photos[currentIndex])
                        .frame(width: 320, height: 450)
                        .cornerRadius(20)
                        .shadow(radius: 10)
                        .opacity(opacity)
                        .offset(x: offset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = value.translation.width
                                    opacity = 1 - min(abs(value.translation.width) / 200, 0.5)
                                }
                                .onEnded { value in
                                    if value.translation.width > 100 {
                                        withAnimation(.easeOut(duration: 0.3)) {
                                            offset = 500
                                            opacity = 0
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            deleteCurrentPhoto()
                                        }
                                    } else if value.translation.width < -100 {
                                        withAnimation(.easeOut(duration: 0.3)) {
                                            offset = -500
                                            opacity = 0
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            nextPhoto()
                                        }
                                    } else {
                                        withAnimation(.spring()) {
                                            offset = 0
                                            opacity = 1
                                        }
                                    }
                                }
                        )
                }
            }
        }
        .alert(isPresented: $showPermissionAlert) {
            Alert(
                title: Text("Permesso Negato"),
                message: Text("Vai nelle impostazioni e abilita l'accesso alla libreria foto."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    func loadPhotos() {
        let status = PHPhotoLibrary.authorizationStatus()
        
        if status == .authorized || status == .limited {
            fetchPhotos()
        } else if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    fetchPhotos()
                } else {
                    showPermissionAlert = true
                }
            }
        } else {
            showPermissionAlert = true
        }
    }
    
    func fetchPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        DispatchQueue.main.async {
            self.photos = (0..<result.count).compactMap { result.object(at: $0) }
        }
    }
    
    func deleteCurrentPhoto() {
        guard currentIndex < photos.count else { return }
        
        let assetToDelete = photos[currentIndex]
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets([assetToDelete] as NSArray)
        } completionHandler: { success, error in
            if success {
                DispatchQueue.main.async {
                    self.photos.remove(at: self.currentIndex)
                    resetView()
                }
            }
        }
    }
    
    func nextPhoto() {
        if currentIndex < photos.count - 1 {
            currentIndex += 1
            resetView()
        }
    }
    
    func resetView() {
        withAnimation(.spring()) {
            offset = 0
            opacity = 1
        }
    }
    
    func backgroundBlur() -> some View {
        ImageLoader(asset: photos[currentIndex])
            .blur(radius: 30)
            .opacity(0.5)
            .edgesIgnoringSafeArea(.all)
    }
}

struct ImageLoader: View {
    let asset: PHAsset
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .onAppear { loadImage() }
            }
        }
    }
    
    func loadImage() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        
        manager.requestImage(for: asset, targetSize: CGSize(width: 320, height: 450), contentMode: .aspectFill, options: options) { image, _ in
            DispatchQueue.main.async {
                self.image = image
            }
        }
    }
}

@main
struct PhotoSwipeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
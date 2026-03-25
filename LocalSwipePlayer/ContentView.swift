import SwiftUI
import AVKit
import AVFoundation

struct FullScreenVideoPlayer: UIViewControllerRepresentable {
    var videoURL: URL
    @Binding var isPlaying: Bool
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = AVPlayer(url: videoURL)
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if isPlaying {
            uiViewController.player?.play()
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: uiViewController.player?.currentItem,
                queue: .main
            ) { _ in
                uiViewController.player?.seek(to: .zero)
                uiViewController.player?.play()
            }
        } else {
            uiViewController.player?.pause()
        }
    }
}

struct VideoItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ContentView: View {
    @State private var videos: [VideoItem] = []
    @State private var currentIndex = 0
    @State private var isPlaying = true
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $currentIndex) {
                ForEach(videos.indices, id: \.self) { index in
                    FullScreenVideoPlayer(
                        videoURL: videos[index].url,
                        isPlaying: $isPlaying
                    )
                    .ignoresSafeArea()
                    .tag(index)
                    .onTapGesture {
                        isPlaying.toggle()
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .rotationEffect(.degrees(-90))
            .frame(
                width: UIScreen.main.bounds.height,
                height: UIScreen.main.bounds.width
            )
        }
        .ignoresSafeArea()
        .statusBar(hidden: true)
        .onAppear(perform: loadLocalVideos)
        .onChange(of: currentIndex) { _ in
            isPlaying = true
        }
    }
    
    func loadLocalVideos() {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsDir, includingPropertiesForKeys: nil)
            self.videos = files
                .filter { $0.pathExtension.lowercased() == "mp4" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
                .map { VideoItem(url: $0) }
        } catch {
            print(error.localizedDescription)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

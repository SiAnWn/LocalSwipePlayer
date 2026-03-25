import SwiftUI
import AVKit
import AVFoundation

// 全屏视频播放器
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
            // 播放完毕自动循环
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

// 视频模型
struct VideoItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ContentView: View {
    // 核心修复：currentIndex改为【可选Int】，适配scrollPosition的Hashable?要求
    @State private var currentIndex: Int? = 0
    @State private var isPlaying = true
    @State private var videos: [VideoItem] = []
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if !videos.isEmpty {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(videos) { video in
                            FullScreenVideoPlayer(
                                videoURL: video.url,
                                isPlaying: $isPlaying
                            )
                            .frame(height: UIScreen.main.bounds.height)
                            .ignoresSafeArea()
                            .onTapGesture {
                                isPlaying.toggle() // 点击暂停/播放
                            }
                        }
                    }
                }
                // 核心修复：明确泛型为Int，绑定可选的currentIndex
                .scrollPosition(id: $currentIndex as Binding<Int?>)
                .scrollIndicators(.hidden) // 隐藏滚动条
                .onChange(of: currentIndex) { _ in
                    isPlaying = true // 切换视频自动播放
                }
            } else {
                // 无视频时的提示
                Text("未找到本地MP4视频\n请放入Documents文件夹")
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 16))
            }
        }
        .onAppear(perform: loadLocalVideos)
        .statusBar(hidden: true)
    }
    
    // 加载Documents文件夹中的MP4视频
    private func loadLocalVideos() {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsDir, includingPropertiesForKeys: nil)
            self.videos = files
                .filter { $0.pathExtension.lowercased() == "mp4" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
                .map { VideoItem(url: $0) }
            // 初始化索引（防止无视频时崩溃）
            if self.videos.count > 0 && currentIndex == nil {
                currentIndex = 0
            }
        } catch {
            print("加载视频失败：\(error.localizedDescription)")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

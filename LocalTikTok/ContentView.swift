import SwiftUI

struct ContentView: View {
    @EnvironmentObject var videoModel: VideoModel
    @State private var currentIndex: Int = 0
    @State private var showDeleteConfirm = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if videoModel.videos.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "video.slash")
                        .font(.largeTitle)
                    Text("请将视频文件放入应用 Documents 目录")
                        .multilineTextAlignment(.center)
                    Button("刷新") {
                        videoModel.loadVideos()
                    }
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            } else {
                VideoPageViewControllerWrapper(
                    videoModel: videoModel,
                    currentIndex: $currentIndex
                )
                .ignoresSafeArea()
            }
            
            // 刷新按钮
            Button(action: { videoModel.loadVideos() }) {
                Image(systemName: "arrow.clockwise")
                    .padding(12)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .foregroundColor(.white)
            }
            .padding()
            
            // 删除按钮
            if !videoModel.videos.isEmpty {
                Button(action: { showDeleteConfirm = true }) {
                    Image(systemName: "trash")
                        .padding(12)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                        .foregroundColor(.white)
                }
                .padding(.leading, 20)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .alert(isPresented: $showDeleteConfirm) {
                    Alert(
                        title: Text("删除视频"),
                        message: Text("确定要删除当前视频吗？"),
                        primaryButton: .destructive(Text("删除")) {
                            videoModel.deleteVideo(at: currentIndex)
                            if videoModel.videos.isEmpty {
                                currentIndex = 0
                            } else if currentIndex >= videoModel.videos.count {
                                currentIndex = videoModel.videos.count - 1
                            }
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
        .onAppear {
            videoModel.loadVideos()
            if videoModel.videos.indices.contains(videoModel.currentIndex) {
                currentIndex = videoModel.currentIndex
            } else {
                currentIndex = 0
            }
        }
    }
}

// 桥接 UIPageViewController 到 SwiftUI
struct VideoPageViewControllerWrapper: UIViewControllerRepresentable {
    let videoModel: VideoModel
    @Binding var currentIndex: Int
    
    func makeUIViewController(context: Context) -> VideoPageViewController {
        let vc = VideoPageViewController(videoModel: videoModel) { newIndex in
            DispatchQueue.main.async {
                currentIndex = newIndex
                videoModel.currentIndex = newIndex
                videoModel.savePosition()
            }
        }
        return vc
    }
    
    func updateUIViewController(_ uiViewController: VideoPageViewController, context: Context) {
        // 无需更新，因为滚动时会自动触发
    }
}

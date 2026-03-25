import SwiftUI

struct ContentView: View {
    @StateObject private var videoModel = VideoModel()
    @State private var currentIndex: Int = 0
    @State private var showDeleteConfirm = false
    
    var body: some View {
        GeometryReader { geometry in
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VideoCollectionView(
                        videos: videoModel.videos,
                        currentIndex: $currentIndex,
                        onVideoChanged: { newURL in
                            // 当滚动到新视频时，通知播放器加载
                            VideoPlayerManager.shared.loadVideo(url: newURL, autoPlay: true)
                        }
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .ignoresSafeArea()
                    .onAppear {
                        // 初始加载第一个视频
                        if let firstURL = videoModel.videos.first {
                            VideoPlayerManager.shared.loadVideo(url: firstURL, autoPlay: true)
                        }
                    }
                }
                
                // 刷新按钮
                Button(action: {
                    videoModel.loadVideos()
                }) {
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
                                // 如果删除后还有视频，重新加载当前视频
                                if !videoModel.videos.isEmpty {
                                    VideoPlayerManager.shared.loadVideo(url: videoModel.videos[currentIndex], autoPlay: true)
                                } else {
                                    VideoPlayerManager.shared.pause()
                                }
                            },
                            secondaryButton: .cancel()
                        )
                    }
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

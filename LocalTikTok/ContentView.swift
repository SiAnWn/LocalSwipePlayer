import SwiftUI

struct ContentView: View {
    @StateObject private var videoModel = VideoModel()
    @State private var currentIndex = 0
    
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
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(videoModel.videos.enumerated()), id: \.offset) { index, url in
                                VideoPlayerView(videoURL: url)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .onAppear {
                                        currentIndex = index
                                    }
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $currentIndex)
                    .ignoresSafeArea()
                }
                
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
            }
        }
        .onAppear {
            videoModel.loadVideos()
        }
    }
}

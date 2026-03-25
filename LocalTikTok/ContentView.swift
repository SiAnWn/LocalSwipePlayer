import SwiftUI

struct ContentView: View {
    @StateObject private var videoModel = VideoModel()  // 注意：改为 @StateObject
    @State private var currentIndex: Int = 0
    
    var body: some View {
        GeometryReader { geometry in
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
                VerticalPagingScrollView(
                    pageCount: videoModel.videos.count,
                    currentPage: $currentIndex
                ) { index in
                    VideoPlayerView(
                        videoURL: videoModel.videos[index],
                        fileName: videoModel.videos[index].lastPathComponent
                    )
                    .environmentObject(videoModel)  // 传递环境对象
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .onAppear {
                        // 更新全局索引
                        videoModel.currentIndex = index
                        // 预加载相邻视频
                        _ = videoModel.preloadItem(for: videoModel.videos[index])
                        if index > 0 {
                            _ = videoModel.preloadItem(for: videoModel.videos[index-1])
                        }
                        if index < videoModel.videos.count - 1 {
                            _ = videoModel.preloadItem(for: videoModel.videos[index+1])
                        }
                        videoModel.cleanupItems(except: videoModel.videos[index])
                    }
                }
                .ignoresSafeArea()
            }
        }
        .onAppear {
            videoModel.loadVideos()
            if videoModel.videos.indices.contains(videoModel.currentIndex) {
                currentIndex = videoModel.currentIndex
            } else {
                currentIndex = 0
                videoModel.currentIndex = 0
            }
        }
    }
}

// MARK: - 竖向分页滚动视图（兼容 iOS 15）
struct VerticalPagingScrollView<Content: View>: UIViewRepresentable {
    let pageCount: Int
    @Binding var currentPage: Int
    let content: (Int) -> Content

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.isPagingEnabled = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bounces = true
        scrollView.delegate = context.coordinator

        let containerView = UIHostingController(rootView: makeContentViews()).view!
        containerView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            containerView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            containerView.heightAnchor.constraint(equalToConstant: CGFloat(pageCount) * UIScreen.main.bounds.height)
        ])

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        let offsetY = CGFloat(currentPage) * uiView.bounds.height
        if uiView.contentOffset.y != offsetY {
            uiView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: true)
        }
        if let containerView = uiView.subviews.first {
            containerView.frame.size.height = CGFloat(pageCount) * uiView.bounds.height
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func makeContentViews() -> some View {
        ForEach(0..<pageCount, id: \.self) { index in
            content(index)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        }
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: VerticalPagingScrollView
        init(_ parent: VerticalPagingScrollView) {
            self.parent = parent
        }
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            let page = Int(scrollView.contentOffset.y / scrollView.bounds.height)
            if page != parent.currentPage {
                parent.currentPage = page
            }
        }
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                let page = Int(scrollView.contentOffset.y / scrollView.bounds.height)
                if page != parent.currentPage {
                    parent.currentPage = page
                }
            }
        }
    }
}

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
                    // 使用 UIKit 的 UIScrollView 实现竖向分页（兼容 iOS 15）
                    VerticalPagingScrollView(
                        pageCount: videoModel.videos.count,
                        currentPage: $currentIndex
                    ) { index in
                        VideoPlayerView(videoURL: videoModel.videos[index])
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                    .ignoresSafeArea()
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
            }
        }
        .onAppear {
            videoModel.loadVideos()
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

        // 设置内容大小和视图
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
        // 当外部 currentPage 改变时，滚动到对应页
        let offsetY = CGFloat(currentPage) * uiView.bounds.height
        if uiView.contentOffset.y != offsetY {
            uiView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: true)
        }
        // 如果页数变化，需要更新内容视图高度
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

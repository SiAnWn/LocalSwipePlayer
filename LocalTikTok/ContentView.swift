import SwiftUI

struct ContentView: View {
    @EnvironmentObject var videoModel: VideoModel
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
                    VerticalPagingScrollView(
                        pageCount: videoModel.videos.count,
                        currentPage: $currentIndex
                    ) { index in
                        VideoPlayerView(
                            videoURL: videoModel.videos[index],
                            fileName: videoModel.videos[index].lastPathComponent,
                            isActive: index == currentIndex
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .onAppear {
                            let url = videoModel.videos[index]
                            _ = videoModel.preloadItem(for: url)
                            if index > 0 {
                                _ = videoModel.preloadItem(for: videoModel.videos[index-1])
                            }
                            if index < videoModel.videos.count - 1 {
                                _ = videoModel.preloadItem(for: videoModel.videos[index+1])
                            }
                            videoModel.cleanupItems(except: url)
                            videoModel.currentIndex = index
                            videoModel.savePosition()
                        }
                    }
                    .ignoresSafeArea()
                }
                
                Button(action: { videoModel.loadVideos() }) {
                    Image(systemName: "arrow.clockwise")
                        .padding(12)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                        .foregroundColor(.white)
                }
                .padding()
                
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

// MARK: - 竖向分页滚动视图（支持向上滑动随机播放）
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
        var lastPage: Int = 0
        var isRandomJumping = false

        init(_ parent: VerticalPagingScrollView) {
            self.parent = parent
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            lastPage = parent.currentPage
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            guard !isRandomJumping else { return }
            let currentPageAfterScroll = Int(scrollView.contentOffset.y / scrollView.bounds.height)

            // 向上滑动（页码减小）则随机跳转
            if currentPageAfterScroll < lastPage {
                guard parent.pageCount > 1 else { return }
                var randomPage = Int.random(in: 0..<parent.pageCount)
                while randomPage == currentPageAfterScroll {
                    randomPage = Int.random(in: 0..<parent.pageCount)
                }
                isRandomJumping = true
                parent.currentPage = randomPage
                DispatchQueue.main.async {
                    self.isRandomJumping = false
                }
            } else {
                if currentPageAfterScroll != parent.currentPage {
                    parent.currentPage = currentPageAfterScroll
                }
            }
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                let currentPageAfterScroll = Int(scrollView.contentOffset.y / scrollView.bounds.height)
                if currentPageAfterScroll < lastPage {
                    guard parent.pageCount > 1 else { return }
                    var randomPage = Int.random(in: 0..<parent.pageCount)
                    while randomPage == currentPageAfterScroll {
                        randomPage = Int.random(in: 0..<parent.pageCount)
                    }
                    isRandomJumping = true
                    parent.currentPage = randomPage
                    DispatchQueue.main.async {
                        self.isRandomJumping = false
                    }
                } else {
                    if currentPageAfterScroll != parent.currentPage {
                        parent.currentPage = currentPageAfterScroll
                    }
                }
            }
        }
    }
}

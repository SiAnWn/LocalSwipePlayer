import SwiftUI

struct ContentView: View {
    @EnvironmentObject var videoModel: VideoModel
    @State private var currentIndex: Int = 0
    @State private var showDeleteConfirm = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                if videoModel.videos.isEmpty {
                    EmptyStateView()
                } else {
                    VerticalPagingScrollView(
                        pageCount: videoModel.videos.count,
                        currentPage: $currentIndex
                    ) { index in
                        // 明确返回 VideoPlayerView
                        VideoPlayerView(
                            videoURL: videoModel.videos[index],
                            playerItem: videoModel.preloadItem(for: videoModel.videos[index]),
                            fileName: videoModel.videos[index].lastPathComponent
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .onAppear {
                            videoModel.cleanupItems(except: videoModel.videos[index])
                            videoModel.currentIndex = index
                            videoModel.savePosition()
                        }
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
                
                // 删除按钮
                if !videoModel.videos.isEmpty {
                    Button(action: {
                        showDeleteConfirm = true
                    }) {
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

// MARK: - 空状态视图
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.slash")
                .font(.largeTitle)
            Text("请将视频文件放入应用 Documents 目录")
                .multilineTextAlignment(.center)
            Button("刷新") {
                // 通过环境对象刷新？需要在 ContentView 中处理，这里留空，实际通过外部的刷新按钮
            }
            .padding()
            .background(Color.blue)
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

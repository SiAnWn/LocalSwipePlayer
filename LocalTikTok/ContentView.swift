import SwiftUI
import AVFoundation

struct ContentView: View {
    @EnvironmentObject var videoModel: VideoModel
    @State private var currentIndex: Int = 0
    @State private var showDeleteConfirm = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var showControls = false
    @State private var showFileName = false
    @State private var showSpeedMenu = false
    @State private var speed: Float = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                if videoModel.videos.isEmpty {
                    EmptyStateView(refreshAction: { videoModel.loadVideos() })
                } else {
                    ZStack(alignment: .bottomLeading) {
                        // 播放器滚动视图
                        VerticalPagingScrollView(
                            pageCount: videoModel.videos.count,
                            currentPage: $currentIndex
                        ) { index in
                            VideoPlayerView(
                                url: videoModel.videos[index],
                                isActive: index == currentIndex
                            )
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                        .ignoresSafeArea()
                        .onTapGesture { toggleControls(); showFileNameBriefly() }
                        .onTapGesture(count: 2) { captureScreenshot() }
                        .onLongPressGesture(minimumDuration: 0.5) {
                            showSpeedMenu.toggle()
                            autoHideSpeedMenu()
                        }
                        .gesture(
                            DragGesture()
                                .onEnded { value in
                                    if value.translation.height < -50 && videoModel.videos.count > 1 {
                                        var randomIndex = Int.random(in: 0..<videoModel.videos.count)
                                        while randomIndex == currentIndex {
                                            randomIndex = Int.random(in: 0..<videoModel.videos.count)
                                        }
                                        withAnimation {
                                            currentIndex = randomIndex
                                        }
                                    }
                                }
                        )
                        
                        // 控制栏（进度条+时间）
                        if showControls {
                            ControlBarView(
                                currentTime: $currentTime,
                                duration: duration,
                                onSeek: { VideoPlayerManager.shared.seek(to: $0) }
                            )
                        }
                        
                        // 文件名浮层
                        if showFileName {
                            FileNameOverlayView(fileName: videoModel.videos[safe: currentIndex]?.lastPathComponent ?? "")
                        }
                        
                        // 倍速菜单
                        if showSpeedMenu {
                            SpeedMenuView(
                                speed: $speed,
                                onSpeedSelected: {
                                    VideoPlayerManager.shared.setRate(speed)
                                    showSpeedMenu = false
                                }
                            )
                        }
                    }
                }
                
                // 右上角刷新按钮
                RefreshButton(action: { videoModel.loadVideos() })
                
                // 左下角删除按钮
                if !videoModel.videos.isEmpty {
                    DeleteButton {
                        showDeleteConfirm = true
                    }
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
                if let firstURL = videoModel.videos.first {
                    VideoPlayerManager.shared.loadVideo(url: firstURL, autoPlay: true)
                }
            }
        }
    }
    
    // MARK: - 辅助方法
    private func toggleControls() {
        withAnimation { showControls = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showControls = false }
        }
    }
    
    private func showFileNameBriefly() {
        withAnimation { showFileName = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showFileName = false }
        }
    }
    
    private func autoHideSpeedMenu() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showSpeedMenu = false }
        }
    }
    
    private func captureScreenshot() {
        guard let currentURL = videoModel.videos[safe: currentIndex] else { return }
        let time = VideoPlayerManager.shared.currentTime
        let asset = AVAsset(url: currentURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        do {
            let cgImage = try generator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 600), actualTime: nil)
            let image = UIImage(cgImage: cgImage)
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            let alert = UIAlertController(title: nil, message: "截图已保存", preferredStyle: .alert)
            if let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows
                .first(where: { $0.isKeyWindow })?.rootViewController {
                rootVC.present(alert, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { alert.dismiss(animated: true) }
            }
        } catch {
            print("截图失败: \(error)")
        }
    }
}

// MARK: - 子视图组件
struct EmptyStateView: View {
    let refreshAction: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.slash")
                .font(.largeTitle)
            Text("请将视频文件放入应用 Documents 目录")
                .multilineTextAlignment(.center)
            Button("刷新", action: refreshAction)
                .padding()
                .background(Color.blue)
                .cornerRadius(8)
        }
    }
}

struct RefreshButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise")
                .padding(12)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
                .foregroundColor(.white)
        }
        .padding()
    }
}

struct DeleteButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
                .padding(12)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
                .foregroundColor(.white)
        }
        .padding(.leading, 20)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }
}

struct ControlBarView: View {
    @Binding var currentTime: TimeInterval
    let duration: TimeInterval
    let onSeek: (TimeInterval) -> Void
    
    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 8) {
                Slider(value: Binding(
                    get: { currentTime },
                    set: { onSeek($0) }
                ), in: 0...max(duration, 1))
                .accentColor(.white)
                .padding(.horizontal, 20)
                
                HStack {
                    Text(formatTime(currentTime))
                        .font(.caption)
                        .foregroundColor(.white)
                    Spacer()
                    Text(formatTime(duration))
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 30)
            .background(Color.black.opacity(0.5))
        }
        .transition(.opacity)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        if seconds.isNaN || seconds.isInfinite { return "00:00" }
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

struct FileNameOverlayView: View {
    let fileName: String
    var body: some View {
        VStack {
            Text(fileName)
                .font(.caption)
                .padding(8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
                .foregroundColor(.white)
                .padding(.top, 50)
            Spacer()
        }
        .transition(.opacity)
    }
}

struct SpeedMenuView: View {
    @Binding var speed: Float
    let onSpeedSelected: () -> Void
    let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(speeds, id: \.self) { sp in
                Button(action: {
                    speed = sp
                    onSpeedSelected()
                }) {
                    Text("\(sp)x")
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .frame(width: 80)
                        .background(speed == sp ? Color.blue : Color.black.opacity(0.7))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
        .transition(.scale)
    }
}

// MARK: - 竖向分页滚动视图
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

// 安全数组访问扩展
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

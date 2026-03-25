import SwiftUI

struct ContentView: View {
    @EnvironmentObject var videoModel: VideoModel
    @State private var currentIndex: Int = 0
    @State private var showDeleteConfirm = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var showControls = false
    @State private var hideControlsWorkItem: DispatchWorkItem?
    @State private var showFileName = false
    @State private var fileNameWorkItem: DispatchWorkItem?
    @State private var showSpeedMenu = false
    @State private var speed: Float = 1.0
    
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
                } else {
                    // 竖向分页滚动视图
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(videoModel.videos.enumerated()), id: \.offset) { index, url in
                                VideoPlayerView(
                                    url: url,
                                    currentTime: $currentTime,
                                    duration: $duration,
                                    isActive: index == currentIndex
                                )
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .onAppear {
                                    // 预加载相邻视频
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
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: $currentIndex)
                    .ignoresSafeArea()
                    .onChange(of: currentIndex) { newIndex in
                        // 当滚动结束时，切换到新视频
                        if newIndex < videoModel.videos.count {
                            let newURL = videoModel.videos[newIndex]
                            VideoPlayerManager.shared.loadVideo(url: newURL, autoPlay: true)
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                // 判断向上滑动（滑动距离大于阈值且垂直位移为负）
                                if value.translation.height < -50 {
                                    // 向上滑动：随机跳转
                                    guard videoModel.videos.count > 1 else { return }
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
                    
                    // 控制栏（进度条、时间、倍速等）
                    if showControls {
                        VStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Slider(value: Binding(
                                    get: { currentTime },
                                    set: { newValue in
                                        VideoPlayerManager.shared.seek(to: newValue)
                                    }
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
                    
                    // 文件名浮层
                    if showFileName {
                        VStack {
                            Text(videoModel.videos[safe: currentIndex]?.lastPathComponent ?? "")
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
                    
                    // 倍速菜单
                    if showSpeedMenu {
                        VStack(spacing: 12) {
                            ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { sp in
                                Button(action: {
                                    speed = sp
                                    VideoPlayerManager.shared.setRate(speed)
                                    showSpeedMenu = false
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
                // 加载第一个视频
                if let firstURL = videoModel.videos.first {
                    VideoPlayerManager.shared.loadVideo(url: firstURL, autoPlay: true)
                }
            }
            .onTapGesture(count: 2) {
                captureScreenshot()
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                showSpeedMenu.toggle()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { showSpeedMenu = false }
                }
            }
            .onTapGesture {
                toggleControls()
                showFileNameBriefly()
            }
        }
    }
    
    // MARK: - 辅助功能
    private func toggleControls() {
        hideControlsWorkItem?.cancel()
        withAnimation { showControls = true }
        let work = DispatchWorkItem { withAnimation { showControls = false } }
        hideControlsWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }
    
    private func showFileNameBriefly() {
        fileNameWorkItem?.cancel()
        withAnimation { showFileName = true }
        let work = DispatchWorkItem { withAnimation { showFileName = false } }
        fileNameWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
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
            // 简单提示
            let alert = UIAlertController(title: nil, message: "截图已保存", preferredStyle: .alert)
            if let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows
                .first(where: { $0.isKeyWindow })?.rootViewController {
                rootVC.present(alert, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    alert.dismiss(animated: true)
                }
            }
        } catch {
            print("截图失败: \(error)")
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        if seconds.isNaN || seconds.isInfinite { return "00:00" }
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

// 安全数组访问扩展
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

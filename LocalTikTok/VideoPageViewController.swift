import UIKit
import SwiftUI
import AVFoundation
import MediaPlayer  // 添加 MediaPlayer 支持 MPVolumeView

class VideoPageViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    private var viewControllersCache: [UIViewController] = []
    private let videoModel: VideoModel
    private let onPageChanged: (Int) -> Void
    private var lastPage: Int = 0
    private var isRandomJumping = false

    init(videoModel: VideoModel, onPageChanged: @escaping (Int) -> Void) {
        self.videoModel = videoModel
        self.onPageChanged = onPageChanged
        super.init(transitionStyle: .scroll, navigationOrientation: .vertical, options: nil)
        self.dataSource = self
        self.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewControllersCache()
        if let firstVC = getViewController(at: videoModel.currentIndex) {
            setViewControllers([firstVC], direction: .forward, animated: false, completion: nil)
        }
    }
    
    private func setupViewControllersCache() {
        viewControllersCache = videoModel.videos.map { url in
            let containerVC = VideoPlayerContainerViewController()
            containerVC.videoURL = url
            containerVC.videoModel = videoModel
            return containerVC
        }
    }
    
    func getViewController(at index: Int) -> UIViewController? {
        guard index >= 0 && index < viewControllersCache.count else { return nil }
        return viewControllersCache[index]
    }
    
    // MARK: - UIPageViewControllerDataSource
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let currentVC = viewController as? VideoPlayerContainerViewController,
              let currentIndex = videoModel.videos.firstIndex(of: currentVC.videoURL) else { return nil }
        let previousIndex = currentIndex - 1
        return getViewController(at: previousIndex)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let currentVC = viewController as? VideoPlayerContainerViewController,
              let currentIndex = videoModel.videos.firstIndex(of: currentVC.videoURL) else { return nil }
        let nextIndex = currentIndex + 1
        return getViewController(at: nextIndex)
    }
    
    // MARK: - UIPageViewControllerDelegate
    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        if let currentVC = viewControllers?.first as? VideoPlayerContainerViewController,
           let currentIndex = videoModel.videos.firstIndex(of: currentVC.videoURL) {
            lastPage = currentIndex
        }
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed, let currentVC = viewControllers?.first as? VideoPlayerContainerViewController,
              let newIndex = videoModel.videos.firstIndex(of: currentVC.videoURL) else { return }
        
        // 向上滑动随机跳转（新索引小于旧索引）
        if newIndex < lastPage && videoModel.videos.count > 1 {
            var randomIndex = Int.random(in: 0..<videoModel.videos.count)
            while randomIndex == newIndex {
                randomIndex = Int.random(in: 0..<videoModel.videos.count)
            }
            if let randomVC = getViewController(at: randomIndex) {
                isRandomJumping = true
                setViewControllers([randomVC], direction: .forward, animated: true) { [weak self] _ in
                    self?.isRandomJumping = false
                }
                videoModel.currentIndex = randomIndex
                onPageChanged(randomIndex)
                return
            }
        }
        
        videoModel.currentIndex = newIndex
        onPageChanged(newIndex)
    }
}

class VideoPlayerContainerViewController: UIViewController {
    var videoURL: URL!
    weak var videoModel: VideoModel!
    private var playerLayer: AVPlayerLayer?
    private var isActive = false
    private var fileNameLabel: UILabel?
    private var controlsView: UIView?
    private var progressSlider: UISlider?
    private var currentTimeLabel: UILabel?
    private var durationLabel: UILabel?
    private var speedMenu: UIStackView?
    private var hideControlsTimer: Timer?
    private var hideFileNameTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        setupGestures()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isActive = true
        if VideoPlayerManager.shared.currentURL != videoURL {
            VideoPlayerManager.shared.loadVideo(url: videoURL, autoPlay: true)
        } else {
            if !VideoPlayerManager.shared.isPlaying {
                VideoPlayerManager.shared.play()
            }
        }
        // 添加播放器层
        if playerLayer == nil, let layer = VideoPlayerManager.shared.getPlayerLayer() {
            layer.frame = view.bounds
            view.layer.insertSublayer(layer, at: 0)
            playerLayer = layer
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isActive = false
        VideoPlayerManager.shared.pause()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.bounds
    }
    
    private func setupUI() {
        // 文件名标签
        fileNameLabel = UILabel()
        fileNameLabel?.text = videoURL.lastPathComponent
        fileNameLabel?.textColor = .white
        fileNameLabel?.font = .systemFont(ofSize: 12)
        fileNameLabel?.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        fileNameLabel?.textAlignment = .center
        fileNameLabel?.layer.cornerRadius = 8
        fileNameLabel?.clipsToBounds = true
        fileNameLabel?.alpha = 0
        view.addSubview(fileNameLabel!)
        fileNameLabel?.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            fileNameLabel!.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            fileNameLabel!.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            fileNameLabel!.heightAnchor.constraint(equalToConstant: 30),
            fileNameLabel!.widthAnchor.constraint(greaterThanOrEqualToConstant: 100)
        ])
        
        // 控制栏
        controlsView = UIView()
        controlsView?.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        controlsView?.alpha = 0
        view.addSubview(controlsView!)
        controlsView?.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            controlsView!.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsView!.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlsView!.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            controlsView!.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        progressSlider = UISlider()
        progressSlider?.minimumTrackTintColor = .white
        progressSlider?.maximumTrackTintColor = .gray
        progressSlider?.thumbTintColor = .white
        controlsView?.addSubview(progressSlider!)
        progressSlider?.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            progressSlider!.leadingAnchor.constraint(equalTo: controlsView!.leadingAnchor, constant: 20),
            progressSlider!.trailingAnchor.constraint(equalTo: controlsView!.trailingAnchor, constant: -20),
            progressSlider!.topAnchor.constraint(equalTo: controlsView!.topAnchor, constant: 15)
        ])
        
        currentTimeLabel = UILabel()
        currentTimeLabel?.textColor = .white
        currentTimeLabel?.font = .systemFont(ofSize: 12)
        durationLabel = UILabel()
        durationLabel?.textColor = .white
        durationLabel?.font = .systemFont(ofSize: 12)
        let timeStack = UIStackView(arrangedSubviews: [currentTimeLabel!, durationLabel!])
        timeStack.axis = .horizontal
        timeStack.distribution = .equalSpacing
        controlsView?.addSubview(timeStack)
        timeStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            timeStack.leadingAnchor.constraint(equalTo: controlsView!.leadingAnchor, constant: 20),
            timeStack.trailingAnchor.constraint(equalTo: controlsView!.trailingAnchor, constant: -20),
            timeStack.topAnchor.constraint(equalTo: progressSlider!.bottomAnchor, constant: 8)
        ])
        
        // 定时更新 UI
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.isActive else { return }
            self.progressSlider?.value = Float(VideoPlayerManager.shared.currentTime)
            self.durationLabel?.text = self.formatTime(VideoPlayerManager.shared.duration)
            self.currentTimeLabel?.text = self.formatTime(VideoPlayerManager.shared.currentTime)
        }
        
        progressSlider?.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
    }
    
    @objc private func sliderChanged() {
        let newTime = TimeInterval(progressSlider?.value ?? 0)
        VideoPlayerManager.shared.seek(to: newTime)
    }
    
    private func setupGestures() {
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        singleTap.numberOfTapsRequired = 1
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        view.addGestureRecognizer(singleTap)
        view.addGestureRecognizer(doubleTap)
        view.addGestureRecognizer(longPress)
        singleTap.require(toFail: doubleTap)
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        view.addGestureRecognizer(pan)
    }
    
    @objc private func handleTap() {
        showFileNameTemporarily()
        showControlsTemporarily()
    }
    
    @objc private func handleDoubleTap() {
        captureScreenshot()
    }
    
    @objc private func handleLongPress() {
        showSpeedMenu()
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let deltaY = translation.y / view.bounds.height
        let location = gesture.location(in: view)
        let isLeft = location.x < view.bounds.width / 2
        
        if gesture.state == .changed {
            if isLeft {
                let newBrightness = UIScreen.main.brightness - deltaY
                UIScreen.main.brightness = min(max(newBrightness, 0), 1)
            } else {
                let volumeView = MPVolumeView()
                if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
                    let newVolume = slider.value - Float(deltaY)
                    slider.value = min(max(newVolume, 0), 1)
                }
            }
        }
        gesture.setTranslation(.zero, in: view)
    }
    
    private func showFileNameTemporarily() {
        UIView.animate(withDuration: 0.2) {
            self.fileNameLabel?.alpha = 1
        }
        hideFileNameTimer?.invalidate()
        hideFileNameTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { _ in
            UIView.animate(withDuration: 0.2) {
                self.fileNameLabel?.alpha = 0
            }
        }
    }
    
    private func showControlsTemporarily() {
        UIView.animate(withDuration: 0.2) {
            self.controlsView?.alpha = 1
        }
        hideControlsTimer?.invalidate()
        hideControlsTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { _ in
            UIView.animate(withDuration: 0.2) {
                self.controlsView?.alpha = 0
            }
        }
    }
    
    private func showSpeedMenu() {
        if speedMenu == nil {
            speedMenu = UIStackView()
            speedMenu?.axis = .vertical
            speedMenu?.spacing = 8
            speedMenu?.backgroundColor = UIColor.black.withAlphaComponent(0.8)
            speedMenu?.layer.cornerRadius = 12
            speedMenu?.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
            speedMenu?.isLayoutMarginsRelativeArrangement = true
            view.addSubview(speedMenu!)
            speedMenu?.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                speedMenu!.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                speedMenu!.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                speedMenu!.widthAnchor.constraint(equalToConstant: 100)
            ])
            
            for sp in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0] {
                let button = UIButton(type: .system)
                button.setTitle("\(sp)x", for: .normal)
                button.setTitleColor(.white, for: .normal)
                button.backgroundColor = UIColor.black.withAlphaComponent(0.7)
                button.layer.cornerRadius = 8
                button.tag = Int(sp * 100)
                button.addTarget(self, action: #selector(speedSelected(_:)), for: .touchUpInside)
                speedMenu?.addArrangedSubview(button)
                button.heightAnchor.constraint(equalToConstant: 40).isActive = true
            }
        }
        speedMenu?.isHidden = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.speedMenu?.isHidden = true
        }
    }
    
    @objc private func speedSelected(_ sender: UIButton) {
        let speed = Float(sender.tag) / 100.0
        VideoPlayerManager.shared.setRate(speed)
        speedMenu?.isHidden = true
    }
    
    private func captureScreenshot() {
        let time = VideoPlayerManager.shared.currentTime
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        do {
            let cgImage = try generator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 600), actualTime: nil)
            let image = UIImage(cgImage: cgImage)
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            let alert = UIAlertController(title: nil, message: "截图已保存", preferredStyle: .alert)
            present(alert, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                alert.dismiss(animated: true)
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

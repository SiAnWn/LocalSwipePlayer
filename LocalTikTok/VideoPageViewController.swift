import UIKit
import SwiftUI

class VideoPageViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    private var viewControllersCache: [UIViewController] = []
    private let videoModel: VideoModel
    private let onPageChanged: (Int) -> Void
    
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
        if let firstVC = viewController(at: videoModel.currentIndex) {
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
    
    func viewController(at index: Int) -> UIViewController? {
        guard index >= 0 && index < viewControllersCache.count else { return nil }
        return viewControllersCache[index]
    }
    
    // MARK: - UIPageViewControllerDataSource
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let currentVC = viewController as? VideoPlayerContainerViewController,
              let currentIndex = videoModel.videos.firstIndex(of: currentVC.videoURL) else { return nil }
        let previousIndex = currentIndex - 1
        guard previousIndex >= 0 else { return nil }
        return viewController(at: previousIndex)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let currentVC = viewController as? VideoPlayerContainerViewController,
              let currentIndex = videoModel.videos.firstIndex(of: currentVC.videoURL) else { return nil }
        let nextIndex = currentIndex + 1
        guard nextIndex < videoModel.videos.count else { return nil }
        return viewController(at: nextIndex)
    }
    
    // MARK: - UIPageViewControllerDelegate
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        guard completed,
              let currentVC = viewControllers?.first as? VideoPlayerContainerViewController,
              let newIndex = videoModel.videos.firstIndex(of: currentVC.videoURL) else { return }
        videoModel.currentIndex = newIndex
        onPageChanged(newIndex)
    }
}

// 每个页面的容器视图控制器，用于显示播放器层并添加手势等 UI
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
        setupPlayerLayer()
        setupUI()
        setupGestures()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isActive = true
        // 如果当前播放器的 URL 与此页不同，则加载
        if VideoPlayerManager.shared.currentURL != videoURL {
            VideoPlayerManager.shared.loadVideo(url: videoURL, autoPlay: true)
        } else {
            // 相同则确保播放
            if !VideoPlayerManager.shared.isPlaying {
                VideoPlayerManager.shared.play()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isActive = false
        VideoPlayerManager.shared.pause()
    }
    
    private func setupPlayerLayer() {
        playerLayer = VideoPlayerManager.shared.getPlayerLayer()
        playerLayer?.frame = view.bounds
        if let layer = playerLayer {
            view.layer.insertSublayer(layer, at: 0)
        }
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
        
        // 更新 UI 的定时器
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
        
        // 亮度/音量手势
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
        
        if gesture.state == .began {
            if isLeft {
                UIScreen.main.brightness = UIScreen.main.brightness
            } else {
                // 音量
            }
        } else if gesture.state == .changed {
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
        guard let playerLayer = playerLayer else { return }
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

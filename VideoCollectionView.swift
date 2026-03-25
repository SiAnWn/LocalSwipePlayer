import SwiftUI
import UIKit

struct VideoCollectionView: UIViewRepresentable {
    let videos: [URL]
    @Binding var currentIndex: Int
    let onVideoChanged: (URL) -> Void
    
    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.itemSize = UIScreen.main.bounds.size
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.isPagingEnabled = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.backgroundColor = .black
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.register(VideoCell.self, forCellWithReuseIdentifier: "VideoCell")
        return collectionView
    }
    
    func updateUIView(_ uiView: UICollectionView, context: Context) {
        if uiView.contentOffset.y != CGFloat(currentIndex) * uiView.bounds.height {
            uiView.setContentOffset(CGPoint(x: 0, y: CGFloat(currentIndex) * uiView.bounds.height), animated: false)
        }
        context.coordinator.parent = self
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
        var parent: VideoCollectionView
        
        init(_ parent: VideoCollectionView) {
            self.parent = parent
        }
        
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            parent.videos.count
        }
        
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "VideoCell", for: indexPath) as! VideoCell
            let url = parent.videos[indexPath.item]
            cell.configure(with: url)
            return cell
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            let page = Int(scrollView.contentOffset.y / scrollView.bounds.height)
            if page != parent.currentIndex {
                parent.currentIndex = page
                let newURL = parent.videos[page]
                parent.onVideoChanged(newURL)
            }
        }
        
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                let page = Int(scrollView.contentOffset.y / scrollView.bounds.height)
                if page != parent.currentIndex {
                    parent.currentIndex = page
                    let newURL = parent.videos[page]
                    parent.onVideoChanged(newURL)
                }
            }
        }
    }
}

class VideoCell: UICollectionViewCell {
    private var playerView: UIView? // 用于承载 AVPlayerLayer
    private var url: URL?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with url: URL) {
        self.url = url
        // 不需要在这里创建播放器，只显示占位黑色背景即可
        // 播放器由全局单例管理，我们只需要在 Cell 上显示播放器的 layer
        setupPlayerLayer()
    }
    
    private func setupPlayerLayer() {
        guard let playerLayer = VideoPlayerManager.shared.player?.currentItem?.asset as? AVURLAsset,
              playerLayer.url == url else {
            // 如果当前全局播放器不是播放这个 URL，先移除 layer
            playerView?.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
            return
        }
        // 将播放器的 layer 添加到 cell 上
        let playerLayer = VideoPlayerManager.shared.player?.currentItem?.asset as? AVURLAsset
        guard let layer = VideoPlayerManager.shared.player?.layer as? AVPlayerLayer else { return }
        layer.frame = contentView.bounds
        contentView.layer.addSublayer(layer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // 确保 layer 的 frame 适应 cell 大小
        if let playerLayer = VideoPlayerManager.shared.player?.layer as? AVPlayerLayer {
            playerLayer.frame = contentView.bounds
        }
    }
}

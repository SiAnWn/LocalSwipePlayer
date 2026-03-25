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
        // 同步 contentOffset
        let targetOffset = CGFloat(currentIndex) * uiView.bounds.height
        if abs(uiView.contentOffset.y - targetOffset) > 0.1 {
            uiView.setContentOffset(CGPoint(x: 0, y: targetOffset), animated: false)
        }
        context.coordinator.parent = self
        
        // 每次更新时，确保当前 cell 上的播放器 layer 正确
        context.coordinator.attachPlayerLayerToCurrentCell(collectionView: uiView)
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
            return cell
        }
        
        // 将播放器 layer 附加到当前显示的 cell 上
        func attachPlayerLayerToCurrentCell(collectionView: UICollectionView) {
            let visibleCells = collectionView.visibleCells
            guard let currentCell = visibleCells.first(where: { collectionView.indexPath(for: $0)?.item == parent.currentIndex }) as? VideoCell else {
                return
            }
            // 从所有 cell 移除播放器 layer
            for cell in visibleCells {
                (cell as? VideoCell)?.removePlayerLayer()
            }
            // 获取播放器 layer
            guard let playerLayer = VideoPlayerManager.shared.playerLayer else { return }
            currentCell.addPlayerLayer(playerLayer)
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            let page = Int(scrollView.contentOffset.y / scrollView.bounds.height)
            if page != parent.currentIndex {
                parent.currentIndex = page
                let newURL = parent.videos[page]
                parent.onVideoChanged(newURL)
            }
            attachPlayerLayerToCurrentCell(collectionView: scrollView as! UICollectionView)
        }
        
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                let page = Int(scrollView.contentOffset.y / scrollView.bounds.height)
                if page != parent.currentIndex {
                    parent.currentIndex = page
                    let newURL = parent.videos[page]
                    parent.onVideoChanged(newURL)
                }
                attachPlayerLayerToCurrentCell(collectionView: scrollView as! UICollectionView)
            }
        }
    }
}

class VideoCell: UICollectionViewCell {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func removePlayerLayer() {
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
    }
    
    func addPlayerLayer(_ playerLayer: AVPlayerLayer) {
        removePlayerLayer()
        playerLayer.frame = bounds
        layer.addSublayer(playerLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if let playerLayer = layer.sublayers?.first(where: { $0 is AVPlayerLayer }) as? AVPlayerLayer {
            playerLayer.frame = bounds
        }
    }
}

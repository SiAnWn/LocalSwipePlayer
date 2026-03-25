import SwiftUI
import UIKit
import AVFoundation

struct VideoPlayerView: UIViewRepresentable {
    let url: URL
    let isActive: Bool
    @EnvironmentObject var videoModel: VideoModel
    @Binding var currentTime: TimeInterval
    @Binding var duration: TimeInterval
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // 预加载当前视频
        _ = videoModel.preloadItem(for: url)
        // 预加载相邻视频
        if let index = videoModel.videos.firstIndex(of: url) {
            if index > 0 { _ = videoModel.preloadItem(for: videoModel.videos[index-1]) }
            if index < videoModel.videos.count - 1 { _ = videoModel.preloadItem(for: videoModel.videos[index+1]) }
        }
        
        // 清理其他缓存
        videoModel.cleanupItems(except: url)
        
        if VideoPlayerManager.shared.currentURL == url {
            if let layer = VideoPlayerManager.shared.getPlayerLayer() {
                if layer.superlayer != uiView.layer {
                    layer.frame = uiView.bounds
                    uiView.layer.addSublayer(layer)
                } else {
                    layer.frame = uiView.bounds
                }
            }
        } else if isActive {
            VideoPlayerManager.shared.loadVideo(url: url, autoPlay: true)
        }
        
        // 保存当前位置
        if isActive {
            videoModel.currentIndex = videoModel.videos.firstIndex(of: url) ?? 0
            videoModel.savePosition()
        }
    }
}

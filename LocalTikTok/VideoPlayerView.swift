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
        // 清理其他缓存
        videoModel.cleanupItems(except: url)
        
        if VideoPlayerManager.shared.currentURL == url {
            // 如果当前播放器正在播放此视频，添加或更新 layer
            if let layer = VideoPlayerManager.shared.getPlayerLayer() {
                if layer.superlayer != uiView.layer {
                    layer.frame = uiView.bounds
                    uiView.layer.addSublayer(layer)
                } else {
                    layer.frame = uiView.bounds
                }
            }
        } else if isActive {
            // 如果当前视图变为激活，但播放器未播放此视频，则切换
            VideoPlayerManager.shared.loadVideo(url: url, autoPlay: true)
        }
        
        // 如果是激活状态，更新模型中的索引和保存位置
        if isActive, let index = videoModel.videos.firstIndex(of: url) {
            videoModel.currentIndex = index
            videoModel.savePosition()
        }
    }
}

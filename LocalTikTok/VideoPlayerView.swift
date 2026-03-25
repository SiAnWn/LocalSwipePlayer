import SwiftUI
import AVKit
import UIKit

struct VideoPlayerView: UIViewRepresentable {
    let url: URL
    @Binding var currentTime: TimeInterval
    @Binding var duration: TimeInterval
    let isActive: Bool
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // 如果当前播放器的 URL 与此视图的 URL 匹配，则添加或更新 layer
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
            // 如果当前视图变为激活，但播放器正在播放其他视频，则切换
            VideoPlayerManager.shared.loadVideo(url: url, autoPlay: true)
        }
    }
}

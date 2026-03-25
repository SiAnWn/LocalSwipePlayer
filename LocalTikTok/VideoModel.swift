import Foundation
import SwiftUI
import AVFoundation
import UIKit  // 添加用于弹窗

class VideoModel: ObservableObject {
    @Published var videos: [URL] = []
    @Published var currentIndex: Int = 0
    @Published var currentTime: TimeInterval = 0
    
    private var playerItems: [URL: AVPlayerItem] = [:]
    let supportedExtensions = ["mp4", "mov", "m4v", "avi", "mkv", "flv", "3gp", "webm"]
    private let lastIndexKey = "lastVideoIndex"
    private let lastTimeKey = "lastVideoTime"
    
    init() {
        loadVideos()
        loadSavedPosition()
    }
    
    func loadVideos() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        var message = "Documents 路径: \(documentsPath.path)\n"
        
        do {
            let allFiles = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            let fileNames = allFiles.map { $0.lastPathComponent }
            message += "所有文件: \(fileNames)\n"
            
            let videoFiles = allFiles.filter { url in
                let ext = url.pathExtension.lowercased()
                return supportedExtensions.contains(ext)
            }
            let videoNames = videoFiles.map { $0.lastPathComponent }
            message += "匹配视频: \(videoNames)"
            
            DispatchQueue.main.async {
                self.videos = videoFiles.sorted { $0.lastPathComponent < $1.lastPathComponent }
                self.playerItems.removeAll()
                if self.currentIndex >= self.videos.count {
                    self.currentIndex = max(0, self.videos.count - 1)
                }
                // 弹窗显示信息（仅在首次加载时）
                if self.videos.isEmpty {
                    self.showAlert(message: "未找到视频文件\n\n\(message)")
                } else {
                    self.showAlert(message: "找到 \(self.videos.count) 个视频\n\n\(message)")
                }
            }
        } catch {
            message += "读取目录失败: \(error)"
            DispatchQueue.main.async {
                self.videos = []
                self.showAlert(message: message)
            }
        }
    }
    
    private func showAlert(message: String) {
        // 延迟确保视图加载完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let alert = UIAlertController(title: "调试信息", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            if let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows
                .first(where: { $0.isKeyWindow })?.rootViewController {
                rootVC.present(alert, animated: true)
            }
        }
    }
    
    // 其他方法不变...
    func preloadItem(for url: URL) -> AVPlayerItem? { ... }
    func cleanupItems(except current: URL) { ... }
    func savePosition() { ... }
    func loadSavedPosition() { ... }
    func deleteVideo(at index: Int) { ... }
}

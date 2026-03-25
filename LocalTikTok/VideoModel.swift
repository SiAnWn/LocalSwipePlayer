import Foundation
import SwiftUI
import AVFoundation
import UIKit

class VideoModel: ObservableObject {
    @Published var videos: [URL] = []
    @Published var currentIndex: Int = 0
    @Published var currentTime: TimeInterval = 0
    
    // 存储每个 URL 对应的 AVPlayerItem（预加载用）
    private var playerItems: [URL: AVPlayerItem] = [:]
    
    // 支持的视频格式（可扩展）
    let supportedExtensions = ["mp4", "mov", "m4v", "avi", "mkv", "flv", "3gp", "webm"]
    
    // 用于记忆播放位置的 UserDefaults 键
    private let lastIndexKey = "lastVideoIndex"
    private let lastTimeKey = "lastVideoTime"
    
    init() {
        loadVideos()
        loadSavedPosition()
    }
    
    // MARK: - 视频列表加载
    func loadVideos() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let allFiles = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            let videoFiles = allFiles.filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
            DispatchQueue.main.async {
                self.videos = videoFiles.sorted { $0.lastPathComponent < $1.lastPathComponent }
                self.playerItems.removeAll()
                // 如果列表变化，重置索引
                if self.currentIndex >= self.videos.count {
                    self.currentIndex = max(0, self.videos.count - 1)
                }
            }
        } catch {
            DispatchQueue.main.async { self.videos = [] }
        }
    }
    
    // MARK: - 预加载 PlayerItem
    func preloadItem(for url: URL) -> AVPlayerItem? {
        if let existing = playerItems[url] { return existing }
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 5.0
        playerItems[url] = item
        asset.loadValuesAsynchronously(forKeys: ["tracks"]) { }
        return item
    }
    
    // 清理不用的 Item
    func cleanupItems(except current: URL) {
        for (url, _) in playerItems where url != current {
            playerItems[url] = nil
        }
    }
    
    // MARK: - 记忆播放位置
    func savePosition() {
        UserDefaults.standard.set(currentIndex, forKey: lastIndexKey)
        UserDefaults.standard.set(currentTime, forKey: lastTimeKey)
    }
    
    func loadSavedPosition() {
        currentIndex = UserDefaults.standard.integer(forKey: lastIndexKey)
        currentTime = UserDefaults.standard.double(forKey: lastTimeKey)
        // 防止索引越界
        if currentIndex >= videos.count {
            currentIndex = 0
        }
    }
    
    // MARK: - 播放列表管理（删除视频）
    func deleteVideo(at index: Int) {
        guard index < videos.count else { return }
        let url = videos[index]
        do {
            try FileManager.default.removeItem(at: url)
            // 重新加载列表
            loadVideos()
            // 调整当前索引
            if videos.isEmpty {
                currentIndex = 0
            } else if index < videos.count {
                currentIndex = index
            } else {
                currentIndex = videos.count - 1
            }
        } catch {
            print("删除失败: \(error)")
        }
    }
}

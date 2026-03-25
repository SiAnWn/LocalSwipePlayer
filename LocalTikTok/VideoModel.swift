import Foundation
import SwiftUI
import AVFoundation

class VideoModel: ObservableObject {
    @Published var videos: [URL] = []
    @Published var currentIndex: Int = 0
    @Published var currentTime: TimeInterval = 0
    
    private var playerItems: [URL: AVPlayerItem] = [:]
    // 支持的小写扩展名
    let supportedExtensions = ["mp4", "mov", "m4v", "avi", "mkv", "flv", "3gp", "webm"]
    private let lastIndexKey = "lastVideoIndex"
    private let lastTimeKey = "lastVideoTime"
    
    init() {
        loadVideos()
        loadSavedPosition()
    }
    
    func loadVideos() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        // 调试：打印 Documents 路径（可在 Xcode 控制台查看）
        print("Documents 路径: \(documentsPath.path)")
        
        do {
            let allFiles = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            print("所有文件: \(allFiles.map { $0.lastPathComponent })")  // 调试
            
            // 不区分大小写匹配扩展名
            let videoFiles = allFiles.filter { url in
                let ext = url.pathExtension.lowercased()
                return supportedExtensions.contains(ext)
            }
            DispatchQueue.main.async {
                self.videos = videoFiles.sorted { $0.lastPathComponent < $1.lastPathComponent }
                self.playerItems.removeAll()
                if self.currentIndex >= self.videos.count {
                    self.currentIndex = max(0, self.videos.count - 1)
                }
                // 调试：打印找到的视频文件
                print("找到视频: \(self.videos.map { $0.lastPathComponent })")
            }
        } catch {
            print("读取目录失败: \(error)")
            DispatchQueue.main.async { self.videos = [] }
        }
    }
    
    func preloadItem(for url: URL) -> AVPlayerItem? {
        if let existing = playerItems[url] { return existing }
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 5.0
        playerItems[url] = item
        asset.loadValuesAsynchronously(forKeys: ["tracks"]) { }
        return item
    }
    
    func cleanupItems(except current: URL) {
        for (url, _) in playerItems where url != current {
            playerItems[url] = nil
        }
    }
    
    func savePosition() {
        UserDefaults.standard.set(currentIndex, forKey: lastIndexKey)
        UserDefaults.standard.set(currentTime, forKey: lastTimeKey)
    }
    
    func loadSavedPosition() {
        currentIndex = UserDefaults.standard.integer(forKey: lastIndexKey)
        currentTime = UserDefaults.standard.double(forKey: lastTimeKey)
        if currentIndex >= videos.count {
            currentIndex = 0
        }
    }
    
    func deleteVideo(at index: Int) {
        guard index < videos.count else { return }
        let url = videos[index]
        do {
            try FileManager.default.removeItem(at: url)
            loadVideos()
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

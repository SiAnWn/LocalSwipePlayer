import Foundation
import SwiftUI
import AVFoundation
import UIKit

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
        do {
            let allFiles = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            let videoFiles = allFiles.filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
            DispatchQueue.main.async {
                self.videos = videoFiles.sorted { $0.lastPathComponent < $1.lastPathComponent }
                self.playerItems.removeAll()
                if self.currentIndex >= self.videos.count {
                    self.currentIndex = max(0, self.videos.count - 1)
                }
            }
        } catch {
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

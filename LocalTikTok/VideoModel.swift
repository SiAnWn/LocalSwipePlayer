import Foundation
import SwiftUI
import AVFoundation

class VideoModel: ObservableObject {
    @Published var videos: [URL] = []
    
    func loadVideos() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        let supportedExtensions = ["mp4", "mov", "m4v", "avi", "mkv"]
        let fileManager = FileManager.default
        
        do {
            let allFiles = try fileManager.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            let videoFiles = allFiles.filter { url in
                supportedExtensions.contains(url.pathExtension.lowercased())
            }
            DispatchQueue.main.async {
                self.videos = videoFiles.sorted { $0.lastPathComponent < $1.lastPathComponent }
            }
        } catch {
            print("读取目录失败: \(error)")
            DispatchQueue.main.async {
                self.videos = []
            }
        }
    }
}

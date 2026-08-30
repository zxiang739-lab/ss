//
//  MediaAsset.swift
//  MediaEnhancer
//
//  媒体资源模型 — 图片 / 视频
//

import UIKit
import AVFoundation

/// 媒体类型
enum MediaType {
    case image
    case video
}

/// 预览对比模式
enum PreviewMode: String, CaseIterable, Identifiable {
    case original = "原图"
    case enhanced = "增强"
    case split = "对比"

    var id: String { rawValue }
}

/// 媒体资源封装
struct MediaAsset: Identifiable {
    let id = UUID()
    let type: MediaType
    let fileName: String
    let pixelSize: CGSize
    let duration: TimeInterval // 视频时长，图片为 0

    // 图片
    var originalImage: UIImage?
    var enhancedImage: UIImage?

    // 视频
    var assetURL: URL?
    var playerItem: AVPlayerItem?

    init(image: UIImage, fileName: String = "Image") {
        self.type = .image
        self.fileName = fileName
        self.pixelSize = image.size
        self.duration = 0
        self.originalImage = image
        self.enhancedImage = nil
        self.assetURL = nil
        self.playerItem = nil
    }

    init(videoURL: URL, fileName: String, size: CGSize, duration: TimeInterval) {
        self.type = .video
        self.fileName = fileName
        self.pixelSize = size
        self.duration = duration
        self.originalImage = nil
        self.enhancedImage = nil
        self.assetURL = videoURL
        self.playerItem = AVPlayerItem(url: videoURL)
    }
}

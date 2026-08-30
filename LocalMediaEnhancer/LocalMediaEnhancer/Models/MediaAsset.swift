//
//  MediaAsset.swift
//  LocalMediaEnhancer
//
//  媒体资源数据模型 — 封装从相册导入的图片/视频元数据
//  参考: https://developer.apple.com/documentation/photos/phasset
//

import Foundation
import Photos
import UIKit

/// 媒体类型枚举
enum MediaType: String, CaseIterable, Identifiable {
    case image
    case video
    var id: String { rawValue }
}

/// 从相册导入的本地媒体资源封装
struct MediaAsset: Identifiable, Equatable {
    let id: String          // PHAsset localIdentifier
    let type: MediaType
    let phAsset: PHAsset?   // 底层相册资源引用（可能为 nil，仅用于本地文件预览）

    // 图片专用
    var image: UIImage? = nil
    // 视频专用
    var videoURL: URL? = nil
    var duration: TimeInterval = 0

    /// 原始尺寸
    var pixelSize: CGSize {
        if let phAsset {
            return CGSize(width: phAsset.pixelWidth, height: phAsset.pixelHeight)
        }
        return image?.size ?? .zero
    }

    /// 文件名（用于导出命名）
    var fileName: String {
        if let phAsset {
            return phAsset.value(forKey: "filename") as? String ?? "media_\(id.prefix(8))"
        }
        return videoURL?.lastPathComponent ?? "media_\(id.prefix(8))"
    }

    // MARK: - Equatable
    static func == (lhs: MediaAsset, rhs: MediaAsset) -> Bool {
        lhs.id == rhs.id
    }
}

/// 预览对比模式
enum PreviewMode: String, CaseIterable, Identifiable {
    case enhanced   // 仅增强后
    case original   // 仅原图
    case split      // 分屏对比
    var id: String { rawValue }

    var label: String {
        switch self {
        case .enhanced: return "增强"
        case .original: return "原图"
        case .split:    return "对比"
        }
    }
}

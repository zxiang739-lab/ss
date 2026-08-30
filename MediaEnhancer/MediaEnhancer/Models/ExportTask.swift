//
//  ExportTask.swift
//  MediaEnhancer
//
//  导出任务模型与错误类型
//

import Foundation

/// 导出处理模式
enum ExportMode: String, CaseIterable, Identifiable {
    case superResolution = "仅超分"
    case frameInterpolation = "仅补帧"
    case combined = "超分 + 补帧"

    var id: String { rawValue }

    var title: String { rawValue }
    var description: String {
        switch self {
        case .superResolution:
            return "提升图片/视频分辨率，输出更清晰的画面"
        case .frameInterpolation:
            return "仅对视频做运动补帧，提高帧率流畅度"
        case .combined:
            return "同时执行超分辨率与运动补帧"
        }
    }

    /// 是否适用于图片
    var supportsImage: Bool {
        self == .superResolution
    }

    /// 是否适用于视频
    var supportsVideo: Bool {
        true
    }
}

/// 导出任务状态
enum ExportStatus {
    case idle
    case processing
    case completed
    case failed
    case cancelled
}

/// 媒体增强错误
enum MediaEnhancerError: LocalizedError {
    case permissionDenied
    case fileNotFound
    case unsupportedFormat
    case decodeFailed
    case encodeFailed
    case insufficientMemory
    case timeout
    case cancelled
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "相册权限被拒绝，请在设置中开启权限"
        case .fileNotFound:
            return "文件不存在或已被删除"
        case .unsupportedFormat:
            return "不支持的媒体格式"
        case .decodeFailed:
            return "文件解码失败，可能已损坏"
        case .encodeFailed:
            return "视频编码失败"
        case .insufficientMemory:
            return "内存不足，请关闭其他应用后重试"
        case .timeout:
            return "处理超时，请尝试较小的文件"
        case .cancelled:
            return "任务已取消"
        case .unknown(let msg):
            return msg
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "点击去设置开启相册访问权限"
        case .insufficientMemory:
            return "建议处理 1080p 及以下分辨率的视频"
        default:
            return nil
        }
    }
}

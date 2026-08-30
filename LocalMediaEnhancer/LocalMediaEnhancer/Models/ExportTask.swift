//
//  ExportTask.swift
//  LocalMediaEnhancer
//
//  离线导出任务模型 — 任务状态、进度、取消支持
//

import Foundation
import Combine

/// 导出处理模式
enum ExportMode: String, CaseIterable, Identifiable {
    case superResolutionOnly      // 仅超分
    case frameInterpolationOnly   // 仅补帧（视频）
    case combined                 // 超分 + 补帧

    var id: String { rawValue }

    var title: String {
        switch self {
        case .superResolutionOnly:    return "仅超分辨率"
        case .frameInterpolationOnly: return "仅运动补帧"
        case .combined:               return "超分 + 补帧"
        }
    }

    var description: String {
        switch self {
        case .superResolutionOnly:
            return "对图片/视频执行超分辨率放大，输出更高分辨率文件"
        case .frameInterpolationOnly:
            return "对视频执行运动补帧插值，提升帧率流畅度（仅视频）"
        case .combined:
            return "同时执行超分辨率与运动补帧，输出高分辨率高帧率视频"
        }
    }

    /// 是否支持图片
    var supportsImage: Bool {
        self == .superResolutionOnly
    }

    /// 是否支持视频
    var supportsVideo: Bool {
        true
    }
}

/// 导出任务状态
enum ExportStatus: Equatable {
    case pending
    case processing(progress: Double)   // 0.0 ~ 1.0
    case completed(outputURL: URL)
    case failed(error: LocalizedError)
    case cancelled

    static func == (lhs: ExportStatus, rhs: ExportStatus) -> Bool {
        switch (lhs, rhs) {
        case (.pending, .pending): return true
        case (.processing(let a), .processing(let b)): return a == b
        case (.completed, .completed): return true
        case (.failed, .failed): return true
        case (.cancelled, .cancelled): return true
        default: return false
        }
    }
}

/// 单个导出任务
final class ExportTask: ObservableObject, Identifiable {
    let id = UUID()
    let asset: MediaAsset
    let mode: ExportMode
    let settings: EnhancementSettings

    @Published var status: ExportStatus = .pending

    /// 取消标记 — ExportManager 轮询此值
    @Published var isCancelled: Bool = false

    init(asset: MediaAsset, mode: ExportMode, settings: EnhancementSettings) {
        self.asset = asset
        self.mode = mode
        self.settings = settings
    }

    func cancel() {
        isCancelled = true
        status = .cancelled
    }
}

/// 导出错误类型
enum ExportError: LocalizedError {
    case unsupportedFormat
    case fileCorrupted
    case insufficientMemory
    case processingTimeout
    case exportFailed(String)
    case permissionDenied
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:  return "不支持的媒体格式"
        case .fileCorrupted:      return "文件已损坏，无法处理"
        case .insufficientMemory: return "设备内存不足，请关闭其他应用后重试"
        case .processingTimeout:  return "处理超时，请尝试降低增强强度或选择较小文件"
        case .exportFailed(let msg): return "导出失败：\(msg)"
        case .permissionDenied:   return "相册权限被拒绝，请在系统设置中开启"
        case .cancelled:          return "任务已取消"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .insufficientMemory: return "建议关闭后台应用或降低超分倍率后重试"
        case .processingTimeout:  return "大文件处理可能需要较长时间，请耐心等待或降低强度"
        case .permissionDenied:   return "前往 设置 > LocalMediaEnhancer > 照片 开启权限"
        default: return nil
        }
    }
}

//
//  EnhancementSettings.swift
//  LocalMediaEnhancer
//
//  增强参数设置模型 — 超分强度、补帧开关等
//

import Foundation
import Combine

/// 增强设置 — ObservableObject，驱动 UI 实时响应
final class EnhancementSettings: ObservableObject {

    // MARK: - 超分辨率
    /// 是否启用超分辨率
    @Published var superResolutionEnabled: Bool = true

    /// 超分强度 0.0 ~ 1.0
    /// 0 = 最轻量（快速），1 = 最高质量（慢）
    @Published var superResolutionStrength: Double = 0.7

    /// 超分倍率（2x / 4x）
    enum SuperResolutionScale: Int, CaseIterable, Identifiable {
        case x2 = 2
        case x4 = 4
        var id: Int { rawValue }
        var label: String { "\(rawValue)x" }
    }
    @Published var superResolutionScale: SuperResolutionScale = .x2

    // MARK: - 运动补帧（仅视频）
    /// 是否启用运动补帧插值
    @Published var frameInterpolationEnabled: Bool = false

    /// 补帧目标帧率倍率（2x = 原帧率 x2，3x = x3）
    enum FrameRateMultiplier: Int, CaseIterable, Identifiable {
        case x2 = 2
        case x3 = 3
        case x4 = 4
        var id: Int { rawValue }
        var label: String { "\(rawValue)x" }
    }
    @Published var frameRateMultiplier: FrameRateMultiplier = .x2

    // MARK: - 预览模式
    @Published var previewMode: PreviewMode = .enhanced

    // MARK: - 便捷计算
    /// 当前是否有任何增强启用
    var hasAnyEnhancement: Bool {
        superResolutionEnabled || frameInterpolationEnabled
    }

    /// 视频是否需要补帧处理
    var needsFrameInterpolation: Bool {
        frameInterpolationEnabled
    }

    /// 重置为默认
    func reset() {
        superResolutionEnabled = true
        superResolutionStrength = 0.7
        superResolutionScale = .x2
        frameInterpolationEnabled = false
        frameRateMultiplier = .x2
        previewMode = .enhanced
    }
}

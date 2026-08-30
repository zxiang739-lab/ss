//
//  EnhancementSettings.swift
//  MediaEnhancer
//
//  增强参数设置
//

import Foundation
import Combine

/// 超分倍率
enum SuperResolutionScale: Double, CaseIterable, Identifiable {
    case x2 = 2.0
    case x3 = 3.0
    case x4 = 4.0

    var id: Double { rawValue }
    var label: String { "\(Int(rawValue))x" }
}

/// 补帧倍率
enum FrameRateMultiplier: Double, CaseIterable, Identifiable {
    case x2 = 2.0
    case x3 = 3.0

    var id: Double { rawValue }
    var label: String { "\(Int(rawValue))x" }
}

/// 增强设置
final class EnhancementSettings: ObservableObject {
    /// 超分开关
    @Published var superResolutionEnabled: Bool = true
    /// 超分强度 0...1
    @Published var superResolutionStrength: Double = 0.7
    /// 超分倍率
    @Published var superResolutionScale: SuperResolutionScale = .x2
    /// 补帧开关（仅视频）
    @Published var frameInterpolationEnabled: Bool = false
    /// 补帧倍率
    @Published var frameRateMultiplier: FrameRateMultiplier = .x2
    /// 预览模式
    @Published var previewMode: PreviewMode = .enhanced
}

//
//  FloatingControlPanel.swift
//  LocalMediaEnhancer
//
//  悬浮液态玻璃控制面板 — 超分开关、补帧开关、强度滑块、预览模式切换
//  严格使用 iOS 26 系统 Liquid Glass 材质，不手写模拟玻璃
//  参考: https://developer.apple.com/design/human-interface-guidelines/liquid-glass
//

import SwiftUI

/// 悬浮液态玻璃控制面板
struct FloatingControlPanel: View {

    @ObservedObject var viewModel: PreviewViewModel
    @ObservedObject var exportVM: ExportViewModel

    /// 是否展开高级设置
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // 主控制行
            HStack(spacing: 12) {
                // 超分开关
                LiquidGlassToggle(
                    isOn: $viewModel.settings.superResolutionEnabled,
                    title: "超分",
                    systemImage: "scalemass.fill"
                )

                // 补帧开关（仅视频显示）
                if viewModel.selectedAsset?.type == .video {
                    LiquidGlassToggle(
                        isOn: $viewModel.settings.frameInterpolationEnabled,
                        title: "补帧",
                        systemImage: "film.stack.fill"
                    )
                }

                // 预览模式切换
                Picker("预览", selection: $viewModel.settings.previewMode) {
                    ForEach(PreviewMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)

                // 展开按钮
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                // 导出按钮
                Button {
                    exportVM.showsExportSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // 展开的高级设置
            if isExpanded {
                Divider()
                    .overlay(.ultraThinMaterial)

                VStack(spacing: 14) {
                    // 超分强度滑块
                    if viewModel.settings.superResolutionEnabled {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("超分强度")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(viewModel.settings.superResolutionStrength * 100))%")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.primary)
                            }
                            Slider(
                                value: $viewModel.settings.superResolutionStrength,
                                in: 0...1,
                                step: 0.05
                            )
                            .tint(.accentColor)
                        }

                        // 超分倍率
                        HStack {
                            Text("超分倍率")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Picker("倍率", selection: $viewModel.settings.superResolutionScale) {
                                ForEach(EnhancementSettings.SuperResolutionScale.allCases) { scale in
                                    Text(scale.label).tag(scale)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 100)
                        }
                    }

                    // 补帧倍率（仅视频）
                    if viewModel.selectedAsset?.type == .video && viewModel.settings.frameInterpolationEnabled {
                        HStack {
                            Text("补帧倍率")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Picker("帧率", selection: $viewModel.settings.frameRateMultiplier) {
                                ForEach(EnhancementSettings.FrameRateMultiplier.allCases) { mult in
                                    Text(mult.label).tag(mult)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 120)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        // iOS 26 Liquid Glass 材质背景
        // 参考: https://developer.apple.com/documentation/swiftui/view/glassbackgroundeffect()
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                // iOS 26 液态玻璃效果
                .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Liquid Glass 风格 Toggle

/// 液态玻璃风格开关按钮
struct LiquidGlassToggle: View {
    @Binding var isOn: Bool
    let title: String
    let systemImage: String

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isOn ? .white : .secondary)
            .background {
                Capsule()
                    .fill(isOn ? Color.accentColor.opacity(0.8) : .clear)
            }
            .overlay {
                Capsule()
                    .strokeBorder(.white.opacity(isOn ? 0.3 : 0.1), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }
}

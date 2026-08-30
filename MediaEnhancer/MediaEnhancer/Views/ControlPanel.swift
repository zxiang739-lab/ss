//
//  ControlPanel.swift
//  MediaEnhancer
//
//  悬浮控制面板 — 超分开关、补帧开关、强度滑块、预览模式
//

import SwiftUI

struct ControlPanel: View {
    @ObservedObject var viewModel: PreviewViewModel
    @ObservedObject var exportVM: ExportViewModel
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Toggle("超分", isOn: $viewModel.settings.superResolutionEnabled)
                    .toggleStyle(.button).frame(width: 70)

                if viewModel.selectedAsset?.type == .video {
                    Toggle("补帧", isOn: $viewModel.settings.frameInterpolationEnabled)
                        .toggleStyle(.button).frame(width: 70)
                }

                Picker("预览", selection: $viewModel.settings.previewMode) {
                    ForEach(PreviewMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
                }
                .pickerStyle(.segmented).frame(width: 140)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                        .font(.title3).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button { exportVM.showsExportSheet = true } label: {
                    Image(systemName: "square.and.arrow.up.circle.fill").font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)

            if isExpanded {
                Divider()
                VStack(spacing: 14) {
                    if viewModel.settings.superResolutionEnabled {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("超分强度").font(.subheadline).foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(viewModel.settings.superResolutionStrength * 100))%")
                                    .font(.subheadline.monospacedDigit())
                            }
                            Slider(value: $viewModel.settings.superResolutionStrength, in: 0...1, step: 0.05)
                                .tint(.accentColor)
                                .onChange(of: viewModel.settings.superResolutionStrength) { _ in
                                    viewModel.applyImageEnhancement()
                                }
                        }

                        HStack {
                            Text("超分倍率").font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            Picker("倍率", selection: $viewModel.settings.superResolutionScale) {
                                ForEach(EnhancementSettings.SuperResolutionScale.allCases) { scale in
                                    Text(scale.label).tag(scale)
                                }
                            }
                            .pickerStyle(.segmented).frame(width: 120)
                            .onChange(of: viewModel.settings.superResolutionScale) { _ in
                                viewModel.applyImageEnhancement()
                            }
                        }
                    }

                    if viewModel.selectedAsset?.type == .video && viewModel.settings.frameInterpolationEnabled {
                        HStack {
                            Text("补帧倍率").font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            Picker("帧率", selection: $viewModel.settings.frameRateMultiplier) {
                                ForEach(EnhancementSettings.FrameRateMultiplier.allCases) { mult in
                                    Text(mult.label).tag(mult)
                                }
                            }
                            .pickerStyle(.segmented).frame(width: 100)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        .frame(maxWidth: .infinity)
    }
}

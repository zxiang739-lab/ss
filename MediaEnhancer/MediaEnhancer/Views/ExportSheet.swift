//
//  ExportSheet.swift
//  MediaEnhancer
//
//  导出 Sheet — 选择模式、进度展示、完成提示
//

import SwiftUI

struct ExportSheet: View {
    @ObservedObject var viewModel: ExportViewModel
    let asset: MediaAsset
    let settings: EnhancementSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        fileInfoSection
                        if !viewModel.isProcessing && !viewModel.isCompleted { modeSelectionSection }
                        if viewModel.isProcessing || viewModel.isCompleted { progressSection }
                        actionButtons
                    }
                    .padding(20)
                }
            }
            .navigationTitle("导出处理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { viewModel.dismiss(); dismiss() }
                }
            }
            .alert("导出完成", isPresented: $viewModel.showsCompletionAlert) {
                Button("好的") { viewModel.showsCompletionAlert = false }
            } message: { Text("增强后的文件已保存到相册。") }
            .alert(item: Binding(
                get: { viewModel.error.map { ErrorWrapper(error: $0) } },
                set: { _ in viewModel.error = nil }
            )) { wrapper in
                Alert(
                    title: Text("导出失败"),
                    message: Text(wrapper.error.errorDescription ?? "未知错误"),
                    dismissButton: .default(Text("确定"))
                )
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var fileInfoSection: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial).frame(width: 56, height: 56)
                Image(systemName: asset.type == .image ? "photo.fill" : "video.fill")
                    .font(.title2).foregroundStyle(.accentColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.fileName).font(.headline).lineLimit(1)
                Text("\(Int(asset.pixelSize.width)) × \(Int(asset.pixelSize.height))")
                    .font(.subheadline).foregroundStyle(.secondary)
                if asset.type == .video && asset.duration > 0 {
                    Text(String(format: "时长 %.1f 秒", asset.duration))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var modeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择处理模式").font(.headline)
            ForEach(viewModel.availableModes(for: asset)) { mode in
                Button {
                    viewModel.selectedMode = mode
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: viewModel.selectedMode == mode ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(viewModel.selectedMode == mode ? .accentColor : .secondary)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.title).font(.subheadline).fontWeight(.semibold)
                            Text(mode.description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14)
                        .fill(viewModel.selectedMode == mode ? Color.accentColor.opacity(0.12) : .ultraThinMaterial))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14).strokeBorder(
                            viewModel.selectedMode == mode ? Color.accentColor.opacity(0.5) : .white.opacity(0.1),
                            lineWidth: 1
                        )
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var progressSection: some View {
        VStack(spacing: 16) {
            if viewModel.isCompleted {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 50)).foregroundStyle(.green)
                    Text("处理完成").font(.headline)
                    Text("文件已保存到相册").font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(20).frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 12) {
                    ProgressView(value: viewModel.currentProgress) {
                        HStack {
                            Text("正在处理...").font(.subheadline)
                            Spacer()
                            Text("\(Int(viewModel.currentProgress * 100))%")
                                .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                    .progressViewStyle(.linear).tint(.accentColor)
                    Text(viewModel.selectedMode.title).font(.caption).foregroundStyle(.secondary)
                }
                .padding(20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var actionButtons: some View {
        Group {
            if !viewModel.isProcessing && !viewModel.isCompleted {
                Button {
                    viewModel.startExport(asset: asset, settings: settings)
                } label: {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("开始导出").fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            } else if viewModel.isProcessing {
                Button(role: .destructive) {
                    viewModel.cancelCurrentTask()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("取消任务").fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .foregroundStyle(.red)
                    .background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

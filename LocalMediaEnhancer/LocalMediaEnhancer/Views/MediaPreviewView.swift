//
//  MediaPreviewView.swift
//  LocalMediaEnhancer
//
//  媒体预览视图 — 图片/视频实时预览，支持原图/增强/分屏对比
//

import SwiftUI
import UIKit

/// 媒体预览视图
struct MediaPreviewView: View {

    @ObservedObject var viewModel: PreviewViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if viewModel.selectedAsset == nil {
                    // 空状态引导
                    emptyStateView
                } else if let asset = viewModel.selectedAsset {
                    switch asset.type {
                    case .image:
                        imagePreviewView(geometry: geometry)
                    case .video:
                        videoPreviewView(geometry: geometry)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse)

            Text("导入本地图片或视频")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Text("所有增强处理均在本地离线完成\n数据不会上传到网络")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - 图片预览

    private func imagePreviewView(geometry: GeometryProxy) -> some View {
        let original = viewModel.selectedAsset?.image
        let enhanced = viewModel.enhancedImage
        let mode = viewModel.settings.previewMode

        return Group {
            switch mode {
            case .original:
                if let original {
                    Image(uiImage: original)
                        .resizable()
                        .scaledToFit()
                }
            case .enhanced:
                if viewModel.isProcessingImage {
                    ProgressView("正在增强...")
                        .progressViewStyle(.circular)
                } else if let enhanced {
                    Image(uiImage: enhanced)
                        .resizable()
                        .scaledToFit()
                } else if let original {
                    Image(uiImage: original)
                        .resizable()
                        .scaledToFit()
                }
            case .split:
                // 分屏对比
                HStack(spacing: 2) {
                    if let original {
                        VStack(spacing: 4) {
                            Image(uiImage: original)
                                .resizable()
                                .scaledToFit()
                            Text("原图")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let enhanced {
                        VStack(spacing: 4) {
                            Image(uiImage: enhanced)
                                .resizable()
                                .scaledToFit()
                            Text("增强")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
    }

    // MARK: - 视频预览

    private func videoPreviewView(geometry: GeometryProxy) -> some View {
        ZStack {
            if let frame = viewModel.currentVideoFrame {
                Image(uiImage: frame)
                    .resizable()
                    .scaledToFit()
            } else {
                // 加载中
                ProgressView("加载视频...")
                    .progressViewStyle(.circular)
            }

            // 播放/暂停按钮（中心）
            if viewModel.selectedAsset?.type == .video {
                Button {
                    viewModel.toggleVideoPlayback()
                } label: {
                    Image(systemName: VideoEnhancer.shared.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white.opacity(0.8))
                        .shadow(radius: 10)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
    }
}

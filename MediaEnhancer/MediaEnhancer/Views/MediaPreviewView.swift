//
//  MediaPreviewView.swift
//  MediaEnhancer
//
//  媒体预览 — 图片原图/增强/分屏对比，视频播放
//

import SwiftUI
import AVKit
import UIKit

struct MediaPreviewView: View {
    @ObservedObject var viewModel: PreviewViewModel

    var body: some View {
        Group {
            if let asset = viewModel.selectedAsset {
                if asset.type == .image { imagePreview(asset) }
                else { videoPreview(asset) }
            } else { Color.clear }
        }
    }

    private func imagePreview(_ asset: MediaAsset) -> some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            HStack(spacing: 0) {
                switch viewModel.settings.previewMode {
                case .original:
                    if let image = asset.originalImage {
                        Image(uiImage: image).resizable().scaledToFit()
                    }
                case .enhanced:
                    if let enhanced = asset.enhancedImage ?? asset.originalImage {
                        Image(uiImage: enhanced).resizable().scaledToFit()
                    }
                case .split:
                    if let original = asset.originalImage {
                        Image(uiImage: original).resizable().scaledToFit()
                            .overlay(alignment: .topLeading) {
                                Text("原图").font(.caption).padding(4)
                                    .background(.ultraThinMaterial).cornerRadius(4).padding(8)
                            }
                    }
                    if let enhanced = asset.enhancedImage {
                        Image(uiImage: enhanced).resizable().scaledToFit()
                            .overlay(alignment: .topLeading) {
                                Text("增强").font(.caption).padding(4)
                                    .background(.ultraThinMaterial).cornerRadius(4).padding(8)
                            }
                    }
                }
            }
        }
        .overlay {
            if viewModel.isProcessing {
                ProgressView("处理中...").padding().background(.ultraThinMaterial).cornerRadius(12)
            }
        }
    }

    private func videoPreview(_ asset: MediaAsset) -> some View {
        VStack {
            if let player = viewModel.player {
                VideoPlayer(player: player)
                    .overlay(alignment: .bottom) {
                        VStack(spacing: 8) {
                            Slider(
                                value: Binding(get: { 0 }, set: { viewModel.seekVideo(to: $0) }),
                                in: 0...1
                            )
                            .tint(.accentColor).padding(.horizontal)
                            Button { viewModel.togglePlay() } label: {
                                Image(systemName: viewModel.videoEnhancer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.largeTitle).foregroundStyle(.white)
                            }
                        }
                        .padding(.bottom, 20)
                    }
            } else {
                ProgressView("加载视频...")
            }
        }
    }
}

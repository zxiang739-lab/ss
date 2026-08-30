//
//  PreviewViewModel.swift
//  LocalMediaEnhancer
//
//  实时预览 ViewModel — 协调媒体导入、实时增强预览
//

import Foundation
import SwiftUI
import Photos
import UIKit
import Combine

/// 实时预览 ViewModel
@MainActor
final class PreviewViewModel: ObservableObject {

    // MARK: - 状态

    /// 当前选中的媒体资源
    @Published var selectedAsset: MediaAsset?

    /// 增强设置
    @Published var settings = EnhancementSettings()

    /// 图片预览：增强后的图片
    @Published var enhancedImage: UIImage?

    /// 是否正在处理图片预览
    @Published var isProcessingImage: Bool = false

    /// 视频实时帧（用于 SwiftUI 展示）
    @Published var currentVideoFrame: UIImage?

    /// 错误信息
    @Published var error: LocalizedError?

    /// 是否显示相册选择器
    @Published var showsImagePicker: Bool = false
    @Published var showsVideoPicker: Bool = false

    /// 相册选择器类型
    enum PickerType {
        case image
        case video
    }
    @Published var activePicker: PickerType?

    // MARK: - 私有

    private var cancellables = Set<AnyCancellable>()
    private let videoEnhancer = VideoEnhancer.shared

    init() {
        setupSettingsObservation()
    }

    // MARK: - 设置变化监听（实时响应）

    private func setupSettingsObservation() {
        // 超分开关/强度变化时重新处理图片
        Publishers.CombineLatest3(
            $settings.map(\.superResolutionEnabled),
            $settings.map(\.superResolutionStrength),
            $settings.map(\.superResolutionScale)
        )
        .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
        .sink { [weak self] _, _, _ in
            self?.reprocessImageIfNeeded()
        }
        .store(in: &cancellables)

        // 视频设置变化
        Publishers.CombineLatest3(
            $settings.map(\.superResolutionEnabled),
            $settings.map(\.frameInterpolationEnabled),
            $settings.map(\.superResolutionScale)
        )
        .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
        .sink { [weak self] _, _, _ in
            self?.updateVideoPreview()
        }
        .store(in: &cancellables)
    }

    // MARK: - 图片导入与处理

    /// 从 PHPicker 结果导入图片
    func importImage(from result: PHPickerResult) {
        isProcessingImage = true
        let itemProvider = result.itemProvider

        if itemProvider.canLoadObject(ofClass: UIImage.self) {
            itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                DispatchQueue.main.async {
                    if let image = image as? UIImage {
                        let asset = MediaAsset(
                            id: UUID().uuidString,
                            type: .image,
                            phAsset: nil,
                            image: image
                        )
                        self?.selectedAsset = asset
                        self?.enhancedImage = image
                        self?.reprocessImageIfNeeded()
                    } else {
                        self?.error = ExportError.unsupportedFormat
                    }
                    self?.isProcessingImage = false
                }
            }
        }
    }

    /// 从 PHAsset 导入图片
    func importImage(from phAsset: PHAsset, manager: PhotoLibraryManager) {
        isProcessingImage = true
        manager.loadImage(for: phAsset) { [weak self] image in
            guard let image = image else {
                self?.error = ExportError.fileCorrupted
                self?.isProcessingImage = false
                return
            }
            let asset = MediaAsset(
                id: phAsset.localIdentifier,
                type: .image,
                phAsset: phAsset,
                image: image
            )
            self?.selectedAsset = asset
            self?.enhancedImage = image
            self?.reprocessImageIfNeeded()
            self?.isProcessingImage = false
        }
    }

    /// 重新处理图片（设置变化时触发）
    private func reprocessImageIfNeeded() {
        guard let asset = selectedAsset,
              asset.type == .image,
              let originalImage = asset.image,
              settings.superResolutionEnabled else {
            // 未启用超分时显示原图
            if let asset = selectedAsset, asset.type == .image {
                enhancedImage = asset.image
            }
            return
        }

        isProcessingImage = true
        Task {
            do {
                let result = try await ImageEnhancer.shared.enhance(
                    originalImage,
                    scale: settings.superResolutionScale,
                    strength: settings.superResolutionStrength
                )
                self.enhancedImage = result
            } catch {
                self.error = error as? LocalizedError ?? ExportError.exportFailed(error.localizedDescription)
            }
            self.isProcessingImage = false
        }
    }

    // MARK: - 视频导入与预览

    /// 从 PHPicker 结果导入视频
    func importVideo(from result: PHPickerResult) {
        let itemProvider = result.itemProvider
        guard itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
            error = ExportError.unsupportedFormat
            return
        }

        itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, error in
            guard let url = url else {
                DispatchQueue.main.async {
                    self?.error = ExportError.fileCorrupted
                }
                return
            }
            // 复制到临时目录（PHPicker 的 URL 是临时的）
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".mov")
            do {
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }
                try FileManager.default.copyItem(at: url, to: tempURL)

                DispatchQueue.main.async {
                    let asset = MediaAsset(
                        id: UUID().uuidString,
                        type: .video,
                        phAsset: nil,
                        videoURL: tempURL
                    )
                    self?.selectedAsset = asset
                    self?.startVideoPreview()
                }
            } catch {
                DispatchQueue.main.async {
                    self?.error = ExportError.exportFailed(error.localizedDescription)
                }
            }
        }
    }

    /// 从 PHAsset 导入视频
    func importVideo(from phAsset: PHAsset, manager: PhotoLibraryManager) {
        manager.loadVideoURL(for: phAsset) { [weak self] url in
            guard let url = url else {
                self?.error = ExportError.fileCorrupted
                return
            }
            let asset = MediaAsset(
                id: phAsset.localIdentifier,
                type: .video,
                phAsset: phAsset,
                videoURL: url,
                duration: CMTimeGetSeconds(phAsset.duration)
            )
            self?.selectedAsset = asset
            self?.startVideoPreview()
        }
    }

    /// 开始视频实时预览
    private func startVideoPreview() {
        guard let asset = selectedAsset,
              let url = asset.videoURL else { return }

        videoEnhancer.onFrameReady = { [weak self] pixelBuffer in
            let image = self?.imageFromPixelBuffer(pixelBuffer)
            DispatchQueue.main.async {
                self?.currentVideoFrame = image
            }
        }

        videoEnhancer.startPreview(
            url: url,
            superResolution: settings.superResolutionEnabled,
            frameInterpolation: settings.frameInterpolationEnabled,
            scale: settings.superResolutionScale.rawValue
        )
    }

    /// 更新视频预览设置（动态切换）
    private func updateVideoPreview() {
        guard selectedAsset?.type == .video else { return }
        videoEnhancer.updatePreviewSettings(
            superResolution: settings.superResolutionEnabled,
            frameInterpolation: settings.frameInterpolationEnabled,
            scale: settings.superResolutionScale.rawValue
        )
    }

    /// 暂停/继续视频
    func toggleVideoPlayback() {
        videoEnhancer.togglePlayPause()
    }

    /// 停止视频预览
    func stopVideoPreview() {
        videoEnhancer.stopPreview()
        currentVideoFrame = nil
    }

    // MARK: - 工具

    private func imageFromPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> UIImage {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return UIImage()
    }

    /// 清除当前选择
    func clearSelection() {
        stopVideoPreview()
        selectedAsset = nil
        enhancedImage = nil
        currentVideoFrame = nil
        error = nil
    }

    deinit {
        videoEnhancer.stopPreview()
    }
}

//
//  PreviewViewModel.swift
//  MediaEnhancer
//
//  实时预览 ViewModel
//

import Foundation
import UIKit
import PhotosUI
import Combine
import AVFoundation

/// 预览 ViewModel
final class PreviewViewModel: ObservableObject {
    @Published var selectedAsset: MediaAsset?
    @Published var settings = EnhancementSettings()
    @Published var isProcessing: Bool = false
    @Published var error: MediaEnhancerError?

    private let imageEnhancer = ImageEnhancer()
    let videoEnhancer = VideoEnhancer()
    private var cancellables = Set<AnyCancellable>()

    var player: AVPlayer? { videoEnhancer.player }

    init() {
        settings.$superResolutionEnabled
            .combineLatest(settings.$superResolutionScale, settings.$superResolutionStrength)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] enabled, scale, strength in
                self?.videoEnhancer.configureSuperResolution(
                    enabled: enabled,
                    scale: scale.rawValue,
                    strength: strength
                )
            }
            .store(in: &cancellables)
    }

    func importImage(from result: PHPickerResult) {
        isProcessing = true
        let manager = PhotoLibraryManager()
        manager.loadImage(from: result) { [weak self] image in
            guard let self = self, let image = image else {
                self?.error = .decodeFailed
                self?.isProcessing = false
                return
            }
            let asset = MediaAsset(image: image, fileName: "Image_\(Int.random(in: 1000...9999))")
            self.selectedAsset = asset
            self.applyImageEnhancement()
        }
    }

    func importVideo(from result: PHPickerResult) {
        isProcessing = true
        let manager = PhotoLibraryManager()
        manager.loadVideo(from: result) { [weak self] url, size, duration in
            guard let self = self, let url = url else {
                self?.error = .decodeFailed
                self?.isProcessing = false
                return
            }
            let fileName = url.lastPathComponent
            let asset = MediaAsset(videoURL: url, fileName: fileName, size: size, duration: duration)
            self.selectedAsset = asset
            self.videoEnhancer.prepare(with: asset)
            self.videoEnhancer.configureSuperResolution(
                enabled: self.settings.superResolutionEnabled,
                scale: self.settings.superResolutionScale.rawValue,
                strength: self.settings.superResolutionStrength
            )
            self.isProcessing = false
        }
    }

    func applyImageEnhancement() {
        guard var asset = selectedAsset, asset.type == .image, let original = asset.originalImage else { return }
        guard settings.superResolutionEnabled else {
            asset.enhancedImage = original
            selectedAsset = asset
            isProcessing = false
            return
        }
        isProcessing = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let enhanced = self.imageEnhancer.enhance(
                original,
                scale: self.settings.superResolutionScale.rawValue,
                strength: self.settings.superResolutionStrength
            )
            DispatchQueue.main.async {
                asset.enhancedImage = enhanced
                self.selectedAsset = asset
                self.isProcessing = false
            }
        }
    }

    func togglePlay() { videoEnhancer.togglePlay() }
    func seekVideo(to progress: Double) { videoEnhancer.seek(to: progress) }

    func clearSelection() {
        videoEnhancer.cleanup()
        selectedAsset = nil
        error = nil
    }
}

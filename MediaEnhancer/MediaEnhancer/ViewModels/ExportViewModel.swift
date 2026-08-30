//
//  ExportViewModel.swift
//  MediaEnhancer
//
//  导出 Sheet ViewModel
//

import Foundation
import UIKit
import Combine

/// 导出 ViewModel
final class ExportViewModel: ObservableObject {
    @Published var showsExportSheet: Bool = false
    @Published var selectedMode: ExportMode = .superResolution
    @Published var isProcessing: Bool = false
    @Published var isCompleted: Bool = false
    @Published var currentProgress: Double = 0
    @Published var error: MediaEnhancerError?
    @Published var showsCompletionAlert: Bool = false

    private let exportManager = ExportManager()
    private let photoLibraryManager = PhotoLibraryManager()

    func availableModes(for asset: MediaAsset) -> [ExportMode] {
        ExportMode.allCases.filter { mode in
            asset.type == .image ? mode.supportsImage : mode.supportsVideo
        }
    }

    func startExport(asset: MediaAsset, settings: EnhancementSettings) {
        isProcessing = true
        isCompleted = false
        currentProgress = 0
        error = nil
        if asset.type == .image {
            exportImage(asset: asset, settings: settings)
        } else {
            exportVideo(asset: asset, settings: settings)
        }
    }

    func cancelCurrentTask() {
        exportManager.cancel()
        isProcessing = false
        error = .cancelled
    }

    func dismiss() {
        showsExportSheet = false
        isProcessing = false
        isCompleted = false
        currentProgress = 0
        error = nil
    }

    private func exportImage(asset: MediaAsset, settings: EnhancementSettings) {
        guard let image = asset.originalImage else {
            error = .fileNotFound; isProcessing = false; return
        }
        exportManager.exportImage(
            image,
            scale: settings.superResolutionScale.rawValue,
            strength: settings.superResolutionStrength
        ) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let enhancedImage):
                self.photoLibraryManager.saveImageToLibrary(enhancedImage) { error in
                    self.isProcessing = false
                    if let error = error {
                        self.error = .unknown(error.localizedDescription)
                    } else {
                        self.isCompleted = true
                        self.showsCompletionAlert = true
                    }
                }
            case .failure(let error):
                self.isProcessing = false
                self.error = error as? MediaEnhancerError ?? .decodeFailed
            }
        }
    }

    private func exportVideo(asset: MediaAsset, settings: EnhancementSettings) {
        guard let url = asset.assetURL else {
            error = .fileNotFound; isProcessing = false; return
        }
        exportManager.exportVideo(
            from: url,
            mode: selectedMode,
            scale: settings.superResolutionScale.rawValue,
            frameRateMultiplier: settings.frameRateMultiplier.rawValue,
            progress: { [weak self] progress in self?.currentProgress = progress },
            completion: { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let outputURL):
                    self.photoLibraryManager.saveVideoToLibrary(outputURL) { error in
                        self.isProcessing = false
                        if let error = error {
                            self.error = .unknown(error.localizedDescription)
                        } else {
                            self.isCompleted = true
                            self.showsCompletionAlert = true
                        }
                        try? FileManager.default.removeItem(at: outputURL)
                    }
                case .failure(let error):
                    self.isProcessing = false
                    if let enhancerError = error as? MediaEnhancerError {
                        self.error = enhancerError
                    } else {
                        self.error = .unknown(error.localizedDescription)
                    }
                }
            }
        )
    }
}

//
//  ExportManager.swift
//  MediaEnhancer
//
//  离线导出处理 — AVAssetExportSession
//  参考: https://developer.apple.com/documentation/avfoundation/avassetexportsession
//

import Foundation
import AVFoundation
import CoreImage
import UIKit

typealias ExportProgressHandler = (Double) -> Void
typealias ExportCompletionHandler = (Result<URL, Error>) -> Void

/// 离线导出管理器
final class ExportManager {
    private var isCancelled = false
    private var exportSession: AVAssetExportSession?

    func cancel() {
        isCancelled = true
        exportSession?.cancelExport()
    }

    func exportVideo(
        from sourceURL: URL,
        mode: ExportMode,
        scale: Double,
        frameRateMultiplier: Double,
        progress: @escaping ExportProgressHandler,
        completion: @escaping ExportCompletionHandler
    ) {
        isCancelled = false
        let asset = AVURLAsset(url: sourceURL)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("enhanced_\(UUID().uuidString)")
            .appendingPathExtension("mp4")

        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            completion(.failure(MediaEnhancerError.encodeFailed))
            return
        }
        exportSession = session
        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true

        if mode == .superResolution || mode == .combined {
            let composition = AVVideoComposition(asset: asset) { [weak self] request in
                guard let self = self, !self.isCancelled else {
                    request.finish(with: request.sourceImage, context: nil)
                    return
                }
                let source = request.sourceImage.clampedToExtent()
                if let filter = CIFilter(name: "CILanczosScaleTransform") {
                    filter.setValue(source, forKey: kCIInputImageKey)
                    filter.setValue(scale, forKey: kCIInputScaleKey)
                    filter.setValue(1.0, forKey: kCIInputAspectRatioKey)
                    if let output = filter.outputImage {
                        request.finish(with: output.cropped(to: request.sourceImage.extent), context: nil)
                        return
                    }
                }
                request.finish(with: request.sourceImage, context: nil)
            }
            session.videoComposition = composition
        }

        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if session.status == .exporting {
                progress(Double(session.progress))
            } else {
                timer.invalidate()
            }
        }

        session.exportAsynchronously {
            progressTimer.invalidate()
            DispatchQueue.main.async {
                switch session.status {
                case .completed:
                    if self.isCancelled {
                        completion(.failure(MediaEnhancerError.cancelled))
                    } else {
                        progress(1.0)
                        completion(.success(outputURL))
                    }
                case .cancelled:
                    completion(.failure(MediaEnhancerError.cancelled))
                case .failed:
                    completion(.failure(session.error ?? MediaEnhancerError.encodeFailed))
                default:
                    completion(.failure(MediaEnhancerError.unknown("导出异常")))
                }
            }
        }
    }

    func exportImage(
        _ image: UIImage,
        scale: Double,
        strength: Double,
        completion: @escaping (Result<UIImage, Error>) -> Void
    ) {
        let enhancer = ImageEnhancer()
        if let enhanced = enhancer.enhance(image, scale: scale, strength: strength) {
            completion(.success(enhanced))
        } else {
            completion(.failure(MediaEnhancerError.decodeFailed))
        }
    }
}

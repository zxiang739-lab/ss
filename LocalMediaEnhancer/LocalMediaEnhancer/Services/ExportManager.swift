//
//  ExportManager.swift
//  LocalMediaEnhancer
//
//  离线导出管理器 — 协调图片/视频的离线处理与保存
//  使用 AVAssetWriter + VideoToolbox 编码输出新视频
//  参考:
//  - AVAssetWriter: https://developer.apple.com/documentation/avfoundation/avassetwriter
//  - AVAssetWriterInput: https://developer.apple.com/documentation/avfoundation/avassetwriterinput
//  - VTCompressionSession: https://developer.apple.com/documentation/videotoolbox/vtcompressionsession
//

import Foundation
import AVFoundation
import CoreMedia
import UIKit
import Photos

/// 导出管理器 — 处理离线导出任务队列
final class ExportManager: ObservableObject {

    static let shared = ExportManager()

    /// 当前任务队列
    @Published private(set) var tasks: [ExportTask] = []

    /// 处理队列（串行，避免内存峰值）
    private let processingQueue = DispatchQueue(label: "com.localmedia.export", qos: .userInitiated)

    private init() {}

    // MARK: - 任务管理

    /// 添加导出任务
    func addTask(_ task: ExportTask) {
        tasks.append(task)
        processTask(task)
    }

    /// 取消所有任务
    func cancelAll() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
    }

    // MARK: - 处理调度

    private func processTask(_ task: ExportTask) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            switch task.asset.type {
            case .image:
                self.processImageExport(task)
            case .video:
                self.processVideoExport(task)
            }
        }
    }

    // MARK: - 图片导出

    private func processImageExport(_ task: ExportTask) {
        DispatchQueue.main.async {
            task.status = .processing(progress: 0.1)
        }

        guard let image = task.asset.image else {
            DispatchQueue.main.async {
                task.status = .failed(error: ExportError.fileCorrupted)
            }
            return
        }

        // 仅超分模式支持图片
        guard task.mode != .frameInterpolationOnly else {
            DispatchQueue.main.async {
                task.status = .failed(error: ExportError.unsupportedFormat)
            }
            return
        }

        Task {
            do {
                // 检查取消
                if task.isCancelled { return }

                DispatchQueue.main.async {
                    task.status = .processing(progress: 0.3)
                }

                // 执行超分
                let enhanced = try await ImageEnhancer.shared.enhance(
                    image,
                    scale: task.settings.superResolutionScale,
                    strength: task.settings.superResolutionStrength
                )

                if task.isCancelled { return }

                DispatchQueue.main.async {
                    task.status = .processing(progress: 0.8)
                }

                // 保存到相册
                PhotoLibraryManager().saveImageToLibrary(enhanced) { success, error in
                    if success {
                        // 保存临时文件用于记录
                        let tempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent("enhanced_\(task.id.uuidString).jpg")
                        if let data = enhanced.jpegData(compressionQuality: 0.95) {
                            try? data.write(to: tempURL)
                        }
                        DispatchQueue.main.async {
                            task.status = .completed(outputURL: tempURL)
                        }
                    } else {
                        DispatchQueue.main.async {
                            task.status = .failed(error: ExportError.exportFailed(error?.localizedDescription ?? "保存失败"))
                        }
                    }
                }
            } catch {
                if task.isCancelled { return }
                DispatchQueue.main.async {
                    task.status = .failed(error: error as? LocalizedError ?? ExportError.exportFailed(error.localizedDescription))
                }
            }
        }
    }

    // MARK: - 视频导出

    private func processVideoExport(_ task: ExportTask) {
        guard let videoURL = task.asset.videoURL else {
            DispatchQueue.main.async {
                task.status = .failed(error: ExportError.fileCorrupted)
            }
            return
        }

        DispatchQueue.main.async {
            task.status = .processing(progress: 0.05)
        }

        Task {
            do {
                // 1. 准备解码器
                let decoder = VideoFrameDecoder(url: videoURL)
                try await decoder.prepare()

                if task.isCancelled { return }

                let originalSize = decoder.naturalSize
                let scale = task.settings.superResolutionScale.rawValue
                let targetSize = task.mode != .frameInterpolationOnly
                    ? CGSize(width: originalSize.width * CGFloat(scale),
                             height: originalSize.height * CGFloat(scale))
                    : originalSize

                let targetFrameRate = task.mode != .superResolutionOnly
                    ? decoder.nominalFrameRate * Float(task.settings.frameRateMultiplier.rawValue)
                    : decoder.nominalFrameRate

                // 2. 创建输出文件
                let outputURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("export_\(task.id.uuidString).mp4")

                // 参考: https://developer.apple.com/documentation/avfoundation/avassetwriter
                let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

                // 视频输入配置
                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: Int(targetSize.width),
                    AVVideoHeightKey: Int(targetSize.height),
                    AVVideoCompressionPropertiesKey: [
                        AVVideoAverageBitRateKey: Int(targetSize.width * targetSize.height * 0.3),
                        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                    ]
                ]

                let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                writerInput.expectsMediaDataInRealTime = false

                // 像素缓冲输入适配器
                let sourcePixelBufferAttributes: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: Int(targetSize.width),
                    kCVPixelBufferHeightKey as String: Int(targetSize.height),
                    kCVPixelBufferMetalCompatibilityKey as String: true
                ]
                let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                    assetWriterInput: writerInput,
                    sourcePixelBufferAttributes: sourcePixelBufferAttributes
                )

                if writer.canAdd(writerInput) {
                    writer.add(writerInput)
                }

                writer.startWriting()
                writer.startSession(atSourceTime: .zero)

                // 3. 逐帧处理
                let renderer = MetalRenderer()
                let totalFrames = decoder.totalFrames
                var frameIndex = 0
                var previousBuffer: CVPixelBuffer?
                let needsInterpolation = task.mode != .superResolutionOnly && task.settings.frameInterpolationEnabled

                while !task.isCancelled {
                    guard let sampleBuffer = decoder.copyNextFrame() else { break }
                    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { continue }

                    let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

                    // 超分处理
                    var processedBuffer = pixelBuffer
                    if task.mode != .frameInterpolationOnly && task.settings.superResolutionEnabled {
                        if let enhanced = renderer.processOffscreen(
                            pixelBuffer: pixelBuffer,
                            targetSize: targetSize,
                            superResolution: true
                        ) {
                            processedBuffer = enhanced
                        }
                    }

                    // 写入原始帧
                    while !writerInput.isReadyForMoreMediaData {
                        if task.isCancelled { break }
                        Thread.sleep(forTimeInterval: 0.01)
                    }
                    if task.isCancelled { break }

                    let outputTime = CMTimeMake(value: Int64(frameIndex), timescale: Int32(targetFrameRate))
                    adaptor.append(processedBuffer, withPresentationTime: outputTime)
                    frameIndex += 1

                    // 补帧：在两帧之间插入插值帧
                    if needsInterpolation, let prev = previousBuffer {
                        let interpolated = await VideoEnhancer.shared.generateInterpolatedFrame(
                            first: prev,
                            second: pixelBuffer
                        )
                        if let interpBuffer = interpolated {
                            // 超分插值帧
                            var finalInterp = interpBuffer
                            if task.settings.superResolutionEnabled {
                                if let enhanced = renderer.processOffscreen(
                                    pixelBuffer: interpBuffer,
                                    targetSize: targetSize,
                                    superResolution: true
                                ) {
                                    finalInterp = enhanced
                                }
                            }

                            while !writerInput.isReadyForMoreMediaData {
                                if task.isCancelled { break }
                                Thread.sleep(forTimeInterval: 0.01)
                            }
                            let interpTime = CMTimeMake(value: Int64(frameIndex), timescale: Int32(targetFrameRate))
                            adaptor.append(finalInterp, withPresentationTime: interpTime)
                            frameIndex += 1
                        }
                    }

                    previousBuffer = pixelBuffer

                    // 更新进度
                    if totalFrames > 0 {
                        let progress = Double(frameIndex) / Double(totalFrames * (needsInterpolation ? 2 : 1))
                        DispatchQueue.main.async {
                            task.status = .processing(progress: min(progress, 0.95))
                        }
                    }

                    // 内存管控：定期释放 autoreleasepool
                    if frameIndex % 30 == 0 {
                        autoreleasepool {}
                    }
                }

                if task.isCancelled {
                    writer.cancelWriting()
                    return
                }

                // 4. 完成写入
                writerInput.markAsFinished()
                await writer.finishWriting()

                DispatchQueue.main.async {
                    task.status = .processing(progress: 0.98)
                }

                // 5. 保存到相册
                PhotoLibraryManager().saveVideoToLibrary(at: outputURL) { success, error in
                    if success {
                        DispatchQueue.main.async {
                            task.status = .completed(outputURL: outputURL)
                        }
                    } else {
                        DispatchQueue.main.async {
                            task.status = .failed(error: ExportError.exportFailed(error?.localizedDescription ?? "保存到相册失败"))
                        }
                    }
                }

            } catch {
                if task.isCancelled { return }
                DispatchQueue.main.async {
                    task.status = .failed(error: error as? LocalizedError ?? ExportError.exportFailed(error.localizedDescription))
                }
            }
        }
    }
}

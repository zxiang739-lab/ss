//
//  ImageEnhancer.swift
//  LocalMediaEnhancer
//
//  图片超分辨率引擎 — Vision + CoreML 本地离线处理
//  参考:
//  - Vision: https://developer.apple.com/documentation/vision
//  - CoreML: https://developer.apple.com/documentation/coreml
//  - iOS 26 新增 VNGenerateImageEnhancementRequest 媒体增强 API
//  - CIImage 处理链: https://developer.apple.com/documentation/coreimage
//

import Foundation
import Vision
import CoreImage
import CoreML
import UIKit
import Metal

/// 图片超分辨率增强引擎
/// 全部运算在本地 GPU/Neural Engine 完成，无网络请求
final class ImageEnhancer {

    /// 共享单例
    static let shared = ImageEnhancer()

    /// Metal 设备（用于 CoreImage GPU 渲染）
    private let metalDevice: MTLDevice?
    private let ciContext: CIContext

    /// iOS 26 新媒体增强 Request（运行时可用性判断）
    /// 参考: iOS 26 Vision 新增 VNGenerateSuperResolutionRequest
    private var superResolutionRequest: VNRequest?

    private init() {
        self.metalDevice = MTLCreateSystemDefaultDevice()
        if let device = metalDevice {
            self.ciContext = CIContext(mtlDevice: device,
                                       options: [.useSoftwareRenderer: false])
        } else {
            self.ciContext = CIContext(options: [.useSoftwareRenderer: false])
        }
        setupVisionRequest()
    }

    // MARK: - Vision Request 初始化

    private func setupVisionRequest() {
        // iOS 26 新增超分 API 可用性判断
        // 参考: iOS 26 Vision Framework - VNGenerateSuperResolutionRequest
        if #available(iOS 26.0, *) {
            // iOS 26: 使用系统原生超分请求
            // 该 Request 利用 Apple Neural Engine 执行本地超分辨率
            let request = VNGenerateImageEnhancementRequest()
            request.revision = VNGenerateImageEnhancementRequestRevision1
            self.superResolutionRequest = request
        } else {
            // 不会到达此分支（Deployment Target = iOS 26）
            self.superResolutionRequest = nil
        }
    }

    // MARK: - 公开 API

    /// 对图片执行超分辨率增强
    /// - Parameters:
    ///   - image: 输入图片
    ///   - scale: 超分倍率
    ///   - strength: 强度 0~1
    /// - Returns: 增强后的 UIImage
    func enhance(_ image: UIImage,
                 scale: EnhancementSettings.SuperResolutionScale,
                 strength: Double) async throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw ExportError.unsupportedFormat
        }

        // 内存管控：超大图片先做尺寸限制，防止 OOM
        let maxDimension: CGFloat = 8192
        let inputSize = CGSize(width: cgImage.width, height: cgImage.height)
        let longerSide = max(inputSize.width, inputSize.height)
        var workingImage = image
        if longerSide > maxDimension {
            workingImage = resizeImage(image, maxDimension: maxDimension)
        }

        // 路径选择：iOS 26 原生 Vision 超分
        if #available(iOS 26.0, *) {
            return try await enhanceWithVision(workingImage, scale: scale, strength: strength)
        } else {
            // Fallback（理论不可达）
            return try enhanceWithCoreImage(workingImage, scale: scale, strength: strength)
        }
    }

    // MARK: - iOS 26 Vision 超分

    @available(iOS 26.0, *)
    private func enhanceWithVision(_ image: UIImage,
                                   scale: EnhancementSettings.SuperResolutionScale,
                                   strength: Double) async throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw ExportError.unsupportedFormat
        }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        // 使用 VNGenerateImageEnhancementRequest
        // 参考: iOS 26 Vision - 本地图像增强，支持超分、降噪、锐化
        let request = VNGenerateImageEnhancementRequest()
        request.enhancementOptions = [
            .superResolution: true,
            .denoise: strength > 0.3,
            .sharpness: strength
        ]

        try requestHandler.perform([request])

        guard let result = request.results?.first,
              let enhancedCGImage = result.enhancedImage else {
            // Vision 失败时降级到 CoreImage  Lanczos 缩放
            return try enhanceWithCoreImage(image, scale: scale, strength: strength)
        }

        // 如果 Vision 结果未达到目标倍率，用 CoreImage 做高质量缩放
        let targetSize = CGSize(width: cgImage.width * scale.rawValue,
                                height: cgImage.height * scale.rawValue)
        if enhancedCGImage.width < Int(targetSize.width) {
            return try upscaleWithCoreImage(enhancedCGImage, targetSize: targetSize, strength: strength)
        }

        return UIImage(cgImage: enhancedCGImage)
    }

    // MARK: - CoreImage 降级方案

    private func enhanceWithCoreImage(_ image: UIImage,
                                      scale: EnhancementSettings.SuperResolutionScale,
                                      strength: Double) throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw ExportError.unsupportedFormat
        }
        let targetSize = CGSize(width: cgImage.width * scale.rawValue,
                                height: cgImage.height * scale.rawValue)
        return try upscaleWithCoreImage(cgImage, targetSize: targetSize, strength: strength)
    }

    /// 使用 CoreImage 高质量 Lanczos 缩放 + 锐化
    private func upscaleWithCoreImage(_ cgImage: CGImage,
                                      targetSize: CGSize,
                                      strength: Double) throws -> UIImage {
        let ciImage = CIImage(cgImage: cgImage)

        // 参考: https://developer.apple.com/documentation/coreimage/cilanczosscaletransform
        guard let scaleFilter = CIFilter(name: "CILanczosScaleTransform") else {
            throw ExportError.exportFailed("CoreImage 滤镜初始化失败")
        }
        scaleFilter.setValue(ciImage, forKey: kCIInputImageKey)
        let scaleFactor = targetSize.width / CGFloat(cgImage.width)
        scaleFilter.setValue(scaleFactor, forKey: kCIInputScaleKey)
        scaleFilter.setValue(1.0, forKey: kCIInputAspectRatioKey)

        guard let scaledImage = scaleFilter.outputImage else {
            throw ExportError.exportFailed("缩放处理失败")
        }

        // 锐化增强（强度控制）
        var finalImage = scaledImage
        if strength > 0.1 {
            let sharpenFilter = CIFilter(name: "CISharpenLuminance")
            sharpenFilter?.setValue(scaledImage, forKey: kCIInputImageKey)
            sharpenFilter?.setValue(strength * 2.0, forKey: kCIInputSharpnessKey)
            if let sharpened = sharpenFilter?.outputImage {
                finalImage = sharpened
            }
        }

        // 渲染到 CGImage
        guard let outputCGImage = ciContext.createCGImage(
            finalImage,
            from: CGRect(origin: .zero, size: targetSize)
        ) else {
            throw ExportError.exportFailed("图像渲染失败")
        }

        return UIImage(cgImage: outputCGImage)
    }

    // MARK: - 工具方法

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let ratio = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - iOS 26 Vision 增强结果扩展（前向兼容声明）
// 参考: iOS 26 Vision 新增 VNGenerateImageEnhancementRequestResult
@available(iOS 26.0, *)
extension VNGenerateImageEnhancementRequestResult {
    /// 增强后的 CGImage（前向兼容属性访问）
    var enhancedImage: CGImage? {
        // iOS 26 API: result.enhancedImage
        return self.value(forKey: "enhancedImage") as? CGImage
    }
}

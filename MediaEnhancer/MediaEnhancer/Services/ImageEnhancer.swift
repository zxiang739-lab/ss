//
//  ImageEnhancer.swift
//  MediaEnhancer
//
//  图片超分辨率 — 使用 CoreImage CILanczosScaleTransform
//  参考: https://developer.apple.com/documentation/coreimage/cilanczosscaletransform
//

import UIKit
import CoreImage

/// 图片增强引擎
final class ImageEnhancer {
    private let context = CIContext(options: [.useSoftwareRenderer: false])

    /// 对图片执行超分辨率
    func enhance(_ image: UIImage, scale: Double, strength: Double) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        // 1. Lanczos 高质量缩放
        guard let lanczosFilter = CIFilter(name: "CILanczosScaleTransform") else { return nil }
        lanczosFilter.setValue(ciImage, forKey: kCIInputImageKey)
        lanczosFilter.setValue(scale, forKey: kCIInputScaleKey)
        lanczosFilter.setValue(1.0, forKey: kCIInputAspectRatioKey)

        guard let scaledImage = lanczosFilter.outputImage else { return nil }

        // 2. 锐化增强
        let sharpenAmount = Float(strength * 0.8)
        guard let sharpenFilter = CIFilter(name: "CISharpenLuminance") else {
            return render(scaledImage, originalSize: image.size, scale: scale)
        }
        sharpenFilter.setValue(scaledImage, forKey: kCIInputImageKey)
        sharpenFilter.setValue(sharpenAmount, forKey: kCIInputSharpnessKey)

        guard let outputImage = sharpenFilter.outputImage else {
            return render(scaledImage, originalSize: image.size, scale: scale)
        }

        return render(outputImage, originalSize: image.size, scale: scale)
    }

    private func render(_ ciImage: CIImage, originalSize: CGSize, scale: Double) -> UIImage? {
        let targetSize = CGSize(
            width: originalSize.width * CGFloat(scale),
            height: originalSize.height * CGFloat(scale)
        )
        guard let cgImage = context.createCGImage(ciImage, from: CGRect(origin: .zero, size: targetSize)) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
    }

    /// 生成对比图（左原图右增强）
    func makeSplitComparison(original: UIImage, enhanced: UIImage) -> UIImage? {
        let size = CGSize(
            width: original.size.width + enhanced.size.width,
            height: max(original.size.height, enhanced.size.height)
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            original.draw(in: CGRect(origin: .zero, size: original.size))
            enhanced.draw(in: CGRect(x: original.size.width, y: 0, width: enhanced.size.width, height: enhanced.size.height))
        }
    }
}

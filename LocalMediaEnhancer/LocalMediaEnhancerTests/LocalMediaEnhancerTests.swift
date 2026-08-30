//
//  LocalMediaEnhancerTests.swift
//  LocalMediaEnhancerTests
//

import XCTest
@testable import LocalMediaEnhancer

final class LocalMediaEnhancerTests: XCTestCase {

    // MARK: - EnhancementSettings 测试

    func testEnhancementSettingsDefault() {
        let settings = EnhancementSettings()
        XCTAssertTrue(settings.superResolutionEnabled)
        XCTAssertFalse(settings.frameInterpolationEnabled)
        XCTAssertEqual(settings.superResolutionStrength, 0.7)
        XCTAssertEqual(settings.superResolutionScale, .x2)
        XCTAssertEqual(settings.frameRateMultiplier, .x2)
    }

    func testEnhancementSettingsHasAnyEnhancement() {
        let settings = EnhancementSettings()
        XCTAssertTrue(settings.hasAnyEnhancement)

        settings.superResolutionEnabled = false
        XCTAssertFalse(settings.hasAnyEnhancement)

        settings.frameInterpolationEnabled = true
        XCTAssertTrue(settings.hasAnyEnhancement)
    }

    func testEnhancementSettingsReset() {
        let settings = EnhancementSettings()
        settings.superResolutionEnabled = false
        settings.superResolutionStrength = 0.9
        settings.frameInterpolationEnabled = true
        settings.reset()
        XCTAssertTrue(settings.superResolutionEnabled)
        XCTAssertEqual(settings.superResolutionStrength, 0.7)
        XCTAssertFalse(settings.frameInterpolationEnabled)
    }

    // MARK: - ExportMode 测试

    func testExportModeSupportsImage() {
        XCTAssertTrue(ExportMode.superResolutionOnly.supportsImage)
        XCTAssertFalse(ExportMode.frameInterpolationOnly.supportsImage)
        XCTAssertFalse(ExportMode.combined.supportsImage)
    }

    func testExportModeSupportsVideo() {
        XCTAssertTrue(ExportMode.superResolutionOnly.supportsVideo)
        XCTAssertTrue(ExportMode.frameInterpolationOnly.supportsVideo)
        XCTAssertTrue(ExportMode.combined.supportsVideo)
    }

    // MARK: - MediaAsset 测试

    func testMediaAssetEquality() {
        let asset1 = MediaAsset(id: "test1", type: .image, phAsset: nil)
        let asset2 = MediaAsset(id: "test1", type: .video, phAsset: nil)
        let asset3 = MediaAsset(id: "test2", type: .image, phAsset: nil)

        XCTAssertEqual(asset1, asset2)  // same ID
        XCTAssertNotEqual(asset1, asset3)
    }

    // MARK: - PreviewMode 测试

    func testPreviewModeLabels() {
        XCTAssertEqual(PreviewMode.enhanced.label, "增强")
        XCTAssertEqual(PreviewMode.original.label, "原图")
        XCTAssertEqual(PreviewMode.split.label, "对比")
    }

    // MARK: - ExportError 测试

    func testExportErrorDescriptions() {
        XCTAssertEqual(ExportError.unsupportedFormat.errorDescription, "不支持的媒体格式")
        XCTAssertEqual(ExportError.fileCorrupted.errorDescription, "文件已损坏，无法处理")
        XCTAssertEqual(ExportError.insufficientMemory.errorDescription, "设备内存不足，请关闭其他应用后重试")
        XCTAssertEqual(ExportError.cancelled.errorDescription, "任务已取消")
    }
}

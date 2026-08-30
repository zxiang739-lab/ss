//
//  MediaEnhancerTests.swift
//  MediaEnhancerTests
//

import XCTest
@testable import MediaEnhancer

final class MediaEnhancerTests: XCTestCase {

    func testEnhancementSettingsDefaults() {
        let settings = EnhancementSettings()
        XCTAssertTrue(settings.superResolutionEnabled)
        XCTAssertEqual(settings.superResolutionStrength, 0.7)
        XCTAssertEqual(settings.superResolutionScale, .x2)
        XCTAssertFalse(settings.frameInterpolationEnabled)
        XCTAssertEqual(settings.previewMode, .enhanced)
    }

    func testExportModeImageSupport() {
        XCTAssertTrue(ExportMode.superResolution.supportsImage)
        XCTAssertFalse(ExportMode.frameInterpolation.supportsImage)
        XCTAssertFalse(ExportMode.combined.supportsImage)
    }

    func testExportModeVideoSupport() {
        XCTAssertTrue(ExportMode.superResolution.supportsVideo)
        XCTAssertTrue(ExportMode.frameInterpolation.supportsVideo)
        XCTAssertTrue(ExportMode.combined.supportsVideo)
    }

    func testMediaAssetImageInit() {
        let image = UIImage(systemName: "photo")!
        let asset = MediaAsset(image: image, fileName: "test")
        XCTAssertEqual(asset.type, .image)
        XCTAssertEqual(asset.fileName, "test")
        XCTAssertEqual(asset.duration, 0)
        XCTAssertNotNil(asset.originalImage)
    }

    func testSuperResolutionScaleLabels() {
        XCTAssertEqual(SuperResolutionScale.x2.label, "2x")
        XCTAssertEqual(SuperResolutionScale.x3.label, "3x")
        XCTAssertEqual(SuperResolutionScale.x4.label, "4x")
    }

    func testPreviewModeAllCases() {
        XCTAssertEqual(PreviewMode.allCases.count, 3)
        XCTAssertEqual(PreviewMode.original.rawValue, "原图")
        XCTAssertEqual(PreviewMode.enhanced.rawValue, "增强")
        XCTAssertEqual(PreviewMode.split.rawValue, "对比")
    }

    func testMediaEnhancerErrorDescriptions() {
        XCTAssertNotNil(MediaEnhancerError.permissionDenied.errorDescription)
        XCTAssertNotNil(MediaEnhancerError.decodeFailed.errorDescription)
        XCTAssertNotNil(MediaEnhancerError.insufficientMemory.errorDescription)
        XCTAssertNotNil(MediaEnhancerError.cancelled.errorDescription)
    }
}

//
//  VideoFrameDecoder.swift
//  LocalMediaEnhancer
//
//  视频帧解码器 — AVFoundation 逐帧读取本地视频
//  参考:
//  - AVAssetReader: https://developer.apple.com/documentation/avfoundation/avassetreader
//  - AVAssetReaderTrackOutput: https://developer.apple.com/documentation/avfoundation/avassetreadertrackoutput
//  - CMSampleBuffer: https://developer.apple.com/documentation/coremedia/cmsamplebuffer
//

import Foundation
import AVFoundation
import CoreMedia
import UIKit

/// 视频帧解码器 — 从本地视频文件逐帧读取 CMSampleBuffer
final class VideoFrameDecoder {

    private let asset: AVAsset
    private var reader: AVAssetReader?
    private var videoOutput: AVAssetReaderTrackOutput?
    private var audioOutput: AVAssetReaderTrackOutput?

    /// 视频轨道
    private(set) var videoTrack: AVAssetTrack?
    /// 视频时长
    private(set) var duration: CMTime = .zero
    /// 视频尺寸
    private(set) var naturalSize: CGSize = .zero
    /// 原始帧率
    private(set) var nominalFrameRate: Float = 30.0
    /// 总帧数（估算）
    private(set) var totalFrames: Int = 0

    init(url: URL) {
        self.asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
    }

    // MARK: - 准备

    /// 异步准备解码器，加载视频轨道信息
    func prepare() async throws {
        // 参考: https://developer.apple.com/documentation/avfoundation/avasset/1387969-loadtracks
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else {
            throw ExportError.unsupportedFormat
        }
        self.videoTrack = track

        let duration = try await asset.load(.duration)
        self.duration = duration

        let size = try await track.load(.naturalSize)
        self.naturalSize = size

        let frameRate = try await track.load(.nominalFrameRate)
        self.nominalFrameRate = frameRate

        self.totalFrames = Int(CMTimeGetSeconds(duration) * Double(frameRate))

        // 创建 Reader
        let reader = try AVAssetReader(asset: asset)

        // 视频输出配置 — 直接输出 BGRA 格式便于 Metal 处理
        // 参考: https://developer.apple.com/documentation/avfoundation/avassetreadertrackoutput
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        let videoOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        videoOutput.alwaysCopiesSampleData = false

        if reader.canAdd(videoOutput) {
            reader.add(videoOutput)
        }

        self.reader = reader
        self.videoOutput = videoOutput

        guard reader.startReading() else {
            throw ExportError.exportFailed("视频读取器启动失败")
        }
    }

    // MARK: - 逐帧读取

    /// 读取下一帧
    /// - Returns: CMSampleBuffer（视频帧），nil 表示读取结束
    func copyNextFrame() -> CMSampleBuffer? {
        return videoOutput?.copyNextSampleBuffer()
    }

    /// 读取下一个视频帧并转为 CVPixelBuffer
    func copyNextPixelBuffer() -> CVPixelBuffer? {
        guard let sampleBuffer = copyNextFrame() else { return nil }
        return CMSampleBufferGetImageBuffer(sampleBuffer)
    }

    // MARK: - 清理

    func cancelReading() {
        reader?.cancelReading()
    }

    var status: AVAssetReader.Status {
        reader?.status ?? .unknown
    }
}

/// 视频帧信息（用于补帧插值）
struct VideoFrameInfo {
    let pixelBuffer: CVPixelBuffer
    let presentationTime: CMTime
    let index: Int
}

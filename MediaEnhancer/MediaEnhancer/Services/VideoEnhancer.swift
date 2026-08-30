//
//  VideoEnhancer.swift
//  MediaEnhancer
//
//  视频实时预览增强 — AVPlayer 播放 + CIFilter 超分
//  参考: https://developer.apple.com/documentation/avfoundation
//

import Foundation
import AVFoundation
import CoreImage
import UIKit
import Combine

/// 视频增强引擎
final class VideoEnhancer: ObservableObject {
    @Published var isPlaying: Bool = false

    private(set) var player: AVPlayer?
    private var timeObserver: Any?
    private var currentFilter: CIFilter?

    /// 当前播放进度 0...1
    @Published var progress: Double = 0

    func prepare(with asset: MediaAsset) {
        guard asset.type == .video, let url = asset.assetURL else { return }
        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        self.player = player

        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, let duration = player.currentItem?.duration.seconds else { return }
            if duration > 0 {
                self.progress = time.seconds / duration
            }
        }

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
    }

    func togglePlay() {
        guard let player = player else { return }
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
    }

    func seek(to progress: Double) {
        guard let player = player, let duration = player.currentItem?.duration.seconds else { return }
        let time = CMTime(seconds: duration * progress, preferredTimescale: 600)
        player.seek(to: time)
    }

    func configureSuperResolution(enabled: Bool, scale: Double, strength: Double) {
        guard enabled else {
            currentFilter = nil
            player?.currentItem?.videoComposition = nil
            return
        }
        let previewScale = min(scale, 1.5)
        guard let filter = CIFilter(name: "CILanczosScaleTransform") else { return }
        filter.setValue(previewScale, forKey: kCIInputScaleKey)
        filter.setValue(strength, forKey: kCIInputAspectRatioKey)
        currentFilter = filter

        if let playerItem = player?.currentItem {
            let composition = AVVideoComposition(asset: playerItem.asset) { request in
                let source = request.sourceImage.clampedToExtent()
                filter.setValue(source, forKey: kCIInputImageKey)
                if let output = filter.outputImage {
                    request.finish(with: output.cropped(to: request.sourceImage.extent), context: nil)
                } else {
                    request.finish(with: request.sourceImage, context: nil)
                }
            }
            playerItem.videoComposition = composition
        }
    }

    func cleanup() {
        player?.pause()
        if let observer = timeObserver { player?.removeTimeObserver(observer) }
        timeObserver = nil
        player = nil
        isPlaying = false
        progress = 0
    }

    deinit { cleanup() }
}

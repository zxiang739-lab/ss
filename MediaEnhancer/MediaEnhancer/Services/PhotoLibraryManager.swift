//
//  PhotoLibraryManager.swift
//  MediaEnhancer
//
//  相册权限管理与媒体导入
//  参考: https://developer.apple.com/documentation/photokit
//

import Foundation
import Photos
import PhotosUI
import UIKit
import AVFoundation

/// 相册权限与导入管理
final class PhotoLibraryManager: ObservableObject {
    @Published var showsPermissionAlert: Bool = false
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined

    /// 检查当前权限状态
    func checkAuthorizationStatus() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authorizationStatus = status
        if status == .denied || status == .restricted {
            showsPermissionAlert = true
        }
    }

    /// 请求相册权限
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                let granted = (status == .authorized || status == .limited)
                if !granted {
                    self?.showsPermissionAlert = true
                }
                completion(granted)
            }
        }
    }

    /// 打开 App 设置
    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    /// 从 PHPickerResult 加载图片
    func loadImage(from result: PHPickerResult, completion: @escaping (UIImage?) -> Void) {
        let provider = result.itemProvider
        if provider.canLoadObject(ofClass: UIImage.self) {
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async {
                    completion(image as? UIImage)
                }
            }
        } else {
            completion(nil)
        }
    }

    /// 从 PHPickerResult 加载视频文件 URL
    func loadVideo(from result: PHPickerResult, completion: @escaping (URL?, CGSize, TimeInterval) -> Void) {
        let provider = result.itemProvider
        provider.loadFileRepresentation(forTypeIdentifier: "public.movie") { url, _ in
            guard let url = url else {
                DispatchQueue.main.async { completion(nil, .zero, 0) }
                return
            }
            // 复制到临时目录（fileRepresentation URL 会过期）
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(url.pathExtension)
            do {
                try FileManager.default.copyItem(at: url, to: tempURL)
                let asset = AVURLAsset(url: tempURL)
                let duration = asset.duration.seconds
                let size = asset.tracks(withMediaType: .video).first?.naturalSize ?? .zero
                DispatchQueue.main.async {
                    completion(tempURL, size, duration)
                }
            } catch {
                DispatchQueue.main.async { completion(nil, .zero, 0) }
            }
        }
    }

    /// 保存图片到相册
    func saveImageToLibrary(_ image: UIImage, completion: @escaping (Error?) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            DispatchQueue.main.async {
                completion(success ? nil : error)
            }
        }
    }

    /// 保存视频到相册
    func saveVideoToLibrary(_ url: URL, completion: @escaping (Error?) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }) { success, error in
            DispatchQueue.main.async {
                completion(success ? nil : error)
            }
        }
    }
}

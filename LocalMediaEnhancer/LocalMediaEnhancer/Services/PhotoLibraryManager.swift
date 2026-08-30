//
//  PhotoLibraryManager.swift
//  LocalMediaEnhancer
//
//  Photos 框架权限管理与媒体资源导入
//  参考: https://developer.apple.com/documentation/photos
//  iOS 14+ 有限照片库权限 / PHPickerViewController
//  iOS 26 新增: PHPhotoLibrary.shared().accessLevel
//

import Foundation
import Photos
import UIKit
import SwiftUI

/// 相册权限状态
enum PhotoLibraryAuthorizationStatus {
    case notDetermined
    case authorized
    case limited
    case denied
    case restricted

    var isAccessible: Bool {
        self == .authorized || self == .limited
    }
}

/// 相册管理 — 权限申请、资源加载、图片/视频读取
final class PhotoLibraryManager: ObservableObject {

    @Published var authorizationStatus: PhotoLibraryAuthorizationStatus = .notDetermined
    @Published var showsPermissionAlert: Bool = false

    // MARK: - 权限检查

    /// 检查当前权限状态（iOS 26 新 API 兼容）
    func checkAuthorizationStatus() {
        // 参考: https://developer.apple.com/documentation/photos/phphotolibrary/3951041-authorizationstatus
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authorizationStatus = mapStatus(status)

        if status == .notDetermined {
            requestAuthorization()
        } else if status == .denied || status == .restricted {
            showsPermissionAlert = true
        }
    }

    /// 申请相册权限
    func requestAuthorization() {
        // 参考: https://developer.apple.com/documentation/photos/phphotolibrary/3951040-requestauthorization
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = self?.mapStatus(status) ?? .denied
                if status == .denied || status == .restricted {
                    self?.showsPermissionAlert = true
                }
            }
        }
    }

    private func mapStatus(_ status: PHAuthorizationStatus) -> PhotoLibraryAuthorizationStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized:    return .authorized
        case .limited:       return .limited
        case .denied:        return .denied
        case .restricted:    return .restricted
        @unknown default:    return .denied
        }
    }

    // MARK: - 资源加载

    /// 从 PHAsset 异步加载图片
    /// - Parameters:
    ///   - asset: 相册资源
    ///   - targetSize: 目标尺寸（PHImageManagerMaximumSize = 原图）
    ///   - completion: 主线程回调
    func loadImage(for asset: PHAsset,
                   targetSize: CGSize = PHImageManagerMaximumSize,
                   completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false  // 仅本地，禁止 iCloud 网络请求
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isSynchronous = false

        // 参考: https://developer.apple.com/documentation/photos/phimagemanager
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { image, info in
            // 过滤降级结果
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            if !isDegraded {
                DispatchQueue.main.async {
                    completion(image)
                }
            }
        }
    }

    /// 从 PHAsset 异步请求视频文件 URL（AVAsset 方式）
    func loadVideoURL(for asset: PHAsset, completion: @escaping (URL?) -> Void) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = false  // 仅本地
        options.deliveryMode = .highQualityFormat
        options.version = .current

        // 参考: https://developer.apple.com/documentation/photos/phimagemanager/1616935-requestavasset
        PHImageManager.default().requestAVAsset(
            forVideo: asset,
            options: options
        ) { avAsset, _, _ in
            guard let urlAsset = avAsset as? AVURLAsset else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            DispatchQueue.main.async {
                completion(urlAsset.url)
            }
        }
    }

    // MARK: - 保存到相册

    /// 保存图片到相册
    func saveImageToLibrary(_ image: UIImage, completion: @escaping (Bool, Error?) -> Void) {
        // 参考: https://developer.apple.com/documentation/photos/phphotolibrary/1616936-performchanges
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }

    /// 保存视频文件到相册
    func saveVideoToLibrary(at url: URL, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }

    // MARK: - 系统设置跳转

    /// 打开应用设置页面（引导用户开启权限）
    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

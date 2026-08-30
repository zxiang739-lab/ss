//
//  MainView.swift
//  LocalMediaEnhancer
//
//  主页面 — Liquid Glass 导航栏 + 相册导入 + 预览区 + 悬浮控制面板
//  设计参考: iOS 26 Human Interface Guidelines - Liquid Glass
//  https://developer.apple.com/design/human-interface-guidelines/liquid-glass
//

import SwiftUI
import PhotosUI

/// 主页面
struct MainView: View {

    @EnvironmentObject var photoLibraryManager: PhotoLibraryManager
    @StateObject private var previewVM = PreviewViewModel()
    @StateObject private var exportVM = ExportViewModel()

    // PHPicker 配置
    @State private var imagePickerConfiguration: PHPickerConfiguration = {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        return config
    }()

    @State private var videoPickerConfiguration: PHPickerConfiguration = {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .videos
        config.selectionLimit = 1
        return config
    }()

    @State private var showsImagePicker = false
    @State private var showsVideoPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景渐变
                LinearGradient(
                    colors: [.black, .gray.opacity(0.3), .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // 主内容区
                VStack(spacing: 0) {
                    // 预览区域
                    MediaPreviewView(viewModel: previewVM)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Spacer(minLength: 120) // 为悬浮面板留空间
                }

                // 悬浮液态玻璃控制面板
                if previewVM.selectedAsset != nil {
                    FloatingControlPanel(viewModel: previewVM, exportVM: exportVM)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                }
            }
            // iOS 26 Liquid Glass 导航栏
            // 参考: https://developer.apple.com/documentation/swiftui/navigationstack
            .navigationTitle("本地媒体增强")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showsImagePicker = true
                        } label: {
                            Label("导入图片", systemImage: "photo")
                        }
                        Button {
                            showsVideoPicker = true
                        } label: {
                            Label("导入视频", systemImage: "video")
                        }
                        if previewVM.selectedAsset != nil {
                            Divider()
                            Button(role: .destructive) {
                                previewVM.clearSelection()
                            } label: {
                                Label("清除当前", systemImage: "trash")
                            }
                        }
                    } label: {
                        // iOS 26 Liquid Glass 按钮样式
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            // iOS 26 导航栏材质
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        // 相册权限弹窗
        .alert("需要相册权限", isPresented: $photoLibraryManager.showsPermissionAlert) {
            Button("去设置") {
                photoLibraryManager.openAppSettings()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("LocalMediaEnhancer 需要访问相册以导入本地图片和视频。所有处理均在设备本地完成，不会上传任何数据。")
        }
        // 错误弹窗
        .alert(item: Binding(
            get: { previewVM.error.map { ErrorWrapper(error: $0) } },
            set: { _ in previewVM.error = nil }
        )) { wrapper in
            Alert(
                title: Text("处理出错"),
                message: Text(wrapper.error.errorDescription ?? "未知错误"),
                dismissButton: .default(Text("确定"))
            )
        }
        // 图片选择器
        .sheet(isPresented: $showsImagePicker) {
            PhotoPicker(configuration: imagePickerConfiguration) { result in
                if let result = result.first {
                    previewVM.importImage(from: result)
                }
                showsImagePicker = false
            }
        }
        // 视频选择器
        .sheet(isPresented: $showsVideoPicker) {
            PhotoPicker(configuration: videoPickerConfiguration) { result in
                if let result = result.first {
                    previewVM.importVideo(from: result)
                }
                showsVideoPicker = false
            }
        }
        // 导出 Sheet
        .sheet(isPresented: $exportVM.showsExportSheet) {
            if let asset = previewVM.selectedAsset {
                ExportSheet(viewModel: exportVM, asset: asset, settings: previewVM.settings)
            }
        }
        .onAppear {
            photoLibraryManager.checkAuthorizationStatus()
        }
    }
}

// MARK: - PHPicker 封装

/// PHPickerViewController 的 SwiftUI 封装
/// 参考: https://developer.apple.com/documentation/photokit/phpickerviewcontroller
struct PhotoPicker: UIViewControllerRepresentable {
    let configuration: PHPickerConfiguration
    let onPicked: ([PHPickerResult]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPicked: ([PHPickerResult]) -> Void

        init(onPicked: @escaping ([PHPickerResult]) -> Void) {
            self.onPicked = onPicked
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            onPicked(results)
        }
    }
}

// MARK: - Error Wrapper

struct ErrorWrapper: Identifiable {
    let id = UUID()
    let error: LocalizedError
}

#Preview {
    MainView()
        .environmentObject(PhotoLibraryManager())
}

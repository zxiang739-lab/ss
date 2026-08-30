//
//  MainView.swift
//  MediaEnhancer
//
//  主页面 — 导航栏 + 相册导入 + 预览区 + 控制面板
//

import SwiftUI
import PhotosUI

struct MainView: View {
    @EnvironmentObject var photoLibraryManager: PhotoLibraryManager
    @StateObject private var previewVM = PreviewViewModel()
    @StateObject private var exportVM = ExportViewModel()

    @State private var showsImagePicker = false
    @State private var showsVideoPicker = false

    private var imagePickerConfig: PHPickerConfiguration {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        return config
    }

    private var videoPickerConfig: PHPickerConfiguration {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .videos
        config.selectionLimit = 1
        return config
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(uiColor: .systemBackground), Color(uiColor: .secondarySystemBackground)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    MediaPreviewView(viewModel: previewVM)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Spacer(minLength: 130)
                }

                if previewVM.selectedAsset != nil {
                    VStack {
                        Spacer()
                        ControlPanel(viewModel: previewVM, exportVM: exportVM)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                    }
                }

                if previewVM.selectedAsset == nil {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("导入图片或视频开始增强")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("所有处理均在本地完成，不上传网络")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .navigationTitle("媒体增强")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showsImagePicker = true } label: {
                            Label("导入图片", systemImage: "photo")
                        }
                        Button { showsVideoPicker = true } label: {
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
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .alert("需要相册权限", isPresented: $photoLibraryManager.showsPermissionAlert) {
                Button("去设置") { photoLibraryManager.openAppSettings() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("MediaEnhancer 需要访问相册以导入本地图片和视频。所有处理均在设备本地完成。")
            }
            .alert(item: Binding(
                get: { previewVM.error.map { ErrorWrapper(error: $0) } },
                set: { _ in previewVM.error = nil }
            )) { wrapper in
                Alert(
                    title: Text("出错了"),
                    message: Text(wrapper.error.errorDescription ?? "未知错误"),
                    dismissButton: .default(Text("确定"))
                )
            }
            .sheet(isPresented: $showsImagePicker) {
                PhotoPicker(configuration: imagePickerConfig) { results in
                    if let result = results.first { previewVM.importImage(from: result) }
                    showsImagePicker = false
                }
            }
            .sheet(isPresented: $showsVideoPicker) {
                PhotoPicker(configuration: videoPickerConfig) { results in
                    if let result = results.first { previewVM.importVideo(from: result) }
                    showsVideoPicker = false
                }
            }
            .sheet(isPresented: $exportVM.showsExportSheet) {
                if let asset = previewVM.selectedAsset {
                    ExportSheet(viewModel: exportVM, asset: asset, settings: previewVM.settings)
                }
            }
            .onAppear { photoLibraryManager.checkAuthorizationStatus() }
        }
    }
}

struct PhotoPicker: UIViewControllerRepresentable {
    let configuration: PHPickerConfiguration
    let onPicked: ([PHPickerResult]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPicked: ([PHPickerResult]) -> Void
        init(onPicked: @escaping ([PHPickerResult]) -> Void) { self.onPicked = onPicked }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            onPicked(results)
        }
    }
}

struct ErrorWrapper: Identifiable {
    let id = UUID()
    let error: LocalizedError
}

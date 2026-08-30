//
//  ExportViewModel.swift
//  LocalMediaEnhancer
//
//  离线导出 ViewModel — 管理导出 Sheet 状态与任务
//

import Foundation
import SwiftUI
import Combine

/// 导出 Sheet ViewModel
@MainActor
final class ExportViewModel: ObservableObject {

    /// 是否显示导出 Sheet
    @Published var showsExportSheet: Bool = false

    /// 选中的导出模式
    @Published var selectedMode: ExportMode = .superResolutionOnly

    /// 当前导出任务
    @Published var currentTask: ExportTask?

    /// 导出完成提示
    @Published var showsCompletionAlert: Bool = false

    /// 错误信息
    @Published var error: LocalizedError?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - 开始导出

    /// 开始导出任务
    func startExport(asset: MediaAsset, settings: EnhancementSettings) {
        // 验证模式与媒体类型匹配
        if asset.type == .image && !selectedMode.supportsImage {
            error = ExportError.unsupportedFormat
            return
        }

        let task = ExportTask(asset: asset, mode: selectedMode, settings: settings)

        // 监听任务状态变化
        task.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .completed:
                    self?.showsCompletionAlert = true
                case .failed(let error):
                    self?.error = error
                default:
                    break
                }
            }
            .store(in: &cancellables)

        currentTask = task
        ExportManager.shared.addTask(task)
    }

    /// 取消当前任务
    func cancelCurrentTask() {
        currentTask?.cancel()
        currentTask = nil
    }

    /// 关闭 Sheet 并清理
    func dismiss() {
        showsExportSheet = false
        currentTask = nil
        error = nil
        showsCompletionAlert = false
    }

    /// 可用的导出模式（根据媒体类型过滤）
    func availableModes(for asset: MediaAsset?) -> [ExportMode] {
        guard let asset = asset else { return ExportMode.allCases }
        return ExportMode.allCases.filter { mode in
            switch asset.type {
            case .image: return mode.supportsImage
            case .video: return mode.supportsVideo
            }
        }
    }

    /// 当前进度（0~1）
    var currentProgress: Double {
        guard let task = currentTask else { return 0 }
        if case .processing(let progress) = task.status {
            return progress
        }
        if case .completed = task.status { return 1.0 }
        return 0
    }

    /// 是否正在处理
    var isProcessing: Bool {
        guard let task = currentTask else { return false }
        if case .processing = task.status { return true }
        return false
    }

    /// 是否已完成
    var isCompleted: Bool {
        guard let task = currentTask else { return false }
        if case .completed = task.status { return true }
        return false
    }
}

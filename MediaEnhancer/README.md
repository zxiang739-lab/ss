# MediaEnhancer

本地媒体增强工具 — 图片超分辨率、视频超分与补帧，全部离线本地处理。

## 功能

### 模式1：实时预览增强
- 从相册导入图片或视频
- 图片：CoreImage CILanczosScaleTransform 实时超分 + 锐化，支持原图/增强/分屏对比
- 视频：AVPlayer 实时播放，AVVideoComposition 应用实时超分滤镜
- 悬浮控制面板：超分开关、补帧开关、强度滑块、倍率选择、预览模式切换

### 模式2：离线导出
- 图片：超分后保存到相册
- 视频：AVAssetExportSession 导出，支持超分、补帧、组合模式
- 进度展示、取消任务、完成提示

## 技术栈

- **Deployment Target**: iOS 16.0
- **UI**: SwiftUI (NavigationStack, .sheet, .ultraThinMaterial)
- **图片超分**: CoreImage (CILanczosScaleTransform + CISharpenLuminance)
- **视频播放**: AVFoundation (AVPlayer, AVVideoComposition)
- **视频导出**: AVFoundation (AVAssetExportSession)
- **相册**: Photos / PhotosUI (PHPickerViewController)
- **零第三方依赖**，全部系统原生框架

## 项目结构

```
MediaEnhancer/
├── MediaEnhancer.xcodeproj/
├── MediaEnhancer/
│   ├── MediaEnhancerApp.swift      # App 入口
│   ├── Models/
│   │   ├── MediaAsset.swift        # 媒体资源模型
│   │   ├── EnhancementSettings.swift # 增强参数
│   │   └── ExportTask.swift        # 导出模式与错误类型
│   ├── Services/
│   │   ├── PhotoLibraryManager.swift # 相册权限与导入
│   │   ├── ImageEnhancer.swift     # 图片超分引擎
│   │   ├── VideoEnhancer.swift     # 视频播放与实时滤镜
│   │   └── ExportManager.swift     # 离线导出管理
│   ├── ViewModels/
│   │   ├── PreviewViewModel.swift  # 预览 VM
│   │   └── ExportViewModel.swift   # 导出 VM
│   ├── Views/
│   │   ├── MainView.swift          # 主界面
│   │   ├── MediaPreviewView.swift  # 预览视图
│   │   ├── ControlPanel.swift      # 悬浮控制面板
│   │   └── ExportSheet.swift       # 导出 Sheet
│   └── Assets.xcassets/
├── MediaEnhancerTests/
└── README.md
```

## 使用方式

1. 用 Xcode 14+ 打开 `MediaEnhancer.xcodeproj`
2. 设置 Team 签名
3. 编译运行
4. App Icon 需手动拖入 1024×1024 PNG 到 Assets.xcassets/AppIcon

## 注意

- 视频实时超分预览使用较低倍率（最高 1.5x）保证流畅度
- 离线导出使用完整倍率
- 所有处理均在设备本地完成，不上传任何数据

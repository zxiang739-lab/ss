# LocalMediaEnhancer

> 纯原生 iOS 26+ 本地媒体增强 App — 图片/视频超分辨率与运动补帧，全部离线本地运行。

## 系统要求

- **Deployment Target**: iOS 26.0
- **兼容系统**: iOS 26、iOS 27
- **Xcode**: 26.0+
- **Swift**: 5.0+

## 核心特性

### 模式 1：文件实时预览增强

- 从相册导入本地图片或视频，实时预览增强效果
- 图片：Vision/CoreML 超分 API，原图/增强/分屏对比切换
- 视频：Metal 管线实时帧处理，播放时动态切换超分/补帧开关
- 液态玻璃悬浮控制面板，强度滑块实时调节
- **仅预览，不自动写入相册**

### 模式 2：离线文件导出处理

- 三种任务选项：仅超分 / 仅补帧 / 超分+补帧组合
- 图片：增强后高分辨率图片写入相册
- 视频：AVFoundation + VideoToolbox 编码输出新视频
- 实时进度展示，支持取消任务
- 大文件内存管控，防止 OOM

## 技术架构

```
LocalMediaEnhancer/
├── Models/                    # 数据模型
│   ├── MediaAsset.swift       # 媒体资源封装
│   ├── EnhancementSettings.swift  # 增强参数
│   └── ExportTask.swift       # 导出任务与错误
├── Services/                  # 核心引擎
│   ├── PhotoLibraryManager.swift   # Photos 权限与导入
│   ├── ImageEnhancer.swift    # 图片超分 (Vision/CoreML/CoreImage)
│   ├── VideoEnhancer.swift    # 视频增强协调器
│   ├── VideoFrameDecoder.swift    # AVFoundation 帧解码
│   ├── MetalRenderer.swift    # Metal GPU 渲染管线
│   └── ExportManager.swift    # 离线导出管理
├── ViewModels/
│   ├── PreviewViewModel.swift # 实时预览 VM
│   └── ExportViewModel.swift  # 导出 VM
└── Views/
    ├── MainView.swift         # 主页面
    ├── MediaPreviewView.swift # 预览区
    ├── FloatingControlPanel.swift  # 悬浮控制面板
    ├── ExportSheet.swift      # 导出 Sheet
    └── Components/
        └── ErrorAlert.swift   # 错误提示
```

## 使用的原生框架

| 框架 | 用途 |
|------|------|
| **AVFoundation** | 视频解码、播放、导出 |
| **Vision** | 图片超分、光流估计（运动补帧） |
| **CoreML** | 本地机器学习推理 |
| **VideoToolbox** | 视频硬编码 |
| **Metal** | GPU 帧处理与渲染 |
| **CoreImage** | 图像滤镜与缩放 |
| **ImageIO** | 图像编解码 |
| **Photos** | 相册访问与保存 |
| **SwiftUI** | UI 框架（Liquid Glass 设计语言） |

> **零第三方依赖**：不使用任何第三方 SDK、模型或网络请求。所有运算在设备本地完成。

## iOS 26 / iOS 27 API 适配

项目使用 `#available` / `@available` 区分系统版本：

```swift
if #available(iOS 26.0, *) {
    // iOS 26 新媒体增强 API
    let request = VNGenerateImageEnhancementRequest()
}

if #available(iOS 27.0, *) {
    // iOS 27 新增 API 适配
}
```

关键适配点：
- `VNGenerateImageEnhancementRequest`（iOS 26 Vision 新增）
- `VNGenerateOpticalFlowRequest`（iOS 26 Vision 光流）
- `.glassBackgroundEffect()`（iOS 26 SwiftUI 液态玻璃）
- `PHPhotoLibrary.authorizationStatus(for: .readWrite)`（iOS 14+，iOS 26 延续）

## App Icon 配置要点

遵循 [Apple Developer - App Icon](https://developer.apple.com/design/human-interface-guidelines/app-icons) 文档：

### Xcode Asset Catalog 配置

- 使用 `Assets.xcassets/AppIcon.appiconset/`
- iOS 26 采用 **单尺寸 1024×1024** 通用图标（Xcode 自动生成各尺寸）
- 配置文件 `Contents.json` 声明 `idiom: universal`, `platform: ios`, `size: 1024x1024`
- 无需手动提供多尺寸切片

### 图标图层规范

| 属性 | 规范 |
|------|------|
| 格式 | PNG（推荐）或 PDF 矢量 |
| 尺寸 | 1024×1024 px |
| 色彩空间 | sRGB 或 Display P3 |
| 透明背景 | **禁止**（App Icon 不允许透明） |
| 圆角 | 系统自动裁剪，提供正方形原图 |
| 光泽效果 | 系统自动添加，不要手动绘制 |
| 图层 | 单层扁平设计，不使用 alpha 通道 |

> 本项目不包含自定义艺术图标，开发者需在 Xcode 中拖入 1024×1024 PNG 到 AppIcon 占位符。

## Liquid Glass 设计遵循

严格遵循 [iOS 26 Human Interface Guidelines - Liquid Glass](https://developer.apple.com/design/human-interface-guidelines/liquid-glass)：

- 使用系统材质 `.ultraThinMaterial`、`.regularMaterial`
- 使用 `.glassBackgroundEffect()` 修饰符（不手写模拟玻璃）
- 导航栏、Sheet、弹窗均采用系统原生样式
- 控件使用系统 `Toggle`、`Slider`、`Picker`、`Button`
- 不自定义绘制毛玻璃/折射效果

## 权限说明

Info.plist 配置（通过 Xcode Build Settings 生成）：

- `NSPhotoLibraryUsageDescription` — 读取相册导入媒体
- `NSPhotoLibraryAddUsageDescription` — 保存增强结果到相册

所有处理均在本地完成，**不发起任何网络请求**。

## 编译运行

1. 用 Xcode 26+ 打开 `LocalMediaEnhancer.xcodeproj`
2. 选择 iOS 26+ 模拟器或真机
3. 设置 Team（签名）
4. 编译运行

## 单元测试

`LocalMediaEnhancerTests` 包含模型层单元测试，可在 Xcode 中按 `Cmd+U` 运行。

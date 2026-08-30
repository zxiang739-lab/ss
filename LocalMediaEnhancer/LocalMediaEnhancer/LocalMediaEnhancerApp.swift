//
//  LocalMediaEnhancerApp.swift
//  LocalMediaEnhancer
//
//  App 入口 — 纯 SwiftUI 生命周期，iOS 26+ Liquid Glass 设计语言
//  参考: Apple Developer Documentation - App Protocol
//  https://developer.apple.com/documentation/swiftui/app
//

import SwiftUI

@main
struct LocalMediaEnhancerApp: App {

    // 全局共享的相册权限管理器（iOS 26 Photos 框架）
    // 参考: https://developer.apple.com/documentation/photos/phphotolibrary
    @StateObject private var photoLibraryManager = PhotoLibraryManager()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(photoLibraryManager)
                // iOS 26 全局 Liquid Glass 色调
                // 参考: https://developer.apple.com/design/human-interface-guidelines/liquid-glass
                .tint(.accentColor)
                .preferredColorScheme(.dark)
        }
    }
}

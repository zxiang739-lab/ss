//
//  MediaEnhancerApp.swift
//  MediaEnhancer
//
//  App 入口
//

import SwiftUI

@main
struct MediaEnhancerApp: App {
    @StateObject private var photoLibraryManager = PhotoLibraryManager()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(photoLibraryManager)
        }
    }
}

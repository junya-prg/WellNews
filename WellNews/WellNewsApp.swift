//
//  WellNewsApp.swift
//  WellNews
//
//  WellNews アプリケーションのエントリーポイント
//

import SwiftUI

@main
struct WellNewsApp: App {
    @State private var showSplash = true
    
    init() {
        // AdMobの初期化
        AdManager.shared.initialize()
        // StoreKit 2商品のロード & 状態同期
        StoreManager.shared.initialize()
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                MainTabView()
                
                if showSplash {
                    SplashScreenView {
                        withAnimation {
                            showSplash = false
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
    }
}



//
//  WellNewsApp.swift
//  WellNews
//
//  WellNews アプリケーションのエントリーポイント
//

import SwiftUI
import AppTrackingTransparency

@main
struct WellNewsApp: App {
    init() {
        // AdMobの初期化
        AdManager.shared.initialize()
        // StoreKit 2商品のロード & 状態同期
        StoreManager.shared.initialize()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// ルートビュー - スプラッシュスクリーンとメイン画面を管理、ATT/UMPフローを実行する
struct RootView: View {
    @State private var showSplash = true
    
    var body: some View {
        ZStack {
            MainTabView()
            
            if showSplash {
                SplashScreenView {
                    showSplash = false
                    // スプラッシュ終了後 → UMP同意 → ATT の順でリクエスト
                    Task { @MainActor in
                        await runConsentAndTrackingFlow()
                    }
                }
                .transition(.opacity)
            }
        }
    }
    
    /// UMP同意フロー → ATTリクエストの順に実行する
    /// AdMob は UMP 同意取得後に ATT を呼ぶことを推奨している
    @MainActor
    private func runConsentAndTrackingFlow() async {
        await withCheckedContinuation { continuation in
            ConsentManager.shared.gatherConsent {
                continuation.resume()
            }
        }
        requestTrackingPermission()
    }
    
    /// トラッキング許可をリクエスト
    private func requestTrackingPermission() {
        let status = ATTrackingManager.trackingAuthorizationStatus
        
        // すでに許可状態が決定している場合はダイアログを出さず、AdManagerにATT確定を通知
        guard status == .notDetermined else {
            AdManager.shared.markATTResolved()
            return
        }
        
        ATTrackingManager.requestTrackingAuthorization { _ in
            DispatchQueue.main.async {
                AdManager.shared.markATTResolved()
            }
        }
    }
}



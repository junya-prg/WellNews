//
//  AdManager.swift
//  WellNews
//
//  広告管理サービス
//  Google AdMobを使用したバナー広告・ネイティブ広告の初期化・管理
//

import Foundation
import SwiftUI
import GoogleMobileAds
import os

private let logger = Logger(subsystem: "jp.junya.WellNews", category: "AdManager")

/// 広告管理サービス
@MainActor
@Observable
final class AdManager {
    /// シングルトンインスタンス
    static let shared = AdManager()
    
    /// 広告の初期化完了フラグ（MobileAds SDK の start() 完了）
    private(set) var isInitialized = false

    /// ATT（App Tracking Transparency）の許可状態が確定したか
    /// .notDetermined → ダイアログ応答後 true、既に .authorized/.denied/.restricted なら初期化時に true
    var attResolved = false

    /// UMP（User Messaging Platform）同意フローが完了したか
    /// 同意フォーム表示が不要な地域でも、ConsentInfo の更新完了で true になる
    var consentResolved = false

    /// 広告をロードしてよい状態か（SDK初期化完了 かつ 同意確定 かつ ATT確定）
    var canLoadAds: Bool { isInitialized && consentResolved && attResolved }

    // MARK: - 広告ユニットID
    
    // テストモード: 実機/シミュレータでの開発中はtrueに設定。リリース時はfalseに設定します。
    private let useTestAds = false
    
    /// バナー広告ユニットID
    var bannerAdUnitId: String {
        if useTestAds {
            // Googleの公式テスト広告ID
            return "ca-app-pub-3940256099942544/2934735716"
        } else {
            // 本番用（WellNews_banner）
            return "ca-app-pub-2534039379765102/3097958702"
        }
    }
    
    /// ネイティブ広告ユニットID
    var nativeAdUnitId: String {
        if useTestAds {
            // Googleの公式テスト広告ID
            return "ca-app-pub-3940256099942544/3986624511"
        } else {
            // 本番用（WellNews_native）
            return "ca-app-pub-2534039379765102/8253552231"
        }
    }
    
    private init() {}
    
    /// AdMobを初期化する
    /// AppDelegate または App の初期化時に呼び出す
    func initialize() {
        guard !isInitialized else { return }
        
        // Google Mobile Ads SDKの初期化
        Task { @MainActor in
            await MobileAds.shared.start()
            self.isInitialized = true
            logger.info("✅ AdMob初期化完了")
        }
    }

    /// ATT許可状態が確定したことを通知する
    func markATTResolved() {
        attResolved = true
        logger.info("✅ ATT状態確定")
    }

    /// UMP 同意フローが完了したことを通知する
    func markConsentResolved() {
        consentResolved = true
        logger.info("✅ UMP同意フロー完了")
    }
}

// MARK: - 広告表示の設定

/// 広告表示設定
struct AdConfiguration {
    /// ニュース一覧でネイティブ広告を表示するか（無料ユーザー向け）
    static let showNativeInNews = true
    
    /// ブックマーク一覧でバナー広告を表示するか（無料ユーザー向け）
    static let showBannerInBookmarks = true
    
    /// ネイティブ広告を表示する間隔（記事数）
    static let nativeAdInterval = 4
}

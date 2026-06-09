//
//  ATTManager.swift
//  WellNews
//
//  App Tracking Transparency (ATT) 管理サービス
//  iOS 14.5以降で広告トラッキングの許可を求める
//

import Foundation
import AppTrackingTransparency
import AdSupport
import os

private let logger = Logger(subsystem: "jp.junya.WellNews", category: "ATTManager")

/// ATT管理サービス
@MainActor
@Observable
final class ATTManager {
    /// シングルトンインスタンス
    static let shared = ATTManager()
    
    /// 現在のトラッキング許可ステータス
    private(set) var trackingStatus: ATTrackingManager.AuthorizationStatus = .notDetermined
    
    /// トラッキングが許可されているか
    var isTrackingAuthorized: Bool {
        trackingStatus == .authorized
    }
    
    /// 許可リクエスト済みか
    var hasRequestedPermission: Bool {
        trackingStatus != .notDetermined
    }
    
    private init() {
        // 現在のステータスを取得
        trackingStatus = ATTrackingManager.trackingAuthorizationStatus
    }
    
    /// トラッキング許可をリクエストする
    /// アプリ起動時に一度だけ呼び出す
    func requestTrackingAuthorization() async {
        // すでに決定済みの場合はスキップ
        guard trackingStatus == .notDetermined else {
            logger.info("ℹ️ ATT: すでに決定済み（ステータス: \(String(describing: self.trackingStatus.rawValue))）")
            return
        }
        
        logger.info("📢 ATT: トラッキング許可をリクエスト")
        
        let status = await ATTrackingManager.requestTrackingAuthorization()
        trackingStatus = status
        
        switch status {
        case .authorized:
            logger.info("✅ ATT: トラッキング許可")
            // IDFAを取得可能
            let idfa = ASIdentifierManager.shared().advertisingIdentifier
            logger.info("📱 IDFA: \(idfa.uuidString)")
            
        case .denied:
            logger.info("❌ ATT: トラッキング拒否")
            
        case .restricted:
            logger.info("⚠️ ATT: トラッキング制限")
            
        case .notDetermined:
            logger.info("❓ ATT: 未決定")
            
        @unknown default:
            logger.warning("⚠️ ATT: 不明なステータス")
        }
    }
    
    /// ステータスの説明文を取得
    var statusDescription: String {
        switch trackingStatus {
        case .authorized:
            return "許可済み"
        case .denied:
            return "拒否"
        case .restricted:
            return "制限あり"
        case .notDetermined:
            return "未設定"
        @unknown default:
            return "不明"
        }
    }
}

//
//  StoreManager.swift
//  WellNews
//
//  アプリ内課金（StoreKit 2）の管理サービス
//  プレミアムプラン（買い切り）の購入状態および開発者支援チップの管理
//

import Foundation
import StoreKit
import os

private let logger = Logger(subsystem: "jp.junya.WellNews", category: "StoreManager")

/// チップ商品の種類
enum TipProduct: String, CaseIterable, Identifiable {
    case coffee = "jp.junya.WellNews.tip.coffee"
    case developer = "jp.junya.WellNews.tip.developer"
    case cheer = "jp.junya.WellNews.tip.cheer"
    
    var id: String { rawValue }
    
    /// 表示名
    var displayName: String {
        switch self {
        case .coffee: return String(localized: "コーヒー1杯")
        case .developer: return String(localized: "開発サポート")
        case .cheer: return String(localized: "応援サポート")
        }
    }
    
    /// アイコン
    var iconName: String {
        switch self {
        case .coffee: return "cup.and.saucer.fill"
        case .developer: return "flame.fill"
        case .cheer: return "heart.fill"
        }
    }
    
    /// 説明文
    var description: String {
        switch self {
        case .coffee: return String(localized: "開発者にコーヒーを奢る")
        case .developer: return String(localized: "開発者を応援する")
        case .cheer: return String(localized: "アプリ開発をさらに応援する")
        }
    }
}

/// チップ・プレミアム管理サービス
@MainActor
@Observable
final class StoreManager {
    /// 共有インスタンス
    static let shared = StoreManager()
    
    /// 読み込まれた全製品リスト
    private(set) var products: [Product] = []
    
    /// 開発者支援チップの製品リスト
    private(set) var tips: [Product] = []
    
    /// プレミアムプランの製品
    private(set) var premiumProduct: Product?
    
    /// プレミアムプラン（買い切り）が購入済みかどうか
    private(set) var isPremium = false
    
    /// 読み込み中フラグ
    private(set) var isLoading = false
    
    /// 購入処理中フラグ
    private(set) var isPurchasing = false
    
    /// エラーメッセージ
    var errorMessage: String?
    
    /// 購入成功フラグ
    var purchaseSucceeded = false
    
    /// トランザクション監視のリスナー・タスク
    private var transactionListenerTask: Task<Void, Error>?
    
    private init() {
        // バックグラウンドでのトランザクションのアップデートを常時監視
        startTransactionListener()
        
        // ローカルに保存されているキャッシュの状態を確認
        self.isPremium = UserDefaults.standard.bool(forKey: "wellnews.isPremium")
    }
    
    /// アプリ起動時の初期処理
    func initialize() {
        Task {
            // 所有状況の同期
            await updatePremiumStatus()
            // 商品リストのロード
            await loadProducts()
        }
    }
    
    /// 商品情報をロードする
    func loadProducts() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // プレミアム商品ID + チップ商品ID
            let productIDs = [
                "jp.junya.WellNews.premium.lifetime"
            ] + TipProduct.allCases.map { $0.rawValue }
            
            let storeProducts = try await Product.products(for: productIDs)
            self.products = storeProducts
            
            // チップ商品をフィルターして価格順にソート
            self.tips = storeProducts.filter { product in
                TipProduct.allCases.contains { $0.rawValue == product.id }
            }.sorted { $0.price < $1.price }
            
            // プレミアムプランの商品を設定
            self.premiumProduct = storeProducts.first { $0.id == "jp.junya.WellNews.premium.lifetime" }
            
            logger.info("✅ 商品ロード完了: チップ \(self.tips.count)件, プレミアム \(self.premiumProduct != nil ? "あり" : "なし")")
        } catch {
            logger.error("❌ 商品の読み込みに失敗: \(error.localizedDescription)")
            errorMessage = String(localized: "商品情報の取得に失敗しました。")
        }
        
        isLoading = false
    }
    
    /// 商品を購入する
    func purchase(_ product: Product) async {
        guard !isPurchasing else { return }
        
        isPurchasing = true
        errorMessage = nil
        purchaseSucceeded = false
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // トランザクションを検証
                switch verification {
                case .verified(let transaction):
                    logger.info("✅ 購入完了: \(product.id)")
                    purchaseSucceeded = true
                    
                    // トランザクション完了をマーク
                    await transaction.finish()
                    
                    // 購入内容に応じてステータス更新
                    await updatePremiumStatus()
                    
                case .unverified(_, let error):
                    logger.error("❌ トランザクション検証失敗: \(error.localizedDescription)")
                    errorMessage = String(localized: "購入内容の署名検証に失敗しました。")
                }
                
            case .userCancelled:
                logger.info("ℹ️ ユーザーが購入をキャンセルしました")
                
            case .pending:
                logger.info("ℹ️ 購入処理が保留中（承認待ちなど）")
                errorMessage = String(localized: "購入処理が保留中です。管理者の承認後に反映されます。")
                
            @unknown default:
                logger.warning("⚠️ 未知の購入結果")
            }
        } catch {
            logger.error("❌ 購入処理中にエラー発生: \(error.localizedDescription)")
            errorMessage = String(localized: "購入処理中にエラーが発生しました。")
        }
        
        isPurchasing = false
    }
    
    /// 購入を復元する（非消費型用）
    func restorePurchases() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            // App Storeから最新の購入トランザクションを同期
            try await AppStore.sync()
            await updatePremiumStatus()
            logger.info("✅ 購入復元処理完了")
            purchaseSucceeded = true
        } catch {
            logger.error("❌ 購入復元中にエラー発生: \(error.localizedDescription)")
            errorMessage = String(localized: "購入の復元に失敗しました。")
        }
        
        isLoading = false
    }
    
    /// プレミアム（非消費型）の現在の購入状態を確認して反映する
    private func updatePremiumStatus() async {
        // App Store から現在所有している権利をスキャン
        var purchased = false
        
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if transaction.productID == "jp.junya.WellNews.premium.lifetime" {
                    // 有効期限のチェック（非消費型の場合は期限なし、無効化されていないこと）
                    if transaction.revocationDate == nil {
                        purchased = true
                    }
                }
            case .unverified(_, let error):
                logger.error("⚠️ 未検証のエンタイトルメント検出: \(error.localizedDescription)")
            }
        }
        
        self.isPremium = purchased
        UserDefaults.standard.set(purchased, forKey: "wellnews.isPremium")
        logger.info("📊 プレミアム権限ステータス更新: \(purchased)")
    }
    
    /// 購入通知の常時監視リスナー
    private func startTransactionListener() {
        transactionListenerTask = Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }
                
                // アクターをメインに移動してステータス更新
                await MainActor.run {
                    Task {
                        switch result {
                        case .verified(let transaction):
                            logger.info("🔔 トランザクションの外部更新を検知: \(transaction.productID)")
                            await transaction.finish()
                            await self.updatePremiumStatus()
                        case .unverified(_, let error):
                            logger.error("🔔 トランザクションの外部更新の検証失敗: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
}

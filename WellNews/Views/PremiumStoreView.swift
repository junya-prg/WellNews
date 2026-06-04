//
//  PremiumStoreView.swift
//  WellNews
//
//  プレミアムプランのご案内・購入モーダル画面
//

import SwiftUI
import StoreKit

struct PremiumStoreView: View {
    @Environment(\.dismiss) private var dismiss
    private var storeManager = StoreManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // ヘッダー部
                    VStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .orange.opacity(0.3), radius: 10, x: 0, y: 5)
                            .padding(.top, 16)
                        
                        Text("WellNews Premium")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        
                        Text("健康ニュースをもっと快適に、もっと深く")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // 特典リスト
                    VStack(spacing: 16) {
                        FeatureRow(
                            icon: "eye.slash.fill",
                            color: .blue,
                            title: "完全広告非表示",
                            description: "記事一覧のインライン広告やブックマーク画面のバナーなど、すべての広告を非表示にして読書に集中できます。"
                        )
                        
                        FeatureRow(
                            icon: "play.circle.fill",
                            color: .purple,
                            title: "健康ラジオ 連続再生の無制限化",
                            description: "通常最大5記事のところ、制限なくすべての記事を続けて聴き流せるようになり、長時間のウォーキングや家事に最適です。"
                        )
                        
                        FeatureRow(
                            icon: "tag.fill",
                            color: .green,
                            title: "健康キーワードの無制限登録",
                            description: "気になる健康トピック（ヨガ、高血圧、睡眠等）を最大10個の制限なく、何個でも登録・追跡できます。"
                        )
                        
                        FeatureRow(
                            icon: "sparkles",
                            color: .indigo,
                            title: "今後の追加特典も自動付与",
                            description: "テーマ変更、リッチウィジェット機能など、今後追加される予定のすべてのプレミアム機能も追加料金なしで利用できます。"
                        )
                    }
                    .padding(.horizontal)
                    
                    Spacer().frame(height: 16)
                    
                    // 購入セクション
                    VStack(spacing: 16) {
                        if storeManager.isPremium {
                            // 購入済み状態
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.title)
                                    .foregroundColor(.green)
                                Text("すでにプレミアムプランに参加しています")
                                    .font(.headline)
                                Text("いつもWellNewsをご利用いただきありがとうございます！")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            // 未購入状態
                            if storeManager.isLoading {
                                ProgressView("商品情報を取得中...")
                                    .padding()
                            } else if let product = storeManager.premiumProduct {
                                Button(action: {
                                    Task {
                                        await storeManager.purchase(product)
                                    }
                                }) {
                                    VStack(spacing: 4) {
                                        Text("プレミアムに参加する")
                                            .font(.headline)
                                        Text("\(product.displayPrice)（買い切り・永久有効）")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(
                                            colors: [.purple, .indigo],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .shadow(color: .indigo.opacity(0.3), radius: 8, x: 0, y: 4)
                                }
                                .disabled(storeManager.isPurchasing)
                                .overlay {
                                    if storeManager.isPurchasing {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(.black.opacity(0.1))
                                            .overlay(ProgressView())
                                    }
                                }
                            } else {
                                Text("現在商品情報を取得できません。時間をおいて再度お試しください。")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                
                                Button("再読み込み") {
                                    Task {
                                        await storeManager.loadProducts()
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                            
                            // 復元ボタン
                            Button(action: {
                                Task {
                                    await storeManager.restorePurchases()
                                }
                            }) {
                                Text("購入情報を復元（リストア）")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            .disabled(storeManager.isPurchasing || storeManager.isLoading)
                        }
                    }
                    .padding(.horizontal)
                    
                    // エラー表示
                    if let error = storeManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    Spacer().frame(height: 32)
                }
            }
            .navigationTitle("プレミアムプラン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .task {
                await storeManager.loadProducts()
            }
            .onChange(of: storeManager.purchaseSucceeded) { _, succeeded in
                if succeeded && storeManager.isPremium {
                    // 購入成功時は数秒待って閉じるなどのUI演出も可能
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 特典の行レイアウト

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.04), lineWidth: 1)
        )
    }
}

#Preview {
    PremiumStoreView()
}

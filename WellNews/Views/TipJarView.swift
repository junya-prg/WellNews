//
//  TipJarView.swift
//  WellNews
//
//  開発者支援（チップ）の購入モーダル画面
//

import SwiftUI
import StoreKit

struct TipJarView: View {
    @Environment(\.dismiss) private var dismiss
    private var storeManager = StoreManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // ヘッダー部
                    VStack(spacing: 12) {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.pink, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .pink.opacity(0.3), radius: 10, x: 0, y: 5)
                            .padding(.top, 16)
                        
                        Text("開発者を支援する")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                        
                        Text("WellNewsは個人開発による広告＆課金型アプリです。\nもし日々の健康管理に役立っていると感じていただけましたら、開発を応援していただけると非常に励みになります！")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .lineSpacing(4)
                    }
                    
                    // チップアイテムのリスト
                    VStack(spacing: 14) {
                        if storeManager.isLoading {
                            ProgressView("商品情報を読み込み中...")
                                .padding()
                        } else if storeManager.tips.isEmpty {
                            VStack(spacing: 12) {
                                Text("チップ情報が見つかりません。")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Button("再試行") {
                                    Task {
                                        await storeManager.loadProducts()
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 32)
                        } else {
                            ForEach(storeManager.tips, id: \.id) { product in
                                let tipType = TipProduct(rawValue: product.id)
                                
                                Button(action: {
                                    Task {
                                        await storeManager.purchase(product)
                                    }
                                }) {
                                    TipProductRow(product: product, tipType: tipType)
                                }
                                .buttonStyle(.plain)
                                .disabled(storeManager.isPurchasing)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // 説明注意書き
                    VStack(alignment: .leading, spacing: 8) {
                        Text("※ 開発者支援チップについて")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        Text("こちらは任意の寄付型アイテム（消耗型）です。購入しても広告非表示などのプレミアム機能は有効になりません（プレミアム機能をお求めの場合は「プレミアムプラン」をご購入ください）。")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineSpacing(3)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    
                    // エラーメッセージ
                    if let error = storeManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    Spacer().frame(height: 32)
                }
            }
            .navigationTitle("開発者支援")
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
                if succeeded {
                    // 購入完了したら自動で閉じる演出
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - チップ商品の各行ビュー

struct TipProductRow: View {
    let product: Product
    let tipType: TipProduct?
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.pink.opacity(0.08))
                    .frame(width: 48, height: 48)
                
                Image(systemName: tipType?.iconName ?? "gift.fill")
                    .font(.title3)
                    .foregroundColor(.pink)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(tipType?.displayName ?? product.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(tipType?.description ?? product.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(product.displayPrice)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [.pink, .rose],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
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

// プレビュー用のColor拡張 (もし.roseが無い場合の安全策)
private extension Color {
    static var rose: Color {
        Color(red: 0.96, green: 0.32, blue: 0.47)
    }
}

#Preview {
    TipJarView()
}

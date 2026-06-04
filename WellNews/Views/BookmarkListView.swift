//
//  BookmarkListView.swift
//  WellNews
//
//  ブックマーク一覧画面
//

import SwiftUI

struct BookmarkListView: View {
    @State private var selectedArticle: Article?
    
    @MainActor
    private var tracker: WellNewsTracker {
        WellNewsTracker.shared
    }
    
    private var storeManager = StoreManager.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Group {
                    if tracker.bookmarkedArticles.isEmpty {
                        ContentUnavailableView(
                            "ブックマークした記事がありません",
                            systemImage: "bookmark",
                            description: Text("役立つ記事を見つけたら詳細画面でブックマークしましょう")
                        )
                    } else {
                        List {
                            ForEach(tracker.bookmarkedArticles) { article in
                                BookmarkRow(article: article)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedArticle = article
                                    }
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    .listRowSeparator(.hidden)
                            }
                            .onDelete(perform: removeBookmark)
                        }
                        .listStyle(.plain)
                    }
                }
                
                if !storeManager.isPremium && AdConfiguration.showBannerInBookmarks {
                    BannerAdView()
                        .padding(.vertical, 4)
                        .background(Color(.systemBackground))
                }
            }
            .navigationTitle("ブックマーク")

            .toolbar {
                if !tracker.bookmarkedArticles.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {
                            SpeechManager.shared.playBriefing(articles: tracker.bookmarkedArticles)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "play.circle.fill")
                                Text("連続再生")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.blue)
                            .clipShape(Capsule())
                            .shadow(color: Color.blue.opacity(0.3), radius: 3, x: 0, y: 1)
                        }
                    }
                }
            }
            .navigationDestination(item: $selectedArticle) { article in
                ArticleDetailView(article: article) { updatedArticle in
                    tracker.updateBookmarkedArticle(updatedArticle)
                }
            }
        }
    }
    
    private func removeBookmark(at offsets: IndexSet) {
        for index in offsets {
            let article = tracker.bookmarkedArticles[index]
            tracker.toggleBookmark(article)
        }
    }
}

/// ブックマーク用の一覧行ビュー
struct BookmarkRow: View {
    let article: Article
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ヘッダー行 (フル幅、左寄せ)
            HStack(spacing: 8) {
                if let category = article.category {
                    CategoryBadge(category: category)
                        .fixedSize(horizontal: true, vertical: false)
                }
                
                HStack(spacing: 4) {
                    FaviconView(domain: (article.url.host?.contains("google.com") == true && article.source.contains(".")) ? article.source : (article.url.host ?? ""))
                    Text(article.source)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer() // すべてを左側に寄せる
            }
            
            // 中間コンテンツセクション (タイトルと画像を横並びにする)
            HStack(alignment: .top, spacing: 16) {
                Text(article.title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                
                // サムネイル画像
                if let imageUrl = article.imageUrl {
                    AsyncImage(url: imageUrl) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else if phase.error != nil {
                            Color.secondary.opacity(0.06)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundStyle(.tertiary)
                                        .font(.caption)
                                )
                        } else {
                            Color.secondary.opacity(0.06)
                        }
                    }
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
                    )
                }
            }
            
            // 下部セクション: 概要 / AI要約 (フル幅)
            if let summary = article.aiSummary ?? article.description {
                Text(summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
    }
}

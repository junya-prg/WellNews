//
//  HomeView.swift
//  WellNews
//
//  メイン画面 - 健康関連記事一覧とAI要約表示
//

import SwiftUI
import os

private let logger = Logger(subsystem: "jp.junya.WellNews", category: "HomeView")

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedArticle: Article?
    private var storeManager = StoreManager.shared
    
    @MainActor
    private var tracker: WellNewsTracker {
        WellNewsTracker.shared
    }
    
    private var aiStatusColor: Color {
        guard let available = viewModel.isAIActuallyAvailable else {
            return .gray
        }
        return available ? .green : .orange
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // リッチなカテゴリフィルターを上部に配置
                CategoryFilterView(
                    selectedCategory: viewModel.selectedCategory,
                    onSelect: { category in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            viewModel.selectCategory(category)
                        }
                    }
                )
                .padding(.top, 8)
                
                // AI処理状況インジケーター
                if viewModel.isProcessingAI {
                    AIProcessingIndicatorView()
                }
                
                // 記事一覧
                Group {
                    if viewModel.isLoading && viewModel.articles.isEmpty {
                        LoadingView()
                    } else if viewModel.filteredArticles.isEmpty {
                        EmptyArticlesView(hasFilter: viewModel.selectedCategory != nil)
                    } else {
                        ArticleListView(
                            items: insertAdsIntoNews(articles: viewModel.filteredArticles, isPremium: storeManager.isPremium),
                            onSelect: { article in
                                selectedArticle = article
                            }
                        )
                    }
                }
            }
            .navigationTitle("WellNews")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // AIラジオ再生ボタン
                        if !viewModel.filteredArticles.isEmpty {
                            Button(action: {
                                let limit = storeManager.isPremium ? viewModel.filteredArticles.count : 5
                                let articlesToPlay = Array(viewModel.filteredArticles.prefix(limit))
                                SpeechManager.shared.playBriefing(articles: articlesToPlay)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "radio.fill")
                                    Text("健康ラジオ")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .clipShape(Capsule())
                                .shadow(color: Color.purple.opacity(0.3), radius: 3, x: 0, y: 1)
                            }
                        }
                        
                        Button(action: {
                            Task {
                                await viewModel.refreshArticles()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 4) {
                        Image(systemName: "brain")
                        if let available = viewModel.isAIActuallyAvailable {
                            Text(available ? "AI" : "")
                                .font(.caption2)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(aiStatusColor)
                }
            }
            .onAppear {
                logger.notice("📱 HomeView onAppear")
                viewModel.resumeAIProcessingIfNeeded()
            }
            .task {
                logger.notice("📱 HomeView task開始")
                if viewModel.articles.isEmpty {
                    await viewModel.loadArticles()
                } else {
                    viewModel.resumeAIProcessingIfNeeded()
                }
                logger.notice("📱 HomeView task完了")
            }
            .refreshable {
                await viewModel.refreshArticles()
            }
            .navigationDestination(item: $selectedArticle) { article in
                ArticleDetailView(article: article) { updatedArticle in
                    if let index = viewModel.articles.firstIndex(where: { $0.id == updatedArticle.id }) {
                        viewModel.articles[index] = updatedArticle
                    }
                }
            }
        }
    }
}

// MARK: - サブビュー

/// カテゴリフィルターバー (リッチデザイン)
struct CategoryFilterView: View {
    let selectedCategory: ArticleCategory?
    let onSelect: (ArticleCategory?) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // すべて
                CategoryCard(
                    title: String(localized: "すべて"),
                    iconName: "newspaper",
                    isSelected: selectedCategory == nil,
                    color: .blue
                ) {
                    onSelect(nil)
                }
                
                // 各カテゴリ
                ForEach(ArticleCategory.allCases) { category in
                    CategoryCard(
                        title: category.displayName,
                        iconName: category.iconName,
                        isSelected: selectedCategory == category,
                        color: categoryColor(for: category)
                    ) {
                        onSelect(category)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
    
    private func categoryColor(for category: ArticleCategory) -> Color {
        switch category {
        case .exercise: return .blue
        case .diet: return .orange
        case .sleep: return .purple
        case .mentalCare: return .green
        case .other: return .gray
        }
    }
}

/// リッチなカード型カテゴリボタン
struct CategoryCard: View {
    let title: String
    let iconName: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : color)
                
                Text(title)
                    .font(.system(size: 11, weight: .bold))
            }
            .frame(width: 75, height: 68)
            .background(
                isSelected ?
                AnyView(LinearGradient(colors: [color, color.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)) :
                AnyView(Color(.systemGray6))
            )
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: isSelected ? color.opacity(0.25) : Color.clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

/// AI処理中インジケーター
struct AIProcessingIndicatorView: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("AIが健康情報を分析中...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
    }
}

/// 読み込み中ビュー
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("健康ニュースを取得中...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 記事がない場合のビュー
struct EmptyArticlesView: View {
    let hasFilter: Bool
    
    var body: some View {
        ContentUnavailableView(
            hasFilter ? "該当する健康記事がありません" : "健康記事がありません",
            systemImage: "newspaper",
            description: Text(hasFilter ? "他のカテゴリを選択してください" : "設定画面でキーワードを追加するか、引っ張って更新してください")
        )
    }
}

/// 記事一覧ビュー
struct ArticleListView: View {
    let items: [NewsListItem]
    let onSelect: (Article) -> Void
    
    var body: some View {
        List(items) { item in
            switch item {
            case .article(let article):
                ArticleCardView(article: article)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect(article)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
            case .ad:
                NativeAdView()
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
    }
}

/// サイトロゴ表示ビュー
struct FaviconView: View {
    let domain: String
    var size: CGFloat = 16
    
    var body: some View {
        AsyncImage(url: URL(string: "https://www.google.com/s2/favicons?sz=64&domain=\(domain)")) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if phase.error != nil {
                Image(systemName: "globe")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.secondary)
            } else {
                Color.secondary.opacity(0.1)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

/// 記事カードビュー
struct ArticleCardView: View {
    let article: Article
    
    @MainActor
    private var tracker: WellNewsTracker {
        WellNewsTracker.shared
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ヘッダー行 (フル幅、左寄せ)
            HStack(spacing: 8) {
                if !tracker.isRead(article) {
                    Circle()
                        .fill(Color.mint)
                        .frame(width: 8, height: 8)
                }
                
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
                
                Text("・")
                    .foregroundStyle(.secondary)
                
                Text(article.relativeDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: true, vertical: false)
                
                Spacer() // すべてを左側に寄せる
            }
            
            // 中間セクション: タイトルとサムネイル画像を横並びにする
            HStack(alignment: .top, spacing: 16) {
                Text(article.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                
                // サムネイル画像 (右側)
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
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
                    )
                }
            }
            
            // 下部セクション: AI要約 (フル幅)
            let displaySummary = article.aiSummary ?? article.description
            if let summary = displaySummary {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: article.isAIProcessed ? "brain" : "doc.text")
                        .font(.caption2)
                        .foregroundStyle(article.isAIProcessed ? .purple : .blue)
                        .padding(.top, 2)
                    
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background((article.isAIProcessed ? Color.purple : Color.blue).opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            // フッター行 (フル幅)
            if let percentage = article.relevancePercentage {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Text("おすすめ度: \(percentage)%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if tracker.isBookmarked(article) {
                        Image(systemName: "bookmark.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                            .padding(.trailing, 4)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 4)
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

/// カテゴリバッジ
struct CategoryBadge: View {
    let category: ArticleCategory

    private var color: Color {
        switch category {
        case .exercise: return .blue
        case .diet: return .orange
        case .sleep: return .purple
        case .mentalCare: return .green
        case .other: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.iconName)
                .font(.caption2)
            Text(category.displayName)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
}

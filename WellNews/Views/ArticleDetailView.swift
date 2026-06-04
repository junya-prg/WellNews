//
//  ArticleDetailView.swift
//  WellNews
//
//  記事詳細画面 - 記事の詳細情報とAI要約を表示
//

import SwiftUI

/// 記事詳細画面
struct ArticleDetailView: View {
    @State private var article: Article
    let onUpdate: ((Article) -> Void)?
    
    @Environment(\.openURL) private var openURL
    @State private var isRegeneratingSummary = false
    @ObservedObject private var speechManager = SpeechManager.shared
    
    @MainActor
    private var tracker: WellNewsTracker {
        WellNewsTracker.shared
    }
    
    init(article: Article, onUpdate: ((Article) -> Void)? = nil) {
        self._article = State(initialValue: article)
        self.onUpdate = onUpdate
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // ヘッダー情報
                ArticleHeaderView(article: article)
                
                // 記事プレビュー画像
                if let imageUrl = article.imageUrl {
                    AsyncImage(url: imageUrl) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else if phase.error != nil {
                            Color.secondary.opacity(0.08)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.secondary)
                                )
                        } else {
                            Color.secondary.opacity(0.08)
                        }
                    }
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
                }
                
                Divider()
                
                // タイトル
                let isTitleSpeaking = isSpeakingTitle()
                Text(article.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(isTitleSpeaking ? .purple : .primary)
                    .padding(.horizontal, isTitleSpeaking ? 4 : 0)
                    .background(isTitleSpeaking ? Color.purple.opacity(0.12) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .animation(.easeInOut(duration: 0.3), value: isTitleSpeaking)
                
                // AI要約セクション（AI要約がない場合はdescriptionを表示）
                let displaySummary = article.aiSummary ?? article.description
                if let summary = displaySummary {
                    VStack(alignment: .leading, spacing: 8) {
                        AISummarySection(
                            article: article,
                            summary: summary,
                            isAIGenerated: article.isAIProcessed
                        )
                        
                        // 再生成ボタン
                        HStack {
                            Spacer()
                            Button(action: {
                                regenerateAISummary()
                            }) {
                                HStack(spacing: 6) {
                                    if isRegeneratingSummary {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                    Text(isRegeneratingSummary ? "AI要約を再生成中..." : "AI要約を再生成")
                                }
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.purple)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.purple.opacity(0.1))
                                .clipShape(Capsule())
                            }
                            .disabled(isRegeneratingSummary)
                        }
                        .padding(.top, 4)
                    }
                }
                
                // おすすめ度
                if let score = article.relevanceScore {
                    RelevanceScoreSection(score: score)
                }
                
                Divider()
                
                // 元記事を開くボタンと共有ボタン
                OpenArticleButton(url: article.url) {
                    openURL(article.url)
                }
                
                // 共有ボタン
                ShareButton(article: article)
            }
            .padding()
        }
        .navigationTitle("記事詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    tracker.toggleBookmark(article)
                }) {
                    Image(systemName: tracker.isBookmarked(article) ? "bookmark.fill" : "bookmark")
                        .foregroundColor(tracker.isBookmarked(article) ? .yellow : .primary)
                }
            }
        }
        .onAppear {
            tracker.markAsRead(article)
        }
    }
    
    private func regenerateAISummary() {
        Task {
            isRegeneratingSummary = true
            defer { isRegeneratingSummary = false }
            
            let aiService = FoundationModelsService()
            await aiService.ensureAIReady()
            
            let interestedCatsRaw = UserDefaults.standard.stringArray(forKey: "wellnews.interestedCategories") ?? []
            let interestedCats = interestedCatsRaw.compactMap { ArticleCategory(rawValue: $0) }
            let finalCats = interestedCats.isEmpty ? ArticleCategory.allCases : interestedCats
            
            let profile = UserHealthProfile(
                interestedCategories: finalCats,
                keywords: ArticleFetchService.shared.keywords.filter { $0.isEnabled }.map { $0.name }
            )
            
            var updatedArticle = article
            updatedArticle.aiSummary = await aiService.summarize(article: article)
            updatedArticle.category = await aiService.categorize(article: article)
            updatedArticle.relevanceScore = await aiService.calculateRelevance(article: article, userProfile: profile)
            updatedArticle.isAIProcessed = true
            
            withAnimation {
                self.article = updatedArticle
            }
            onUpdate?(updatedArticle)
        }
    }
    
    private func isSpeakingTitle() -> Bool {
        guard let current = speechManager.currentArticle, current.id == article.id else { return false }
        return speechManager.isReadingTitle
    }
}

// MARK: - サブビュー

/// 記事ヘッダー（カテゴリ・ソース・日時）
struct ArticleHeaderView: View {
    let article: Article
    
    var body: some View {
        HStack {
            if let category = article.category {
                CategoryBadge(category: category)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(article.source)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(article.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

/// AI要約セクション
struct AISummarySection: View {
    let article: Article
    let summary: String
    /// AI生成の要約かどうか（falseの場合はRSSの説明文）
    var isAIGenerated: Bool = true
    
    @ObservedObject private var speechManager = SpeechManager.shared
    
    private var headerTitle: String {
        isAIGenerated ? "AI要約" : "記事の概要"
    }
    
    private var headerIcon: String {
        isAIGenerated ? "brain" : "doc.text"
    }
    
    private var themeColor: Color {
        isAIGenerated ? .purple : .blue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: headerIcon)
                    .foregroundStyle(themeColor)
                Text(headerTitle)
                    .font(.headline)
                    .foregroundStyle(themeColor)
                
                Spacer()
                
                // 音声読み上げボタン
                Button(action: {
                    if speechManager.currentArticle?.id == article.id {
                        if speechManager.isPaused {
                            speechManager.resume()
                        } else if speechManager.isPlaying {
                            speechManager.pause()
                        } else {
                            speechManager.play(article: article)
                        }
                    } else {
                        speechManager.play(article: article)
                    }
                }) {
                    let isCurrent = speechManager.currentArticle?.id == article.id
                    let isSpeaking = isCurrent && speechManager.isPlaying && !speechManager.isPaused
                    
                    HStack(spacing: 4) {
                        Image(systemName: isSpeaking ? "pause.fill" : "play.fill")
                        Text(isSpeaking ? "一時停止" : "音声で聴く")
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(themeColor)
                    .clipShape(Capsule())
                    .shadow(color: themeColor.opacity(0.2), radius: 3, x: 0, y: 1)
                }
            }
            
            // 文ごとのハイライトテキスト生成
            let sentences = SpeechManager.splitIntoSentences(summary)
            let isCurrentArticle = speechManager.currentArticle?.id == article.id
            
            VStack(alignment: .leading, spacing: 4) {
                if isCurrentArticle {
                    sentences.enumerated().reduce(Text("")) { result, item in
                        let index = item.offset
                        let sentence = item.element
                        let isSpeakingThis = isSpeakingSentence(index: index)
                        
                        let sentenceText = Text(sentence)
                            .foregroundColor(isSpeakingThis ? .purple : .secondary)
                            .font(.system(size: 16, weight: isSpeakingThis ? .semibold : .regular))
                        
                        return result + sentenceText + Text(" ")
                    }
                    .lineSpacing(6)
                    .animation(.easeInOut(duration: 0.2), value: speechManager.currentSentenceIndex)
                } else {
                    Text(summary)
                        .font(.body)
                        .lineSpacing(4)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(themeColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func isSpeakingSentence(index: Int) -> Bool {
        guard let currentArticle = speechManager.currentArticle,
              currentArticle.id == article.id else {
            return false
        }
        return !speechManager.isReadingTitle && speechManager.currentSentenceIndex == index
    }
}

/// おすすめ度セクション
struct RelevanceScoreSection: View {
    let score: Double
    
    private var percentage: Int {
        Int(score * 100)
    }
    
    private var scoreColor: Color {
        switch percentage {
        case 80...100:
            return .green
        case 60..<80:
            return .blue
        case 40..<60:
            return .orange
        default:
            return .gray
        }
    }
    
    private var scoreDescription: String {
        switch percentage {
        case 80...100:
            return "この記事はあなたに非常に強くおすすめされます"
        case 60..<80:
            return "この記事はあなたに関連性が高いです"
        case 40..<60:
            return "この記事はあなたの設定した関心と一部関連しています"
        default:
            return "この記事はあなたとの関連性が低めです"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                Text("おすすめ度")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(percentage)%")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(scoreColor)
                    
                    Spacer()
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(scoreColor)
                            .frame(width: geometry.size.width * score, height: 8)
                    }
                }
                .frame(height: 8)
                
                Text(scoreDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// 元記事を開くボタン
struct OpenArticleButton: View {
    let url: URL
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "safari")
                Text("元の記事を読む")
                Spacer()
                Image(systemName: "arrow.up.right.square")
            }
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

/// 共有ボタン
struct ShareButton: View {
    let article: Article
    
    var body: some View {
        ShareLink(
            item: article.url,
            subject: Text(article.title),
            message: Text("\(article.title)\n\n\(article.aiSummary ?? "")")
        ) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("記事を共有")
                Spacer()
            }
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

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
            
            let updatedArticle = await aiService.processOneArticle(article, userProfile: profile)
            
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
            
            if let digest = article.summaryDigest {
                // 構造化要約のリッチカード表示
                DigestView(digest: digest, article: article, themeColor: themeColor)
            } else {
                // 従来のプレーンテキスト要約（文ごとのハイライト表示）
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
    }
    
    private func isSpeakingSentence(index: Int) -> Bool {
        guard let currentArticle = speechManager.currentArticle,
              currentArticle.id == article.id else {
            return false
        }
        return !speechManager.isReadingTitle && speechManager.currentSentenceIndex == index
    }
}

/// 構造化要約（digest）のリッチ表示
struct DigestView: View {
    let digest: ArticleDigest
    let article: Article
    let themeColor: Color
    
    @ObservedObject private var speechManager = SpeechManager.shared
    
    private let actionColor: Color = .green
    
    private var isAudioPlaying: Bool {
        speechManager.currentArticle?.id == article.id && speechManager.isPlaying && !speechManager.isPaused
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ひとことで言うと
            let isHeadlineActive = isAudioPlaying && speechManager.currentSentenceIndex == 0
            headlineCard(isActive: isHeadlineActive)
            
            // 3つのポイント
            if !digest.points.isEmpty {
                pointsCard(activePointIndex: isAudioPlaying ? speechManager.currentSentenceIndex - 1 : nil)
            }
            
            // 今日からできること
            if !digest.actionTip.isEmpty {
                let isActionActive = isAudioPlaying && speechManager.currentSentenceIndex == (digest.points.count + 1)
                actionCard(isActive: isActionActive)
            }
            
            // 関連キーワード
            if !digest.keywords.isEmpty {
                keywordChips
            }
        }
    }
    
    /// ひとことで言うと（強調カード）
    private func headlineCard(isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            DigestLabel(title: String(localized: "ひとことで言うと"), iconName: "quote.opening", color: themeColor)
            
            Text(digest.headline)
                .font(.body)
                .fontWeight(.semibold)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeColor.opacity(isActive ? 0.16 : 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(themeColor.opacity(isActive ? 0.8 : 0), lineWidth: 2)
        )
        .shadow(color: themeColor.opacity(isActive ? 0.3 : 0), radius: 8, x: 0, y: 4)
        .scaleEffect(isActive ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isActive)
    }
    
    /// 3つのポイント（番号バッジ＋見出し＋説明）
    private func pointsCard(activePointIndex: Int?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            DigestLabel(title: String(localized: "要点のまとめ"), iconName: "list.bullet.indent", color: themeColor)
            
            ForEach(Array(digest.points.enumerated()), id: \.offset) { index, point in
                let isActive = activePointIndex == index
                
                HStack(alignment: .top, spacing: 12) {
                    // 番号バッジ
                    Text("\(index + 1)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(isActive ? themeColor : Color.gray.opacity(0.6))
                        .clipShape(Circle())
                        .scaleEffect(isActive ? 1.15 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isActive)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if !point.label.isEmpty {
                            Text(point.label)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(isActive ? themeColor : .primary)
                        }
                        if !point.detail.isEmpty {
                            Text(point.detail)
                                .font(.subheadline)
                                .foregroundStyle(isActive ? .primary : .secondary)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(isActive ? 10 : 0)
                .background(themeColor.opacity(isActive ? 0.12 : 0))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(themeColor.opacity(isActive ? 0.6 : 0), lineWidth: 1.5)
                )
                .shadow(color: themeColor.opacity(isActive ? 0.2 : 0), radius: 6, x: 0, y: 3)
                .scaleEffect(isActive ? 1.02 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isActive)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    /// 今日からできること（アクセントカード）
    private func actionCard(isActive: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundStyle(actionColor)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("今日からできるアクション")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(actionColor)
                
                Text(digest.actionTip)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(actionColor.opacity(isActive ? 0.18 : 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(actionColor.opacity(isActive ? 0.8 : 0), lineWidth: 2)
        )
        .shadow(color: actionColor.opacity(isActive ? 0.3 : 0), radius: 8, x: 0, y: 4)
        .scaleEffect(isActive ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isActive)
    }
    
    /// 関連キーワード
    private var keywordChips: some View {
        WrapChips(items: digest.keywords, color: themeColor)
    }
}

/// 各ブロックの見出しラベル
struct DigestLabel: View {
    let title: String
    let iconName: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
    }
}

/// 折り返し対応のキーワードチップ群
struct WrapChips: View {
    let items: [String]
    let color: Color
    
    var body: some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, keyword in
                Text("# \(keyword)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(color)
                    .background(color.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }
}

/// 子ビューを横に並べ、横幅を超えたら折り返す簡易 Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubview]] = [[]]
        var currentRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let addition = currentRowWidth == 0 ? size.width : size.width + spacing
            if currentRowWidth + addition > maxWidth, currentRowWidth > 0 {
                rows.append([subview])
                currentRowWidth = size.width
            } else {
                rows[rows.count - 1].append(subview)
                currentRowWidth += addition
            }
        }

        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        for row in rows {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            let rowWidth = row.reduce(CGFloat(0)) { $0 + $1.sizeThatFits(.unspecified).width }
                + CGFloat(max(0, row.count - 1)) * spacing
            totalHeight += rowHeight
            totalWidth = max(totalWidth, rowWidth)
        }
        totalHeight += CGFloat(max(0, rows.count - 1)) * lineSpacing
        return CGSize(width: proposal.width ?? totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
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

//
//  FoundationModelsService.swift
//  WellNews
//
//  Foundation Modelsフレームワークを使用したAI処理サービス
//  iOS 26以降でApple Intelligenceのオンデバイスモデルを使用
//

import Foundation
import Combine
import FoundationModels

/// ユーザーの健康プロフィール（おすすめ度計算用）
struct UserHealthProfile {
    /// 関心のあるカテゴリ
    let interestedCategories: [ArticleCategory]
    
    /// 追跡しているキーワード
    let keywords: [String]
}

// MARK: - エラー定義

enum FoundationModelsError: LocalizedError {
    case modelNotAvailable
    case sessionNotAvailable
    case summarizationFailed(Error)
    case categorizationFailed(Error)
    case relevanceCalculationFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .modelNotAvailable:
            return String(localized: "Apple Intelligenceが利用できません。デバイスの設定を確認してください。")
        case .sessionNotAvailable:
            return String(localized: "AIセッションが利用できません")
        case .summarizationFailed(let error):
            return String(format: String(localized: "要約の生成に失敗しました: %@"), error.localizedDescription)
        case .categorizationFailed(let error):
            return String(format: String(localized: "カテゴリ分類に失敗しました: %@"), error.localizedDescription)
        case .relevanceCalculationFailed(let error):
            return String(format: String(localized: "おすすめ度の計算に失敗しました: %@"), error.localizedDescription)
        }
    }
}

// MARK: - Foundation Models実装

/// Foundation Modelsを使用したAI処理サービス
@available(iOS 26.0, macOS 26.0, *)
@MainActor
class FoundationModelsService: ObservableObject {
    /// 処理中かどうか
    @Published private(set) var isProcessing = false

    /// エラーメッセージ
    @Published var errorMessage: String?

    /// isAvailableのキャッシュ
    private var _isAvailableCache: Bool?

    /// 現在のUI言語が英語かどうか（将来の多言語化用。現在は日本語に固定）
    private var isEnglishUI: Bool {
        return false
    }
    
    /// 利用可能判定
    var isAvailable: Bool {
        if let cached = _isAvailableCache {
            return cached
        }
        return true
    }
    
    var isActuallyAvailable: Bool {
        return _isAvailableCache ?? false
    }
    
    /// AIの利用可能性チェック
    func checkAvailability() async -> Bool {
        let available = SystemLanguageModel.default.isAvailable
        print("🤖 Foundation Models isAvailable: \(available)")
        _isAvailableCache = available
        return available
    }
    
    // MARK: - 要約生成
    
    func summarize(article: Article) async -> String {
        guard _isAvailableCache == true else {
            return article.description ?? String(localized: "要約を生成できません")
        }

        let content = article.description ?? article.title

        let summaryLengthRaw = UserDefaults.standard.string(forKey: "wellnews.summaryLength") ?? "medium"
        let summaryLength = SummaryLength(rawValue: summaryLengthRaw) ?? .medium

        let instructions: String
        let prompt: String
        if isEnglishUI {
            let lengthInstruction: String
            switch summaryLength {
            case .short: lengthInstruction = "Summarize in 1-2 concise sentences in English"
            case .medium: lengthInstruction = "Summarize in 2-3 sentences in English"
            case .detailed: lengthInstruction = "Summarize in 4-5 detailed sentences in English"
            }
            instructions = """
                You are an assistant that creates summaries of news articles.
                This app supports people tracking wellness and health information.
                Follow these rules:
                - \(lengthInstruction)
                - Highlight key action items or benefits related to health/wellness
                - Include only objective information
                """
            prompt = """
                Please summarize the following news article.

                Title: \(article.title)
                Content: \(content)
                """
        } else {
            let lengthInstruction: String
            switch summaryLength {
            case .short: lengthInstruction = "日本語で1-2文で簡潔に要約してください"
            case .medium: lengthInstruction = "日本語で2-3文で要約してください"
            case .detailed: lengthInstruction = "日本語で4-5文で詳しく要約してください"
            }
            instructions = """
                あなたはニュース記事の要約を作成するアシスタントです。
                このアプリはユーザーの健康増進やウェルネス習慣をサポートするアプリです。
                以下のルールに従って要約してください：
                - \(lengthInstruction)
                - 健康上のメリットや具体的な改善アクションを強調
                - 客観的な情報のみを含める
                """
            prompt = """
                以下のニュース記事を要約してください。

                タイトル: \(article.title)
                内容: \(content)
                """
        }

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            print("要約生成エラー: \(error)")
            return article.description ?? String(localized: "要約を生成できませんでした")
        }
    }
    
    // MARK: - カテゴリ分類
    
    func categorize(article: Article) async -> ArticleCategory {
        guard _isAvailableCache == true else {
            return fallbackCategorize(article: article)
        }

        let content = article.description ?? article.title

        let instructions: String
        let prompt: String
        if isEnglishUI {
            instructions = """
                You categorize news articles. Reply with exactly one of the following category names:
                - 運動 (Exercise/Fitness/Workouts)
                - 食事・栄養 (Diet/Nutrition/Food/Recipes)
                - 睡眠・休養 (Sleep/Rest/Relaxation/Sauna)
                - メンタルケア (Mental Care/Mindfulness/Stress Management)
                - その他 (Other; anything not matching above)

                Reply with the Japanese category keyword only (exactly as shown above), nothing else.
                """
            prompt = """
                Classify the following article into the most appropriate category.

                Title: \(article.title)
                Content: \(content)

                Reply with just the Japanese category keyword.
                """
        } else {
            instructions = """
                あなたはニュース記事をカテゴリ分類するアシスタントです。
                以下のカテゴリのいずれかを選んで、カテゴリ名のみを回答してください：
                - 運動（フィットネス、筋トレ、ウォーキング、スポーツに関する記事）
                - 食事・栄養（レシピ、健康食材、サプリメント、糖質制限など食事に関する記事）
                - 睡眠・休養（睡眠改善、不眠対策、サウナ、温泉、休養に関する記事）
                - メンタルケア（マインドフルネス、瞑想、ストレス解消、心理ケアに関する記事）
                - その他（上記に該当しない健康関連の記事）
                """
            prompt = """
                以下の記事を最も適切なカテゴリに分類してください。

                タイトル: \(article.title)
                内容: \(content)

                カテゴリ名のみを回答してください。
                """
        }

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)

            let categoryText = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

            for category in ArticleCategory.allCases {
                if categoryText.contains(category.rawValue) {
                    return category
                }
            }
            return .other
        } catch {
            print("カテゴリ分類エラー: \(error)")
            return fallbackCategorize(article: article)
        }
    }
    
    // MARK: - おすすめ度計算
    
    func calculateRelevance(article: Article, userProfile: UserHealthProfile?) async -> Double {
        guard _isAvailableCache == true, let userProfile = userProfile else {
            return fallbackCalculateRelevance(article: article, userProfile: userProfile)
        }

        let content = article.description ?? article.title
        let interestedCats = userProfile.interestedCategories.map { $0.rawValue }.joined(separator: ", ")
        let keywords = userProfile.keywords.joined(separator: ", ")

        let instructions: String
        let prompt: String
        if isEnglishUI {
            instructions = """
                You rate how useful a news article is for someone aiming to improve their health and wellness.
                Consider the user's focus and rate relevance on a 0-100 numeric scale.

                [High score (70-100)]
                - The article content directly matches the user's interested categories or contains their tracked keywords.
                - Practical, scientific, or actionable health/habits advice.
                
                [Medium score (30-60)]
                - General wellness statistics or medical industry news.
                - Moderately matches the user's interest area.

                [Low score (0-30)]
                - Unrelated to health/wellness, or thin on substance.

                Reply with the number only.
                """
            prompt = """
                Rate how relevant this article is to the following user.

                [User Profile]
                - Interested Categories: \(interestedCats)
                - Tracked Keywords: \(keywords)

                [Article]
                Title: \(article.title)
                Content: \(content)

                Reply with just a number from 0 to 100.
                """
        } else {
            instructions = """
                あなたは健康管理やウェルネス習慣を向上させたいユーザー向けに、ニュースのおすすめ度を評価するアシスタントです。
                ユーザーのプロフィール情報を踏まえ、記事の関連性を0から100の数値で評価してください。

                【高スコア（70〜100）にすべき記事】
                - ユーザーが関心のあるカテゴリに合致している、または登録キーワードが重要テーマとして扱われている。
                - 具体的な健康改善メソッド、行動のヒント、科学的実証データが含まれる。

                【中スコア（30〜60）にすべき記事】
                - 一般的な健康・医療に関する統計データやニュース。
                - ユーザーの関心カテゴリにゆるく関連する内容。

                【低スコア（0〜30）にすべき記事】
                - 健康やウェルネスに直接関係がない記事、あるいは実質的な内容がない記事。

                数値のみを回答してください。
                """
            prompt = """
                以下のユーザーにとって、この記事がどれくらいおすすめか評価してください。

                【ユーザー情報】
                - 関心のあるカテゴリ: \(interestedCats)
                - 登録キーワード: \(keywords)

                【記事情報】
                タイトル: \(article.title)
                内容: \(content)

                0から100の数値のみで回答してください。
                """
        }

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)

            let scoreText = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

            let numbers = scoreText.components(separatedBy: CharacterSet.decimalDigits.inverted)
                .compactMap { Int($0) }
                .filter { $0 >= 0 && $0 <= 100 }

            if let score = numbers.first {
                return Double(score) / 100.0
            }
            return 0.5
        } catch {
            print("おすすめ度計算エラー: \(error)")
            return fallbackCalculateRelevance(article: article, userProfile: userProfile)
        }
    }
    
    // MARK: - 一括処理
    
    func processArticles(_ articles: [Article], userProfile: UserHealthProfile?) async -> [Article] {
        isProcessing = true
        defer { isProcessing = false }
        
        await ensureAIReady()
        
        guard _isAvailableCache == true else {
            return processArticlesWithFallback(articles, userProfile: userProfile)
        }
        
        var processedArticles: [Article] = []
        for (index, article) in articles.enumerated() {
            print("🤖 記事 \(index + 1)/\(articles.count) を処理中...")
            var processed = article
            processed.category = await categorize(article: article)
            processed.aiSummary = await summarize(article: article)
            processed.relevanceScore = await calculateRelevance(article: article, userProfile: userProfile)
            processed.isAIProcessed = true
            processedArticles.append(processed)
        }
        
        return processedArticles.sorted { ($0.relevanceScore ?? 0) > ($1.relevanceScore ?? 0) }
    }
    
    /// 1件の記事をAI処理
    func processOneArticle(_ article: Article, userProfile: UserHealthProfile?) async -> Article {
        var targetURL = article.url
        if targetURL.host?.contains("google.com") == true {
            if let resolved = await resolveGoogleNewsURL(targetURL) {
                targetURL = resolved
            }
        }
        
        var finalImageURL = article.imageUrl
        if finalImageURL == nil {
            if let ogpImage = await fetchOGPImage(from: targetURL) {
                finalImageURL = ogpImage
            }
        }
        
        var category: ArticleCategory = .other
        var aiSummary: String? = nil
        var relevanceScore: Double = 0.5
        var isProcessed = false
        
        if _isAvailableCache == true {
            category = await categorize(article: article)
            aiSummary = await summarize(article: article)
            relevanceScore = await calculateRelevance(article: article, userProfile: userProfile)
            isProcessed = true
        } else {
            category = fallbackCategorize(article: article)
            aiSummary = article.description
            relevanceScore = fallbackCalculateRelevance(article: article, userProfile: userProfile)
            isProcessed = false
        }
        
        return Article(
            id: article.id,
            title: article.title,
            source: article.source,
            publishedAt: article.publishedAt,
            url: targetURL,
            description: article.description,
            aiSummary: aiSummary,
            category: category,
            relevanceScore: relevanceScore,
            isAIProcessed: isProcessed,
            imageUrl: finalImageURL
        )
    }
    
    private func processOneArticleWithFallback(_ article: Article, userProfile: UserHealthProfile?) -> Article {
        var processed = article
        processed.category = fallbackCategorize(article: article)
        processed.aiSummary = nil
        processed.relevanceScore = fallbackCalculateRelevance(article: article, userProfile: userProfile)
        processed.isAIProcessed = false
        return processed
    }
    
    func ensureAIReady() async {
        if _isAvailableCache == nil {
            let testResult = await testAIAvailability()
            _isAvailableCache = testResult
        }
    }
    
    private func testAIAvailability() async -> Bool {
        do {
            return try await withThrowingTaskGroup(of: Bool.self) { group in
                group.addTask {
                    do {
                        let session = LanguageModelSession(instructions: "日本語で回答してください。")
                        let response = try await session.respond(to: "「準備完了」と返してください。")
                        return response.content.contains("準備完了") || !response.content.isEmpty
                    } catch {
                        return false
                    }
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    throw CancellationError()
                }
                guard let result = try await group.next() else { return false }
                group.cancelAll()
                return result
            }
        } catch {
            return false
        }
    }
    
    private func processArticlesWithFallback(_ articles: [Article], userProfile: UserHealthProfile?) -> [Article] {
        var processedArticles: [Article] = []
        for article in articles {
            var processed = article
            processed.category = fallbackCategorize(article: article)
            processed.aiSummary = article.description
            processed.relevanceScore = fallbackCalculateRelevance(article: article, userProfile: userProfile)
            processed.isAIProcessed = false
            processedArticles.append(processed)
        }
        return processedArticles.sorted { ($0.relevanceScore ?? 0) > ($1.relevanceScore ?? 0) }
    }
    
    // MARK: - フォールバックロジック
    
    private func fallbackCategorize(article: Article) -> ArticleCategory {
        let text = (article.title + " " + (article.description ?? "")).lowercased()
        
        if text.contains("歩") || text.contains("走") || text.contains("筋トレ") || text.contains("フィットネス") || text.contains("運動") || text.contains("ストレッチ") || text.contains("exercise") || text.contains("workout") {
            return .exercise
        } else if text.contains("食") || text.contains("栄養") || text.contains("カロリー") || text.contains("糖") || text.contains("レシピ") || text.contains("diet") || text.contains("nutrition") || text.contains("food") {
            return .diet
        } else if text.contains("眠") || text.contains("休") || text.contains("ベッド") || text.contains("サウナ") || text.contains("温泉") || text.contains("sleep") || text.contains("rest") {
            return .sleep
        } else if text.contains("ストレス") || text.contains("心") || text.contains("瞑想") || text.contains("マインド") || text.contains("メンタル") || text.contains("mental") || text.contains("mindfulness") {
            return .mentalCare
        }
        return .other
    }
    
    private func fallbackCalculateRelevance(article: Article, userProfile: UserHealthProfile?) -> Double {
        var score = 0.5
        let text = (article.title + " " + (article.description ?? "")).lowercased()
        
        guard let profile = userProfile else { return score }
        
        let matchedCat = fallbackCategorize(article: article)
        if profile.interestedCategories.contains(matchedCat) {
            score += 0.2
        }
        
        for keyword in profile.keywords {
            if text.contains(keyword.lowercased()) {
                score += 0.15
                break
            }
        }
        
        let hours = Date().timeIntervalSince(article.publishedAt) / 3600
        if hours < 24 {
            score += 0.1
        }
        
        return min(max(score, 0.0), 1.0)
    }
    
    // MARK: - Google News URL & OGP Image Helper
    
    /// Google NewsのリダイレクトURLを本来の配信記事URLに解決する
    func resolveGoogleNewsURL(_ googleNewsURL: URL) async -> URL? {
        let pathComponents = googleNewsURL.pathComponents
        guard pathComponents.count > 1,
              let artId = pathComponents.last else {
            return nil
        }
        
        var urlComponents = URLComponents(string: "https://news.google.com/articles/\(artId)")
        urlComponents?.queryItems = [
            URLQueryItem(name: "hl", value: "ja"),
            URLQueryItem(name: "gl", value: "JP"),
            URLQueryItem(name: "ceid", value: "JP:ja")
        ]
        
        guard let fetchURL = urlComponents?.url else { return nil }
        
        do {
            var request = URLRequest(url: fetchURL)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 5.0
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            
            guard let html = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            let sgPattern = #"data-n-a-sg="([^"]+)""#
            let tsPattern = #"data-n-a-ts="([^"]+)""#
            
            guard let sgRange = html.range(of: sgPattern, options: .regularExpression),
                  let tsRange = html.range(of: tsPattern, options: .regularExpression) else {
                return nil
            }
            
            let sgMatch = html[sgRange]
            let tsMatch = html[tsRange]
            
            guard let sgValue = extractRegexValue(pattern: sgPattern, in: String(sgMatch)),
                  let tsValue = extractRegexValue(pattern: tsPattern, in: String(tsMatch)) else {
                return nil
            }
            
            return await callBatchExecute(artId: artId, timestamp: tsValue, signature: sgValue)
        } catch {
            print("Error resolving Google News URL: \(error)")
            return nil
        }
    }

    private func extractRegexValue(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let nsString = text as NSString
        let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        if let firstMatch = results.first, firstMatch.numberOfRanges > 1 {
            return nsString.substring(with: firstMatch.range(at: 1))
        }
        return nil
    }

    private func callBatchExecute(artId: String, timestamp: String, signature: String) async -> URL? {
        let url = URL(string: "https://news.google.com/_/DotsSplashUi/data/batchexecute")!
        
        let innerArray: [Any] = [
            ["X", "X", ["X", "X"], NSNull(), NSNull(), 1, 1, "US:en", NSNull(), 1, NSNull(), NSNull(), NSNull(), NSNull(), NSNull(), 0, 1],
            "X",
            "X",
            1,
            [1, 1, 1],
            1,
            1,
            NSNull(),
            0,
            0,
            NSNull(),
            0
        ]
        
        let gartUrlReq: [Any] = [
            "garturlreq",
            innerArray,
            artId,
            timestamp,
            signature
        ]
        
        // Wait, gartUrlReq should be converted to a JSON string first before embedding in the outer array!
        // Let's do that properly:
        guard let gartUrlReqData = try? JSONSerialization.data(withJSONObject: gartUrlReq, options: []),
              let gartUrlReqString = String(data: gartUrlReqData, encoding: .utf8) else {
            return nil
        }
        
        let finalRequestPayload: [Any] = [
            [
                [
                    "Fbv4je",
                    gartUrlReqString
                ]
            ]
        ]
        
        guard let outerJSONData = try? JSONSerialization.data(withJSONObject: finalRequestPayload, options: []),
              let outerJSONString = String(data: outerJSONData, encoding: .utf8) else {
            return nil
        }
        
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "f.req", value: outerJSONString)
        ]
        
        guard let postBodyString = components.percentEncodedQuery else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.httpBody = postBodyString.data(using: .utf8)
        request.timeoutInterval = 5.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            
            guard let resString = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            let pattern = #"https?://[^\s\\\"\'\<\>]+"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
            let nsString = resString as NSString
            let results = regex.matches(in: resString, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in results {
                let urlString = nsString.substring(with: match.range)
                if !urlString.contains("google") {
                    let cleaned = urlString.replacingOccurrences(of: "\\", with: "")
                    if let resolvedURL = URL(string: cleaned) {
                        return resolvedURL
                    }
                }
            }
        } catch {
            print("Error calling batchexecute: \(error)")
        }
        return nil
    }

    /// 記事の最終URLからOGP画像を抽出する
    func fetchOGPImage(from url: URL) async -> URL? {
        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 5.0
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            
            var html = String(data: data, encoding: .utf8)
            if html == nil {
                let shiftJIS = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.dosJapanese.rawValue))
                html = String(data: data, encoding: String.Encoding(rawValue: shiftJIS))
            }
            
            guard let html = html else { return nil }
            
            let patterns = [
                #"<meta[^>]+property="og:image"[^>]+content="([^"]+)""#,
                #"<meta[^>]+content="([^"]+)"[^>]+property="og:image""#,
                #"<meta[^>]+name="twitter:image"[^>]+content="([^"]+)""#,
                #"<meta[^>]+content="([^"]+)"[^>]+name="twitter:image""#
            ]
            
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                    let nsString = html as NSString
                    let results = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
                    if let firstMatch = results.first, firstMatch.numberOfRanges > 1 {
                        var urlString = nsString.substring(with: firstMatch.range(at: 1))
                        urlString = urlString.replacingOccurrences(of: "&amp;", with: "&")
                        if let imageURL = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            return imageURL
                        }
                    }
                }
            }
        } catch {
            print("Error fetching OGP image for \(url): \(error)")
        }
        return nil
    }
}

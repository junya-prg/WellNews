//
//  ArticleFetchService.swift
//  WellNews
//
//  健康関連記事を取得するサービス
//

import Foundation
import SwiftUI
import Combine
import WidgetKit

/// 記事取得サービス
@MainActor
class ArticleFetchService: ObservableObject {
    /// 共有インスタンス
    static let shared = ArticleFetchService()
    
    /// 取得した記事一覧
    @Published private(set) var articles: [Article] = []
    
    /// 読み込み中かどうか
    @Published private(set) var isLoading = false
    
    /// エラーメッセージ
    @Published var errorMessage: String?
    
    /// 追跡中のキーワードリスト
    @Published var keywords: [TrackedKeyword] = []
    
    /// 有効なRSS配信元
    @Published var activeRSSSources: Set<RSSSource> = Set(RSSSource.allCases)
    
    /// Google News RSSのベースURL
    private let googleNewsRSSBaseURL = "https://news.google.com/rss/search"
    
    /// UserDefaultsキー (TrackedKeyword構造体用にv3に更新)
    private let keywordsKey = "wellnews.trackedKeywords_v3"
    
    /// UserDefaultsキー (RSS配信元の保存用)
    private let rssSourcesKey = "wellnews.activeRSSSources_v1"
    
    /// 現在のUI言語が英語かどうか（将来の多言語化用。現在は日本語に固定）
    private var isEnglishUI: Bool {
        return false
    }

    /// デフォルトのキーワード（日本語固定）
    private var defaultKeywords: [TrackedKeyword] {
        return [
            TrackedKeyword(name: "睡眠改善", isEnabled: true),
            TrackedKeyword(name: "糖質制限", isEnabled: true),
            TrackedKeyword(name: "筋トレ", isEnabled: true),
            TrackedKeyword(name: "サウナ健康", isEnabled: true),
            TrackedKeyword(name: "メンタルケア", isEnabled: true),
            TrackedKeyword(name: "マインドフルネス", isEnabled: true)
        ]
    }

    /// UI言語に応じた Google News RSS のクエリパラメータ
    private var newsRegionParams: String {
        return "hl=ja&gl=JP&ceid=JP:ja"
    }

    /// キャッシュ用のUserDefaultsキー
    private var cacheKey: String {
        "cachedArticles_ja"
    }
    private var cacheTimestampKey: String {
        "cachedArticlesTimestamp_ja"
    }
    
    /// キャッシュの有効期限（1時間）
    private let cacheExpiration: TimeInterval = 3600
    
    /// 最大記事取得数
    private let maxArticleCount = 35
    
    init() {
        loadKeywords()
        loadRSSSources()
    }
    
    /// キーワードを読み込み
    func loadKeywords() {
        if let data = UserDefaults.standard.data(forKey: keywordsKey),
           let saved = try? JSONDecoder().decode([TrackedKeyword].self, from: data),
           !saved.isEmpty {
            self.keywords = saved
        } else {
            self.keywords = defaultKeywords
            saveKeywords()
        }
    }
    
    /// キーワードを保存
    func saveKeywords() {
        if let encoded = try? JSONEncoder().encode(keywords) {
            UserDefaults.standard.set(encoded, forKey: keywordsKey)
        }
    }
    
    /// キーワードを追加。上限に達した場合は追加せず false を返す
    @discardableResult
    func addKeyword(_ keyword: String) -> Bool {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        
        // 無料ユーザーは最大10個制限
        let isPremium = StoreManager.shared.isPremium
        if !isPremium && keywords.count >= 10 {
            return false
        }
        
        if !keywords.contains(where: { $0.name == trimmed }) {
            keywords.append(TrackedKeyword(name: trimmed, isEnabled: true))
            saveKeywords()
        }
        return true
    }

    
    /// キーワードを削除
    func removeKeyword(_ keyword: TrackedKeyword) {
        keywords.removeAll(where: { $0.id == keyword.id })
        saveKeywords()
    }
    
    /// キーワードの有効・無効を切り替え
    func toggleKeyword(_ keyword: TrackedKeyword) {
        if let index = keywords.firstIndex(where: { $0.id == keyword.id }) {
            keywords[index].isEnabled.toggle()
            saveKeywords()
        }
    }
    
    /// RSS配信元の設定を読み込み
    func loadRSSSources() {
        if let data = UserDefaults.standard.data(forKey: rssSourcesKey),
           let saved = try? JSONDecoder().decode([RSSSource].self, from: data) {
            self.activeRSSSources = Set(saved)
            if self.activeRSSSources.isEmpty {
                self.activeRSSSources = Set(RSSSource.allCases)
                saveRSSSources()
            }
        } else {
            self.activeRSSSources = Set(RSSSource.allCases)
            saveRSSSources()
        }
    }
    
    /// RSS配信元の設定を保存
    func saveRSSSources() {
        let sourcesArray = Array(activeRSSSources)
        if let encoded = try? JSONEncoder().encode(sourcesArray) {
            UserDefaults.standard.set(encoded, forKey: rssSourcesKey)
        }
    }
    
    /// RSS配信元の有効/無効を切り替え
    func toggleRSSSource(_ source: RSSSource, enabled: Bool) {
        if enabled {
            activeRSSSources.insert(source)
        } else {
            // 最低1つはオンにしておく必要がある
            guard activeRSSSources.count > 1 else { return }
            activeRSSSources.remove(source)
        }
        saveRSSSources()
    }
    
    /// 記事を取得
    func fetchArticles() async {
        print("📰 fetchArticles開始")
        isLoading = true
        errorMessage = nil
        
        if let cachedArticles = loadCachedArticles(), !cachedArticles.isEmpty {
            let limitedArticles = Array(cachedArticles.prefix(maxArticleCount))
            print("📰 キャッシュから\(limitedArticles.count)件の記事を取得")
            articles = limitedArticles
            isLoading = false
            
            // バックグラウンドで最新記事を取得
            Task {
                await fetchFromRSS()
            }
            return
        }
        
        // RSSから取得
        print("📰 RSSから記事を取得中...")
        await fetchFromRSS()
        
        // RSSが失敗した場合はサンプルデータを使用
        if articles.isEmpty {
            print("📰 RSSから取得できなかったため、サンプルデータを使用")
            articles = Article.sampleArticles
        }
        
        print("📰 fetchArticles完了: \(articles.count)件")
        isLoading = false
    }
    
    /// RSSから記事を取得
    private func fetchFromRSS() async {
        // 有効なキーワードのみを抽出
        let activeKeywords = keywords.filter { $0.isEnabled }.map { $0.name }
        
        guard !activeKeywords.isEmpty else {
            print("📰 有効なキーワードがありません")
            articles = []
            return
        }
        
        guard !activeRSSSources.isEmpty else {
            print("📰 有効なRSS配信元がありません")
            articles = []
            return
        }
        
        // ターゲットとする (URL, RSSSource) のリストを作成する
        var targets: [(url: URL, source: RSSSource)] = []
        
        // 1. Googleニュース
        if activeRSSSources.contains(.googleNews) {
            let googleQuery = activeKeywords.joined(separator: "+OR+")
            if let encodedGoogleQuery = googleQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let googleURL = URL(string: "\(googleNewsRSSBaseURL)?q=\(encodedGoogleQuery)&\(newsRegionParams)") {
                targets.append((googleURL, .googleNews))
            }
        }
        
        // 2. はてなブックマーク (上位3キーワード)
        if activeRSSSources.contains(.hatenaBookmark) && !isEnglishUI {
            let hatenaKeywords = Array(activeKeywords.prefix(3))
            let hatenaQuery = hatenaKeywords.joined(separator: " OR ")
            if let encodedHatenaQuery = hatenaQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let hatenaURL = URL(string: "https://b.hatena.ne.jp/q/\(encodedHatenaQuery)?mode=rss&sort=recent") {
                targets.append((hatenaURL, .hatenaBookmark))
            }
        }
        
        // 3. note (キーワードごとに個別のRSSが存在するため、上位5キーワード分を追加)
        if activeRSSSources.contains(.note) {
            for keyword in activeKeywords.prefix(5) {
                if let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                   let url = URL(string: "https://note.com/hashtag/\(encodedKeyword)/rss") {
                    targets.append((url, .note))
                }
            }
        }
        
        // 4. PR TIMES (キーワードごとに個別のRSSが存在するため、上位5キーワード分を追加)
        if activeRSSSources.contains(.prTimes) {
            for keyword in activeKeywords.prefix(5) {
                if let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                   let url = URL(string: "https://prtimes.jp/main/html/rd/index.class.php?action=view_rss&keyword=\(encodedKeyword)") {
                    targets.append((url, .prTimes))
                }
            }
        }
        
        var allFetchedArticles: [Article] = []
        
        // TaskGroupを用いて並行フェッチを実行
        await withTaskGroup(of: (Data, RSSSource)?.self) { group in
            for target in targets {
                group.addTask {
                    guard let data = await self.fetchRawData(from: target.url) else {
                        return nil
                    }
                    return (data, target.source)
                }
            }
            
            for await result in group {
                guard let (data, source) = result else { continue }
                
                // メインアクター側で安全にパースと変換を行う
                let rawArticles = RSSParser().parse(data: data)
                
                let transformed: [Article]
                switch source {
                case .googleNews:
                    transformed = rawArticles
                case .hatenaBookmark:
                    transformed = self.transformHatenaArticles(rawArticles)
                case .note:
                    transformed = self.transformNoteArticles(rawArticles)
                case .prTimes:
                    transformed = self.transformPRTimesArticles(rawArticles)
                }
                
                allFetchedArticles.append(contentsOf: transformed)
            }
        }
        
        var uniqueArticlesMap: [UUID: Article] = [:]
        for article in allFetchedArticles {
            if uniqueArticlesMap[article.id] == nil {
                uniqueArticlesMap[article.id] = article
            }
        }
        
        let sortedArticles = uniqueArticlesMap.values.sorted { $0.publishedAt > $1.publishedAt }
        
        if !sortedArticles.isEmpty {
            let limitedArticles = Array(sortedArticles.prefix(maxArticleCount))
            articles = limitedArticles
            cacheArticles(limitedArticles)
        }
    }
    
    /// はてなブックマーク記事のメタデータを正規化・変換
    private func transformHatenaArticles(_ hatenaArticles: [Article]) -> [Article] {
        return hatenaArticles.map { art in
            var modified = art
            if modified.source.isEmpty || modified.source.contains("b.hatena.ne.jp") {
                modified = Article(
                    id: modified.id,
                    title: modified.title,
                    source: self.isEnglishUI ? "Hatena Bookmark" : "はてなブックマーク",
                    publishedAt: modified.publishedAt,
                    url: modified.url,
                    description: modified.description,
                    aiSummary: modified.aiSummary,
                    category: modified.category,
                    relevanceScore: modified.relevanceScore,
                    isAIProcessed: modified.isAIProcessed,
                    imageUrl: modified.imageUrl
                )
            }
            return modified
        }
    }
    
    /// note記事のメタデータを正規化・変換
    private func transformNoteArticles(_ noteArticles: [Article]) -> [Article] {
        return noteArticles.map { art in
            var modified = art
            if modified.source.isEmpty || modified.source.contains("note.com") {
                modified = Article(
                    id: modified.id,
                    title: modified.title,
                    source: "note",
                    publishedAt: modified.publishedAt,
                    url: modified.url,
                    description: modified.description,
                    aiSummary: modified.aiSummary,
                    category: modified.category,
                    relevanceScore: modified.relevanceScore,
                    isAIProcessed: modified.isAIProcessed,
                    imageUrl: modified.imageUrl
                )
            }
            return modified
        }
    }
    
    /// PR TIMES記事のメタデータを正規化・変換
    private func transformPRTimesArticles(_ prTimesArticles: [Article]) -> [Article] {
        return prTimesArticles.map { art in
            var modified = art
            if modified.source.isEmpty || modified.source.contains("prtimes.jp") {
                modified = Article(
                    id: modified.id,
                    title: modified.title,
                    source: "PR TIMES",
                    publishedAt: modified.publishedAt,
                    url: modified.url,
                    description: modified.description,
                    aiSummary: modified.aiSummary,
                    category: modified.category,
                    relevanceScore: modified.relevanceScore,
                    isAIProcessed: modified.isAIProcessed,
                    imageUrl: modified.imageUrl
                )
            }
            return modified
        }
    }
    
    private func fetchRawData(from url: URL) async -> Data? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            return data
        } catch {
            print("URL読み込みエラー (\(url)): \(error)")
            return nil
        }
    }
    
    private var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: "group.jp.junya.WellNews") ?? UserDefaults.standard
    }
    
    private func cacheArticles(_ articles: [Article]) {
        if let encoded = try? JSONEncoder().encode(articles) {
            sharedDefaults.set(encoded, forKey: cacheKey)
            sharedDefaults.set(Date().timeIntervalSince1970, forKey: cacheTimestampKey)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    private func loadCachedArticles() -> [Article]? {
        let timestamp = sharedDefaults.double(forKey: cacheTimestampKey)
        let currentTime = Date().timeIntervalSince1970
        
        guard currentTime - timestamp < cacheExpiration else {
            return nil
        }
        
        guard let data = sharedDefaults.data(forKey: cacheKey),
              let articles = try? JSONDecoder().decode([Article].self, from: data) else {
            return nil
        }
        
        return articles
    }
    
    func clearCache() {
        sharedDefaults.removeObject(forKey: cacheKey)
        sharedDefaults.removeObject(forKey: cacheTimestampKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func refreshArticles() async {
        clearCache()
        await fetchArticles()
    }
}

// MARK: - RSSパーサー

private class RSSParser: NSObject, XMLParserDelegate {
    private var articles: [Article] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentPubDate = ""
    private var currentSource = ""
    private var currentDescription = ""
    private var currentImageUrlString = ""
    private var isInItem = false
    
    func parse(data: Data) -> [Article] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return articles
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        
        if elementName == "item" {
            isInItem = true
            currentTitle = ""
            currentLink = ""
            currentPubDate = ""
            currentSource = ""
            currentDescription = ""
            currentImageUrlString = ""
        }
        
        if elementName == "source", let sourceUrl = attributeDict["url"] {
            if let url = URL(string: sourceUrl) {
                currentSource = url.host ?? ""
            }
        }
        
        if isInItem {
            if elementName == "enclosure", let urlString = attributeDict["url"] {
                let type = attributeDict["type"] ?? ""
                if type.contains("image") || urlString.contains(".jpg") || urlString.contains(".jpeg") || urlString.contains(".png") || urlString.contains(".gif") || urlString.contains(".webp") {
                    currentImageUrlString = urlString
                }
            } else if (elementName == "media:content" || elementName == "media:thumbnail" || elementName == "content" || elementName == "thumbnail"), let urlString = attributeDict["url"] {
                currentImageUrlString = urlString
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInItem else { return }
        
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        switch currentElement {
        case "title":
            currentTitle += trimmed
        case "link":
            currentLink += trimmed
        case "pubDate", "dc:date", "date":
            currentPubDate += trimmed
        case "source":
            if currentSource.isEmpty {
                currentSource = trimmed
            }
        case "description":
            currentDescription += trimmed
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            isInItem = false
            
            let trimmedLink = currentLink.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: trimmedLink) {
                let publishedDate = parseDate(currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines)) ?? Date()
                
                let (cleanTitle, extractedSource) = extractSourceFromTitle(currentTitle)
                let finalSource = extractedSource.isEmpty ? currentSource : extractedSource
                
                var finalImageUrl: URL? = nil
                if !currentImageUrlString.isEmpty {
                    finalImageUrl = URL(string: currentImageUrlString.trimmingCharacters(in: .whitespacesAndNewlines))
                } else if let htmlImageUrl = extractImageUrlFromHtml(currentDescription) {
                    finalImageUrl = URL(string: htmlImageUrl.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                
                let article = Article(
                    title: cleanTitle,
                    source: finalSource,
                    publishedAt: publishedDate,
                    url: url,
                    description: cleanDescription(currentDescription),
                    imageUrl: finalImageUrl
                )
                articles.append(article)
            }
        }
    }
    
    private func extractImageUrlFromHtml(_ html: String) -> String? {
        let pattern = "<img[^>]+src=\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let nsString = html as NSString
        let results = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))
        if let firstMatch = results.first, firstMatch.numberOfRanges > 1 {
            return nsString.substring(with: firstMatch.range(at: 1))
        }
        return nil
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }()
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        return nil
    }
    
    private func extractSourceFromTitle(_ title: String) -> (cleanTitle: String, source: String) {
        if let range = title.range(of: " - ", options: .backwards) {
            let cleanTitle = String(title[..<range.lowerBound])
            let source = String(title[range.upperBound...])
            return (cleanTitle, source)
        }
        return (title, "")
    }
    
    private func cleanDescription(_ description: String) -> String? {
        var cleaned = description.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        cleaned = decodeHTMLEntities(cleaned)
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    
    private func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        let entities: [(String, String)] = [
            ("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&apos;", "'"), ("&#39;", "'"), ("&#x27;", "'"),
            ("&hellip;", "…"), ("&mdash;", "—"), ("&ndash;", "–")
        ]
        
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        
        result = decodeNumericEntities(result)
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return result
    }
    
    private func decodeNumericEntities(_ string: String) -> String {
        var result = string
        
        while let range = result.range(of: "&#\\d+;", options: .regularExpression) {
            let entity = String(result[range])
            let numberString = entity.dropFirst(2).dropLast(1)
            if let codePoint = Int(numberString), let scalar = Unicode.Scalar(codePoint) {
                result.replaceSubrange(range, with: String(Character(scalar)))
            } else {
                break
            }
        }
        
        while let range = result.range(of: "&#[xX][0-9a-fA-F]+;", options: .regularExpression) {
            let entity = String(result[range])
            let hexString = entity.dropFirst(3).dropLast(1)
            if let codePoint = Int(hexString, radix: 16), let scalar = Unicode.Scalar(codePoint) {
                result.replaceSubrange(range, with: String(Character(scalar)))
            } else {
                break
            }
        }
        
        return result
    }
}

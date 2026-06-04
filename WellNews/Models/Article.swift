//
//  Article.swift
//  WellNews
//
//  健康ニュース記事を表すモデル
//

import Foundation
import CryptoKit

/// 追跡対象の健康キーワード（トグルの有効/無効状態を保持）
struct TrackedKeyword: Codable, Hashable, Identifiable {
    var id: String { name }
    let name: String
    var isEnabled: Bool
}

/// 健康ニュースのカテゴリ
enum ArticleCategory: String, CaseIterable, Codable, Identifiable {
    case exercise = "運動"
    case diet = "食事・栄養"
    case sleep = "睡眠・休養"
    case mentalCare = "メンタルケア"
    case other = "その他"

    var id: String { rawValue }

    /// ローカライズ済みの表示名
    var displayName: String {
        switch self {
        case .exercise: return String(localized: "運動")
        case .diet: return String(localized: "食事・栄養")
        case .sleep: return String(localized: "睡眠・休養")
        case .mentalCare: return String(localized: "メンタルケア")
        case .other: return String(localized: "その他")
        }
    }

    /// カテゴリに対応するSF Symbolsアイコン名
    var iconName: String {
        switch self {
        case .exercise:
            return "figure.run"
        case .diet:
            return "fork.knife"
        case .sleep:
            return "bed.double.fill"
        case .mentalCare:
            return "brain.head.profile"
        case .other:
            return "doc.text"
        }
    }
    
    /// カテゴリの色名
    var color: String {
        switch self {
        case .exercise:
            return "blue"
        case .diet:
            return "orange"
        case .sleep:
            return "purple"
        case .mentalCare:
            return "green"
        case .other:
            return "gray"
        }
    }
}

/// AI要約の長さ設定
enum SummaryLength: String, CaseIterable, Identifiable, Codable {
    case short = "short"
    case medium = "medium"
    case detailed = "detailed"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .short: return String(localized: "簡潔 (1〜2文)")
        case .medium: return String(localized: "標準 (2〜3文)")
        case .detailed: return String(localized: "詳細 (4〜5文)")
        }
    }
}

/// 利用可能なRSSソース
public enum RSSSource: String, Codable, CaseIterable, Identifiable {
    case googleNews = "googleNews"
    case hatenaBookmark = "hatenaBookmark"
    case note = "note"
    case prTimes = "prTimes"
    
    public var id: String { rawValue }
    
    /// RSS配信元の表示名
    public var displayName: String {
        switch self {
        case .googleNews:
            return "Google ニュース"
        case .hatenaBookmark:
            return "はてなブックマーク"
        case .note:
            return "note (ノート)"
        case .prTimes:
            return "PR TIMES"
        }
    }
    
    /// RSS配信元の公式特徴・概要
    public var description: String {
        switch self {
        case .googleNews:
            return "世界中の多様な報道メディアから最新のニュース記事を網羅的に収集します。特定の健康キーワードに関する客観的で信頼性の高い報道を幅広くキャッチするのに最適です。"
        case .hatenaBookmark:
            return "ソーシャルブックマークサービス「はてなブックマーク」で話題になっている記事やブログなどを収集します。ネット上で注目されているトレンドや、体験談・まとめ記事などを探すのに適しています。"
        case .note:
            return "クリエイタープラットフォーム「note」のハッシュタグから記事を収集します。個人によるリアルな体験談や専門家のコラムなど、ライフスタイルに寄り添った多様な読み物を探すのに最適です。"
        case .prTimes:
            return "プレスリリース配信サービス「PR TIMES」から新着リリースを収集します。ヘルスケア分野の新しいサービス、睡眠グッズ、健康食品などの新商品情報や最新のビジネトレンドをいち早くキャッチできます。"
        }
    }
    
    /// SF Symbolsアイコン名
    public var iconName: String {
        switch self {
        case .googleNews:
            return "globe.asia.australia.fill"
        case .hatenaBookmark:
            return "bookmark.circle.fill"
        case .note:
            return "pencil.line"
        case .prTimes:
            return "megaphone.fill"
        }
    }
    
    /// テーマカラー名
    public var colorName: String {
        switch self {
        case .googleNews:
            return "blue"
        case .hatenaBookmark:
            return "cyan"
        case .note:
            return "green"
        case .prTimes:
            return "indigo"
        }
    }
    
    /// 公式サイトURL
    public var officialURL: URL? {
        switch self {
        case .googleNews:
            return URL(string: "https://news.google.co.jp/")
        case .hatenaBookmark:
            return URL(string: "https://b.hatena.ne.jp/")
        case .note:
            return URL(string: "https://note.com/")
        case .prTimes:
            return URL(string: "https://prtimes.jp/")
        }
    }
}

/// ニュース記事を表すモデル
struct Article: Identifiable, Codable, Hashable {
    /// 一意識別子
    let id: UUID
    
    /// 記事タイトル
    let title: String
    
    /// 記事ソース（ニュースサイト名など）
    let source: String
    
    /// 公開日時
    let publishedAt: Date
    
    /// 記事URL
    let url: URL
    
    /// 記事の説明・抜粋（RSSから取得）
    let description: String?
    
    /// AI生成の要約
    var aiSummary: String?
    
    /// AIが判定したカテゴリ
    var category: ArticleCategory?
    
    /// おすすめ度（0.0〜1.0）
    var relevanceScore: Double?
    
    /// AIによる処理が行われたかどうか（falseの場合はフォールバック処理）
    var isAIProcessed: Bool = false
    
    /// 記事の画像URL
    let imageUrl: URL?
    
    /// 初期化
    /// - Parameters:
    ///   - title: 記事タイトル
    ///   - source: 記事ソース
    ///   - publishedAt: 公開日時
    ///   - url: 記事URL
    ///   - description: 記事の説明
    init(
        id: UUID? = nil,
        title: String,
        source: String,
        publishedAt: Date,
        url: URL,
        description: String? = nil,
        aiSummary: String? = nil,
        category: ArticleCategory? = nil,
        relevanceScore: Double? = nil,
        isAIProcessed: Bool = false,
        imageUrl: URL? = nil
    ) {
        self.id = id ?? Article.deterministicID(from: url)
        self.title = title
        self.source = source
        self.publishedAt = publishedAt
        self.url = url
        self.description = description
        self.aiSummary = aiSummary
        self.category = category
        self.relevanceScore = relevanceScore
        self.isAIProcessed = isAIProcessed
        self.imageUrl = imageUrl
    }
    
    /// URL 文字列から決定論的に UUID を生成
    static func deterministicID(from url: URL) -> UUID {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        var bytes = [UInt8]()
        bytes.reserveCapacity(16)
        for (index, byte) in digest.enumerated() {
            guard index < 16 else { break }
            bytes.append(byte)
        }
        while bytes.count < 16 { bytes.append(0) }
        let uuidTuple: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: uuidTuple)
    }
    
    /// 公開日時のフォーマット済み文字列
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: publishedAt)
    }

    /// 公開日時の相対表示
    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.current
        formatter.unitsStyle = .short
        return formatter.localizedString(for: publishedAt, relativeTo: Date())
    }
    
    /// おすすめ度のパーセント表示
    var relevancePercentage: Int? {
        guard let score = relevanceScore else { return nil }
        return Int(score * 100)
    }
}

// MARK: - サンプルデータ

extension Article {
    /// プレビュー・テスト用のサンプル記事
    static let sampleArticles: [Article] = [
        Article(
            title: "睡眠の質を劇的に向上させる5つの就寝前ルーティン",
            source: "Health & Care",
            publishedAt: Date().addingTimeInterval(-3600),
            url: URL(string: "https://example.com/article1")!,
            description: "最新の睡眠科学に基づき、深い睡眠を得るための具体的な寝室環境の整え方や、カフェイン制限の時間、スマホ使用制限などの具体的なアクションを解説。",
            aiSummary: "質の高い睡眠をとるためには、就寝前の行動が不可欠です。本記事ではスマホの光カット、室温の調整、ハーブティーの導入など、科学的に実証された5つの方法を紹介します。",
            category: .sleep,
            relevanceScore: 0.92,
            isAIProcessed: true,
            imageUrl: URL(string: "https://images.unsplash.com/photo-1511295742364-92767eb89d9e?w=500&auto=format&fit=crop")
        ),
        Article(
            title: "毎日の15分ウォーキングが脳と体に与えるメリット",
            source: "フィットネスライフ",
            publishedAt: Date().addingTimeInterval(-7200),
            url: URL(string: "https://example.com/article2")!,
            description: "激しい運動をしなくても、1日わずか15分の散歩で心肺機能が向上し、うつ病リスクが低減する理由について解説。",
            aiSummary: "短時間のウォーキングであっても、日常的に行うことで心疾患のリスクを下げ、脳の活性化を促し、ストレス物質を減少させるメリットがあることが判明しました。",
            category: .exercise,
            relevanceScore: 0.88,
            isAIProcessed: true,
            imageUrl: URL(string: "https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?w=500&auto=format&fit=crop")
        ),
        Article(
            title: "糖質制限vs脂質制限：あなたに最適なダイエット法は？",
            source: "栄養科学ジャーナル",
            publishedAt: Date().addingTimeInterval(-14400),
            url: URL(string: "https://example.com/article3")!,
            description: "体質やライフスタイルによって適したカロリー制限の方法は異なります。遺伝子レベルでのエネルギー代謝と最新の研究トレンドを解説。",
            aiSummary: "炭水化物を減らすアプローチと脂肪を減らすアプローチの効果を比較。個人の体質や筋肉量によって適正な食事法を選ぶことで、持続可能かつ効果的な減量が可能になります。",
            category: .diet,
            relevanceScore: 0.75,
            isAIProcessed: true,
            imageUrl: URL(string: "https://images.unsplash.com/photo-1490645935967-10de6ba17061?w=500&auto=format&fit=crop")
        ),
        Article(
            title: "マインドフルネス瞑想でビジネスパーソンの集中力を高める",
            source: "心の健康ナビ",
            publishedAt: Date().addingTimeInterval(-28800),
            url: URL(string: "https://example.com/article4")!,
            description: "仕事中のストレスに対処するための呼吸法や、1回5分から始められる手軽なマインドフルネス瞑想の実践法を紹介。",
            aiSummary: "日常の仕事ストレスを減らし、脳の疲労を軽減するためのマインドフルネス瞑想を提案。1回5分の呼吸への集中により、作業の生産性が向上します。",
            category: .mentalCare,
            relevanceScore: 0.81,
            isAIProcessed: true,
            imageUrl: URL(string: "https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=500&auto=format&fit=crop")
        ),
        Article(
            title: "サウナの「ととのう」メカニズムと健康的な入り方",
            source: "Well-Being",
            publishedAt: Date().addingTimeInterval(-43200),
            url: URL(string: "https://example.com/article5")!,
            description: "温冷交代浴が自律神経に与える影響と、安全にサウナを楽しむための水分補給や時間配分の目安を医師が解説。",
            aiSummary: "サウナによる血管の収縮と拡張が、自律神経のバランスを整え、深いリラックス効果をもたらします。急激な血圧変化には注意し、適度な時間で楽しむことが推奨されます。",
            category: .sleep,
            relevanceScore: 0.85,
            isAIProcessed: true,
            imageUrl: URL(string: "https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=500&auto=format&fit=crop")
        )
    ]
    
    /// 単一のサンプル記事
    static let sample = sampleArticles[0]
}

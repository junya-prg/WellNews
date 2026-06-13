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

/// AI要約の構造化データ
struct ArticleDigest: Codable, Hashable {
    /// ひとことで言うと
    var headline: String
    /// 3つのポイント
    var points: [DigestPoint]
    /// 今日からできるアクション
    var actionTip: String
    /// 関連キーワード
    var keywords: [String]
}

/// 要約の1ポイント
struct DigestPoint: Codable, Hashable {
    /// 短い見出し
    var label: String
    /// 見出しを説明する前向きな1文
    var detail: String
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
            return String(localized: "Google ニュース")
        case .hatenaBookmark:
            return String(localized: "はてなブックマーク")
        case .note:
            return String(localized: "note (ノート)")
        case .prTimes:
            return String(localized: "PR TIMES")
        }
    }
    
    /// RSS配信元の公式特徴・概要
    public var description: String {
        switch self {
        case .googleNews:
            return String(localized: "世界中の多様な報道メディアから最新のニュース記事を網羅的に収集します。特定の健康キーワードに関する客観的で信頼性の高い報道を幅広くキャッチするのに最適です。")
        case .hatenaBookmark:
            return String(localized: "ソーシャルブックマークサービス「はてなブックマーク」で話題になっている記事やブログなどを収集します。ネット上で注目されているトレンドや、体験談・まとめ記事などを探すのに適しています。")
        case .note:
            return String(localized: "クリエイタープラットフォーム「note」のハッシュタグから記事を収集します。個人によるリアルな体験談や専門家のコラムなど、ライフスタイルに寄り添った多様な読み物を探すのに最適です。")
        case .prTimes:
            return String(localized: "プレスリリース配信サービス「PR TIMES」から新着リリースを収集します。ヘルスケア分野の新しいサービス、睡眠グッズ、健康食品などの新商品情報や最新のビジネトレンドをいち早くキャッチできます。")
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
    
    /// AI生成の構造化要約
    var summaryDigest: ArticleDigest?
    
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
        summaryDigest: ArticleDigest? = nil,
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
        self.summaryDigest = summaryDigest
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
    static var sampleArticles: [Article] {
        let isEnglish = (Bundle.main.preferredLocalizations.first ?? "en").hasPrefix("en")
        if isEnglish {
            return [
                Article(
                    title: "5 Bedtime Routines to Dramatically Improve Your Sleep Quality",
                    source: "Health & Care",
                    publishedAt: Date().addingTimeInterval(-3600),
                    url: URL(string: "https://example.com/article1")!,
                    description: "Based on the latest sleep science, we explain how to set up your bedroom environment, caffeine limits, and smartphone use before bed to get deep sleep.",
                    aiSummary: "Rethinking your bedtime habits is key to improving sleep quality. This article introduces five scientifically proven methods including cutting screen light, adjusting room temperature, and introducing herbal tea.",
                    summaryDigest: ArticleDigest(
                        headline: "By rethinking your bedtime habits, your sleep quality can be dramatically improved.",
                        points: [
                            DigestPoint(label: "Sleep Environment", detail: "Keep the room temperature comfortable and dim the lights 1 hour before bed."),
                            DigestPoint(label: "Limit Caffeine", detail: "Avoid caffeine intake in the evening to fall asleep more smoothly."),
                            DigestPoint(label: "Limit Screen Time", detail: "Cutting off blue light 30 minutes before bed promotes melatonin secretion.")
                        ],
                        actionTip: "Tonight, try turning off your smartphone 30 minutes before getting into bed.",
                        keywords: ["Sleep Quality", "Night Routine", "Blue Light", "Melatonin"]
                    ),
                    category: .sleep,
                    relevanceScore: 0.92,
                    isAIProcessed: true,
                    imageUrl: URL(string: "https://images.unsplash.com/photo-1511295742364-92767eb89d9e?w=500&auto=format&fit=crop")
                ),
                Article(
                    title: "The Brain and Body Benefits of a Daily 15-Minute Walk",
                    source: "Fitness Life",
                    publishedAt: Date().addingTimeInterval(-7200),
                    url: URL(string: "https://example.com/article2")!,
                    description: "Even without intense exercise, a simple 15-minute daily walk can improve cardiorespiratory function and lower depression risk.",
                    aiSummary: "Studies show that even short daily walks lower heart disease risk, stimulate the brain, and reduce stress hormones.",
                    summaryDigest: ArticleDigest(
                        headline: "Even a daily 15-minute walk can significantly benefit your brain and body health.",
                        points: [
                            DigestPoint(label: "Cardio Health", detail: "Lowers heart disease risk and improves cardiovascular functions."),
                            DigestPoint(label: "Brain Activity", detail: "Stimulates brain cells, enhancing focus and cognitive clarity."),
                            DigestPoint(label: "Stress Relief", detail: "Reduces stress hormones and boosts your mood naturally.")
                        ],
                        actionTip: "Try taking a short 15-minute walk during your lunch break today.",
                        keywords: ["Walking", "Cardio Health", "Brain Benefits", "Stress Reduction"]
                    ),
                    category: .exercise,
                    relevanceScore: 0.88,
                    isAIProcessed: true,
                    imageUrl: URL(string: "https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?w=500&auto=format&fit=crop")
                ),
                Article(
                    title: "Low-Carb vs. Low-Fat: Which Diet Is Best for You?",
                    source: "Nutritional Science Journal",
                    publishedAt: Date().addingTimeInterval(-14400),
                    url: URL(string: "https://example.com/article3")!,
                    description: "The best calorie restriction approach varies by body type and lifestyle. We explain energy metabolism at a genetic level and the latest research trends.",
                    aiSummary: "Comparing low-carb and low-fat approaches. Choosing the right diet based on your body type and muscle mass leads to sustainable and effective weight loss.",
                    summaryDigest: ArticleDigest(
                        headline: "Choosing the right diet based on your body type leads to sustainable weight loss.",
                        points: [
                            DigestPoint(label: "Body Type", detail: "The best calorie restriction approach varies by individual genetics and lifestyle."),
                            DigestPoint(label: "Low-Carb", detail: "Reducing carbohydrates works well for those with lower daily activity levels."),
                            DigestPoint(label: "Low-Fat", detail: "Cutting fat is effective for active individuals who need steady carb energy.")
                        ],
                        actionTip: "Assess your daily activity level to choose the most sustainable diet approach.",
                        keywords: ["Diet Comparison", "Low-Carb", "Low-Fat", "Metabolism"]
                    ),
                    category: .diet,
                    relevanceScore: 0.75,
                    isAIProcessed: true,
                    imageUrl: URL(string: "https://images.unsplash.com/photo-1490645935967-10de6ba17061?w=500&auto=format&fit=crop")
                ),
                Article(
                    title: "Enhancing Business Focus with Mindfulness Meditation",
                    source: "Mental Health Nav",
                    publishedAt: Date().addingTimeInterval(-28800),
                    url: URL(string: "https://example.com/article4")!,
                    description: "Introducing breathing techniques to manage workplace stress and simple mindfulness practices you can start in just 5 minutes.",
                    aiSummary: "Suggesting mindfulness meditation to reduce daily work stress and brain fatigue. Focusing on breathing for 5 minutes improves overall productivity.",
                    summaryDigest: ArticleDigest(
                        headline: "Practicing 5-minute mindfulness meditation improves work focus and reduces brain fatigue.",
                        points: [
                            DigestPoint(label: "Stress Relief", detail: "Simple breathing techniques help manage daily workplace tension."),
                            DigestPoint(label: "Brain Recovery", detail: "Mindfulness lets your brain rest and recover from cognitive fatigue."),
                            DigestPoint(label: "Productivity", detail: "Focusing on your breath for just 5 minutes boosts daily work efficiency.")
                        ],
                        actionTip: "Set a timer and practice breathing mindfully for 5 minutes during your next break.",
                        keywords: ["Mindfulness", "Meditation", "Focus", "Stress Management"]
                    ),
                    category: .mentalCare,
                    relevanceScore: 0.81,
                    isAIProcessed: true,
                    imageUrl: URL(string: "https://images.unsplash.com/photo-1506126613408-eca07ce68773?w=500&auto=format&fit=crop")
                ),
                Article(
                    title: "How Saunas Help You 'Recover' and How to Do It Safely",
                    source: "Well-Being",
                    publishedAt: Date().addingTimeInterval(-43200),
                    url: URL(string: "https://example.com/article5")!,
                    description: "A doctor explains how alternating hot and cold baths affects the autonomic nervous system, along with tips on hydration and time limits.",
                    aiSummary: "Alternating hot saunas and cold baths regulates the autonomic nervous system, producing deep relaxation. Mind rapid blood pressure changes and hydrate well.",
                    summaryDigest: ArticleDigest(
                        headline: "Alternating hot saunas and cold baths regulates your nervous system for deep recovery.",
                        points: [
                            DigestPoint(label: "Nervous System", detail: "Saunas regulate the autonomic nervous system, promoting deep physical relaxation."),
                            DigestPoint(label: "Cold Bath Tips", detail: "Alternating hot and cold exposure improves blood circulation and recovery."),
                            DigestPoint(label: "Safe Hydration", detail: "Be mindful of rapid blood pressure changes and drink plenty of water.")
                        ],
                        actionTip: "Always drink a glass of water before and after your sauna session.",
                        keywords: ["Sauna Health", "Recovery", "Nervous System", "Hydration"]
                    ),
                    category: .sleep,
                    relevanceScore: 0.85,
                    isAIProcessed: true,
                    imageUrl: URL(string: "https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=500&auto=format&fit=crop")
                )
            ]
        } else {
            return [
                Article(
                    title: "睡眠の質を劇的に向上させる5つの就寝前ルーティン",
                    source: "Health & Care",
                    publishedAt: Date().addingTimeInterval(-3600),
                    url: URL(string: "https://example.com/article1")!,
                    description: "最新の睡眠科学に基づき、深い睡眠を得るための具体的な寝室環境の整え方や、カフェイン制限の時間、スマホ使用制限などの具体的なアクションを解説。",
                    aiSummary: "質の高い睡眠をとるためには、就寝前の行動が不可欠です。本記事ではスマホの光カット、室温の調整、ハーブティーの導入など、科学的に実証された5つの方法を紹介します。",
                    summaryDigest: ArticleDigest(
                        headline: "就寝前の習慣を見直すことで、睡眠の質は劇的に改善できます。",
                        points: [
                            DigestPoint(label: "睡眠環境の調整", detail: "室温を快適に保ち、寝る1時間前から室内の照明を暗くしましょう。"),
                            DigestPoint(label: "カフェイン制限", detail: "夕方以降のカフェイン摂取を避けることで、入眠がスムーズになります。"),
                            DigestPoint(label: "スマホ制限", detail: "就寝30分前のブルーライト遮断は、メラトニンの分泌を促します。")
                        ],
                        actionTip: "今夜は布団に入る30分前にスマホの電源を切ってみましょう。",
                        keywords: ["睡眠の質", "ナイトルーティン", "ブルーライト", "メラトニン"]
                    ),
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
                    summaryDigest: ArticleDigest(
                        headline: "日々のわずか15分のウォーキングが、心肺機能の向上とうつ病リスクの低減に効果的です。",
                        points: [
                            DigestPoint(label: "心肺機能向上", detail: "軽いウォーキングでも毎日続けることで心疾患のリスクを低下させます。"),
                            DigestPoint(label: "脳の活性化", detail: "歩くことで脳が刺激され、認知機能の維持や向上につながります。"),
                            DigestPoint(label: "ストレス緩和", detail: "適度な運動はストレスホルモンを減少させ、気分転換に最適です。")
                        ],
                        actionTip: "今日のランチタイムや通勤時に、意識して15分歩く時間を作ってみましょう。",
                        keywords: ["ウォーキング", "有酸素運動", "脳の活性化", "ストレス解消"]
                    ),
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
                    summaryDigest: ArticleDigest(
                        headline: "体質やライフスタイルに合わせて糖質か脂質の制限を選ぶことが、健康的な減量への近道です。",
                        points: [
                            DigestPoint(label: "個別アプローチ", detail: "遺伝子レベルの代謝や活動量によって、最適な食事制限法は異なります。"),
                            DigestPoint(label: "糖質制限", detail: "デスクワーク中心など、日常の活動量が比較的少ない人に適しています。"),
                            DigestPoint(label: "脂質制限", detail: "運動習慣があり、エネルギー源として炭水化物を必要とする人に効果的です。")
                        ],
                        actionTip: "自分の日頃の運動量を振り返り、どちらの制限が続けやすいか考えてみましょう。",
                        keywords: ["食事制限", "糖質制限", "脂質制限", "代謝改善"]
                    ),
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
                    summaryDigest: ArticleDigest(
                        headline: "1回5分からのマインドフルネス瞑想は、脳の疲労を和らげ仕事の集中力を高めます。",
                        points: [
                            DigestPoint(label: "呼吸コントロール", detail: "ゆっくりとした呼吸に集中することで、仕事中の緊張や焦りを和らげます。"),
                            DigestPoint(label: "脳疲労のリセット", detail: "情報過多な日常から離れ、脳をしっかりと休める時間を作ります。"),
                            DigestPoint(label: "生産性の向上", detail: "短時間の瞑想を習慣にすることで、作業効率や判断力がアップします。")
                        ],
                        actionTip: "次の作業に移る前の5分間、静かに目を閉じて自分の呼吸に意識を向けてみましょう。",
                        keywords: ["マインドフルネス", "瞑想習慣", "集中力アップ", "ストレスケア"]
                    ),
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
                    summaryDigest: ArticleDigest(
                        headline: "サウナと水風呂を正しく組み合わせることで、自律神経が整い深いリラックス効果が得られます。",
                        points: [
                            DigestPoint(label: "自律神経の調整", detail: "温冷交代浴による血管の伸縮が、神経バランスを整え疲労を回復します。"),
                            DigestPoint(label: "安全な入り方", detail: "急激な血圧変化を防ぐため、サウナや水風呂の時間は無理のない範囲に留めます。"),
                            DigestPoint(label: "十分な水分補給", detail: "脱水症状を防ぐために、入浴前後に必ずコップ1杯以上の水分を取りましょう。")
                        ],
                        actionTip: "サウナに入る前と出た後に、必ず十分な量の水分補給を行うようにしましょう。",
                        keywords: ["サウナ効果", "温冷交代浴", "疲労回復", "自律神経調整"]
                    ),
                    category: .sleep,
                    relevanceScore: 0.85,
                    isAIProcessed: true,
                    imageUrl: URL(string: "https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=500&auto=format&fit=crop")
                )
            ]
        }
    }
    
    /// 単一のサンプル記事
    static var sample: Article {
        return sampleArticles[0]
    }
}

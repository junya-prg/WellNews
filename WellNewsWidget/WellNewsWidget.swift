import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), articles: Article.sampleArticles)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), articles: loadArticles())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = SimpleEntry(date: Date(), articles: loadArticles())
        
        // Refresh every 15 minutes to keep it up to date
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private var isEnglishUI: Bool {
        let lang = Bundle.main.preferredLocalizations.first ?? "en"
        return lang.hasPrefix("en")
    }

    private func loadArticles() -> [Article] {
        let cacheKey = isEnglishUI ? "cachedArticles_en" : "cachedArticles_ja"
        let suiteName = "group.jp.junya.WellNews"
        if let sharedDefaults = UserDefaults(suiteName: suiteName),
           let data = sharedDefaults.data(forKey: cacheKey),
           let articles = try? JSONDecoder().decode([Article].self, from: data) {
            return articles
        }
        return Article.sampleArticles
    }
}

// MARK: - Entry Model

struct SimpleEntry: TimelineEntry {
    let date: Date
    let articles: [Article]
}

// MARK: - Main Widget View

struct WellNewsWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch family {
            case .systemSmall:
                SmallWidgetView(article: entry.articles.first)
            case .systemMedium:
                MediumWidgetView(articles: entry.articles)
            case .systemLarge:
                LargeWidgetView(articles: entry.articles)
            case .systemExtraLarge:
                ExtraLargeWidgetView(articles: entry.articles)
            @unknown default:
                MediumWidgetView(articles: entry.articles)
            }
        }
        .containerBackground(for: .widget) {
            ContainerBackgroundView()
        }
    }
}

// MARK: - Supporting Views

struct ContainerBackgroundView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            if colorScheme == .dark {
                // Deep dark premium background
                Color(red: 0.05, green: 0.06, blue: 0.11)
                
                // Subtle glowing gradient for modern premium look
                LinearGradient(
                    colors: [
                        Color.cyan.opacity(0.10),
                        Color.indigo.opacity(0.15),
                        Color.clear
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            } else {
                // Fresh light premium background (matches light app icon)
                Color(red: 0.94, green: 0.97, blue: 0.95)
                
                // Soft minty gradient for light mode
                LinearGradient(
                    colors: [
                        Color.green.opacity(0.08),
                        Color.cyan.opacity(0.05),
                        Color.clear
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            }
        }
    }
}

/// Small Widget Layout: Displays one key featured article.
struct SmallWidgetView: View {
    let article: Article?
    
    var body: some View {
        if let article = article {
            VStack(alignment: .leading, spacing: 6) {
                // Header (App Icon / Mini Name)
                HStack(spacing: 5) {
                    Image("AppIconImage")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                    Text("WellNews")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary.opacity(0.9))
                    Spacer()
                }
                
                Spacer()
                
                // Category badge
                HStack(spacing: 3) {
                    Image(systemName: categoryIconName(for: article.category))
                        .font(.system(size: 8))
                    Text(article.category?.displayName ?? String(localized: "健康"))
                        .font(.system(size: 8, weight: .bold))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(categoryColor(for: article.category).opacity(0.15))
                .foregroundColor(categoryColor(for: article.category))
                .clipShape(Capsule())
                
                // Article Title
                Text(article.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Footer
                HStack {
                    Text(article.source)
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    Spacer()
                    if let score = article.relevancePercentage {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.amber)
                            Text("\(score)%")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.amber)
                        }
                    }
                }
            }
            .widgetURL(URL(string: "wellnews://article?id=\(article.id.uuidString)")!)
        } else {
            EmptyWidgetView()
        }
    }
}

/// Medium Widget Layout: Displays header and list of 2 articles.
struct MediumWidgetView: View {
    let articles: [Article]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Widget Header
            HStack(spacing: 6) {
                Image("AppIconImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                Text("WellNews")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
                Text("健康ピックアップ")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.bottom, 2)
            
            if articles.isEmpty {
                Spacer()
                Text("ニュースがありません")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(articles.prefix(2))) { article in
                        ArticleRowView(article: article, compact: true)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// Large Widget Layout: Displays header and list of 5 articles.
struct LargeWidgetView: View {
    let articles: [Article]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Widget Header
            HStack(spacing: 8) {
                Image("AppIconImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))
                VStack(alignment: .leading, spacing: 0) {
                    Text("WellNews")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                    Text("本日の健康おすすめトピック")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.bottom, 2)
            
            if articles.isEmpty {
                Spacer()
                Text("ニュースがありません")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(articles.prefix(5))) { article in
                        ArticleRowView(article: article, compact: false)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// Extra Large Widget Layout: Split dashboard layout displaying one large featured article and a list of 4 articles.
struct ExtraLargeWidgetView: View {
    let articles: [Article]
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            // Left Column: Featured article
            if let featured = articles.first {
                Link(destination: URL(string: "wellnews://article?id=\(featured.id.uuidString)")!) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("注目記事")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.cyan.opacity(0.15))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.cyan.opacity(0.2), lineWidth: 0.5)
                                )
                            
                            Spacer()
                            
                            if let score = featured.relevancePercentage {
                                HStack(spacing: 3) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 9))
                                        .foregroundColor(.amber)
                                    Text("おすすめ度 \(score)%")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.amber)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.amber.opacity(0.12))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.amber.opacity(0.2), lineWidth: 0.5)
                                )
                            }
                        }
                        
                        if let category = featured.category {
                            HStack(spacing: 4) {
                                Image(systemName: category.iconName)
                                    .font(.system(size: 10))
                                Text(category.displayName)
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(categoryColor(for: category).opacity(0.15))
                            .foregroundColor(categoryColor(for: category))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(categoryColor(for: category).opacity(0.25), lineWidth: 0.5)
                            )
                        }
                        
                        Text(featured.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                        
                        let displaySummary = featured.aiSummary ?? featured.description
                        if let summary = displaySummary {
                            Text(summary)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(4)
                                .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                        
                        HStack {
                            Text(featured.source)
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                            Spacer()
                            Text(featured.relativeDate)
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .background(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 0.5)
                    )
                }
            } else {
                EmptyWidgetView()
            }
            
            // Right Column: List of next 4 articles
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.cyan)
                    Text("最新健康トピックス")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                }
                .padding(.bottom, 4)
                
                if articles.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(articles.dropFirst().prefix(4))) { article in
                            ArticleRowView(article: article, compact: false)
                        }
                    }
                    Spacer(minLength: 0)
                } else {
                    Spacer()
                    Text("他の記事はありません")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                }
            }
            .frame(width: 320)
        }
    }
}

/// Row view for rendering each article inside lists.
struct ArticleRowView: View {
    let article: Article
    let compact: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Link(destination: URL(string: "wellnews://article?id=\(article.id.uuidString)")!) {
            HStack(spacing: 10) {
                // Category Icon with subtle border
                categoryIcon(for: article.category)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(categoryColor(for: article.category).opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(categoryColor(for: article.category).opacity(0.2), lineWidth: 0.5)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(article.title)
                        .font(.system(size: compact ? 12 : 13, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(compact ? 1 : 2)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 6) {
                        Text(article.source)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Text("•")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text(article.relativeDate)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer(minLength: 8)
                
                // Score Star Badge
                if let score = article.relevancePercentage {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.amber)
                        Text("\(score)%")
                            .font(.system(size: compact ? 9 : 10, weight: .bold))
                            .foregroundColor(.amber)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.amber.opacity(0.10))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.amber.opacity(0.15), lineWidth: 0.5)
                    )
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.05), lineWidth: 0.5)
            )
        }
    }
    
    private func categoryIcon(for category: ArticleCategory?) -> some View {
        Image(systemName: categoryIconName(for: category))
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(categoryColor(for: category))
    }
}

/// Fallback view for empty state.
struct EmptyWidgetView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "newspaper")
                .font(.title)
                .foregroundColor(.gray)
            Text("ニュースがありません")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Color & Style Helpers

extension Color {
    static let amber = Color(red: 1.0, green: 0.75, blue: 0.0)
}

func categoryColor(for category: ArticleCategory?) -> Color {
    switch category {
    case .exercise: return .blue
    case .diet: return .orange
    case .sleep: return .purple
    case .mentalCare: return .green
    case .other, .none: return .cyan
    }
}

func categoryIconName(for category: ArticleCategory?) -> String {
    return category?.iconName ?? "newspaper"
}

// MARK: - Widget Configuration Entry Point

@main
struct WellNewsWidget: Widget {
    let kind: String = "WellNewsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WellNewsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("WellNews")
        .description("最新の健康ニュースとお勧め度をホーム画面で確認。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

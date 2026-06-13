//
//  MainTabView.swift
//  WellNews
//
//  アプリ全体の主要なナビゲーションを管理するタブビュー
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .feed
    @ObservedObject private var speechManager = SpeechManager.shared
    @State private var selectedArticleForDetail: Article?
    
    enum Tab {
        case feed
        case bookmarks
        case settings
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Label("ニュース", systemImage: "newspaper")
                    }
                    .tag(Tab.feed)
                
                BookmarkListView()
                    .tabItem {
                        Label("ブックマーク", systemImage: "bookmark")
                    }
                    .tag(Tab.bookmarks)
                
                SettingsView()
                    .tabItem {
                        Label("設定", systemImage: "gearshape")
                    }
                    .tag(Tab.settings)
            }
            
            // 音声再生中の場合、フローティング再生バーを表示（タブバーの上に重ねる）
            if speechManager.currentArticle != nil {
                FloatingAudioPlayerBar(onTapGesture: {
                    selectedArticleForDetail = speechManager.currentArticle
                })
                .padding(.bottom, 56) // タブバーの上に配置するためのマージン
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $selectedArticleForDetail) { article in
            NavigationStack {
                ArticleDetailView(article: article)
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }
    
    private var isEnglishUI: Bool {
        let lang = Bundle.main.preferredLocalizations.first ?? "en"
        return lang.hasPrefix("en")
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "wellnews" else { return }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              components.host == "article",
              let queryItems = components.queryItems,
              let idString = queryItems.first(where: { $0.name == "id" })?.value,
              let uuid = UUID(uuidString: idString) else {
            return
        }
        
        let loadedArticles = ArticleFetchService.shared.articles
        if let article = loadedArticles.first(where: { $0.id == uuid }) {
            self.selectedArticleForDetail = article
        } else {
            let cacheKey = isEnglishUI ? "cachedArticles_en" : "cachedArticles_ja"
            let suiteName = "group.jp.junya.WellNews"
            if let sharedDefaults = UserDefaults(suiteName: suiteName),
               let data = sharedDefaults.data(forKey: cacheKey),
               let articles = try? JSONDecoder().decode([Article].self, from: data),
               let article = articles.first(where: { $0.id == uuid }) {
                self.selectedArticleForDetail = article
            }
        }
    }
}

#Preview {
    MainTabView()
}


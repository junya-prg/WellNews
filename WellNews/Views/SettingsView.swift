//
//  SettingsView.swift
//  WellNews
//
//  設定画面 - 追跡キーワード、関心カテゴリ、およびウェルネス統計ダッシュボード
//

import SwiftUI
import AVFoundation

struct SettingsView: View {
    @State private var newKeyword = ""
    @State private var interestedCategories: [ArticleCategory] = []
    @State private var summaryLength: SummaryLength = .medium
    
    @State private var speechSpeed: Float = 1.2
    @State private var selectedVoiceName: String = ""
    
    @State private var showPremiumStore = false
    @State private var showTipJar = false
    
    @ObservedObject private var fetchService = ArticleFetchService.shared
    
    @MainActor
    private var tracker: WellNewsTracker {
        WellNewsTracker.shared
    }
    
    private let interestedCategoriesKey = "wellnews.interestedCategories"
    
    var body: some View {
        NavigationStack {
            Form {
                // セクション1: ウェルネス統計
                Section(header: Text("ウェルネス統計")) {
                    HStack(spacing: 16) {
                        StatCard(
                            title: String(localized: "既読記事数"),
                            value: "\(tracker.totalReadCount)",
                            icon: "checkmark.circle.fill",
                            color: .green,
                            gradient: Gradient(colors: [Color.green.opacity(0.12), Color.green.opacity(0.02)])
                        )
                        
                        StatCard(
                            title: String(localized: "ブックマーク"),
                            value: "\(tracker.totalBookmarkCount)",
                            icon: "bookmark.fill",
                            color: .yellow,
                            gradient: Gradient(colors: [Color.yellow.opacity(0.12), Color.yellow.opacity(0.02)])
                        )
                    }
                    .padding(.vertical, 4)
                }
                
                // セクション: プレミアム & 支援
                Section(header: Text("プレミアム & 支援")) {
                    Button(action: { showPremiumStore = true }) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.yellow.opacity(0.12))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 14))
                            }
                            Text("Premiumプラン")
                                .foregroundColor(.primary)
                            Spacer()
                            if StoreManager.shared.isPremium {
                                Text("有効")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Button(action: { showTipJar = true }) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.pink.opacity(0.12))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.pink)
                                    .font(.system(size: 14))
                            }
                            Text("開発者を支援する")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // セクション2: 健康追跡キーワード
                Section(header: Text("健康追跡キーワード"), footer: Text("スイッチをオフにすると、そのキーワードに関する検索と記事の取得を一時的に無効化できます。")) {
                    HStack {
                        TextField("新しいキーワード (例: ヨガ)", text: $newKeyword)
                            .submitLabel(.done)
                            .onSubmit {
                                addKeyword()
                            }
                        
                        Button(action: addKeyword) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .disabled(newKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    
                    if fetchService.keywords.isEmpty {
                        Text("キーワードが登録されていません。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(fetchService.keywords) { keyword in
                            HStack {
                                Toggle(isOn: Binding(
                                    get: { keyword.isEnabled },
                                    set: { _ in
                                        fetchService.toggleKeyword(keyword)
                                        fetchService.clearCache()
                                    }
                                )) {
                                    Text(keyword.name)
                                        .font(.body)
                                }
                                .toggleStyle(SwitchToggleStyle(tint: .green))
                                
                                Spacer()
                                    .frame(width: 20)
                                
                                Button(action: {
                                    withAnimation {
                                        fetchService.removeKeyword(keyword)
                                        fetchService.clearCache()
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                // セクション: ニュース配信元 (RSS)
                Section(header: Text("ニュース配信元 (RSS)"), footer: Text("チェックを入れた配信元から健康ニュースを取得します。すべてオフにすることはできません。")) {
                    ForEach(RSSSource.allCases) { source in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                HStack(spacing: 12) {
                                    Image(systemName: source.iconName)
                                        .font(.title3)
                                        .foregroundColor(sourceColor(for: source))
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(source.displayName)
                                            .font(.body)
                                            .fontWeight(.semibold)
                                        
                                        if let url = source.officialURL {
                                            Link(destination: url) {
                                                HStack(spacing: 2) {
                                                    Text("公式サイト")
                                                    Image(systemName: "arrow.up.forward.app")
                                                }
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: Binding(
                                    get: { fetchService.activeRSSSources.contains(source) },
                                    set: { isEnabled in
                                        withAnimation {
                                            fetchService.toggleRSSSource(source, enabled: isEnabled)
                                            fetchService.clearCache()
                                        }
                                    }
                                ))
                                .toggleStyle(SwitchToggleStyle(tint: sourceColor(for: source)))
                                .disabled(fetchService.activeRSSSources.count == 1 && fetchService.activeRSSSources.contains(source))
                            }
                            
                            Text(source.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 36)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // セクション3: 特に関心のあるカテゴリ
                Section(header: Text("関心のあるカテゴリ"), footer: Text("選択したカテゴリの記事がフィードで優先的におすすめされます（高スコア判定）。")) {
                    ForEach(ArticleCategory.allCases) { category in
                        Toggle(isOn: Binding(
                            get: { interestedCategories.contains(category) },
                            set: { isSelected in
                                if isSelected {
                                    if !interestedCategories.contains(category) {
                                        interestedCategories.append(category)
                                    }
                                } else {
                                    interestedCategories.removeAll(where: { $0 == category })
                                }
                                saveInterestedCategories()
                            }
                        )) {
                            HStack(spacing: 12) {
                                Image(systemName: category.iconName)
                                    .foregroundColor(categoryColor(for: category))
                                Text(category.displayName)
                            }
                        }
                    }
                }
                                // セクション4: AI要約設定
                Section(header: Text("AI要約設定"), footer: Text("要約の長さを変更した場合、新しく記事を取得するか、記事詳細で「AI要約を再生成」を実行すると適用されます。")) {
                    Picker("要約の長さ", selection: $summaryLength) {
                        ForEach(SummaryLength.allCases) { length in
                            Text(length.displayName).tag(length)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: summaryLength) { newValue in
                        UserDefaults.standard.set(newValue.rawValue, forKey: "wellnews.summaryLength")
                    }
                }
                
                // セクション5: 音声読み上げ設定
                Section(header: Text("音声読み上げ設定"), footer: Text("基本速度や声の種類を変更できます。日本語の高品質なSiri音声がインストールされている場合、ここに表示されます。")) {
                    Picker("基本速度", selection: $speechSpeed) {
                        Text("0.8x").tag(Float(0.8))
                        Text("1.0x").tag(Float(1.0))
                        Text("1.2x (推奨)").tag(Float(1.2))
                        Text("1.5x").tag(Float(1.5))
                        Text("2.0x").tag(Float(2.0))
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: speechSpeed) { newValue in
                        SpeechManager.shared.setSpeed(newValue)
                    }
                    
                    let availableVoices = SpeechManager.shared.getAvailableVoices()
                    if !availableVoices.isEmpty {
                        Picker("声の種類", selection: $selectedVoiceName) {
                            Text("システムデフォルト").tag("")
                            ForEach(availableVoices, id: \.name) { voice in
                                Text(voice.name).tag(voice.name)
                            }
                        }
                        .onChange(of: selectedVoiceName) { newValue in
                            SpeechManager.shared.setSelectedVoice(name: newValue)
                        }
                    }
                }
            }
            .navigationTitle("設定")
            .onAppear {
                loadInterestedCategories()
                let savedLength = UserDefaults.standard.string(forKey: "wellnews.summaryLength") ?? "medium"
                self.summaryLength = SummaryLength(rawValue: savedLength) ?? .medium
                
                self.speechSpeed = SpeechManager.shared.speechSpeed
                self.selectedVoiceName = SpeechManager.shared.getSelectedVoiceName() ?? ""
            }
            .sheet(isPresented: $showPremiumStore) {
                PremiumStoreView()
            }
            .sheet(isPresented: $showTipJar) {
                TipJarView()
            }
        }
    }
    
    private func addKeyword() {
        let trimmed = newKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let success = fetchService.addKeyword(trimmed)
        if !success {
            showPremiumStore = true
        } else {
            newKeyword = ""
            fetchService.clearCache()
        }
    }
    
    private func loadInterestedCategories() {
        let savedCats = UserDefaults.standard.stringArray(forKey: interestedCategoriesKey) ?? []
        let loaded = savedCats.compactMap { ArticleCategory(rawValue: $0) }
        
        if loaded.isEmpty {
            self.interestedCategories = ArticleCategory.allCases
        } else {
            self.interestedCategories = loaded
        }
    }
    
    private func saveInterestedCategories() {
        let rawValues = interestedCategories.map { $0.rawValue }
        UserDefaults.standard.set(rawValues, forKey: interestedCategoriesKey)
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
    
    private func sourceColor(for source: RSSSource) -> Color {
        switch source {
        case .googleNews: return .blue
        case .hatenaBookmark: return .cyan
        case .note: return .green
        case .prTimes: return .indigo
        }
    }
}

// MARK: - 統計カードコンポーネント

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let gradient: Gradient
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(color)
                }
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(
            LinearGradient(gradient: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
    }
}

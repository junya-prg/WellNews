//
//  HomeViewModel.swift
//  WellNews
//
//  メイン画面のViewModel
//

import Foundation
import SwiftUI
import Combine
import os

private let logger = Logger(subsystem: "jp.junya.WellNews", category: "HomeViewModel")

@MainActor
class HomeViewModel: ObservableObject {
    /// 取得した記事一覧
    @Published var articles: [Article] = []
    
    /// 読み込み中かどうか
    @Published var isLoading = false
    
    /// AI処理中かどうか
    @Published var isProcessingAI = false
    
    /// AIが実際に利用可能かどうか
    @Published var isAIActuallyAvailable: Bool?
    
    /// エラーメッセージ
    @Published var errorMessage: String?
    
    /// 選択中のカテゴリフィルター（nilの場合は全て表示）
    @Published var selectedCategory: ArticleCategory? = nil
    
    /// 記事取得サービス
    let articleFetchService = ArticleFetchService.shared
    
    /// AI処理サービス
    private let aiService: FoundationModelsService
    
    /// 進行中の AI 処理タスク
    private var aiProcessingTask: Task<Void, Never>?
    
    /// フィルター済みの記事一覧
    var filteredArticles: [Article] {
        guard let category = selectedCategory else {
            return articles
        }
        return articles.filter { $0.category == category }
    }
    
    /// 関心のあるカテゴリのUserDefaults保存用キー
    private let interestedCategoriesKey = "wellnews.interestedCategories"
    
    init() {
        self.aiService = FoundationModelsService()
    }
    
    /// AI機能が利用可能かどうか
    var isAIAvailable: Bool {
        aiService.isAvailable
    }
    
    /// ユーザープロファイルを構築
    func getUserHealthProfile() -> UserHealthProfile {
        let savedCats = UserDefaults.standard.stringArray(forKey: interestedCategoriesKey) ?? []
        let interestedCats = savedCats.compactMap { ArticleCategory(rawValue: $0) }
        
        let finalCats = interestedCats.isEmpty ? ArticleCategory.allCases : interestedCats
        
        return UserHealthProfile(
            interestedCategories: finalCats,
            keywords: articleFetchService.keywords.filter { $0.isEnabled }.map { $0.name }
        )
    }
    
    /// ユーザーの関心カテゴリを保存
    func saveInterestedCategories(_ categories: [ArticleCategory]) {
        let rawValues = categories.map { $0.rawValue }
        UserDefaults.standard.set(rawValues, forKey: interestedCategoriesKey)
    }
    
    /// 記事を取得してAI処理を開始
    func loadArticles() async {
        logger.notice("📱 loadArticles開始")
        isLoading = true
        errorMessage = nil
        
        await articleFetchService.fetchArticles()
        
        var fetchedArticles = articleFetchService.articles
        if fetchedArticles.isEmpty {
            fetchedArticles = Article.sampleArticles
        }
        
        let profile = getUserHealthProfile()
        
        articles = fetchedArticles
        isLoading = false
        logger.notice("📱 記事を即座に表示: \(self.articles.count)件")
        
        startAIProcessingIfNeeded(profile: profile)
    }
    
    /// AI 処理を独立 Task として開始
    private func startAIProcessingIfNeeded(profile: UserHealthProfile) {
        if let existing = aiProcessingTask, !existing.isCancelled {
            logger.notice("📱 AI処理は既に実行中のためスキップ")
            return
        }

        let targetArticleIDs = articles.map { $0.id }

        aiProcessingTask = Task { [weak self] in
            guard let self else { return }
            await self.runAIProcessingLoop(for: targetArticleIDs, profile: profile)
        }
    }

    /// AI 処理の非同期ループ
    private func runAIProcessingLoop(for targetArticleIDs: [UUID], profile: UserHealthProfile) async {
        logger.notice("📱 AI準備中...")
        await aiService.ensureAIReady()
        isAIActuallyAvailable = aiService.isActuallyAvailable
        logger.notice("📱 AI利用可能: \(self.isAIActuallyAvailable == true ? "はい" : "いいえ")")

        logger.notice("📱 AI処理開始...")
        isProcessingAI = true
        defer { isProcessingAI = false }

        for (index, articleID) in targetArticleIDs.enumerated() {
            guard let currentIndex = articles.firstIndex(where: { $0.id == articleID }) else {
                continue
            }
            
            let currentArticle = articles[currentIndex]
            if currentArticle.isAIProcessed {
                continue
            }

            logger.notice("📱 記事 \(index + 1)/\(targetArticleIDs.count) を処理中...")
            
            let processedArticle = await aiService.processOneArticle(currentArticle, userProfile: profile)
            
            if let targetIndex = articles.firstIndex(where: { $0.id == processedArticle.id }) {
                articles[targetIndex] = processedArticle
            }
            
            if Task.isCancelled {
                logger.notice("📱 AI処理がキャンセルされました（中断）")
                return
            }
        }

        articles.sort { ($0.relevanceScore ?? 0) > ($1.relevanceScore ?? 0) }
        logger.notice("📱 AI処理完了・ソート済み: \(self.articles.count)件")
    }

    /// 進行中の AI 処理をキャンセル
    func cancelAIProcessing() {
        aiProcessingTask?.cancel()
        aiProcessingTask = nil
        isProcessingAI = false
    }

    /// 必要であればAI処理を再開
    func resumeAIProcessingIfNeeded() {
        let hasUnprocessed = articles.contains(where: { !$0.isAIProcessed })
        guard hasUnprocessed else { return }
        
        let profile = getUserHealthProfile()
        startAIProcessingIfNeeded(profile: profile)
    }
    
    /// 記事を強制リフレッシュ
    func refreshArticles() async {
        cancelAIProcessing()
        await articleFetchService.refreshArticles()
        await loadArticles()
    }
    
    /// 特定の記事のAI処理を手動で再実行
    func reprocessArticle(_ article: Article) async {
        guard let index = articles.firstIndex(where: { $0.id == article.id }) else {
            return
        }
        
        isProcessingAI = true
        let profile = getUserHealthProfile()
        var updatedArticle = article
        
        updatedArticle.aiSummary = await aiService.summarize(article: article)
        updatedArticle.category = await aiService.categorize(article: article)
        updatedArticle.relevanceScore = await aiService.calculateRelevance(article: article, userProfile: profile)
        updatedArticle.isAIProcessed = true
        
        articles[index] = updatedArticle
        isProcessingAI = false
    }
    
    /// カテゴリフィルターを設定
    func selectCategory(_ category: ArticleCategory?) {
        selectedCategory = category
    }
}

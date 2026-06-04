//
//  WellNewsTracker.swift
//  WellNews
//
//  ニュースの既読・お気に入り管理を行うサービス
//  UserDefaults に永続化することで、アプリ再起動後も状態を復元する
//

import Foundation
import SwiftUI
import os

private let logger = Logger(subsystem: "jp.junya.WellNews", category: "WellNewsTracker")

// MARK: - ウェルネストラッカー

/// 既読・お気に入り・ウェルネス統計を管理する
@available(iOS 17.0, macOS 14.0, *)
@Observable
@MainActor
final class WellNewsTracker {
    /// 共有インスタンス
    static let shared = WellNewsTracker()
    
    /// 既読記事の ID 集合
    private(set) var readArticleIDs: Set<UUID> = []

    /// お気に入り記事の ID 集合 (判定用)
    private(set) var bookmarkedArticleIDs: Set<UUID> = []
    
    /// お気に入り記事の配列 (実体データ)
    private(set) var bookmarkedArticles: [Article] = []

    /// 読んだ記事のカテゴリ集合
    private(set) var readCategories: Set<ArticleCategory> = []

    // MARK: - UserDefaults キー

    private let readArticleIDsKey = "wellnews.readArticleIDs"
    private let bookmarkedArticleIDsKey = "wellnews.bookmarkedArticleIDs"
    private let bookmarkedArticlesKey = "wellnews.bookmarkedArticles"
    private let readCategoriesKey = "wellnews.readCategories"

    // MARK: - 初期化

    private init() {
        load()
    }

    // MARK: - 集計値

    /// 既読記事数
    var totalReadCount: Int {
        readArticleIDs.count
    }

    /// お気に入り数
    var totalBookmarkCount: Int {
        bookmarkedArticles.count
    }

    /// カテゴリ網羅率（読んだカテゴリ数 / 全カテゴリ数）
    var categoryCoverageRatio: Double {
        let total = Double(ArticleCategory.allCases.count)
        guard total > 0 else { return 0 }
        return Double(readCategories.count) / total
    }

    // MARK: - 既読操作

    /// 既読かどうか
    func isRead(_ article: Article) -> Bool {
        readArticleIDs.contains(article.id)
    }

    /// 既読としてマーク
    func markAsRead(_ article: Article) {
        guard !readArticleIDs.contains(article.id) else {
            if let category = article.category {
                if !readCategories.contains(category) {
                    readCategories.insert(category)
                    persistReadCategories()
                }
            }
            return
        }

        readArticleIDs.insert(article.id)
        persistReadArticleIDs()

        if let category = article.category, !readCategories.contains(category) {
            readCategories.insert(category)
            persistReadCategories()
        }
    }

    // MARK: - お気に入り操作

    /// お気に入りかどうか
    func isBookmarked(_ article: Article) -> Bool {
        bookmarkedArticleIDs.contains(article.id)
    }

    /// お気に入りトグル
    func toggleBookmark(_ article: Article) {
        if bookmarkedArticleIDs.contains(article.id) {
            bookmarkedArticleIDs.remove(article.id)
            bookmarkedArticles.removeAll(where: { $0.id == article.id })
        } else {
            bookmarkedArticleIDs.insert(article.id)
            bookmarkedArticles.insert(article, at: 0)
        }
        persistBookmarkedArticleIDs()
        persistBookmarkedArticles()
    }

    /// お気に入り記事のデータを更新する
    func updateBookmarkedArticle(_ article: Article) {
        if let index = bookmarkedArticles.firstIndex(where: { $0.id == article.id }) {
            bookmarkedArticles[index] = article
            persistBookmarkedArticles()
        }
    }

    // MARK: - 永続化（読み込み）

    private func load() {
        readArticleIDs = loadUUIDSet(forKey: readArticleIDsKey)
        bookmarkedArticleIDs = loadUUIDSet(forKey: bookmarkedArticleIDsKey)
        bookmarkedArticles = loadBookmarkedArticles()
        readCategories = loadCategorySet(forKey: readCategoriesKey)
        logger.notice("📊 WellNewsTracker 復元: 既読\(self.readArticleIDs.count)件 / お気に入り\(self.bookmarkedArticles.count)件 / 網羅\(self.readCategories.count)カテゴリ")
    }

    private func loadUUIDSet(forKey key: String) -> Set<UUID> {
        guard let data = UserDefaults.standard.data(forKey: key),
              let array = try? JSONDecoder().decode([UUID].self, from: data) else {
            return []
        }
        return Set(array)
    }

    private func loadBookmarkedArticles() -> [Article] {
        guard let data = UserDefaults.standard.data(forKey: bookmarkedArticlesKey),
              let array = try? JSONDecoder().decode([Article].self, from: data) else {
            return []
        }
        return array
    }

    private func loadCategorySet(forKey key: String) -> Set<ArticleCategory> {
        guard let data = UserDefaults.standard.data(forKey: key),
              let array = try? JSONDecoder().decode([ArticleCategory].self, from: data) else {
            return []
        }
        return Set(array)
    }

    // MARK: - 永続化（保存）

    private func persistReadArticleIDs() {
        let array = Array(readArticleIDs)
        if let data = try? JSONEncoder().encode(array) {
            UserDefaults.standard.set(data, forKey: readArticleIDsKey)
        }
    }

    private func persistBookmarkedArticleIDs() {
        let array = Array(bookmarkedArticleIDs)
        if let data = try? JSONEncoder().encode(array) {
            UserDefaults.standard.set(data, forKey: bookmarkedArticleIDsKey)
        }
    }

    private func persistBookmarkedArticles() {
        if let data = try? JSONEncoder().encode(bookmarkedArticles) {
            UserDefaults.standard.set(data, forKey: bookmarkedArticlesKey)
        }
    }

    private func persistReadCategories() {
        let array = Array(readCategories)
        if let data = try? JSONEncoder().encode(array) {
            UserDefaults.standard.set(data, forKey: readCategoriesKey)
        }
    }
}

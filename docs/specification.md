# WellNews - 詳細仕様書

## 1. アプリ概要
**WellNews** は、利用者が関心を持つ健康関連のキーワードを設定し、それにマッチする最新のニュース記事をRSS（Google News等）から自動取得した上で、iOSのオンデバイスAI（Apple Intelligence）を用いて「要約」「カテゴリ分類」「おすすめ度算出」を行い、パーソナライズされたニュースフィードを提供するiOSアプリケーションです。

AI非対応のデバイスやシミュレータ環境においても、ローカルのキーワードマッチングおよび優先度算出によるフォールバック処理を行い、快適に動作するユニバーサルな設計を採用しています。

---

## 2. 動作要件・技術スタック
* **対応OS**: iOS 26.0+ (オンデバイスAI使用時。非対応環境ではフォールバック機能が動作)
* **開発言語**: Swift
* **UIフレームワーク**: SwiftUI
* **AI機能**: `FoundationModels` (Apple Intelligence オンデバイス言語モデル)
* **データ保存**: `UserDefaults` (簡易設定・既読キャッシュ用)

---

## 3. ディレクトリ構成
```
WellNews/
├── docs/
│   └── specification.md       # 本仕様書
├── WellNews/
│   ├── WellNewsApp.swift      # アプリのエントリーポイント
│   ├── Models/
│   │   └── Article.swift      # 記事データモデル & カテゴリ定義
│   ├── Services/
│   │   ├── ArticleFetchService.swift  # RSSニュース取得サービス
│   │   ├── FoundationModelsService.swift # AI処理サービス (LanguageModelSession)
│   │   └── WellNewsTracker.swift      # 既読・お気に入り・スコア管理
│   ├── ViewModels/
│   │   └── HomeViewModel.swift        # メイン画面ロジック
│   └── Views/
│       ├── MainTabView.swift          # タブナビゲーション
│       ├── HomeView.swift             # メインニュースフィード画面
│       ├── ArticleDetailView.swift    # 記事詳細（Webビュー）画面
│       ├── BookmarkListView.swift     # ブックマーク一覧画面
│       └── SettingsView.swift         # 設定画面
└── README.md
```

---

## 4. 主要コンポーネント詳細

### 4.1. データモデル (`Models/`)
* **`Article`**:
  * `id`: UUID (タイトルとURLから決定論的に生成されるユニークID)
  * `title`: String (記事タイトル)
  * `source`: String (提供元メディア名)
  * `publishedAt`: Date (公開日時)
  * `url`: URL (記事のオリジナルリンク)
  * `description`: String? (RSSから取得した本文プレビュー)
  * `aiSummary`: String? (AIが生成した日本語の要約)
  * `category`: ArticleCategory (判定したカテゴリ)
  * `relevanceScore`: Double? (ユーザープロファイルに基づいたおすすめ度: 0.0 ~ 1.0)
  * `isAIProcessed`: Bool (AI処理が完了しているか)

* **`ArticleCategory`**:
  * `.exercise` (運動・フィットネス)
  * `.diet` (食事・栄養)
  * `.sleep` (睡眠・休養)
  * `.mentalCare` (メンタルケア)
  * `.other` (その他)

### 4.2. サービス (`Services/`)

* **`ArticleFetchService`**:
  * Google News RSS (`https://news.google.com/rss/search`) および はてなブックマーク を利用し、登録されたキーワード（複数）でOR検索をかけ、記事を一括取得。
  * シングルトンパターン (`.shared`) でインスタンス化し、アプリ全体で同じキーワードリストを管理。
  * 初期設定キーワード例: `睡眠改善`, `糖質制限`, `筋トレ`, `サウナ健康`, `メンタルケア`, `マインドフルネス`

* **`FoundationModelsService`**:
  * **対応機種**: iOS 26+ の `LanguageModelSession` を使用。
    * 要約: 2〜3文の日本語で記事を要約。
    * カテゴリ分類: 記事テキストからカテゴリを特定。
    * おすすめ度計算: ユーザープロフィール（関心カテゴリ、キーワード）と照らし合わせ、0〜100点（0.0〜1.0）でおすすめ度を算出。
  * **非対応機種 (フォールバック)**:
    * カテゴリ分類: タイトルと本文からローカルキーワード検索によるルールベース分類。
    * 要約: RSSの `description` で代替。
    * おすすめ度: ユーザーの関心カテゴリやキーワードの一致数に基づきルールベースで算出。

* **`WellNewsTracker`**:
  * 既読記事のIDリストを管理。
  * お気に入り（ブックマーク）した記事のIDリストに加え、**`Article` オブジェクトの実体データ**もUserDefaultsにシリアライズ保存（RSSから記事が消えてもオフラインで永久に閲覧可能）。
  * 読んだ記事数に応じて「健康の苗木」レベルメーター（種、双葉、若木、大樹、伝説の大樹）がレベルアップするゲーミフィケーションを搭載。

### 4.3. UI / 画面構成 (`Views/`)
* **`MainTabView`**: タブの切り替えを制御。
* **`HomeView`**:
  * タイムライン形式のニュースフィード。
  * 各記事カードには、タイトル、メディア名、カテゴリ、おすすめ度（％表示）、要約を表示。
  * リフレッシュ、AIステータスランプ、レベルアップのお祝いポップアップを内包。
* **`ArticleDetailView`**:
  * 記事の詳細情報とAI要約を表示。
  * 元記事をSafariで開く機能、共有機能、ブックマークトグルの設置。
* **`BookmarkListView`**:
  * ブックマークされた記事のタイムライン表示。スワイプ削除によるブックマーク解除。
* **`SettingsView`**:
  * キーワードの追加・削除リスト、関心カテゴリの設定。
  * 既読数、ブックマーク数、カテゴリ網羅率を表示する「ウェルネスダッシュボード」セクション。

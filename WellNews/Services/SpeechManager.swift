//
//  SpeechManager.swift
//  WellNews
//
//  音声読み上げ（テキスト読み上げ）を管理するシングルトンサービス
//  ロック画面表示 (MediaPlayer) および実機バックグラウンド完全対応版
//

import Foundation
import AVFoundation
import Combine
import MediaPlayer
import UIKit

/// 音声読み上げ中の文のオフセット情報
struct SpokenSentenceOffset: Equatable {
    let text: String
    let range: NSRange
    let isTitle: Bool
    let sentenceIndex: Int // 要約内での文インデックス（タイトルは -1）
}

/// 音声読み上げサービス
@MainActor
class SpeechManager: NSObject, ObservableObject {
    /// 共有インスタンス
    static let shared = SpeechManager()
    
    /// 音声合成エンジン
    private let synthesizer = AVSpeechSynthesizer()
    
    /// 実機バックグラウンド再生・ロック画面表示用のダミー無音オーディオプレイヤー
    private var silentAudioPlayer: AVAudioPlayer?
    
    // MARK: - 再生状態
    
    /// 再生中かどうか
    @Published private(set) var isPlaying = false
    
    /// 一時停止中かどうか
    @Published private(set) var isPaused = false
    
    /// 現在再生中の記事
    @Published private(set) var currentArticle: Article?
    
    /// 再生速度 (0.8x 〜 2.0x, デフォルト 1.2x)
    @Published private(set) var speechSpeed: Float = 1.2
    
    /// 現在読み上げ中の文のインデックス
    @Published private(set) var currentSentenceIndex = -1
    
    /// 現在タイトルを読み上げ中かどうか
    @Published private(set) var isReadingTitle = false
    
    /// キュー（連続再生リスト）
    @Published private(set) var queue: [Article] = []
    
    /// 現在再生中のキューのインデックス
    @Published private(set) var queueIndex = 0
    
    /// ブリーフィング（連続再生）モードかどうか
    @Published private(set) var isBriefingMode = false
    
    /// 音声の言語（日本語固定）
    private let speechLanguage = "ja-JP"
    
    /// 再生速度の保存キー
    private let speedKey = "wellnews.speechSpeed"
    
    /// 音声名の保存キー
    private let voiceNameKey = "wellnews.speechVoiceName"
    
    // MARK: - 内部データ
    
    /// 現在再生しているテキスト全体の文の範囲リスト
    private var sentenceOffsets: [SpokenSentenceOffset] = []
    
    /// 読み上げるフルテキスト
    private var fullSpokenText = ""
    
    /// キャンセル・停止用のフラグ（デリゲート処理中の競合回避）
    private var isStoppingExplicitly = false
    
    override init() {
        super.init()
        synthesizer.delegate = self
        
        // 速度設定の読み込み
        let savedSpeed = UserDefaults.standard.float(forKey: speedKey)
        if savedSpeed > 0 {
            self.speechSpeed = savedSpeed
        } else {
            self.speechSpeed = 1.2
        }
        
        setupAudioSession()
        setupSilentAudioPlayer()
        setupRemoteCommandCenter()
        
        // ロック画面からのリモート操作イベント受信を開始
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }
    
    /// オーディオセッションの初期設定（バックグラウンド再生・マナーモード対応）
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // optionsを [] にすることで、このアプリをシステムの主要な音楽プレイヤーとしてOSに認識させ、ロック画面にコントロールを強制表示します
            try session.setCategory(.playback, mode: .default, options: [])
        } catch {
            print("🔊 AudioSession設定エラー: \(error)")
        }
    }
    
    private func activateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("🔊 AudioSessionアクティブ化エラー: \(error)")
        }
    }
    
    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("🔊 AudioSession非アクティブ化エラー: \(error)")
        }
    }
    
    // MARK: - 無音再生によるバックグラウンド維持対策 (AVAudioPlayer)
    
    /// バックグラウンドで再生を維持するための無音 WAV プレイヤーをセットアップ
    private func setupSilentAudioPlayer() {
        guard let silentURL = generateSilentWavFile() else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: silentURL)
            player.numberOfLoops = -1 // 無限ループ
            player.volume = 0.01      // 極小音量（ほぼ無音ですが、OSの再生判定を維持します）
            player.prepareToPlay()
            self.silentAudioPlayer = player
        } catch {
            print("🔊 無音オーディオプレイヤーの初期化失敗: \(error)")
        }
    }
    
    /// プログラム的に1秒間の無音 WAV ファイルを生成して一時ディレクトリに保存する
    private func generateSilentWavFile() -> URL? {
        let sampleRate = 8000
        let numChannels = 1
        let bitsPerSample = 16
        let durationSeconds = 1
        
        let bytesPerSample = bitsPerSample / 8
        let dataSize = sampleRate * numChannels * bytesPerSample * durationSeconds
        let fileSize = 44 + dataSize
        
        var header = Data()
        header.append("RIFF".data(using: .utf8)!)
        var temp32 = UInt32(fileSize - 8)
        header.append(Data(bytes: &temp32, count: 4))
        header.append("WAVE".data(using: .utf8)!)
        
        // fmt subchunk
        header.append("fmt ".data(using: .utf8)!)
        temp32 = 16
        header.append(Data(bytes: &temp32, count: 4))
        var temp16 = UInt16(1) // PCM format = 1
        header.append(Data(bytes: &temp16, count: 2))
        temp16 = UInt16(numChannels)
        header.append(Data(bytes: &temp16, count: 2))
        temp32 = UInt32(sampleRate)
        header.append(Data(bytes: &temp32, count: 4))
        temp32 = UInt32(sampleRate * numChannels * bytesPerSample)
        header.append(Data(bytes: &temp32, count: 4))
        temp16 = UInt16(numChannels * bytesPerSample)
        header.append(Data(bytes: &temp16, count: 2))
        temp16 = UInt16(bitsPerSample)
        header.append(Data(bytes: &temp16, count: 2))
        
        // data subchunk
        header.append("data".data(using: .utf8)!)
        temp32 = UInt32(dataSize)
        header.append(Data(bytes: &temp32, count: 4))
        
        // 無音データ（すべてゼロ）
        let silence = Data(repeating: 0, count: dataSize)
        var wavData = header
        wavData.append(silence)
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("silence.wav")
        do {
            try wavData.write(to: fileURL)
            return fileURL
        } catch {
            print("🔊 無音WAVファイル書き込み失敗: \(error)")
            return nil
        }
    }
    
    // MARK: - ロック画面・通知センター統合 (MediaPlayer)
    
    /// リモートコマンド（ロック画面やコントロールセンターの操作ボタン）の設定
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // 再生ボタン
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                self.resume()
            }
            return .success
        }
        
        // 一時停止ボタン
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                self.pause()
            }
            return .success
        }
        
        // 次の曲（記事）ボタン
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                if self.isBriefingMode {
                    self.skipNext()
                }
            }
            return .success
        }
        
        // 前の曲（記事）ボタン
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                if self.isBriefingMode {
                    self.skipPrevious()
                }
            }
            return .success
        }
    }
    
    /// ロック画面やコントロールセンターに表示するメディア情報を更新
    private func updateNowPlayingInfo() {
        guard let article = currentArticle else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var nowPlayingInfo = [String: Any]()
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = article.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = article.source
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = String(localized: "WellNews 健康ニュース")
        
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPaused ? 0.0 : Double(speechSpeed)
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = true
        
        // 画像サムネイルを非同期でダウンロードして設定
        if let imageUrl = article.imageUrl {
            Task {
                if let image = await fetchImage(from: imageUrl) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? nowPlayingInfo
                    currentInfo[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
                }
            }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func fetchImage(from url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
    
    // MARK: - 再生コントロール
    
    /// 特定の記事を読み上げる
    func play(article: Article) {
        if currentArticle?.id == article.id && isPaused {
            resume()
            return
        }
        
        stopPlaybackInternal()
        activateAudioSession()
        
        currentArticle = article
        isBriefingMode = false
        queue = []
        queueIndex = 0
        
        speakFrom(sentenceIndex: -1, isTitle: true)
        updateNowPlayingInfo()
    }
    
    /// 記事リストをブリーフィング再生（連続再生）する
    func playBriefing(articles: [Article]) {
        guard !articles.isEmpty else { return }
        
        stopPlaybackInternal()
        activateAudioSession()
        
        isBriefingMode = true
        
        // 無料ユーザーは最大5つまでに制限
        let isPremium = StoreManager.shared.isPremium
        if !isPremium {
            queue = Array(articles.prefix(5))
        } else {
            queue = articles
        }
        
        queueIndex = 0
        
        playBriefingCurrentArticle()
    }

    
    /// ブリーフィング内の現在のインデックスの記事を再生
    private func playBriefingCurrentArticle() {
        guard queueIndex < queue.count else {
            speakClosingBriefing()
            return
        }
        
        let article = queue[queueIndex]
        currentArticle = article
        
        speakFrom(sentenceIndex: -1, isTitle: true)
        updateNowPlayingInfo()
    }
    
    /// ブリーフィング終了時のアナウンス
    private func speakClosingBriefing() {
        currentArticle = nil
        isBriefingMode = false
        queue = []
        queueIndex = 0
        
        // 終わりの挨拶を単一発話として再生
        sentenceOffsets = []
        let closeText = "今日のウェルネスニュースは以上です。健康的な一日をお過ごしください。"
        let range = NSRange(location: 0, length: closeText.utf16.count)
        sentenceOffsets.append(SpokenSentenceOffset(text: closeText, range: range, isTitle: false, sentenceIndex: 0))
        fullSpokenText = closeText
        currentSentenceIndex = 0
        isReadingTitle = false
        
        speakCurrentUtterance()
        updateNowPlayingInfo()
    }
    
    /// 一時停止
    func pause() {
        guard isPlaying && !isPaused else { return }
        synthesizer.pauseSpeaking(at: .immediate)
        silentAudioPlayer?.pause()
        isPaused = true
        updateNowPlayingInfo()
    }
    
    /// 再開
    func resume() {
        guard isPlaying && isPaused else { return }
        synthesizer.continueSpeaking()
        silentAudioPlayer?.play()
        isPaused = false
        updateNowPlayingInfo()
    }
    
    /// 停止
    func stop() {
        stopPlaybackInternal()
        deactivateAudioSession()
    }
    
    private func stopPlaybackInternal() {
        isStoppingExplicitly = true
        synthesizer.stopSpeaking(at: .immediate)
        silentAudioPlayer?.stop()
        isPlaying = false
        isPaused = false
        currentArticle = nil
        sentenceOffsets = []
        fullSpokenText = ""
        currentSentenceIndex = -1
        isReadingTitle = false
        queue = []
        queueIndex = 0
        isBriefingMode = false
        isStoppingExplicitly = false
        updateNowPlayingInfo()
    }
    
    /// 次の記事へスキップ（ブリーフィング時のみ）
    func skipNext() {
        guard isBriefingMode else { return }
        synthesizer.stopSpeaking(at: .immediate)
        queueIndex += 1
        playBriefingCurrentArticle()
    }
    
    /// 前の記事へ戻る（ブリーフィング時のみ）
    func skipPrevious() {
        guard isBriefingMode else { return }
        if queueIndex > 0 {
            synthesizer.stopSpeaking(at: .immediate)
            queueIndex -= 1
            playBriefingCurrentArticle()
        }
    }
    
    // MARK: - 速度調整
    
    /// 再生速度を設定
    func setSpeed(_ speed: Float) {
        guard speed >= 0.8 && speed <= 2.0 else { return }
        self.speechSpeed = speed
        UserDefaults.standard.set(speed, forKey: speedKey)
        
        // 再生中の場合は、現在の文の位置から新しい速度で再生し直す（再生ストリームの維持）
        if isPlaying && !isPaused {
            let resumeIndex = currentSentenceIndex
            let resumeIsTitle = isReadingTitle
            
            isStoppingExplicitly = true
            synthesizer.stopSpeaking(at: .immediate)
            isStoppingExplicitly = false
            
            speakFrom(sentenceIndex: resumeIndex, isTitle: resumeIsTitle)
        }
        updateNowPlayingInfo()
    }
    
    /// 再生速度を次の値にサイクルする
    func cycleSpeed() {
        let speeds: [Float] = [0.8, 1.0, 1.2, 1.5, 2.0]
        let nextIndex = (speeds.firstIndex(of: speechSpeed) ?? 2) + 1
        let targetSpeed = speeds[nextIndex % speeds.count]
        setSpeed(targetSpeed)
    }
    
    // MARK: - 音声選択
    
    /// 利用可能な日本語音声リストを取得
    func getAvailableVoices() -> [AVSpeechSynthesisVoice] {
        return AVSpeechSynthesisVoice.speechVoices().filter { $0.language == speechLanguage }
    }
    
    /// 設定されている音声名を取得
    func getSelectedVoiceName() -> String? {
        return UserDefaults.standard.string(forKey: voiceNameKey)
    }
    
    /// 音声を設定
    func setSelectedVoice(name: String) {
        UserDefaults.standard.set(name, forKey: voiceNameKey)
        
        // 再生中の場合は現在の文から読み直し
        if isPlaying && !isPaused {
            let resumeIndex = currentSentenceIndex
            let resumeIsTitle = isReadingTitle
            
            isStoppingExplicitly = true
            synthesizer.stopSpeaking(at: .immediate)
            isStoppingExplicitly = false
            
            speakFrom(sentenceIndex: resumeIndex, isTitle: resumeIsTitle)
        }
        updateNowPlayingInfo()
    }
    
    // MARK: - ヘルパーメソッド
    
    /// 指定の文インデックスからテキストを構築して読み上げを開始（1本のUtteranceにまとめる）
    private func speakFrom(sentenceIndex: Int, isTitle: Bool) {
        guard let article = currentArticle else { return }
        
        sentenceOffsets = []
        var text = ""
        
        // 1. タイトル部分の追加（タイトルから再生する場合のみ）
        if isTitle {
            let prefix = isBriefingMode ? "第\(queueIndex + 1)位。" : ""
            let titleText = prefix + article.title + "。"
            let range = NSRange(location: 0, length: titleText.utf16.count)
            sentenceOffsets.append(SpokenSentenceOffset(text: titleText, range: range, isTitle: true, sentenceIndex: -1))
            text += titleText
            // タイトルと要約の間に少し長めのポーズを入れるため改行を追加
            text += "\n"
        }
        
        // 2. 要約部分の追加
        let sentences: [String]
        if let digest = article.summaryDigest {
            var formattedSentences: [String] = []
            formattedSentences.append(digest.headline)
            for (index, point) in digest.points.enumerated() {
                var pointText = ""
                if !point.label.isEmpty {
                    pointText += "ポイント\(index + 1)、\(point.label)。"
                }
                if !point.detail.isEmpty {
                    pointText += point.detail
                }
                if !pointText.isEmpty {
                    formattedSentences.append(pointText)
                }
            }
            if !digest.actionTip.isEmpty {
                formattedSentences.append("今日からできるアクション。\(digest.actionTip)")
            }
            sentences = formattedSentences
        } else {
            let summary = article.aiSummary ?? article.description ?? ""
            sentences = SpeechManager.splitIntoSentences(summary)
        }
        
        // 指定されたインデックス以降の文のみを連結
        let startIndex = isTitle ? 0 : max(0, sentenceIndex)
        
        for index in startIndex..<sentences.count {
            let sentence = sentences[index]
            let startLocation = text.utf16.count
            
            // 文の末尾に半角スペースを付与することで自然な間を設ける
            let sentenceText = sentence + " "
            let range = NSRange(location: startLocation, length: sentenceText.utf16.count)
            sentenceOffsets.append(SpokenSentenceOffset(text: sentence, range: range, isTitle: false, sentenceIndex: index))
            text += sentenceText
        }
        
        self.fullSpokenText = text
        self.currentSentenceIndex = sentenceIndex
        self.isReadingTitle = isTitle
        
        speakCurrentUtterance()
    }
    
    /// `fullSpokenText` を単一の `AVSpeechUtterance` として再生する
    private func speakCurrentUtterance() {
        guard !fullSpokenText.isEmpty else {
            handlePlaybackFinished()
            return
        }
        
        let utterance = AVSpeechUtterance(string: fullSpokenText)
        utterance.voice = selectVoice()
        
        // 再生速度
        let rate = AVSpeechUtteranceDefaultSpeechRate * speechSpeed
        utterance.rate = min(max(rate, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
        
        isPlaying = true
        isPaused = false
        
        // 無音オーディオプレイヤーをバックグラウンド再生の維持目的で並行スタート
        silentAudioPlayer?.play()
        
        synthesizer.speak(utterance)
    }
    
    /// 最適な日本語の音声を選択
    private func selectVoice() -> AVSpeechSynthesisVoice? {
        let availableVoices = getAvailableVoices()
        
        if let savedName = getSelectedVoiceName(),
           let voice = availableVoices.first(where: { $0.name == savedName }) {
            return voice
        }
        
        let premiumVoices = availableVoices.filter {
            $0.quality == .premium || $0.identifier.contains("premium") || $0.identifier.contains("enhanced")
        }
        
        if let firstPremium = premiumVoices.first {
            return firstPremium
        }
        
        return AVSpeechSynthesisVoice(language: speechLanguage)
    }
    
    /// 現在の再生リストが完了した時の処理
    private func handlePlaybackFinished() {
        if isBriefingMode {
            queueIndex += 1
            playBriefingCurrentArticle()
        } else {
            stop()
        }
    }
    
    /// 日本語テキストを句読点・改行で文に分割する（句読点を含める）
    static func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        
        for char in text {
            current.append(char)
            if char == "。" || char == "！" || char == "？" || char == "\n" {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    sentences.append(trimmed)
                }
                current = ""
            }
        }
        
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            sentences.append(trimmed)
        }
        
        return sentences
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechManager: @preconcurrency AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        // 再生が開始された
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard !isStoppingExplicitly else { return }
        handlePlaybackFinished()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // キャンセル時
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        // 音声が読んでいる現在の文字位置から、対応する文/タイトルを特定してインデックスを更新する
        let location = characterRange.location
        if let match = sentenceOffsets.first(where: { location >= $0.range.location && location < ($0.range.location + $0.range.length) }) {
            // SwiftUI の無駄な再描画を抑えるため値が異なる場合のみ反映
            if self.currentSentenceIndex != match.sentenceIndex || self.isReadingTitle != match.isTitle {
                self.currentSentenceIndex = match.sentenceIndex
                self.isReadingTitle = match.isTitle
            }
        }
    }
}

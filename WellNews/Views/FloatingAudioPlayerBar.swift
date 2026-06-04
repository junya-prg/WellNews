//
//  FloatingAudioPlayerBar.swift
//  WellNews
//
//  アプリ下部に常駐するガラスモーフィズムデザインのオーディオ再生バー
//

import SwiftUI

struct FloatingAudioPlayerBar: View {
    @ObservedObject private var speechManager = SpeechManager.shared
    @State private var animateWaves = false
    
    /// 詳細ビューを表示するためのアクション
    let onTapGesture: () -> Void
    
    var body: some View {
        guard let article = speechManager.currentArticle else {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            HStack(spacing: 12) {
                // 1. サムネイル画像またはカテゴリプレースホルダー
                Button(action: onTapGesture) {
                    HStack(spacing: 10) {
                        if let imageUrl = article.imageUrl {
                            AsyncImage(url: imageUrl) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    placeholderImage(for: article)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            placeholderImage(for: article)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        // 2. タイトルとソース名
                        VStack(alignment: .leading, spacing: 3) {
                            Text(article.title)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            HStack(spacing: 6) {
                                Text(article.source)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                if speechManager.isBriefingMode {
                                    Text("•")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Text(String(localized: "AI健康ラジオ (\(speechManager.queueIndex + 1)/\(speechManager.queue.count))"))
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.purple)
                                }
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // 3. 再生ウェーブビジュアライザー (再生中のみ動く)
                if speechManager.isPlaying && !speechManager.isPaused {
                    SoundWaveVisualizer()
                        .frame(width: 24, height: 18)
                        .padding(.trailing, 4)
                }
                
                // 4. 速度切り替えボタン
                Button(action: {
                    withAnimation(.spring()) {
                        speechManager.cycleSpeed()
                    }
                }) {
                    Text(String(format: "%.1fx", speechManager.speechSpeed))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                
                // 5. 前へ / 次へ ボタン (ブリーフィングモード時のみ)
                if speechManager.isBriefingMode {
                    Button(action: {
                        speechManager.skipNext()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .disabled(speechManager.queueIndex >= speechManager.queue.count - 1)
                }
                
                // 6. 再生/一時停止 ボタン
                Button(action: {
                    if speechManager.isPaused {
                        speechManager.resume()
                    } else {
                        speechManager.pause()
                    }
                }) {
                    Image(systemName: speechManager.isPaused ? "play.fill" : "pause.fill")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                // 7. 停止/閉じる ボタン
                Button(action: {
                    withAnimation(.easeOut(duration: 0.25)) {
                        speechManager.stop()
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        )
    }
    
    private func placeholderImage(for article: Article) -> some View {
        ZStack {
            let color: Color = {
                guard let category = article.category else { return .gray }
                switch category {
                case .exercise: return .blue
                case .diet: return .orange
                case .sleep: return .purple
                case .mentalCare: return .green
                case .other: return .gray
                }
            }()
            
            color.opacity(0.15)
            
            Image(systemName: article.category?.iconName ?? "doc.text")
                .foregroundColor(color)
                .font(.system(size: 16))
        }
    }
}

// MARK: - 音声波形アニメーション

struct SoundWaveVisualizer: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.purple)
                    .frame(width: 2.5)
                    .frame(height: isAnimating ? CGFloat.random(in: 6...18) : 4)
                    .animation(
                        isAnimating ?
                            .linear(duration: Double.random(in: 0.2...0.4)).repeatForever(autoreverses: true) :
                            .default,
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
}

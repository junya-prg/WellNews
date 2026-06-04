//
//  SplashScreenView.swift
//  WellNews
//
//  アプリ起動時のスプラッシュスクリーン
//

import SwiftUI

/// スプラッシュスクリーンビュー
struct SplashScreenView: View {
    // アニメーション状態
    @State private var iconScale: CGFloat = 0.5
    @State private var iconOpacity: Double = 0
    @State private var iconRotation: Double = -30
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 20
    @State private var backgroundOpacity: Double = 1
    
    // 完了コールバック
    var onFinished: () -> Void
    
    var body: some View {
        ZStack {
            // 背景グラデーション (WellNewsのブランドトーンに合わせた深みのあるダークブルー)
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.07, blue: 0.13),
                    Color(red: 0.03, green: 0.04, blue: 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // アプリアイコン
                Image("AppIconImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                    .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 12)
                    .shadow(color: Color.cyan.opacity(0.25), radius: 35, x: 0, y: 0)
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)
                    .rotationEffect(.degrees(iconRotation))
                
                // アプリ名 & スローガン
                VStack(spacing: 12) {
                    Text("WellNews")
                        .font(.custom("Avenir Next", size: 36).weight(.bold))
                        .tracking(6)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.cyan,
                                    Color.indigo
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.indigo.opacity(0.3), radius: 8, x: 0, y: 2)
                    
                    Text("— 気になる情報を、あなたの健やかな毎日へ —")
                        .font(.system(size: 13, weight: .medium))
                        .tracking(1.5)
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                .opacity(textOpacity)
                .offset(y: textOffset)
            }
        }
        .opacity(backgroundOpacity)
        .onAppear {
            startAnimation()
        }
    }
    
    /// アニメーションを開始
    private func startAnimation() {
        // アイコンのフェードイン＆スケール（スプリングアニメーションで自然にバウンド）
        withAnimation(.spring(response: 0.9, dampingFraction: 0.75, blendDuration: 0)) {
            iconScale = 1.0
            iconOpacity = 1.0
            iconRotation = 0
        }
        
        // テキストのフェードイン
        withAnimation(.easeOut(duration: 0.7).delay(0.5)) {
            textOpacity = 1.0
            textOffset = 0
        }
        
        // 表示時間を確保してフェードアウト
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            withAnimation(.easeInOut(duration: 0.5)) {
                backgroundOpacity = 0
            }
            
            // アニメーション完了後にコールバックを呼ぶ
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onFinished()
            }
        }
    }
}

#Preview {
    SplashScreenView(onFinished: {})
}

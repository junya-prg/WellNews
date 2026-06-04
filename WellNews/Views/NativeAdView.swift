//
//  NativeAdView.swift
//  WellNews
//
//  ネイティブ広告コンポーネント
//  健康ニュース一覧（フィード）のスタイルに溶け込む広告カード
//

import SwiftUI
import GoogleMobileAds
import Combine

// MARK: - ネイティブ広告ビュー

struct NativeAdView: View {
    @StateObject private var adLoader = NativeAdLoader()
    private let adManager = AdManager.shared

    var body: some View {
        Group {
            if adLoader.loadFailed {
                // 広告のロード失敗時は非表示（枠を詰め、表示領域を無駄にしない）
                EmptyView()
            } else if let nativeAd = adLoader.nativeAd {
                // 広告が読み込まれた場合
                NativeAdContentRepresentable(nativeAd: nativeAd)
                    .frame(minHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
            } else {
                // 読み込み中のプレースホルダー
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("広告")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.15))
                            .foregroundColor(.secondary)
                            .clipShape(Capsule())

                        Spacer()
                    }

                    NativeAdPlaceholder()
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
            }
        }
        .onAppear {
            loadIfReady()
        }
        .onChange(of: adManager.canLoadAds) { _, _ in
            loadIfReady()
        }
    }

    /// 広告をロードする
    private func loadIfReady() {
        guard adManager.canLoadAds else { return }
        adLoader.loadAd(adUnitId: adManager.nativeAdUnitId)
    }
}

// MARK: - GADNativeAdView UIViewRepresentable

struct NativeAdContentRepresentable: UIViewRepresentable {
    let nativeAd: NativeAd
    
    func makeUIView(context: Context) -> NativeAdView_UIKit {
        let nativeAdView = NativeAdView_UIKit(frame: CGRect(x: 0, y: 0, width: 320, height: 300))
        return nativeAdView
    }
    
    func updateUIView(_ nativeAdView: NativeAdView_UIKit, context: Context) {
        nativeAdView.configure(with: nativeAd)
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: NativeAdView_UIKit, context: Context) -> CGSize? {
        let width = max(proposal.width ?? UIScreen.main.bounds.width, 320)
        let fittingSize = uiView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return fittingSize
    }
}

// MARK: - GADNativeAdView Custom UIKit View

class NativeAdView_UIKit: GoogleMobileAds.NativeAdView {
    
    private let adBadgeLabel = UILabel()
    private let iconImageView = UIImageView()
    private let headlineLabel = UILabel()
    private let bodyLabel = UILabel()
    private let nativeMediaView = MediaView()
    private let advertiserLabel = UILabel()
    private let callToActionLabel = UILabel()
    
    private var mediaHeightConstraint: NSLayoutConstraint?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        clipsToBounds = true
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 16
        
        // 広告バッジの設定
        adBadgeLabel.text = "広告"
        adBadgeLabel.font = .systemFont(ofSize: 9, weight: .bold)
        adBadgeLabel.textColor = .secondaryLabel
        adBadgeLabel.textAlignment = .center
        adBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // アイコン画像の設定
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.clipsToBounds = true
        iconImageView.layer.cornerRadius = 8
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        // ヘッドラインラベルの設定 (ニュースのタイトルに合わせる)
        headlineLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        headlineLabel.numberOfLines = 2
        headlineLabel.textColor = .label
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // ボディラベルの設定
        bodyLabel.font = .systemFont(ofSize: 13)
        bodyLabel.numberOfLines = 2
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // メディアビューの設定 (動画・画像)
        nativeMediaView.contentMode = .scaleAspectFill
        nativeMediaView.clipsToBounds = true
        nativeMediaView.layer.cornerRadius = 10
        nativeMediaView.translatesAutoresizingMaskIntoConstraints = false
        
        // 広告主ラベルの設定
        advertiserLabel.font = .systemFont(ofSize: 11)
        advertiserLabel.textColor = .tertiaryLabel
        advertiserLabel.numberOfLines = 1
        advertiserLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // CTAラベル（ボタン風アクションテキスト）
        callToActionLabel.font = .systemFont(ofSize: 12, weight: .bold)
        callToActionLabel.textColor = .systemBlue
        callToActionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // レイアウト構築
        let badgeRow = UIStackView(arrangedSubviews: [adBadgeLabel, UIView()])
        badgeRow.axis = .horizontal
        
        let textColumn = UIStackView(arrangedSubviews: [headlineLabel, bodyLabel])
        textColumn.axis = .vertical
        textColumn.spacing = 4
        
        let headerRow = UIStackView(arrangedSubviews: [iconImageView, textColumn])
        headerRow.axis = .horizontal
        headerRow.spacing = 10
        headerRow.alignment = .top
        
        let footerRow = UIStackView(arrangedSubviews: [advertiserLabel, UIView(), callToActionLabel])
        footerRow.axis = .horizontal
        footerRow.alignment = .center
        
        let mainStack = UIStackView(arrangedSubviews: [badgeRow, headerRow, nativeMediaView, footerRow])
        mainStack.axis = .vertical
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(mainStack)
        
        let mediaMinHeight = nativeMediaView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120)
        let mediaHeight = nativeMediaView.heightAnchor.constraint(equalToConstant: 150)
        mediaHeight.priority = .defaultHigh
        mediaHeightConstraint = mediaHeight
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            
            iconImageView.widthAnchor.constraint(equalToConstant: 40),
            iconImageView.heightAnchor.constraint(equalToConstant: 40),
            
            mediaMinHeight,
            mediaHeight
        ])
        
        // AdMobビューに各プロパティをバインド
        self.headlineView = headlineLabel
        self.bodyView = bodyLabel
        self.iconView = iconImageView
        self.callToActionView = callToActionLabel
        self.mediaView = nativeMediaView
        self.advertiserView = advertiserLabel
    }
    
    func configure(with nativeAd: NativeAd) {
        self.nativeAd = nativeAd
        
        headlineLabel.text = nativeAd.headline
        bodyLabel.text = nativeAd.body
        callToActionLabel.text = nativeAd.callToAction
        callToActionLabel.isHidden = (nativeAd.callToAction == nil)
        
        advertiserLabel.text = nativeAd.advertiser
        advertiserLabel.isHidden = (nativeAd.advertiser == nil)
        
        if let icon = nativeAd.icon?.image {
            iconImageView.image = icon
            iconImageView.contentMode = .scaleAspectFill
            iconImageView.backgroundColor = .clear
        } else {
            iconImageView.image = UIImage(systemName: "megaphone.fill")
            iconImageView.tintColor = .systemBlue.withAlphaComponent(0.5)
            iconImageView.contentMode = .center
            iconImageView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.08)
        }
        iconImageView.isHidden = false
        
        if nativeAd.mediaContent.hasVideoContent || nativeAd.images?.isEmpty == false {
            nativeMediaView.isHidden = false
            mediaHeightConstraint?.constant = 150
        } else {
            nativeMediaView.isHidden = false
            mediaHeightConstraint?.constant = 100
        }
        
        setNeedsLayout()
        layoutIfNeeded()
    }
}

// MARK: - 広告読み込みプレースホルダー

struct NativeAdPlaceholder: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.05))
                .frame(width: 50, height: 50)
                .overlay {
                    ProgressView()
                }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("広告を読み込み中...")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.4))
                
                Text("しばらくお待ちください")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.4))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundStyle(.gray.opacity(0.3))
        )
    }
}

// MARK: - NativeAdLoader

class NativeAdLoader: NSObject, ObservableObject, AdLoaderDelegate, NativeAdLoaderDelegate {
    @Published var nativeAd: NativeAd?
    @Published var loadFailed = false
    private var adLoader: AdLoader?
    private var timeoutTimer: Timer?
    
    func loadAd(adUnitId: String) {
        guard nativeAd == nil && !loadFailed else { return }
        
        var rootViewController: UIViewController?
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            rootViewController = windowScene.windows.first?.rootViewController
        }
        
        adLoader = AdLoader(
            adUnitID: adUnitId,
            rootViewController: rootViewController,
            adTypes: [.native],
            options: nil
        )
        adLoader?.delegate = self
        adLoader?.load(Request())
        
        // 8秒でタイムアウト
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                if self?.nativeAd == nil {
                    self?.loadFailed = true
                }
            }
        }
    }
    
    // MARK: - AdLoaderDelegate
    
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        timeoutTimer?.invalidate()
        let nsError = error as NSError
        print("❌ [Native Ad] ロード失敗: \(nsError.localizedDescription) (コード: \(nsError.code))")
        DispatchQueue.main.async {
            self.loadFailed = true
        }
    }
    
    // MARK: - NativeAdLoaderDelegate
    
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        timeoutTimer?.invalidate()
        print("✅ [Native Ad] ロード成功")
        DispatchQueue.main.async {
            self.nativeAd = nativeAd
        }
    }
}

// MARK: - 広告差し込みヘルパー

enum NewsListItem: Identifiable {
    case article(Article)
    case ad(id: String)
    
    var id: String {
        switch self {
        case .article(let article):
            return "art_\(article.id.uuidString)"
        case .ad(let id):
            return "ad_\(id)"
        }
    }
}

/// ニュース記事一覧に広告を挿入する
func insertAdsIntoNews(articles: [Article], isPremium: Bool) -> [NewsListItem] {
    guard !isPremium && AdConfiguration.showNativeInNews else {
        return articles.map { .article($0) }
    }
    
    var result: [NewsListItem] = []
    let interval = AdConfiguration.nativeAdInterval
    
    for (index, article) in articles.enumerated() {
        result.append(.article(article))
        
        // 1つ目の記事の直後（index == 0）に1個目を必ず表示
        if index == 0 {
            result.append(.ad(id: "first"))
        } else if (index) % interval == 0 && index < articles.count - 1 {
            // 以降、5記事ごとの周期で挿入
            result.append(.ad(id: "seq_\(index)"))
        }
    }
    
    return result
}

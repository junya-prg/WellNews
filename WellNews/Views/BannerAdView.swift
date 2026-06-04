//
//  BannerAdView.swift
//  WellNews
//
//  バナー広告コンポーネント
//  画面下部に固定配置する標準的なバナー広告
//

import SwiftUI
import GoogleMobileAds

struct BannerAdView: View {
    private let adManager = AdManager.shared
    
    var body: some View {
        BannerViewControllerRepresentable()
            .frame(height: AdSizeBanner.size.height)
            .background(Color.clear)
    }
}

private struct BannerViewControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        let bannerView = BannerView(adSize: AdSizeBanner)
        
        bannerView.adUnitID = AdManager.shared.bannerAdUnitId
        bannerView.rootViewController = viewController
        bannerView.load(Request())
        
        viewController.view.addSubview(bannerView)
        
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bannerView.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            bannerView.centerYAnchor.constraint(equalTo: viewController.view.centerYAnchor),
            bannerView.widthAnchor.constraint(equalToConstant: AdSizeBanner.size.width),
            bannerView.heightAnchor.constraint(equalToConstant: AdSizeBanner.size.height)
        ])
        
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}


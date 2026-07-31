import GoogleMobileAds
import SwiftUI
import UIKit
import UserMessagingPlatform

enum AdMobPlacement {
    case bottomBanner

    var adUnitID: String? {
        let key: String

        switch self {
        case .bottomBanner:
            key = "NUGUSAUCE_ADMOB_BOTTOM_BANNER_AD_UNIT_ID"
        }

        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    static var hasConfiguredAdUnit: Bool {
        bottomBanner.adUnitID != nil
    }
}

@MainActor
final class AdConsentManager: ObservableObject {
    @Published private(set) var canRequestAds = false
    @Published private(set) var isPrivacyOptionsRequired = false

    private var hasStartedMobileAds = false

    func requestConsentAndStartAds() async {
        guard AdMobPlacement.hasConfiguredAdUnit else {
            return
        }

        let consentInformation = ConsentInformation.shared

        do {
            try await consentInformation.requestConsentInfoUpdate(with: RequestParameters())
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            // The SDK may still allow non-personalized requests with a consent result from a prior launch.
        }

        isPrivacyOptionsRequired = consentInformation.privacyOptionsRequirementStatus == .required

        guard consentInformation.canRequestAds else {
            canRequestAds = false
            return
        }

        if !hasStartedMobileAds {
            hasStartedMobileAds = true
            _ = await MobileAds.shared.start()
        }

        canRequestAds = true
    }

    func presentPrivacyOptions() async {
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
        } catch {
            return
        }

        let consentInformation = ConsentInformation.shared
        canRequestAds = consentInformation.canRequestAds
        isPrivacyOptionsRequired = consentInformation.privacyOptionsRequirementStatus == .required
    }
}

struct InlineFooterBanner: View {
    @EnvironmentObject private var consentManager: AdConsentManager
    @State private var availableWidth = UIScreen.main.bounds.width

    var body: some View {
        Group {
            if consentManager.canRequestAds,
               let adUnitID = AdMobPlacement.bottomBanner.adUnitID,
               availableWidth > 0 {
                let adSize = adSizeFor(cgSize: CGSize(width: min(availableWidth, 320), height: 50))

                AdMobBannerView(adUnitID: adUnitID, adSize: adSize)
                    .frame(width: adSize.size.width, height: adSize.size.height)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(SauceColor.surfaceContainerLow)
                .accessibilityIdentifier("admob.banner.footer")
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { availableWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, newWidth in
                        availableWidth = newWidth
                    }
            }
        }
    }
}

private struct AdMobBannerView: UIViewRepresentable {
    let adUnitID: String
    let adSize: AdSize

    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: adSize)
        bannerView.adUnitID = adUnitID
        bannerView.delegate = context.coordinator
        bannerView.load(Request())
        return bannerView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(adSize: adSize)
    }

    func updateUIView(_ bannerView: BannerView, context: Context) {
        guard context.coordinator.adSize.size != adSize.size else {
            return
        }

        context.coordinator.adSize = adSize
        bannerView.adSize = adSize
        bannerView.load(Request())
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        var adSize: AdSize

        init(adSize: AdSize) {
            self.adSize = adSize
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            #if DEBUG
            let adUnitID = bannerView.adUnitID ?? "unknown"
            print("AdMob banner loaded: \(adUnitID)")
            #endif
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            #if DEBUG
            print("AdMob banner failed: \(error.localizedDescription)")
            #endif
        }
    }
}

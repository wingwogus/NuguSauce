import SwiftUI

struct HomeView: View {
    let apiClient: APIClientProtocol
    @ObservedObject var authStore: AuthSessionStore
    let openProfile: () -> Void
    let openCreate: () -> Void
    let openSearch: () -> Void
    @StateObject private var viewModel: HomeViewModel
    @State private var selectedBannerID: HomeBanner.ID? = HomeBanner.allCases.first?.id
    @Environment(\.openURL) private var openURL

    init(
        apiClient: APIClientProtocol,
        authStore: AuthSessionStore,
        openProfile: @escaping () -> Void,
        openCreate: @escaping () -> Void,
        openSearch: @escaping () -> Void
    ) {
        self.apiClient = apiClient
        self.authStore = authStore
        self.openProfile = openProfile
        self.openCreate = openCreate
        self.openSearch = openSearch
        _viewModel = StateObject(wrappedValue: HomeViewModel(apiClient: apiClient))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SauceSpacing.section) {
                homeTopBar
                homeBannerCarousel

                if viewModel.isLoading && !hasRecipeContent {
                    loadingState
                } else {
                    if let errorMessage = viewModel.errorMessage {
                        SauceStatusBanner(message: errorMessage)
                            .padding(.horizontal, SauceSpacing.screen)
                            .accessibilityIdentifier("home.error")
                    }

                    popularRankingSection
                    latestSourceRailSection
                }
            }
            .padding(.bottom, 34)
        }
        .background(SauceColor.surfaceLowest.ignoresSafeArea())
        .navigationBarHidden(true)
        .task(id: homeContentRefreshID) {
            await viewModel.load()
        }
    }

    private var hasRecipeContent: Bool {
        !viewModel.popularRankingRecipes.isEmpty || !viewModel.latestSourceRecipes.isEmpty
    }

    private var homeContentRefreshID: String {
        guard authStore.isAuthenticated else {
            return "guest"
        }
        return authStore.currentSession?.memberId.map { "member-\($0)" } ?? "authenticated"
    }

    private var homeTopBar: some View {
        HStack(alignment: .center) {
            Text("홈")
                .font(SauceTypography.sectionTitle())
                .foregroundStyle(SauceColor.onSurface)

            NuguMascotImage(asset: .red)
                .frame(width: 72, height: 72)
                .accessibilityLabel("NuguSauce")
                .accessibilityIdentifier("home.brand")

            Spacer()

            Button(action: openProfile) {
                ProfileAvatar(
                    imageURL: authStore.currentSession?.profileImageUrl,
                    size: 44,
                    identityName: authStore.currentSession?.displayName,
                    fallbackSeed: authStore.currentSession?.profilePlaceholderSeed
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.profileButton")
            .accessibilityLabel("프로필")
        }
        .padding(.top, 18)
        .padding(.horizontal, SauceSpacing.screen)
    }

    private var homeBannerCarousel: some View {
        GeometryReader { proxy in
            let cardSpacing: CGFloat = 18
            let sidePeek = min(44, max(34, proxy.size.width * 0.09))
            let cardWidth = max(292, proxy.size.width - sidePeek * 2)
            let cardHeight = min(304, max(272, cardWidth * 0.9))
            let banners = HomeBanner.allCases

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: cardSpacing) {
                    ForEach(Array(banners.enumerated()), id: \.element.id) { index, banner in
                        Button {
                            open(banner)
                        } label: {
                            HomeBannerCard(
                                banner: banner,
                                position: index + 1,
                                totalCount: banners.count
                            )
                                .frame(width: cardWidth, height: cardHeight)
                        }
                        .buttonStyle(.plain)
                        .id(banner.id)
                        .accessibilityIdentifier("home.banner.\(banner.id)")
                        .accessibilityValue("\(index + 1) / \(banners.count)")
                    }
                }
                .scrollTargetLayout()
            }
            .safeAreaPadding(.horizontal, sidePeek)
            .scrollPosition(id: $selectedBannerID)
            .scrollTargetBehavior(.viewAligned)
        }
        .frame(height: 304)
        .accessibilityIdentifier("home.bannerCarousel")
    }

    private var popularRankingSection: some View {
        let popularRecipes = viewModel.popularRankingRecipes

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                NuguMascotImage(asset: .yellow)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
                Text("요즘 인기 많은 소스")
                    .font(SauceTypography.sectionTitle())
                    .foregroundStyle(SauceColor.onSurface)
            }
            .padding(.horizontal, SauceSpacing.screen)

            if popularRecipes.isEmpty {
                Text("인기 소스가 아직 없어요.")
                    .font(SauceTypography.body(.semibold))
                    .foregroundStyle(SauceColor.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(SauceColor.surfaceContainerLow)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, SauceSpacing.screen)
                    .accessibilityIdentifier("home.popularRanking.empty")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(Array(popularRecipes.enumerated()), id: \.element.id) { index, recipe in
                            NavigationLink(value: AppRoute.recipeDetail(recipe.id)) {
                                RecipeCard(recipe: recipe, rank: index + 1)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("home.popularRanking.card.\(recipe.id)")
                        }
                    }
                    .padding(.horizontal, SauceSpacing.screen)
                }
                .accessibilityIdentifier("home.popularRanking.rail")
            }
        }
        .accessibilityIdentifier("home.popularRanking")
    }

    private var latestSourceRailSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 8) {
                NuguMascotImage(asset: .green)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
                Text("방금 만들어진 소스")
                    .font(SauceTypography.sectionTitle())
                    .foregroundStyle(SauceColor.onSurface)
            }
            .padding(.horizontal, SauceSpacing.screen)

            if viewModel.latestSourceRecipes.isEmpty {
                Text("새로운 소스 조합이 아직 없어요.")
                    .font(SauceTypography.body(.semibold))
                    .foregroundStyle(SauceColor.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(SauceColor.surfaceContainerLow)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, SauceSpacing.screen)
                    .accessibilityIdentifier("home.latest.empty")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(viewModel.latestSourceRecipes) { recipe in
                            NavigationLink(value: AppRoute.recipeDetail(recipe.id)) {
                                RecipeCard(recipe: recipe)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("home.latest.card.\(recipe.id)")
                        }
                    }
                    .padding(.horizontal, SauceSpacing.screen)
                }
                .accessibilityIdentifier("home.latest.rail")
            }
        }
        .accessibilityIdentifier("home.latest")
    }

    private var loadingState: some View {
        ProgressView()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
            .accessibilityIdentifier("home.loading")
    }

    private func open(_ banner: HomeBanner) {
        switch banner {
        case .openFeedback:
            if let url = URL(string: "https://docs.google.com/forms/d/e/1FAIpQLSeFu5sd3NgrCeVP_GvCKXvU2HyL8gJAnOWjtsxelD2E5AYjaA/viewform?usp=header") {
                openURL(url)
            }
        case .createRecipe:
            openCreate()
        case .searchRecipe:
            openSearch()
        }
    }
}

private struct HomeBannerCard: View {
    let banner: HomeBanner
    let position: Int
    let totalCount: Int

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Image(banner.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                LinearGradient(
                    colors: [
                        .black.opacity(0.02),
                        .black.opacity(0.12),
                        .black.opacity(0.74)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .center, spacing: 8) {
                    Text(banner.title)
                        .font(SauceTypography.heroTitle())
                        .foregroundStyle(SauceColor.onPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text(banner.message)
                        .font(SauceTypography.body(.semibold))
                        .foregroundStyle(SauceColor.onPrimary.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text("\(Self.twoDigit(position)) | \(Self.twoDigit(totalCount))")
                        .font(SauceTypography.badge(.bold))
                        .foregroundStyle(SauceColor.onPrimary.opacity(0.95))
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private static func twoDigit(_ value: Int) -> String {
        String(format: "%02d", value)
    }
}

import SwiftUI

struct HomeView: View {
    let apiClient: APIClientProtocol
    @ObservedObject var authStore: AuthSessionStore
    let openProfile: () -> Void
    @StateObject private var viewModel: HomeViewModel

    init(apiClient: APIClientProtocol, authStore: AuthSessionStore, openProfile: @escaping () -> Void) {
        self.apiClient = apiClient
        self.authStore = authStore
        self.openProfile = openProfile
        _viewModel = StateObject(wrappedValue: HomeViewModel(apiClient: apiClient))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SauceSpacing.section) {
                homeTopBar

                if viewModel.isLoading && !hasContent {
                    loadingState
                } else {
                    if let errorMessage = viewModel.errorMessage {
                        SauceStatusBanner(message: errorMessage)
                            .padding(.horizontal, SauceSpacing.screen)
                            .accessibilityIdentifier("home.error")
                    }

                    if !hasContent {
                        emptyState
                    } else {
                        hotHeroCard
                        popularRankingSection
                        latestSourceRailSection
                    }
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

    private var hasContent: Bool {
        viewModel.hotHeroRecipe != nil ||
            !viewModel.popularRankingRecipes.isEmpty ||
            !viewModel.latestSourceRecipes.isEmpty
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

    @ViewBuilder
    private var hotHeroCard: some View {
        if let recipe = viewModel.hotHeroRecipe {
            NavigationLink(value: AppRoute.recipeDetail(recipe.id)) {
                ZStack(alignment: .bottomLeading) {
                    RecipeImage(imageURL: recipe.imageUrl, recipeID: recipe.id, height: 340)

                    LinearGradient(
                        colors: [
                            .black.opacity(0.0),
                            .black.opacity(0.36),
                            .black.opacity(0.78)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("🔥 HOT")
                            .font(SauceTypography.badge(.black))
                            .foregroundStyle(SauceColor.onPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(SauceColor.primaryContainer)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        Text(recipe.title)
                            .font(SauceTypography.heroTitle())
                            .foregroundStyle(SauceColor.onPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)

                        Text(recipe.description)
                            .font(SauceTypography.supporting(.semibold))
                            .foregroundStyle(SauceColor.onPrimary.opacity(0.9))
                            .lineLimit(2)

                        RecipeCardMetricRow(
                            recipe: recipe,
                            favoriteColor: SauceColor.onPrimary.opacity(0.92)
                        )
                            .font(SauceTypography.badge(.bold))
                            .foregroundStyle(SauceColor.onPrimary.opacity(0.92))

                        tagRow(for: recipe)
                    }
                    .padding(18)
                    .padding(.trailing, 58)

                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            RecipeFavoriteStateBadge(
                                isFavorite: recipe.isFavorited,
                                foreground: SauceColor.primaryContainer,
                                inactiveForeground: SauceColor.onPrimary.opacity(0.86)
                            )
                        }
                        .padding(18)
                    }
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, SauceSpacing.screen)
            .accessibilityIdentifier("home.hero")
        } else {
            Text("핫한 소스를 준비 중이에요.")
                .font(SauceTypography.body(.semibold))
                .foregroundStyle(SauceColor.onSurfaceVariant)
                .padding(.horizontal, SauceSpacing.screen)
                .accessibilityIdentifier("home.hero.empty")
        }
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

    private var emptyState: some View {
        Text("불러올 소스 조합이 아직 없어요.")
            .font(SauceTypography.body(.semibold))
            .foregroundStyle(SauceColor.onSurfaceVariant)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(SauceColor.surfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, SauceSpacing.screen)
            .accessibilityIdentifier("home.empty")
    }

    @ViewBuilder
    private func tagRow(for recipe: RecipeSummaryDTO) -> some View {
        if !recipe.tags.isEmpty {
            HStack(spacing: 7) {
                ForEach(recipe.tags.prefix(2)) { tag in
                    RecipeTasteTag(title: tag.name)
                }
            }
        }
    }
}

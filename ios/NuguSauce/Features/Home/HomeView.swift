import SwiftUI

struct HomeView: View {
    let apiClient: APIClientProtocol
    let authStore: AuthSessionStore
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
                        latestGridSection
                    }
                }
            }
            .padding(.bottom, 34)
        }
        .background(SauceColor.surfaceLowest.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            await viewModel.load()
        }
    }

    private var hasContent: Bool {
        viewModel.hotHeroRecipe != nil ||
            !viewModel.popularRankingRecipes.isEmpty ||
            !viewModel.latestGridRecipes.isEmpty
    }

    private var homeTopBar: some View {
        HStack(alignment: .center) {
            Image("AppIconMark")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .accessibilityLabel("NuguSauce")
                .accessibilityIdentifier("home.brand")

            Spacer()

            Button(action: openProfile) {
                ProfileAvatar(imageURL: authStore.currentSession?.profileImageUrl, size: 44)
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

                    VStack(alignment: .leading, spacing: 12) {
                        Text("🔥 HOT")
                            .font(.caption.weight(.black))
                            .foregroundStyle(SauceColor.onPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(SauceColor.primaryContainer)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                        Text(recipe.title)
                            .font(.system(size: 32, weight: .black))
                            .foregroundStyle(SauceColor.onPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)

                        Text(recipe.description)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SauceColor.onPrimary.opacity(0.9))
                            .lineLimit(2)

                        RecipeCardMetricRow(
                            recipe: recipe,
                            bookmarkColor: SauceColor.onPrimary.opacity(0.92)
                        )
                            .font(.caption.weight(.bold))
                            .foregroundStyle(SauceColor.onPrimary.opacity(0.92))

                        tagRow(for: recipe)
                    }
                    .padding(20)
                    .padding(.trailing, 58)

                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            HomeFavoriteStateBadge(
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SauceColor.onSurfaceVariant)
                .padding(.horizontal, SauceSpacing.screen)
                .accessibilityIdentifier("home.hero.empty")
        }
    }

    private var popularRankingSection: some View {
        let popularRecipes = viewModel.popularRankingRecipes

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(SauceColor.secondary)
                Text("인기 TOP 5")
                    .font(.title2.weight(.black))
                    .foregroundStyle(SauceColor.onSurface)
            }

            if popularRecipes.isEmpty {
                Text("인기 소스가 아직 없어요.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SauceColor.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(SauceColor.surfaceContainerLow)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityIdentifier("home.popularRanking.empty")
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(popularRecipes.enumerated()), id: \.element.id) { index, recipe in
                        NavigationLink(value: AppRoute.recipeDetail(recipe.id)) {
                            HomePopularRankRow(rank: index + 1, recipe: recipe)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, SauceSpacing.screen)
        .accessibilityIdentifier("home.popularRanking")
    }

    private var latestGridSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "seal.fill")
                    .foregroundStyle(SauceColor.primaryContainer)
                Text("최신 소스 조합")
                    .font(.title2.weight(.black))
                    .foregroundStyle(SauceColor.onSurface)
            }

            if viewModel.latestGridRecipes.isEmpty {
                Text("새로운 소스 조합이 아직 없어요.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SauceColor.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(SauceColor.surfaceContainerLow)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityIdentifier("home.latest.empty")
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 14),
                        GridItem(.flexible(), spacing: 14)
                    ],
                    alignment: .center,
                    spacing: 18
                ) {
                    ForEach(viewModel.latestGridRecipes) { recipe in
                        NavigationLink(value: AppRoute.recipeDetail(recipe.id)) {
                            RecipeGridCard(recipe: recipe)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, SauceSpacing.screen)
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
            .font(.subheadline.weight(.semibold))
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
        if !recipe.reviewTags.isEmpty {
            HStack(spacing: 7) {
                ForEach(recipe.reviewTags.prefix(2)) { tag in
                    RecipeTasteTag(title: tag.name)
                }
            }
        }
    }
}

private struct HomePopularRankRow: View {
    let rank: Int
    let recipe: RecipeSummaryDTO

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RecipeImage(imageURL: recipe.imageUrl, recipeID: recipe.id, height: 96)
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.title)
                    .font(.headline.weight(.black))
                    .foregroundStyle(SauceColor.onSurface)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                RecipeMiniTagRow(recipe: recipe)

                Spacer(minLength: 0)

                RecipeCardMetricRow(recipe: recipe)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(SauceColor.onSurfaceVariant)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .frame(height: 96, alignment: .topLeading)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 0) {
                HomeFavoriteStateBadge(
                    isFavorite: recipe.isFavorited,
                    size: 34,
                    foreground: SauceColor.primaryContainer,
                    inactiveForeground: SauceColor.onSurfaceVariant
                )

                Spacer(minLength: 18)

                Text("TOP \(rank)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(SauceColor.onSurfaceVariant)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .overlay {
                        Capsule()
                            .stroke(SauceColor.outline.opacity(0.18), lineWidth: 1)
                    }
            }
            .frame(height: 96, alignment: .topTrailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

private struct HomeFavoriteStateBadge: View {
    let isFavorite: Bool
    var size: CGFloat = 30
    var foreground: Color = SauceColor.primaryContainer
    var inactiveForeground: Color = SauceColor.onSurfaceVariant

    var body: some View {
        Image(systemName: isFavorite ? "bookmark.fill" : "bookmark")
            .font(.system(size: size * 0.58, weight: .black))
            .foregroundStyle(isFavorite ? foreground : inactiveForeground)
            .frame(width: size, height: size)
            .accessibilityLabel(isFavorite ? "찜한 소스" : "찜하지 않은 소스")
    }
}

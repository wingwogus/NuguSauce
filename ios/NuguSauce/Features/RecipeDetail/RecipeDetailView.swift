import SwiftUI

struct RecipeDetailView: View {
    @StateObject private var viewModel: RecipeDetailViewModel

    init(recipeID: Int, apiClient: APIClientProtocol, authStore: AuthSessionStoreProtocol) {
        _viewModel = StateObject(
            wrappedValue: RecipeDetailViewModel(recipeID: recipeID, apiClient: apiClient, authStore: authStore)
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                content
            }
        }
        .background(SauceColor.surface.ignoresSafeArea())
        .navigationBarBackButtonHidden(false)
        .task {
            await viewModel.load()
        }
    }

    private var hero: some View {
        ZStack(alignment: .topTrailing) {
            RecipeImage(imageURL: viewModel.detail?.imageUrl, recipeID: viewModel.recipeID, height: 310)
                .overlay(
                    LinearGradient(
                        colors: [.clear, SauceColor.surface.opacity(0.96)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                )
            SauceIconButton(
                systemName: viewModel.isFavorite ? "heart.fill" : "heart",
                foreground: SauceColor.primaryContainer,
                background: .white.opacity(0.9)
            ) {
                Task {
                    await viewModel.toggleFavorite()
                }
            }
            .padding(18)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 30) {
            if let detail = viewModel.detail {
                if let errorMessage = viewModel.errorMessage {
                    SauceStatusBanner(message: errorMessage)
                }
                if let firstTag = detail.reviewTags.first {
                    SauceChip(title: firstTag.name, isSelected: false, icon: "flame.fill")
                }
                titleBlock(detail)
                ingredients(detail.ingredients)
                pairings(detail.reviewTags)
                if let tips = detail.tips, !tips.isEmpty {
                    chefTip(tips)
                }
                reviewSection
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            } else {
                Text(viewModel.errorMessage ?? "상세 정보를 찾을 수 없어요.")
                    .foregroundStyle(SauceColor.onSurfaceVariant)
            }
        }
        .padding(.horizontal, SauceSpacing.screen)
        .padding(.top, 18)
        .padding(.bottom, 42)
        .background(SauceColor.surface)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
        .offset(y: -28)
    }

    private func titleBlock(_ detail: RecipeDetailDTO) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(detail.title)
                .font(.largeTitle.weight(.black))
                .foregroundStyle(SauceColor.onSurface)
                .lineLimit(3)

            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.fill")
                    .foregroundStyle(SauceColor.onSurfaceVariant)
                Text(detail.authorType == .curated ? "by NuguSauce" : "by 사용자")
                Text("·")
                    .foregroundStyle(SauceColor.muted)
                Image(systemName: "star.fill")
                    .foregroundStyle(SauceColor.secondary)
                Text(String(format: "%.1f", detail.ratingSummary.averageRating))
                    .fontWeight(.bold)
                Text("(리뷰 \(detail.ratingSummary.reviewCount)개)")
                    .foregroundStyle(SauceColor.muted)
            }
            .font(.caption)
            .foregroundStyle(SauceColor.onSurfaceVariant)
        }
    }

    private func ingredients(_ ingredients: [RecipeIngredientDTO]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("필요한 재료")
                .font(.headline.weight(.bold))

            VStack(spacing: 0) {
                ForEach(ingredients) { ingredient in
                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(SauceColor.primaryContainer)
                            .frame(width: 36, height: 36)
                            .background(SauceColor.redTint)
                            .clipShape(Circle())
                        Text(ingredient.name)
                            .font(.subheadline.weight(.bold))
                        Spacer()
                        Text((ingredient.amount ?? ingredient.ratio ?? 0).formatted())
                            .font(.headline.weight(.black))
                        Text(ingredient.unit ?? "비율")
                            .font(.caption)
                            .foregroundStyle(SauceColor.onSurfaceVariant)
                    }
                    .padding(.vertical, 14)
                    if ingredient.id != ingredients.last?.id {
                        Rectangle()
                            .fill(SauceColor.surfaceContainerLow)
                            .frame(height: 1)
                    }
                }
            }
            .padding(.horizontal, 16)
            .sauceCard(cornerRadius: 18)
        }
    }

    private func pairings(_ tags: [ReviewTagDTO]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("추천 조합 (꿀조합)")
                .font(.headline.weight(.bold))
            HStack {
                if tags.isEmpty {
                    SauceChip(title: "리뷰 태그 없음")
                } else {
                    ForEach(tags.prefix(4)) { tag in
                        SauceChip(title: tag.name)
                    }
                }
            }
        }
    }

    private func chefTip(_ tips: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("셰프의 꿀팁", systemImage: "lightbulb.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(SauceColor.primaryContainer)
            Text(tips)
                .font(.body)
                .lineSpacing(5)
                .foregroundStyle(SauceColor.onSurfaceVariant)
        }
        .padding(20)
        .sauceCard(cornerRadius: 18)
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("사용자 리뷰")
                .font(.headline.weight(.bold))

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ForEach(1...5, id: \.self) { rating in
                        Image(systemName: rating <= viewModel.selectedRating ? "star.fill" : "star")
                            .foregroundStyle(SauceColor.secondary)
                            .onTapGesture {
                                viewModel.selectedRating = rating
                            }
                    }
                }
                TextField("리뷰를 남겨주세요", text: $viewModel.reviewText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(SauceColor.surfaceContainerLow)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Button("리뷰 등록") {
                    Task {
                        await viewModel.submitReview()
                    }
                }
                .primarySauceButton()
            }
            .padding(16)
            .sauceCard(cornerRadius: 18)

            ForEach(viewModel.reviews) { review in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(SauceColor.onSurfaceVariant)
                        Text("리뷰 #\(review.id)")
                            .font(.subheadline.weight(.bold))
                        Spacer()
                        Text("최근")
                            .font(.caption2)
                            .foregroundStyle(SauceColor.muted)
                    }
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { index in
                            Image(systemName: index <= review.rating ? "star.fill" : "star.fill")
                                .font(.caption2)
                                .foregroundStyle(index <= review.rating ? SauceColor.secondary : SauceColor.surfaceContainer)
                        }
                    }
                    Text(review.text ?? "")
                        .font(.subheadline)
                        .foregroundStyle(SauceColor.onSurfaceVariant)
                }
                .padding(18)
                .sauceCard(cornerRadius: 18)
            }
        }
    }
}

import SwiftUI

struct RecipeDetailView: View {
    @ObservedObject private var authStore: AuthSessionStore
    @StateObject private var viewModel: RecipeDetailViewModel

    init(recipeID: Int, apiClient: APIClientProtocol, authStore: AuthSessionStore) {
        _authStore = ObservedObject(wrappedValue: authStore)
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
            favoriteButton
                .padding(18)
        }
    }

    @ViewBuilder
    private var favoriteButton: some View {
        if authStore.isAuthenticated {
            Button {
                Task {
                    await viewModel.toggleFavorite()
                }
            } label: {
                favoriteButtonLabel
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isUpdatingFavorite)
            .accessibilityLabel(viewModel.isFavorite ? "찜 해제" : "찜하기")
        } else {
            NavigationLink(value: AppRoute.login) {
                favoriteButtonLabel
            }
            .buttonStyle(.plain)
            .accessibilityLabel("로그인하고 찜하기")
        }
    }

    private var favoriteButtonLabel: some View {
        Image(systemName: viewModel.isFavorite ? "bookmark.fill" : "bookmark")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(SauceColor.primaryContainer)
            .frame(width: 42, height: 42)
            .background(SauceColor.surfaceLowest.opacity(0.9))
            .clipShape(Circle())
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 30) {
            if let detail = viewModel.detail {
                if let errorMessage = viewModel.errorMessage {
                    SauceStatusBanner(message: errorMessage)
                }
                titleBlock(detail)
                ingredients(detail.ingredients)
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

            Text(detail.description)
                .font(.body)
                .lineSpacing(5)
                .foregroundStyle(SauceColor.onSurfaceVariant)

            HStack(spacing: 10) {
                if let authorName = detail.displayAuthorName {
                    recipeAuthorLabel(name: authorName, detail: detail)
                    Text("·")
                        .foregroundStyle(SauceColor.muted)
                }
                Image(systemName: "star.fill")
                    .foregroundStyle(SauceColor.secondary)
                Text(String(format: "%.1f", detail.ratingSummary.averageRating))
                    .fontWeight(.bold)
                Text("(리뷰 \(detail.ratingSummary.reviewCount)개)")
                    .foregroundStyle(SauceColor.muted)
                Text("·")
                    .foregroundStyle(SauceColor.muted)
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(SauceColor.primaryContainer)
                Text("\(detail.displayFavoriteCount.formatted())")
                    .fontWeight(.bold)
            }
            .font(.caption)
            .foregroundStyle(SauceColor.onSurfaceVariant)
        }
    }

    @ViewBuilder
    private func recipeAuthorLabel(name: String, detail: RecipeDetailDTO) -> some View {
        if let authorId = detail.authorId {
            NavigationLink(value: AppRoute.publicProfile(authorId)) {
                authorIdentityLabel(name: name, imageURL: detail.authorProfileImageUrl)
            }
            .buttonStyle(.plain)
        } else {
            authorIdentityLabel(name: name, imageURL: detail.authorProfileImageUrl)
        }
    }

    private func ingredients(_ ingredients: [RecipeIngredientDTO]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("필요한 재료")
                .font(.headline.weight(.bold))

            VStack(spacing: 0) {
                ForEach(ingredients) { ingredient in
                    HStack {
                        IngredientArtwork(name: ingredient.name, category: nil, size: 36)
                        Text(ingredient.name)
                            .font(.subheadline.weight(.bold))
                        Spacer()
                        Text(RecipeMeasurementFormatter.oneDecimalText(ingredient.amount ?? ingredient.ratio))
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

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("사용자 리뷰")
                    .font(.headline.weight(.bold))
                Spacer()
                reviewWriteLink
            }

            ForEach(viewModel.reviews) { review in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        reviewAuthorLabel(review)
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

    @ViewBuilder
    private var reviewWriteLink: some View {
        if authStore.isAuthenticated {
            NavigationLink {
                ReviewComposeView(viewModel: viewModel)
            } label: {
                reviewWriteLabel
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: AppRoute.login) {
                reviewWriteLabel
            }
            .buttonStyle(.plain)
        }
    }

    private var reviewWriteLabel: some View {
        Label("리뷰 쓰기", systemImage: "square.and.pencil")
            .font(.caption.weight(.bold))
            .foregroundStyle(SauceColor.primaryContainer)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(SauceColor.redTint)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func reviewAuthorLabel(_ review: RecipeReviewDTO) -> some View {
        if let authorId = review.authorId {
            NavigationLink(value: AppRoute.publicProfile(authorId)) {
                authorIdentityLabel(
                    name: review.authorName,
                    imageURL: review.authorProfileImageUrl,
                    iconFont: .title2,
                    nameFont: .subheadline.weight(.bold)
                )
            }
            .buttonStyle(.plain)
        } else {
            authorIdentityLabel(
                name: review.authorName,
                imageURL: review.authorProfileImageUrl,
                iconFont: .title2,
                nameFont: .subheadline.weight(.bold)
            )
        }
    }

    private func authorIdentityLabel(
        name: String,
        imageURL: String?,
        iconFont: Font? = nil,
        nameFont: Font? = nil
    ) -> some View {
        HStack(spacing: 8) {
            ProfileAvatar(imageURL: imageURL, size: iconFont == nil ? 22 : 26)
            Text(name)
                .font(nameFont)
        }
        .foregroundStyle(SauceColor.onSurfaceVariant)
    }
}

private struct ReviewComposeView: View {
    @ObservedObject var viewModel: RecipeDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isSubmitting = false
    private let tagColumns = [GridItem(.adaptive(minimum: 96), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                recipeSummaryBlock
                ratingBlock
                tagBlock
                textBlock

                if let errorMessage = viewModel.errorMessage {
                    SauceStatusBanner(message: errorMessage)
                } else if !viewModel.isAuthenticated {
                    SauceStatusBanner(message: "로그인 후 리뷰를 작성할 수 있어요.")
                }
            }
            .padding(.horizontal, SauceSpacing.screen)
            .padding(.vertical, 24)
        }
        .background(SauceColor.redTint.opacity(0.18).ignoresSafeArea())
        .navigationTitle("리뷰 작성")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSubmitting ? "저장 중" : "등록") {
                    Task {
                        await submit()
                    }
                }
                .font(.headline.weight(.bold))
                .foregroundStyle(SauceColor.primaryContainer)
                .disabled(isSubmitting || !viewModel.canSubmitReview)
            }
        }
        .onAppear {
            viewModel.beginReviewDraft()
        }
        .task {
            await viewModel.loadTasteTagsIfNeeded()
        }
    }

    private var recipeSummaryBlock: some View {
        HStack(spacing: 16) {
            if let detail = viewModel.detail {
                RecipeImage(imageURL: detail.imageUrl, recipeID: detail.id, height: 82)
                    .frame(width: 82, height: 82)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(SauceColor.surfaceContainerLow)
                    .frame(width: 82, height: 82)
                    .overlay {
                        Image(systemName: "drop.fill")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(SauceColor.primaryContainer)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.detail?.title ?? "리뷰할 소스")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(SauceColor.onSurface)
                    .lineLimit(2)
                Text(summaryDescription)
                    .font(.subheadline)
                    .foregroundStyle(SauceColor.onSurfaceVariant)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(24)
        .sauceCard(cornerRadius: 28)
    }

    private var summaryDescription: String {
        guard let description = viewModel.detail?.description.trimmingCharacters(in: .whitespacesAndNewlines),
              !description.isEmpty else {
            return "소스 조합에 대한 솔직한 후기를 남겨주세요."
        }
        return description
    }

    private var ratingBlock: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text("이 소스 어떠셨나요?")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(SauceColor.onSurface)
                Text("별점을 선택해주세요")
                    .font(.subheadline)
                    .foregroundStyle(SauceColor.onSurfaceVariant)
            }

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { rating in
                    Button {
                        viewModel.selectedRating = rating
                    } label: {
                        Image(systemName: "star.fill")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(rating <= viewModel.selectedRating ? SauceColor.secondary : SauceColor.surfaceContainer)
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(rating)점")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 34)
        .sauceCard(cornerRadius: 28)
    }

    private var tagBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("맛 표현 (다중 선택)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(SauceColor.onSurface)
                Spacer()
                if !viewModel.selectedTasteTagIDs.isEmpty {
                    Text("\(viewModel.selectedTasteTagIDs.count)개 선택")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SauceColor.primaryContainer)
                }
            }

            if viewModel.isLoadingTasteTags {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let message = viewModel.tasteTagErrorMessage {
                SauceStatusBanner(message: message)
            } else if viewModel.availableTasteTags.isEmpty {
                Text("선택할 맛 태그가 아직 없어요.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SauceColor.onSurfaceVariant)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SauceColor.surfaceLowest)
                    .clipShape(RoundedRectangle(cornerRadius: SauceSpacing.controlRadius, style: .continuous))
            } else {
                LazyVGrid(columns: tagColumns, alignment: .leading, spacing: 10) {
                    ForEach(viewModel.availableTasteTags) { tag in
                        let isSelected = viewModel.selectedTasteTagIDs.contains(tag.id)
                        Button {
                            viewModel.toggleTasteTag(tag)
                        } label: {
                            SauceChip(
                                title: tag.name,
                                isSelected: isSelected,
                                icon: isSelected ? "checkmark" : nil
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tag.name)
                        .accessibilityValue(isSelected ? "선택됨" : "선택 안 됨")
                    }
                }
            }
        }
    }

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("상세 리뷰")
                .font(.headline.weight(.bold))

            ZStack(alignment: .bottomTrailing) {
                TextField(
                    "소스 조합에 대한 솔직한 후기를 남겨주세요.\n(최소 10자 이상)",
                    text: $viewModel.reviewText,
                    axis: .vertical
                )
                .lineLimit(6, reservesSpace: true)
                .textFieldStyle(.plain)
                .padding(18)
                .padding(.bottom, 26)
                .background(SauceColor.surfaceLowest)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(SauceColor.primaryContainer.opacity(0.24), lineWidth: 1)
                }
                .onChange(of: viewModel.reviewText) { _, _ in
                    viewModel.trimReviewTextIfNeeded()
                }

                Text("\(viewModel.reviewText.count) / \(viewModel.maxReviewTextLength)")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(SauceColor.onSurfaceVariant)
                    .padding(.trailing, 18)
                    .padding(.bottom, 14)
            }
        }
    }

    @MainActor
    private func submit() async {
        guard !isSubmitting else {
            return
        }

        isSubmitting = true
        let didSubmit = await viewModel.submitReview()
        isSubmitting = false

        if didSubmit {
            dismiss()
        }
    }
}

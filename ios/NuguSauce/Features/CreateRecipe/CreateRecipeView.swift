import SwiftUI

struct CreateRecipeView: View {
    let apiClient: APIClientProtocol
    @ObservedObject var authStore: AuthSessionStore
    let onCreatedRecipe: (Int) -> Void
    @StateObject private var viewModel: CreateRecipeViewModel
    @State private var expandedQuickAddSectionIDs: Set<String> = []
    private let quickAddDisclosureAnimation = Animation.spring(response: 0.28, dampingFraction: 0.88, blendDuration: 0.08)
    private let quickAddColumns = [
        GridItem(.adaptive(minimum: 132), spacing: 10, alignment: .top)
    ]

    init(apiClient: APIClientProtocol, authStore: AuthSessionStore, onCreatedRecipe: @escaping (Int) -> Void = { _ in }) {
        self.apiClient = apiClient
        self.authStore = authStore
        self.onCreatedRecipe = onCreatedRecipe
        _viewModel = StateObject(wrappedValue: CreateRecipeViewModel(apiClient: apiClient, authStore: authStore))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                topBar
                if authStore.isAuthenticated {
                    formContent
                } else {
                    LoginRequiredView(apiClient: apiClient, authStore: authStore)
                }
            }
            .padding(.horizontal, SauceSpacing.screen)
            .padding(.bottom, 42)
        }
        .background(SauceColor.surface.ignoresSafeArea())
        .task {
            await viewModel.load()
        }
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 30) {
            photoUpload
            titleFields
            ingredientEditor
            quickAdd
            statusBanners
            Button {
                Task {
                    if let recipeID = await viewModel.submit() {
                        onCreatedRecipe(recipeID)
                    }
                }
            } label: {
                Text(viewModel.isSubmitting ? "등록 중..." : "레시피 등록하기")
            }
            .primarySauceButton()
            .opacity(viewModel.canSubmit ? 1 : 0.72)
            .disabled(viewModel.isSubmitting)
            .padding(.top, 6)
        }
    }

    private var topBar: some View {
        SauceScreenTitle(title: "새 레시피 등록")
    }

    private var statusBanners: some View {
        VStack(spacing: 10) {
            if let errorMessage = viewModel.errorMessage {
                SauceStatusBanner(message: errorMessage)
            }
            if viewModel.didSubmit, let title = viewModel.submittedRecipeTitle {
                SauceStatusBanner(message: "\(title) 등록이 완료되었습니다.", isError: false)
            }
        }
    }

    private var photoUpload: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [SauceColor.photoPlaceholderStart, SauceColor.photoPlaceholderEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            VStack(spacing: 10) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(SauceColor.onSurfaceVariant)
                Text("맛있는 소스 사진을 찍어주세요")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(SauceColor.onSurfaceVariant)
                Text("사진 API 계약이 연결되면 imageUrl로 전송됩니다")
                    .font(.subheadline)
                    .foregroundStyle(SauceColor.muted)
            }
        }
        .frame(height: 260)
    }

    private var titleFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("소스 이름을 입력하세요...", text: $viewModel.title)
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(SauceColor.onSurface)
            TextField("이 소스의 맛과 어울리는 재료를 설명해주세요...", text: $viewModel.description, axis: .vertical)
                .font(.subheadline)
                .foregroundStyle(SauceColor.onSurfaceVariant)
        }
        .padding(.leading, 14)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(SauceColor.surfaceContainer)
                .frame(width: 3)
        }
    }

    private var ingredientEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("재료 배합하기")
                    .font(.title2.weight(.black))
                Spacer()
            }

            if viewModel.ingredients.isEmpty {
                SauceStatusBanner(message: "빠른 추가에서 재료를 선택해주세요.", isError: false)
            } else {
                ForEach(viewModel.ingredients) { ingredient in
                    ingredientCard(ingredient)
                }
            }
        }
    }

    private func ingredientCard(_ ingredient: EditableIngredient) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "fork.knife")
                    .foregroundStyle(SauceColor.onSurfaceVariant)
                    .frame(width: 42, height: 42)
                    .background(SauceColor.chip)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(ingredient.ingredient.name)
                        .font(.headline.weight(.bold))
                    Text(viewModel.categoryTitle(for: ingredient.ingredient))
                        .font(.caption)
                        .foregroundStyle(SauceColor.onSurfaceVariant)
                }
                Spacer()
                Text(RecipeMeasurementFormatter.oneDecimalText(ingredient.ratio))
                    .font(.title3.weight(.black))
                    .foregroundStyle(SauceColor.primaryContainer)
                Text("비율")
                    .font(.caption)
                    .foregroundStyle(SauceColor.onSurfaceVariant)
                Button {
                    viewModel.removeIngredient(ingredient)
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SauceColor.onSurfaceVariant)
                        .frame(width: 30, height: 30)
                        .background(SauceColor.surfaceContainerLow)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            Slider(
                value: Binding(
                    get: { ingredient.ratio },
                    set: { viewModel.updateRatio(for: ingredient, ratio: $0) }
                ),
                in: 0.5...5.0,
                step: 0.5
            )
            .tint(SauceColor.primaryContainer)
        }
        .padding(22)
        .sauceCard(cornerRadius: 14)
    }

    private var quickAdd: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("빠른 추가")
                    .font(.headline.weight(.black))
                    .foregroundStyle(SauceColor.onSurface)
                Spacer()
                Text("\(viewModel.quickAddVisibleIngredientCount)개")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(SauceColor.primaryContainer)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(SauceColor.redTint)
                    .clipShape(Capsule())
            }

            Text("재료를 검색하거나 카테고리를 펼쳐 배합에 추가하세요.")
                .font(.caption)
                .foregroundStyle(SauceColor.onSurfaceVariant)

            ingredientSearchField

            if viewModel.quickAddIngredients.isEmpty {
                SauceStatusBanner(message: "불러온 재료가 없습니다.", isError: false)
            } else if viewModel.quickAddSections.isEmpty {
                SauceStatusBanner(message: "검색 결과가 없습니다.", isError: false)
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(viewModel.quickAddSections) { section in
                        quickAddSection(section)
                    }
                }
            }
        }
        .padding(16)
        .background(SauceColor.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var ingredientSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(SauceColor.onSurfaceVariant)

            TextField("재료 검색", text: $viewModel.ingredientSearchText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SauceColor.onSurface)
                .autocorrectionDisabled()

            if viewModel.hasIngredientSearchText {
                Button {
                    viewModel.clearIngredientSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(SauceColor.onSurfaceVariant)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("재료 검색어 지우기")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(SauceColor.surfaceLowest)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityIdentifier("ingredient-search-field")
    }

    private func quickAddSection(_ section: IngredientQuickAddSection) -> some View {
        let isExpanded = isQuickAddSectionExpanded(section)

        return VStack(alignment: .leading, spacing: 10) {
            Button {
                toggleQuickAddSection(section)
            } label: {
                HStack(spacing: 10) {
                    Text(section.title)
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(SauceColor.onSurface)
                    Text("\(section.ingredients.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SauceColor.primaryContainer)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(SauceColor.redTint)
                        .clipShape(Capsule())
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.black))
                        .foregroundStyle(SauceColor.onSurfaceVariant)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(SauceColor.surfaceLowest)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("quick-add-section-\(section.id)")
            .accessibilityValue(isExpanded ? "펼쳐짐" : "접힘")

            if isExpanded {
                LazyVGrid(columns: quickAddColumns, alignment: .leading, spacing: 10) {
                    ForEach(section.ingredients) { ingredient in
                        quickAddIngredientButton(ingredient)
                    }
                }
                .padding(.top, 2)
                .transition(
                    .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                )
            }
        }
        .animation(quickAddDisclosureAnimation, value: isExpanded)
    }

    private func isQuickAddSectionExpanded(_ section: IngredientQuickAddSection) -> Bool {
        viewModel.hasIngredientSearchText || expandedQuickAddSectionIDs.contains(section.id)
    }

    private func toggleQuickAddSection(_ section: IngredientQuickAddSection) {
        withAnimation(quickAddDisclosureAnimation) {
            if expandedQuickAddSectionIDs.contains(section.id) {
                expandedQuickAddSectionIDs.remove(section.id)
            } else {
                expandedQuickAddSectionIDs.insert(section.id)
            }
        }
    }

    private func quickAddIngredientButton(_ ingredient: IngredientDTO) -> some View {
        let isSelected = viewModel.isIngredientSelected(ingredient)

        return Button {
            viewModel.addIngredient(ingredient)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isSelected ? SauceColor.primaryContainer : SauceColor.onSurfaceVariant)

                VStack(alignment: .leading, spacing: 2) {
                    Text(ingredient.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(SauceColor.onSurface)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(viewModel.categoryTitle(for: ingredient))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(SauceColor.onSurfaceVariant)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? SauceColor.redTint : SauceColor.surfaceLowest)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: SauceColor.primary.opacity(isSelected ? 0.08 : 0.03), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("quick-add-ingredient-\(ingredient.id)")
        .accessibilityLabel("\(ingredient.name) 재료 추가")
        .accessibilityValue(isSelected ? "선택됨" : viewModel.categoryTitle(for: ingredient))
    }
}

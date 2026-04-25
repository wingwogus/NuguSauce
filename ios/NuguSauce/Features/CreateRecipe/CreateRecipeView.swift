import SwiftUI

struct CreateRecipeView: View {
    let apiClient: APIClientProtocol
    @ObservedObject var authStore: AuthSessionStore
    @StateObject private var viewModel: CreateRecipeViewModel
    private let quickAddColumns = [
        GridItem(.adaptive(minimum: 132), spacing: 10, alignment: .top)
    ]

    init(apiClient: APIClientProtocol, authStore: AuthSessionStore) {
        self.apiClient = apiClient
        self.authStore = authStore
        _viewModel = StateObject(wrappedValue: CreateRecipeViewModel(apiClient: apiClient, authStore: authStore))
    }

    var body: some View {
        ScrollView {
            if authStore.isAuthenticated {
                formContent
            } else {
                LoginRequiredView(apiClient: apiClient, authStore: authStore)
                    .padding(.horizontal, SauceSpacing.screen)
                    .padding(.top, 28)
                    .padding(.bottom, 42)
            }
        }
        .background(SauceColor.surface.ignoresSafeArea())
        .task {
            await viewModel.load()
        }
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 30) {
            topBar
            photoUpload
            titleFields
            ingredientEditor
            quickAdd
            statusBanners
            Button {
                Task {
                    await viewModel.submit()
                }
            } label: {
                Text(viewModel.isSubmitting ? "등록 중..." : "레시피 등록하기")
            }
            .primarySauceButton()
            .opacity(viewModel.canSubmit ? 1 : 0.72)
            .disabled(viewModel.isSubmitting)
            .padding(.top, 6)
        }
        .padding(.horizontal, SauceSpacing.screen)
        .padding(.bottom, 42)
    }

    private var topBar: some View {
        HStack {
            Text("새 레시피 등록")
                .font(.title2.weight(.black))
            Spacer()
        }
        .padding(.top, 18)
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
                        colors: [Color(red: 0.86, green: 0.90, blue: 0.90), Color(red: 0.95, green: 0.92, blue: 0.88)],
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
                Button {
                    viewModel.addNextIngredient()
                } label: {
                    Label("베이스 추가", systemImage: "plus")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(SauceColor.primaryContainer)
                }
                .buttonStyle(.plain)
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
                Text(String(format: "%.1f", ingredient.ratio))
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
                Text("\(viewModel.quickAddIngredients.count)개")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(SauceColor.primaryContainer)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(SauceColor.redTint)
                    .clipShape(Capsule())
            }

            Text("카테고리별 전체 재료를 눌러 배합에 추가하세요.")
                .font(.caption)
                .foregroundStyle(SauceColor.onSurfaceVariant)

            if viewModel.quickAddIngredients.isEmpty {
                SauceStatusBanner(message: "불러온 재료가 없습니다.", isError: false)
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

    private func quickAddSection(_ section: IngredientQuickAddSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(.caption.weight(.black))
                .foregroundStyle(SauceColor.onSurfaceVariant)

            LazyVGrid(columns: quickAddColumns, alignment: .leading, spacing: 10) {
                ForEach(section.ingredients) { ingredient in
                    quickAddIngredientButton(ingredient)
                }
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

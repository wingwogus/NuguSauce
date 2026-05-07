import PhotosUI
import SwiftUI
import UIKit

struct CreateRecipeView: View {
    let apiClient: APIClientProtocol
    @ObservedObject var authStore: AuthSessionStore
    let onCreatedRecipe: (Int) -> Void
    @StateObject private var viewModel: CreateRecipeViewModel
    @State private var expandedQuickAddSectionIDs: Set<String> = []
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var ratioInputDrafts: [EditableIngredient.ID: String] = [:]
    @FocusState private var focusedRatioIngredientID: EditableIngredient.ID?
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
                    LoginGatePlaceholder(
                        title: "소스 등록은 로그인 후 가능해요.",
                        message: "로그인 화면으로 이동해 나만의 소스 조합을 기록해보세요.",
                        systemImage: "plus.circle.fill"
                    )
                }
            }
            .padding(.horizontal, SauceSpacing.screen)
            .padding(.bottom, 42)
        }
        .background(SauceColor.surface.ignoresSafeArea())
            .task {
            await viewModel.load()
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                await loadSelectedPhoto(newItem)
            }
        }
        .onChange(of: focusedRatioIngredientID) { previousID, newID in
            guard let previousID, previousID != newID else {
                return
            }
            commitRatioInput(for: previousID)
        }
        .toolbar {
            if focusedRatioIngredientID != nil {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("완료") {
                        commitFocusedRatioInput()
                        focusedRatioIngredientID = nil
                    }
                }
            }
        }
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 30) {
            photoUpload
            titleFields
            ingredientEditor
            quickAdd
            statusBanners
            if let pendingConsentStatus = viewModel.pendingConsentStatus,
               !pendingConsentStatus.requiredConsentsAccepted {
                ConsentAgreementScreen(
                    status: pendingConsentStatus,
                    isLoading: false,
                    isAccepting: viewModel.isAcceptingConsents
                ) {
                    Task {
                        _ = await viewModel.acceptRequiredConsents()
                    }
                }
            }
            Button {
                Task {
                    if let recipeID = await viewModel.submit() {
                        onCreatedRecipe(recipeID)
                    }
                }
            } label: {
                Text(viewModel.isSubmitting ? "등록 중..." : "소스 등록하기")
            }
            .primarySauceButton()
            .opacity(viewModel.canSubmit ? 1 : 0.72)
            .disabled(viewModel.isSubmitting)
            .padding(.top, 6)
        }
    }

    private var topBar: some View {
        SauceScreenTitle(title: "새 소스 등록")
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
        VStack(alignment: .leading, spacing: 12) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [SauceColor.photoPlaceholderStart, SauceColor.photoPlaceholderEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    if let data = viewModel.selectedPhotoData,
                       let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundStyle(SauceColor.onSurfaceVariant)
                            Text("소스 사진 추가")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(SauceColor.onSurfaceVariant)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    HStack(spacing: 10) {
                        Image(systemName: viewModel.hasSelectedPhoto ? "photo.fill" : "plus.circle.fill")
                            .font(.subheadline.weight(.bold))
                        Text(viewModel.hasSelectedPhoto ? "사진 변경" : "사진 선택")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(SauceColor.onPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(SauceColor.primary.opacity(0.92))
                    .clipShape(Capsule())
                    .padding(16)

                    if viewModel.isUploadingImage {
                        ProgressView()
                            .tint(SauceColor.onPrimary)
                            .padding(12)
                            .background(SauceColor.primary.opacity(0.88))
                            .clipShape(Circle())
                            .padding(16)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            if viewModel.hasSelectedPhoto {
                Toggle("직접 촬영했거나 사용할 권리가 있는 사진입니다.", isOn: $viewModel.photoRightsAccepted)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(SauceColor.onSurfaceVariant)
                    .tint(SauceColor.primaryContainer)
            }
        }
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
                .fill(SauceColor.redTint)
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
                IngredientArtwork(
                    name: ingredient.ingredient.name,
                    category: ingredient.ingredient.category,
                    size: 42
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(ingredient.ingredient.name)
                        .font(.headline.weight(.bold))
                    Text(viewModel.categoryTitle(for: ingredient.ingredient))
                        .font(.caption)
                        .foregroundStyle(SauceColor.onSurfaceVariant)
                }
                Spacer()
                ratioInput(for: ingredient)
                Button {
                    ratioInputDrafts[ingredient.id] = nil
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
                    set: { newRatio in
                        ratioInputDrafts[ingredient.id] = nil
                        viewModel.updateRatio(for: ingredient, ratio: newRatio)
                    }
                ),
                in: RecipeRatioInputRules.range,
                step: RecipeRatioInputRules.step
            )
            .tint(SauceColor.primaryContainer)
        }
        .padding(22)
        .sauceCard(cornerRadius: 14)
    }

    private func ratioInput(for ingredient: EditableIngredient) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            TextField("1.0", text: ratioInputBinding(for: ingredient))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.title3.weight(.black))
                .foregroundStyle(SauceColor.primaryContainer)
                .frame(width: 58)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(SauceColor.surfaceContainerLow)
                .clipShape(Capsule())
                .focused($focusedRatioIngredientID, equals: ingredient.id)
                .accessibilityIdentifier("ingredient-ratio-input-\(ingredient.ingredient.id)")
                .accessibilityLabel("\(ingredient.ingredient.name) 비율 직접 입력")
                .onSubmit {
                    commitRatioInput(for: ingredient.id)
                }

            Text("비율")
                .font(.caption)
                .foregroundStyle(SauceColor.onSurfaceVariant)
        }
    }

    private func ratioInputBinding(for ingredient: EditableIngredient) -> Binding<String> {
        Binding(
            get: {
                ratioInputDrafts[ingredient.id] ?? RecipeMeasurementFormatter.oneDecimalText(ingredient.ratio)
            },
            set: { newValue in
                ratioInputDrafts[ingredient.id] = newValue
                _ = viewModel.updateRatio(for: ingredient, inputText: newValue)
            }
        )
    }

    private func commitFocusedRatioInput() {
        guard let focusedRatioIngredientID else {
            return
        }
        commitRatioInput(for: focusedRatioIngredientID)
    }

    private func commitRatioInput(for ingredientID: EditableIngredient.ID) {
        guard let draft = ratioInputDrafts[ingredientID] else {
            return
        }

        guard let ingredient = viewModel.ingredients.first(where: { $0.id == ingredientID }),
              viewModel.updateRatio(for: ingredient, inputText: draft),
              let updatedIngredient = viewModel.ingredients.first(where: { $0.id == ingredientID }) else {
            ratioInputDrafts[ingredientID] = nil
            return
        }

        ratioInputDrafts[ingredientID] = RecipeMeasurementFormatter.oneDecimalText(updatedIngredient.ratio)
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
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SauceColor.outline.opacity(0.16), lineWidth: 1)
        }
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
                quickAddIngredientArtwork(ingredient, isSelected: isSelected)

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
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("quick-add-ingredient-\(ingredient.id)")
        .accessibilityLabel("\(ingredient.name) 재료 추가")
        .accessibilityValue(isSelected ? "선택됨" : viewModel.categoryTitle(for: ingredient))
    }

    private func quickAddIngredientArtwork(_ ingredient: IngredientDTO, isSelected: Bool) -> some View {
        ZStack(alignment: .bottomTrailing) {
            IngredientArtwork(name: ingredient.name, category: ingredient.category, size: 42)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle.fill")
                .font(.caption2.weight(.black))
                .foregroundStyle(isSelected ? SauceColor.primaryContainer : SauceColor.onSurfaceVariant)
                .background(SauceColor.surfaceLowest)
                .clipShape(Circle())
        }
        .frame(width: 44, height: 44)
    }

    @MainActor
    private func loadSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else {
            viewModel.clearSelectedPhoto()
            return
        }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                viewModel.setSelectedPhoto(
                    data: ImageUploadPreprocessor.normalizedJPEGData(
                        from: data,
                        maxDimension: 1800,
                        compressionQuality: 0.82
                    ),
                    contentType: "image/jpeg",
                    fileExtension: "jpg"
                )
            }
        } catch {
            viewModel.clearSelectedPhoto()
        }
    }

}

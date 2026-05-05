import SwiftUI

struct SearchView: View {
    let apiClient: APIClientProtocol
    let authStore: AuthSessionStore
    @State private var activeFilterSheet: SearchFilterSheet?
    @StateObject private var viewModel: SearchViewModel

    init(apiClient: APIClientProtocol, authStore: AuthSessionStore) {
        self.apiClient = apiClient
        self.authStore = authStore
        _viewModel = StateObject(wrappedValue: SearchViewModel(apiClient: apiClient))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SauceScreenTitle(title: "검색")
                searchField
                sortPicker
                filterBar
                results
            }
            .padding(.horizontal, SauceSpacing.screen)
            .padding(.bottom, 42)
        }
        .background(SauceColor.surface.ignoresSafeArea())
        .task {
            await viewModel.load()
        }
        .sheet(item: $activeFilterSheet) { sheet in
            SearchFilterBottomSheet(
                initialTab: sheet,
                tags: viewModel.tags,
                ingredients: viewModel.ingredients,
                initialDraft: viewModel.makeFilterDraft(),
                resetDraft: {
                    viewModel.resetFilterDraft()
                },
                applySelection: { draft in
                    viewModel.applyFilterDraft(draft)
                    Task {
                        try? await viewModel.search()
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
    }

    private var searchField: some View {
        SauceSearchBar(text: $viewModel.query) {
            Task {
                try? await viewModel.search()
            }
        }
    }

    private var sortPicker: some View {
        Picker("정렬", selection: $viewModel.sort) {
            ForEach(RecipeSort.allCases) { sort in
                Text(sort.label).tag(sort)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.sort) { _, _ in
            Task {
                try? await viewModel.search()
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                filterPill(
                    sheet: .flavor,
                    title: "맛",
                    summary: viewModel.selectedTagSummary,
                    selectedCount: viewModel.selectedTagIDs.count
                )

                filterPill(
                    sheet: .ingredient,
                    title: "재료",
                    summary: viewModel.selectedIngredientSummary,
                    selectedCount: viewModel.selectedIngredientIDs.count
                )
            }
            .padding(.vertical, 2)
        }
        .accessibilityIdentifier("search-filter-bar")
    }

    private var results: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("검색 결과")
                .font(.headline.weight(.bold))
            ForEach(viewModel.results) { recipe in
                NavigationLink(value: AppRoute.recipeDetail(recipe.id)) {
                    CompactRecipeRow(recipe: recipe)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func filterPill(
        sheet: SearchFilterSheet,
        title: String,
        summary: String,
        selectedCount: Int
    ) -> some View {
        Button {
            activeFilterSheet = sheet
        } label: {
            HStack(spacing: 7) {
                Text(title)
                    .font(.subheadline.weight(.bold))

                if selectedCount > 0 {
                    Text(summary)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                }

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(selectedCount > 0 ? SauceColor.onPrimary : SauceColor.onSurfaceVariant)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(selectedCount > 0 ? SauceColor.primaryContainer : SauceColor.surfaceContainerLow)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(sheet.buttonAccessibilityIdentifier)
        .accessibilityLabel("\(title) 필터")
        .accessibilityValue(Text(summary))
    }
}

private enum SearchFilterSheet: String, Identifiable, CaseIterable {
    case flavor
    case ingredient

    var id: String {
        rawValue
    }

    var tabTitle: String {
        switch self {
        case .flavor:
            return "맛"
        case .ingredient:
            return "재료"
        }
    }

    var helperText: String {
        switch self {
        case .flavor:
            return "원하는 맛을 골라 검색 결과를 좁혀보세요."
        case .ingredient:
            return "재료를 골라 검색 결과를 좁혀보세요."
        }
    }

    var emptyText: String {
        switch self {
        case .flavor:
            return "불러온 맛 태그가 없습니다."
        case .ingredient:
            return "불러온 재료가 없습니다."
        }
    }

    var buttonAccessibilityIdentifier: String {
        switch self {
        case .flavor:
            return "flavor-filter-button"
        case .ingredient:
            return "ingredient-filter-button"
        }
    }

    var tabAccessibilityIdentifier: String {
        switch self {
        case .flavor:
            return "search-filter-tab-flavor"
        case .ingredient:
            return "search-filter-tab-ingredient"
        }
    }
}

struct FlexibleChips<Item: Identifiable, Content: View>: View {
    let items: [Item]
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(items) { item in
                content(item)
            }
        }
    }
}

private struct SearchFilterBottomSheet: View {
    let tags: [TagDTO]
    let ingredients: [IngredientDTO]
    let resetDraft: () -> SearchFilterDraft
    let applySelection: (SearchFilterDraft) -> Void
    @State private var selectedTab: SearchFilterSheet
    @State private var draft: SearchFilterDraft
    @Environment(\.dismiss) private var dismiss

    init(
        initialTab: SearchFilterSheet,
        tags: [TagDTO],
        ingredients: [IngredientDTO],
        initialDraft: SearchFilterDraft,
        resetDraft: @escaping () -> SearchFilterDraft,
        applySelection: @escaping (SearchFilterDraft) -> Void
    ) {
        self.tags = tags
        self.ingredients = ingredients
        self.resetDraft = resetDraft
        self.applySelection = applySelection
        _selectedTab = State(initialValue: initialTab)
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        VStack(spacing: 0) {
            dragHandle
            tabRow

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sheetContent
                }
                .padding(.horizontal, SauceSpacing.screen)
                .padding(.top, 22)
                .padding(.bottom, 120)
            }

            footer
        }
        .background(SauceColor.surfaceLowest.ignoresSafeArea())
        .accessibilityIdentifier("search-filter-sheet")
    }

    private var dragHandle: some View {
        Capsule()
            .fill(SauceColor.surfaceContainer)
            .frame(width: 48, height: 5)
            .padding(.top, 10)
            .padding(.bottom, 18)
            .accessibilityHidden(true)
    }

    private var tabRow: some View {
        HStack(spacing: 28) {
            ForEach(SearchFilterSheet.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 9) {
                        Text(tab.tabTitle)
                            .font(.headline.weight(selectedTab == tab ? .bold : .semibold))
                            .foregroundStyle(selectedTab == tab ? SauceColor.onSurface : SauceColor.onSurfaceVariant)

                        Capsule()
                            .fill(selectedTab == tab ? SauceColor.onSurface : Color.clear)
                            .frame(width: 34, height: 3)
                    }
                    .frame(minWidth: 50)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(tab.tabAccessibilityIdentifier)
                .accessibilityValue(selectedTab == tab ? "선택됨" : "선택 안 됨")
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, SauceSpacing.screen)
        .padding(.bottom, 2)
        .background(SauceColor.surfaceLowest)
    }

    @ViewBuilder
    private var sheetContent: some View {
        switch selectedTab {
        case .flavor:
            optionSection(
                helperText: SearchFilterSheet.flavor.helperText,
                emptyText: SearchFilterSheet.flavor.emptyText,
                items: tags,
                selectedIDs: draft.tagIDs,
                itemTitle: { $0.name },
                toggle: toggleTag
            )
        case .ingredient:
            optionSection(
                helperText: SearchFilterSheet.ingredient.helperText,
                emptyText: SearchFilterSheet.ingredient.emptyText,
                items: ingredients,
                selectedIDs: draft.ingredientIDs,
                itemTitle: { $0.name },
                toggle: toggleIngredient
            )
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                draft = resetDraft()
            } label: {
                Text("초기화")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(SauceColor.onSurface)
                    .frame(width: 102)
                    .padding(.vertical, 18)
                    .background(SauceColor.surfaceContainerLow)
                    .clipShape(RoundedRectangle(cornerRadius: SauceSpacing.controlRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("search-filter-reset-button")

            Button {
                applySelection(draft)
                dismiss()
            } label: {
                Text("결과 보기")
                    .primarySauceButton()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("search-filter-apply-button")
        }
        .padding(.horizontal, SauceSpacing.screen)
        .padding(.top, 14)
        .padding(.bottom, 22)
        .background(SauceColor.surfaceLowest)
    }

    @ViewBuilder
    private func optionSection<Item: Identifiable>(
        helperText: String,
        emptyText: String,
        items: [Item],
        selectedIDs: Set<Int>,
        itemTitle: @escaping (Item) -> String,
        toggle: @escaping (Item) -> Void
    ) -> some View where Item.ID == Int {
        Text(helperText)
            .font(.subheadline)
            .foregroundStyle(SauceColor.onSurfaceVariant)

        if items.isEmpty {
            Text(emptyText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SauceColor.onSurfaceVariant)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(SauceColor.surfaceContainerLow)
                .clipShape(RoundedRectangle(cornerRadius: SauceSpacing.controlRadius, style: .continuous))
        } else {
            FlexibleChips(items: items) { item in
                let isSelected = selectedIDs.contains(item.id)

                Button {
                    toggle(item)
                } label: {
                    SauceChip(
                        title: itemTitle(item),
                        isSelected: isSelected,
                        icon: isSelected ? "checkmark" : nil
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("search-filter-chip-\(item.id)")
                .accessibilityLabel(itemTitle(item))
                .accessibilityValue(isSelected ? "선택됨" : "선택 안 됨")
            }
        }
    }

    private func toggleTag(_ tag: TagDTO) {
        if draft.tagIDs.contains(tag.id) {
            draft.tagIDs.remove(tag.id)
        } else {
            draft.tagIDs.insert(tag.id)
        }
    }

    private func toggleIngredient(_ ingredient: IngredientDTO) {
        if draft.ingredientIDs.contains(ingredient.id) {
            draft.ingredientIDs.remove(ingredient.id)
        } else {
            draft.ingredientIDs.insert(ingredient.id)
        }
    }
}

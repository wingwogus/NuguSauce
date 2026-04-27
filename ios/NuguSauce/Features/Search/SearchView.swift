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
                tagSection
                ingredientSection
                results
            }
            .padding(.horizontal, SauceSpacing.screen)
            .padding(.bottom, 42)
        }
        .background(SauceColor.surface.ignoresSafeArea())
        .navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .recipeDetail(let id):
                RecipeDetailView(recipeID: id, apiClient: apiClient, authStore: authStore)
            case .publicProfile:
                PublicProfilePlaceholderView()
            case .loginRequired:
                LoginRequiredView(apiClient: apiClient, authStore: authStore)
            }
        }
        .task {
            await viewModel.load()
        }
        .sheet(item: $activeFilterSheet) { sheet in
            filterSheet(for: sheet)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("맛별 필터")
                    .font(.headline.weight(.bold))
                Spacer()
                if !viewModel.selectedTagIDs.isEmpty {
                    Text("\(viewModel.selectedTagIDs.count)개 선택")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SauceColor.primaryContainer)
                }
            }

            Button {
                activeFilterSheet = .flavor
            } label: {
                filterButtonLabel(title: "맛별", summary: viewModel.selectedTagSummary, systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("flavor-filter-button")
            .accessibilityLabel("맛별 필터")
            .accessibilityValue(Text(viewModel.selectedTagSummary))
        }
    }

    private var ingredientSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("재료별 필터")
                    .font(.headline.weight(.bold))
                Spacer()
                if !viewModel.selectedIngredientIDs.isEmpty {
                    Text("\(viewModel.selectedIngredientIDs.count)개 선택")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SauceColor.primaryContainer)
                }
            }

            Button {
                activeFilterSheet = .ingredient
            } label: {
                filterButtonLabel(title: "재료별", summary: viewModel.selectedIngredientSummary, systemImage: "leaf.fill")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("ingredient-filter-button")
            .accessibilityLabel("재료별 필터")
            .accessibilityValue(Text(viewModel.selectedIngredientSummary))
        }
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

    @ViewBuilder
    private func filterSheet(for sheet: SearchFilterSheet) -> some View {
        switch sheet {
        case .flavor:
            FilterSelectionSheet(
                title: "맛별 선택",
                helperText: "원하는 맛을 골라 검색 결과를 좁혀보세요.",
                emptyText: "불러온 맛 태그가 없습니다.",
                accessibilityIdentifier: "flavor-filter-sheet",
                items: viewModel.tags,
                selectedIDs: viewModel.selectedTagIDs,
                itemTitle: \.name,
                clearSelection: {
                    viewModel.clearTags()
                    Task {
                        try? await viewModel.search()
                    }
                },
                toggleSelection: { tag in
                    viewModel.toggleTag(tag)
                    Task {
                        try? await viewModel.search()
                    }
                }
            )
        case .ingredient:
            FilterSelectionSheet(
                title: "재료별 선택",
                helperText: "재료를 골라 검색 결과를 좁혀보세요.",
                emptyText: "불러온 재료가 없습니다.",
                accessibilityIdentifier: "ingredient-filter-sheet",
                items: viewModel.ingredients,
                selectedIDs: viewModel.selectedIngredientIDs,
                itemTitle: \.name,
                clearSelection: {
                    viewModel.clearIngredients()
                    Task {
                        try? await viewModel.search()
                    }
                },
                toggleSelection: { ingredient in
                    viewModel.toggleIngredient(ingredient)
                    Task {
                        try? await viewModel.search()
                    }
                }
            )
        }
    }

    private func filterButtonLabel(title: String, summary: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(SauceColor.primaryContainer)
                .frame(width: 38, height: 38)
                .background(SauceColor.redTint)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(SauceColor.onSurface)
                Text(summary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SauceColor.onSurfaceVariant)
            }

            Spacer()

            Image(systemName: "chevron.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(SauceColor.onSurfaceVariant)
        }
        .padding(14)
        .background(SauceColor.surfaceLowest)
        .clipShape(RoundedRectangle(cornerRadius: SauceSpacing.controlRadius, style: .continuous))
        .shadow(color: SauceColor.primary.opacity(0.06), radius: 18, x: 0, y: 8)
    }
}

private enum SearchFilterSheet: String, Identifiable {
    case flavor
    case ingredient

    var id: String {
        rawValue
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

private struct FilterSelectionSheet<Item: Identifiable>: View where Item.ID == Int {
    let title: String
    let helperText: String
    let emptyText: String
    let accessibilityIdentifier: String
    let items: [Item]
    let selectedIDs: Set<Int>
    let itemTitle: (Item) -> String
    let clearSelection: () -> Void
    let toggleSelection: (Item) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
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
                            Button {
                                toggleSelection(item)
                            } label: {
                                SauceChip(
                                    title: itemTitle(item),
                                    isSelected: selectedIDs.contains(item.id),
                                    icon: selectedIDs.contains(item.id) ? "checkmark" : nil
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, SauceSpacing.screen)
                .padding(.vertical, 20)
            }
            .background(SauceColor.surface.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("전체 해제") {
                        clearSelection()
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(selectedIDs.isEmpty ? SauceColor.muted : SauceColor.primaryContainer)
                    .disabled(selectedIDs.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") {
                        dismiss()
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(SauceColor.primaryContainer)
                }
            }
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

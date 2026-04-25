import SwiftUI

struct CreateRecipeView: View {
    @StateObject private var viewModel: CreateRecipeViewModel

    init(apiClient: APIClientProtocol, authStore: AuthSessionStoreProtocol) {
        _viewModel = StateObject(wrappedValue: CreateRecipeViewModel(apiClient: apiClient, authStore: authStore))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                topBar
                photoUpload
                titleFields
                tasteTags
                ingredientEditor
                quickAdd
                Button("레시피 등록하기") {
                    Task {
                        await viewModel.submit()
                    }
                }
                .primarySauceButton()
                .padding(.top, 20)
            }
            .padding(.horizontal, SauceSpacing.screen)
            .padding(.bottom, 42)
        }
        .background(SauceColor.surface.ignoresSafeArea())
        .task {
            await viewModel.load()
        }
    }

    private var topBar: some View {
        HStack {
            Text("새 레시피 등록")
                .font(.title2.weight(.black))
            Spacer()
            Text("임시저장")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(SauceColor.primaryContainer)
        }
        .padding(.top, 18)
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
                Text("클릭하여 사진 업로드")
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

    private var tasteTags: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("맛 태그 선택")
                .font(.headline.weight(.black))
            HStack {
                ForEach(["매콤", "고소", "달달", "감칠맛"], id: \.self) { tag in
                    SauceChip(title: tag, isSelected: viewModel.selectedTagNames.contains(tag))
                }
            }
            SauceChip(title: "직접 입력", icon: "plus")
        }
    }

    private var ingredientEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("재료 배합하기")
                    .font(.title2.weight(.black))
                Spacer()
                Label("베이스 추가", systemImage: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(SauceColor.primaryContainer)
            }

            ForEach(viewModel.ingredients) { ingredient in
                ingredientCard(ingredient)
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
                    Text(ingredient.ingredient.category)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("빠른 추가")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(SauceColor.onSurfaceVariant)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(viewModel.quickAddIngredients.prefix(8)) { ingredient in
                        Button {
                            viewModel.addIngredient(ingredient)
                        } label: {
                            SauceChip(title: ingredient.name)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

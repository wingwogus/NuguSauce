import PhotosUI
import SwiftUI
import UIKit

struct ProfileView: View {
    let apiClient: APIClientProtocol
    @ObservedObject var authStore: AuthSessionStore
    @StateObject private var viewModel: ProfileViewModel
    @AppStorage(SauceThemePreference.storageKey) private var themePreferenceRawValue = SauceThemePreference.system.rawValue

    init(apiClient: APIClientProtocol, authStore: AuthSessionStore) {
        self.apiClient = apiClient
        self.authStore = authStore
        _viewModel = StateObject(wrappedValue: ProfileViewModel(apiClient: apiClient, authStore: authStore))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                topBar
                appearanceSettingsCard
                if authStore.isAuthenticated {
                    ProfileHeroCard(
                        displayName: viewModel.displayName,
                        profileImageUrl: viewModel.profileImageUrl,
                        stats: [
                            ProfileHeroStat(value: "\(viewModel.myRecipes.count)", label: "내 소스"),
                            ProfileHeroStat(value: "\(viewModel.favoriteRecipes.count)", label: "찜한 소스")
                        ],
                        editRoute: .profileEdit,
                        actionTitle: "로그아웃",
                        action: {
                            authStore.clear()
                        }
                    )
                    if viewModel.profileSetupRequired {
                        nicknameSetupCard
                    }
                    ProfileRecipeSection(title: "내가 올린 소스", recipes: viewModel.myRecipes)
                } else {
                    LoginGatePlaceholder(
                        title: "내 프로필은 로그인 후 볼 수 있어요.",
                        message: "로그인 화면으로 이동해 내가 만든 조합과 저장한 소스를 확인해보세요.",
                        systemImage: "person.crop.circle.fill"
                    )
                }
            }
            .padding(.horizontal, SauceSpacing.screen)
            .padding(.bottom, 42)
        }
        .background(SauceColor.surface.ignoresSafeArea())
        .task(id: profileRefreshID) {
            if authStore.isAuthenticated {
                await viewModel.load()
            }
        }
        .onChange(of: authStore.currentSession) { _, session in
            if session == nil {
                viewModel.clearData()
            }
        }
    }

    private var topBar: some View {
        SauceScreenTitle(title: "내 프로필")
    }

    private var profileRefreshID: String {
        guard let session = authStore.currentSession else {
            return "guest"
        }
        return [
            session.memberId.map { String($0) } ?? "anonymous",
            session.nickname ?? "",
            session.displayName,
            session.profileImageUrl ?? "",
            String(session.profileSetupRequired)
        ].joined(separator: "|")
    }

    private var appearanceSettingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(SauceColor.primaryContainer)
                Text("화면 모드")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(SauceColor.onSurface)
            }

            Picker("화면 모드", selection: themePreferenceBinding) {
                ForEach(SauceThemePreference.allCases) { preference in
                    Text(preference.title)
                        .tag(preference)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .background(SauceColor.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var themePreferenceBinding: Binding<SauceThemePreference> {
        Binding(
            get: {
                SauceThemePreference(rawValue: themePreferenceRawValue) ?? .system
            },
            set: { preference in
                themePreferenceRawValue = preference.rawValue
            }
        )
    }

    private var nicknameSetupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("닉네임 설정")
                .font(.title3.weight(.black))
            TextField("소스장인", text: $viewModel.nicknameDraft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(SauceColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Button {
                Task {
                    _ = await viewModel.saveNickname()
                }
            } label: {
                Text(viewModel.isSavingNickname ? "저장 중..." : "저장")
                    .frame(maxWidth: .infinity)
            }
            .primarySauceButton()
            .disabled(viewModel.isSavingNickname)

            if let nicknameErrorMessage = viewModel.nicknameErrorMessage {
                SauceStatusBanner(message: nicknameErrorMessage)
            }
        }
        .padding(18)
        .background(SauceColor.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

}

struct PublicProfileView: View {
    @StateObject private var viewModel: PublicProfileViewModel

    init(memberID: Int, apiClient: APIClientProtocol) {
        _viewModel = StateObject(wrappedValue: PublicProfileViewModel(memberID: memberID, apiClient: apiClient))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SauceScreenTitle(title: "프로필")

                if let member = viewModel.member {
                    ProfileHeroCard(
                        displayName: member.displayName,
                        profileImageUrl: member.profileImageUrl,
                        stats: [
                            ProfileHeroStat(value: "\(viewModel.recipes.count)", label: "내 소스"),
                            ProfileHeroStat(value: "\(viewModel.favoriteRecipes.count)", label: "찜한 소스")
                        ],
                        editRoute: nil,
                        actionTitle: nil,
                        action: nil
                    )
                    ProfileRecipeSection(title: viewModel.authoredRecipeSectionTitle, recipes: viewModel.recipes)
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                }

                if let errorMessage = viewModel.errorMessage {
                    VStack(alignment: .leading, spacing: 14) {
                        SauceStatusBanner(message: errorMessage)
                        Button {
                            Task {
                                await viewModel.load()
                            }
                        } label: {
                            Text("다시 불러오기")
                                .frame(maxWidth: .infinity)
                        }
                        .primarySauceButton()
                    }
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

}

private struct ProfileHeroStat: Identifiable {
    var id: String { label }
    let value: String
    let label: String
}

private struct ProfileHeroCard: View {
    let displayName: String
    let profileImageUrl: String?
    let stats: [ProfileHeroStat]
    let editRoute: AppRoute?
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                ProfileAvatar(imageURL: profileImageUrl, size: 98)

                if let editRoute {
                    NavigationLink(value: editRoute) {
                        Image(systemName: "pencil")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(SauceColor.onPrimary)
                            .frame(width: 34, height: 34)
                            .background(SauceColor.primaryContainer)
                            .clipShape(Circle())
                            .overlay {
                                Circle()
                                    .stroke(SauceColor.surfaceContainerLow, lineWidth: 3)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("프로필 편집")
                }
            }
            Text(displayName)
                .font(.largeTitle.weight(.black))
                .foregroundStyle(SauceColor.onSurface)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            HStack(spacing: 44) {
                ForEach(stats) { stat in
                    VStack(spacing: 2) {
                        Text(stat.value)
                            .font(.title3.weight(.black))
                        Text(stat.label)
                            .font(.caption2)
                            .foregroundStyle(SauceColor.onSurfaceVariant)
                    }
                }
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(SauceColor.onPrimary)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 13)
                    .background(SauceColor.primaryContainer)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(SauceColor.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct ProfileEditView: View {
    let apiClient: APIClientProtocol
    @ObservedObject var authStore: AuthSessionStore
    @StateObject private var viewModel: ProfileEditViewModel
    @State private var selectedPhotoItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss

    init(apiClient: APIClientProtocol, authStore: AuthSessionStore) {
        self.apiClient = apiClient
        self.authStore = authStore
        _viewModel = StateObject(wrappedValue: ProfileEditViewModel(apiClient: apiClient, authStore: authStore))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                SauceScreenTitle(title: "프로필 편집")

                VStack(alignment: .center, spacing: 18) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            profilePreview

                            Image(systemName: "pencil")
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(SauceColor.onPrimary)
                                .frame(width: 34, height: 34)
                                .background(SauceColor.primaryContainer)
                                .clipShape(Circle())
                                .overlay {
                                    Circle()
                                        .stroke(SauceColor.surface, lineWidth: 3)
                                }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("프로필 사진 변경")

                    Text(viewModel.hasSelectedPhoto ? "새 사진 선택됨" : "프로필 사진")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SauceColor.onSurfaceVariant)

                    if viewModel.hasSelectedPhoto {
                        Toggle("직접 촬영했거나 사용할 권리가 있는 사진입니다.", isOn: $viewModel.photoRightsAccepted)
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(SauceColor.onSurfaceVariant)
                            .tint(SauceColor.primaryContainer)
                            .padding(.horizontal, 22)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(SauceColor.surfaceContainerLow)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    Text("닉네임")
                        .font(.headline.weight(.bold))
                    TextField("소스장인", text: $viewModel.nicknameDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.nickname)
                        .padding(16)
                        .background(SauceColor.surfaceContainerLow)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                if let errorMessage = viewModel.errorMessage {
                    SauceStatusBanner(message: errorMessage)
                }

                if let pendingConsentStatus = viewModel.pendingConsentStatus,
                   !pendingConsentStatus.requiredConsentsAccepted {
                    ConsentRequiredPanel(
                        status: pendingConsentStatus,
                        isAccepting: viewModel.isAcceptingConsents
                    ) {
                        Task {
                            _ = await viewModel.acceptRequiredConsents()
                        }
                    }
                }

                Button {
                    Task {
                        if await viewModel.save() {
                            dismiss()
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isUploadingImage {
                            ProgressView()
                                .tint(SauceColor.onPrimary)
                        }
                        Text(viewModel.isSaving ? "저장 중..." : "변경사항 저장")
                    }
                    .frame(maxWidth: .infinity)
                }
                .primarySauceButton()
                .disabled(!viewModel.canSave)
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
    }

    @ViewBuilder
    private var profilePreview: some View {
        if let data = viewModel.selectedPhotoData,
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 118, height: 118)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(SauceColor.surface, lineWidth: 4)
                }
        } else {
            ProfileAvatar(imageURL: viewModel.profileImageUrl, size: 118)
        }
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
                        maxDimension: 1200,
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

private struct ProfileRecipeSection: View {
    let title: String
    let recipes: [RecipeSummaryDTO]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title2.weight(.black))
            ForEach(recipes) { recipe in
                NavigationLink(value: AppRoute.recipeDetail(recipe.id)) {
                    RecipeCard(recipe: recipe)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ProfileSetupGateView: View {
    @StateObject private var viewModel: ProfileViewModel
    @FocusState private var isNicknameFocused: Bool

    init(apiClient: APIClientProtocol, authStore: AuthSessionStore) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(apiClient: apiClient, authStore: authStore))
    }

    var body: some View {
        ZStack {
            SauceColor.surfaceContainerLow.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("NuguSauce")
                        .font(.largeTitle.weight(.black).italic())
                        .foregroundStyle(SauceColor.primaryContainer)
                    Text("닉네임을 정해주세요")
                        .font(.title.weight(.black))
                    Text("저장한 닉네임은 소스와 리뷰에 표시됩니다.")
                        .font(.subheadline)
                        .foregroundStyle(SauceColor.onSurfaceVariant)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("닉네임")
                        .font(.headline.weight(.bold))
                    TextField("소스장인", text: $viewModel.nicknameDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.nickname)
                        .submitLabel(.done)
                        .focused($isNicknameFocused)
                        .padding(16)
                        .background(SauceColor.surfaceContainerLow)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .onSubmit {
                            Task {
                                await saveNickname()
                            }
                        }
                }

                Button {
                    Task {
                        await saveNickname()
                    }
                } label: {
                    Text(viewModel.isSavingNickname ? "저장 중..." : "닉네임 저장")
                        .frame(maxWidth: .infinity)
                }
                .primarySauceButton()
                .disabled(!canSaveNickname)

                if let nicknameErrorMessage = viewModel.nicknameErrorMessage {
                    SauceStatusBanner(message: nicknameErrorMessage)
                }
            }
            .padding(26)
            .frame(maxWidth: 430)
            .background(SauceColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, SauceSpacing.screen)
        }
        .task {
            isNicknameFocused = true
        }
    }

    private var canSaveNickname: Bool {
        !viewModel.isSavingNickname &&
            !viewModel.nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @MainActor
    private func saveNickname() async {
        guard canSaveNickname else {
            return
        }
        _ = await viewModel.saveNickname()
    }
}

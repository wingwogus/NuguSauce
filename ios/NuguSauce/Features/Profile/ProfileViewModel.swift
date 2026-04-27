import Foundation

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published private(set) var member: MemberProfileDTO?
    @Published private(set) var myRecipes: [RecipeSummaryDTO] = []
    @Published private(set) var favoriteRecipes: [RecipeSummaryDTO] = []
    @Published private(set) var errorMessage: String?
    @Published var nicknameDraft: String = ""
    @Published private(set) var nicknameErrorMessage: String?
    @Published private(set) var isSavingNickname = false

    private let apiClient: APIClientProtocol
    private let authStore: AuthSessionStoreProtocol

    init(apiClient: APIClientProtocol, authStore: AuthSessionStoreProtocol) {
        self.apiClient = apiClient
        self.authStore = authStore
    }

    var session: AuthSession? {
        authStore.currentSession
    }

    var isAuthenticated: Bool {
        authStore.isAuthenticated
    }

    var displayName: String {
        member?.displayName ?? session?.displayName ?? "게스트"
    }

    var profileSetupRequired: Bool {
        member?.profileSetupRequired ?? session?.profileSetupRequired ?? false
    }

    func load() async {
        guard authStore.isAuthenticated else {
            clearData()
            return
        }
        do {
            async let member = apiClient.fetchMyMember()
            async let myRecipes = apiClient.fetchMyRecipes()
            async let favoriteRecipes = apiClient.fetchFavoriteRecipes()
            let loadedMember = try await member
            self.member = loadedMember
            nicknameDraft = loadedMember.nickname ?? ""
            authStore.updateMemberProfile(loadedMember)
            self.myRecipes = try await myRecipes
            self.favoriteRecipes = try await favoriteRecipes
        } catch {
            errorMessage = "프로필 정보를 불러오지 못했어요."
        }
    }

    func saveNickname() async -> Bool {
        let nickname = nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nickname.isEmpty else {
            nicknameErrorMessage = "닉네임을 입력해주세요."
            return false
        }

        isSavingNickname = true
        nicknameErrorMessage = nil
        defer {
            isSavingNickname = false
        }

        do {
            let updatedMember = try await apiClient.updateMyMember(nickname: nickname)
            member = updatedMember
            nicknameDraft = updatedMember.nickname ?? ""
            authStore.updateMemberProfile(updatedMember)
            return true
        } catch let error as ApiError {
            nicknameErrorMessage = nicknameMessage(for: error)
            return false
        } catch {
            nicknameErrorMessage = "닉네임을 저장하지 못했어요."
            return false
        }
    }

    func clearData() {
        member = nil
        myRecipes = []
        favoriteRecipes = []
        errorMessage = nil
        nicknameDraft = ""
        nicknameErrorMessage = nil
        isSavingNickname = false
    }

    private func nicknameMessage(for error: ApiError) -> String {
        switch error.code {
        case ApiErrorCode.invalidNickname:
            return "2~20자의 한글, 영문, 숫자, 밑줄만 사용할 수 있어요."
        case ApiErrorCode.duplicateNickname:
            return "이미 사용 중인 닉네임입니다."
        default:
            return "닉네임을 저장하지 못했어요. (\(error.code))"
        }
    }
}

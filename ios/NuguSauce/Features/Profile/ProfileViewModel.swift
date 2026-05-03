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
        currentSessionForLoadedMember?.displayName ?? member?.displayName ?? session?.displayName ?? "게스트"
    }

    var profileImageUrl: String? {
        currentSessionForLoadedMember?.profileImageUrl ?? member?.profileImageUrl ?? session?.profileImageUrl
    }

    var profileSetupRequired: Bool {
        currentSessionForLoadedMember?.profileSetupRequired ?? member?.profileSetupRequired ?? session?.profileSetupRequired ?? false
    }

    private var currentSessionForLoadedMember: AuthSession? {
        guard let session else {
            return nil
        }
        guard let member else {
            return session
        }
        return session.memberId == member.id ? session : nil
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
            let updatedMember = try await apiClient.updateMyMember(nickname: nickname, profileImageId: nil)
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
            return error.userVisibleMessage(default: "닉네임을 저장하지 못했어요.")
        }
    }
}

@MainActor
final class ProfileEditViewModel: ObservableObject {
    @Published private(set) var member: MemberProfileDTO?
    @Published var nicknameDraft: String = ""
    @Published private(set) var selectedPhotoData: Data?
    @Published private(set) var selectedPhotoContentType = "image/jpeg"
    @Published private(set) var selectedPhotoFileExtension = "jpg"
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var isUploadingImage = false

    private let apiClient: APIClientProtocol
    private let authStore: AuthSessionStoreProtocol

    init(apiClient: APIClientProtocol, authStore: AuthSessionStoreProtocol) {
        self.apiClient = apiClient
        self.authStore = authStore
    }

    var profileImageUrl: String? {
        member?.profileImageUrl ?? authStore.currentSession?.profileImageUrl
    }

    var hasSelectedPhoto: Bool {
        selectedPhotoData != nil
    }

    var canSave: Bool {
        !isSaving && !nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func load() async {
        guard authStore.isAuthenticated else {
            errorMessage = "로그인이 필요합니다."
            return
        }
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
        }
        do {
            let loadedMember = try await apiClient.fetchMyMember()
            member = loadedMember
            nicknameDraft = loadedMember.nickname ?? ""
            authStore.updateMemberProfile(loadedMember)
        } catch {
            errorMessage = "프로필 정보를 불러오지 못했어요."
        }
    }

    func setSelectedPhoto(data: Data, contentType: String = "image/jpeg", fileExtension: String = "jpg") {
        selectedPhotoData = data
        selectedPhotoContentType = contentType
        selectedPhotoFileExtension = fileExtension
        errorMessage = nil
    }

    func clearSelectedPhoto() {
        selectedPhotoData = nil
        selectedPhotoContentType = "image/jpeg"
        selectedPhotoFileExtension = "jpg"
    }

    func save() async -> Bool {
        guard canSave else {
            errorMessage = "닉네임을 입력해주세요."
            return false
        }

        isSaving = true
        errorMessage = nil
        defer {
            isSaving = false
            isUploadingImage = false
        }

        do {
            let profileImageId = try await uploadSelectedPhotoIfNeeded()
            let updatedMember = try await apiClient.updateMyMember(
                nickname: nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines),
                profileImageId: profileImageId
            )
            member = updatedMember
            nicknameDraft = updatedMember.nickname ?? ""
            clearSelectedPhoto()
            authStore.updateMemberProfile(updatedMember)
            return true
        } catch let error as ApiError {
            errorMessage = profileEditMessage(for: error)
            return false
        } catch {
            errorMessage = "프로필을 저장하지 못했어요."
            return false
        }
    }

    private func uploadSelectedPhotoIfNeeded() async throws -> Int? {
        guard let selectedPhotoData else {
            return nil
        }
        isUploadingImage = true
        let intent = try await apiClient.createImageUploadIntent(
            ImageUploadIntentRequestDTO(
                contentType: selectedPhotoContentType,
                byteSize: selectedPhotoData.count,
                fileExtension: selectedPhotoFileExtension
            )
        )
        try await apiClient.uploadImage(
            data: selectedPhotoData,
            contentType: selectedPhotoContentType,
            fileExtension: selectedPhotoFileExtension,
            using: intent
        )
        let verifiedImage = try await apiClient.completeImageUpload(imageId: intent.imageId)
        isUploadingImage = false
        return verifiedImage.imageId
    }

    private func profileEditMessage(for error: ApiError) -> String {
        switch error.code {
        case ApiErrorCode.invalidNickname:
            return "2~20자의 한글, 영문, 숫자, 밑줄만 사용할 수 있어요."
        case ApiErrorCode.duplicateNickname:
            return "이미 사용 중인 닉네임입니다."
        default:
            return error.userVisibleMessage(default: "프로필을 저장하지 못했어요.")
        }
    }
}

@MainActor
final class PublicProfileViewModel: ObservableObject {
    @Published private(set) var member: MemberProfileDTO?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let memberID: Int
    private let apiClient: APIClientProtocol

    init(memberID: Int, apiClient: APIClientProtocol) {
        self.memberID = memberID
        self.apiClient = apiClient
    }

    var displayName: String {
        member?.displayName ?? "사용자 정보"
    }

    var nicknameText: String? {
        let nickname = member?.nickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let nickname, !nickname.isEmpty else {
            return nil
        }
        return "@\(nickname)"
    }

    var recipes: [RecipeSummaryDTO] {
        member?.recipes ?? []
    }

    var favoriteRecipes: [RecipeSummaryDTO] {
        member?.favoriteRecipes ?? []
    }

    var authoredRecipeSectionTitle: String {
        "\(displayName)\(KoreanParticle.subject(for: displayName)) 올린 소스"
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            member = try await apiClient.fetchMember(id: memberID)
        } catch {
            errorMessage = "프로필 정보를 불러오지 못했어요."
        }
        isLoading = false
    }
}

private enum KoreanParticle {
    static func subject(for text: String) -> String {
        guard let lastScalar = text.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.last else {
            return "가"
        }
        let value = lastScalar.value
        guard value >= 0xAC00 && value <= 0xD7A3 else {
            return "가"
        }
        return (value - 0xAC00) % 28 == 0 ? "가" : "이"
    }
}

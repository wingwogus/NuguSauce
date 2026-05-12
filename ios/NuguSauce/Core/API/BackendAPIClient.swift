import Foundation

struct APIConfiguration: Equatable {
    let baseURL: URL

    static var current: APIConfiguration {
        let rawValue = ProcessInfo.processInfo.environment["NUGUSAUCE_API_BASE_URL"]
            ?? Bundle.main.object(forInfoDictionaryKey: "NUGUSAUCE_API_BASE_URL") as? String
            ?? "https://nugusauce.jaehyuns.com"

        guard let url = URL(string: rawValue), url.scheme != nil, url.host != nil else {
            preconditionFailure("Invalid NUGUSAUCE_API_BASE_URL: \(rawValue)")
        }
        return APIConfiguration(baseURL: url)
    }
}

final class BackendAPIClient: APIClientProtocol {
    private let configuration: APIConfiguration
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let authStore: AuthSessionStoreProtocol

    init(
        configuration: APIConfiguration = .current,
        session: URLSession = .shared,
        authStore: AuthSessionStoreProtocol
    ) {
        self.configuration = configuration
        self.session = session
        self.authStore = authStore

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .useDefaultKeys
        self.encoder = encoder
    }

    func fetchRecipes(query: RecipeListQuery) async throws -> [RecipeSummaryDTO] {
        var queryItems: [URLQueryItem] = []
        let keyword = query.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        if !keyword.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: keyword))
        }
        queryItems.append(contentsOf: query.tagIDs.sorted().map { URLQueryItem(name: "tagIds", value: "\($0)") })
        queryItems.append(contentsOf: query.ingredientIDs.sorted().map { URLQueryItem(name: "ingredientIds", value: "\($0)") })
        queryItems.append(URLQueryItem(name: "sort", value: query.sort.rawValue))

        return try await send(
            path: "/api/v1/recipes",
            queryItems: queryItems,
            includesAuthenticationIfAvailable: true
        )
    }

    func fetchRecipeDetail(id: Int) async throws -> RecipeDetailDTO {
        try await send(path: "/api/v1/recipes/\(id)", includesAuthenticationIfAvailable: true)
    }

    func fetchReviews(recipeID: Int) async throws -> [RecipeReviewDTO] {
        try await send(path: "/api/v1/recipes/\(recipeID)/reviews")
    }

    func fetchIngredients() async throws -> [IngredientDTO] {
        try await send(path: "/api/v1/ingredients")
    }

    func fetchTags() async throws -> [TagDTO] {
        try await send(path: "/api/v1/tags")
    }

    func createImageUploadIntent(_ request: ImageUploadIntentRequestDTO) async throws -> ImageUploadIntentDTO {
        try await send(
            path: "/api/v1/media/images/upload-intent",
            method: "POST",
            body: AnyEncodable(request),
            requiresAuthentication: true
        )
    }

    func uploadImage(
        data: Data,
        contentType: String,
        fileExtension: String,
        using intent: ImageUploadIntentDTO
    ) async throws {
        guard let url = URL(string: intent.upload.url) else {
            throw APIClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = intent.upload.method
        intent.upload.headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        if intent.upload.method.uppercased() == "POST", !intent.upload.fields.isEmpty {
            let boundary = "NuguSauce-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = multipartBody(
                fields: intent.upload.fields,
                fileField: intent.upload.fileField,
                fileName: "recipe.\(fileExtension)",
                contentType: contentType,
                fileData: data,
                boundary: boundary
            )
        } else {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            request.httpBody = data
        }

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIClientError.httpStatus(httpResponse.statusCode)
        }
    }

    func completeImageUpload(imageId: Int) async throws -> VerifiedImageDTO {
        try await send(
            path: "/api/v1/media/images/\(imageId)/complete",
            method: "POST",
            requiresAuthentication: true
        )
    }

    func createRecipe(_ request: CreateRecipeRequestDTO) async throws -> RecipeDetailDTO {
        try await send(path: "/api/v1/recipes", method: "POST", body: AnyEncodable(request), requiresAuthentication: true)
    }

    func updateRecipe(id: Int, request: UpdateRecipeRequestDTO) async throws -> RecipeDetailDTO {
        try await send(
            path: "/api/v1/me/recipes/\(id)",
            method: "PATCH",
            body: AnyEncodable(request),
            requiresAuthentication: true
        )
    }

    func deleteRecipe(id: Int) async throws {
        try await sendEmpty(
            path: "/api/v1/me/recipes/\(id)",
            method: "DELETE",
            requiresAuthentication: true
        )
    }

    func createReview(recipeID: Int, request: CreateReviewRequestDTO) async throws -> RecipeReviewDTO {
        try await send(
            path: "/api/v1/recipes/\(recipeID)/reviews",
            method: "POST",
            body: AnyEncodable(request),
            requiresAuthentication: true
        )
    }

    func fetchMyRecipes() async throws -> [RecipeSummaryDTO] {
        try await send(path: "/api/v1/me/recipes", requiresAuthentication: true)
    }

    func fetchFavoriteRecipes() async throws -> [RecipeSummaryDTO] {
        try await send(path: "/api/v1/me/favorite-recipes", requiresAuthentication: true)
    }

    func addFavorite(recipeID: Int) async throws -> FavoriteResponseDTO {
        try await send(
            path: "/api/v1/me/favorite-recipes/\(recipeID)",
            method: "POST",
            requiresAuthentication: true
        )
    }

    func deleteFavorite(recipeID: Int) async throws {
        try await sendEmpty(
            path: "/api/v1/me/favorite-recipes/\(recipeID)",
            method: "DELETE",
            requiresAuthentication: true
        )
    }

    func fetchMyMember() async throws -> MemberProfileDTO {
        try await send(path: "/api/v1/members/me", requiresAuthentication: true)
    }

    func fetchMember(id: Int) async throws -> MemberProfileDTO {
        try await send(path: "/api/v1/members/\(id)")
    }

    func updateMyMember(nickname: String, profileImageId: Int? = nil) async throws -> MemberProfileDTO {
        try await send(
            path: "/api/v1/members/me",
            method: "PATCH",
            body: AnyEncodable(UpdateMemberRequest(nickname: nickname, profileImageId: profileImageId)),
            requiresAuthentication: true
        )
    }

    func updateMyMember(nickname: String, profileImageId: Int? = nil, accessToken: String) async throws -> MemberProfileDTO {
        try await send(
            path: "/api/v1/members/me",
            method: "PATCH",
            body: AnyEncodable(UpdateMemberRequest(nickname: nickname, profileImageId: profileImageId)),
            requiresAuthentication: true,
            accessTokenOverride: accessToken
        )
    }

    func authenticateWithKakao(idToken: String, nonce: String, kakaoAccessToken: String) async throws -> SocialLoginResponseDTO {
        try await send(
            path: "/api/v1/auth/kakao/login",
            method: "POST",
            body: AnyEncodable(KakaoLoginRequest(idToken: idToken, nonce: nonce, kakaoAccessToken: kakaoAccessToken))
        )
    }

    func authenticateWithApple(
        identityToken: String,
        nonce: String,
        authorizationCode: String?,
        userIdentifier: String?
    ) async throws -> SocialLoginResponseDTO {
        try await send(
            path: "/api/v1/auth/apple/login",
            method: "POST",
            body: AnyEncodable(
                AppleLoginRequest(
                    identityToken: identityToken,
                    nonce: nonce,
                    authorizationCode: authorizationCode,
                    userIdentifier: userIdentifier
                )
            )
        )
    }

    func reissue(refreshToken: String) async throws -> TokenResponseDTO {
        try await send(
            path: "/api/v1/auth/reissue",
            method: "POST",
            body: AnyEncodable(ReissueRequest(refreshToken: refreshToken))
        )
    }

    func fetchConsentStatus() async throws -> ConsentStatusDTO {
        try await send(path: "/api/v1/consents/status", requiresAuthentication: true)
    }

    func fetchConsentStatus(accessToken: String) async throws -> ConsentStatusDTO {
        try await send(
            path: "/api/v1/consents/status",
            requiresAuthentication: true,
            accessTokenOverride: accessToken
        )
    }

    func acceptConsents(_ request: ConsentAcceptRequestDTO) async throws -> ConsentStatusDTO {
        try await send(
            path: "/api/v1/consents/accept",
            method: "POST",
            body: AnyEncodable(request),
            requiresAuthentication: true
        )
    }

    func acceptConsents(_ request: ConsentAcceptRequestDTO, accessToken: String) async throws -> ConsentStatusDTO {
        try await send(
            path: "/api/v1/consents/accept",
            method: "POST",
            body: AnyEncodable(request),
            requiresAuthentication: true,
            accessTokenOverride: accessToken
        )
    }

    private func send<Response: Decodable>(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem] = [],
        body: AnyEncodable? = nil,
        requiresAuthentication: Bool = false,
        includesAuthenticationIfAvailable: Bool = false,
        accessTokenOverride: String? = nil
    ) async throws -> Response {
        let request = try makeRequest(
            path: path,
            method: method,
            queryItems: queryItems,
            body: body,
            requiresAuthentication: requiresAuthentication,
            includesAuthenticationIfAvailable: includesAuthenticationIfAvailable,
            accessTokenOverride: accessTokenOverride
        )
        let (data, response) = try await session.data(for: request)
        return try decodeEnvelope(Response.self, from: data, response: response)
    }

    private func sendEmpty(
        path: String,
        method: String,
        requiresAuthentication: Bool
    ) async throws {
        let request = try makeRequest(
            path: path,
            method: method,
            queryItems: [],
            body: nil,
            requiresAuthentication: requiresAuthentication,
            includesAuthenticationIfAvailable: false,
            accessTokenOverride: nil
        )
        let (data, response) = try await session.data(for: request)
        _ = try decodeEnvelope(EmptyResponse.self, from: data, response: response)
    }

    private func makeRequest(
        path: String,
        method: String,
        queryItems: [URLQueryItem],
        body: AnyEncodable?,
        requiresAuthentication: Bool,
        includesAuthenticationIfAvailable: Bool,
        accessTokenOverride: String? = nil
    ) throws -> URLRequest {
        guard var components = URLComponents(url: url(for: path), resolvingAgainstBaseURL: false) else {
            throw APIClientError.invalidURL
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw APIClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if requiresAuthentication {
            guard let accessToken = accessTokenOverride ?? authStore.accessToken, !accessToken.isEmpty else {
                throw APIClientError.missingAuthentication
            }
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        } else if includesAuthenticationIfAvailable,
                  let accessToken = accessTokenOverride ?? authStore.accessToken,
                  !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func url(for path: String) -> URL {
        path
            .split(separator: "/")
            .reduce(configuration.baseURL) { partialURL, component in
                partialURL.appending(path: String(component))
            }
    }

    private func decodeEnvelope<Response: Decodable>(
        _ responseType: Response.Type,
        from data: Data,
        response: URLResponse
    ) throws -> Response {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        if !(200..<300).contains(httpResponse.statusCode) {
            if let failure = try? decoder.decode(ApiEnvelope<EmptyResponse>.self, from: data),
               let error = failure.error {
                throw error
            }
            throw APIClientError.httpStatus(httpResponse.statusCode)
        }

        let envelope = try decoder.decode(ApiEnvelope<Response>.self, from: data)
        guard envelope.success else {
            throw envelope.error ?? APIClientError.unsuccessfulEnvelope
        }

        if let value = envelope.data {
            return value
        }

        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }

        throw APIClientError.missingData
    }

    private func multipartBody(
        fields: [String: String],
        fileField: String,
        fileName: String,
        contentType: String,
        fileData: Data,
        boundary: String
    ) -> Data {
        var body = Data()
        for key in fields.keys.sorted() {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(fields[key] ?? "")\r\n")
        }
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fileName)\"\r\n")
        body.append("Content-Type: \(contentType)\r\n\r\n")
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n")
        return body
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}

private struct KakaoLoginRequest: Encodable {
    let idToken: String
    let nonce: String
    let kakaoAccessToken: String
}

private struct AppleLoginRequest: Encodable {
    let identityToken: String
    let nonce: String
    let authorizationCode: String?
    let userIdentifier: String?
}

private struct ReissueRequest: Encodable {
    let refreshToken: String
}

private struct UpdateMemberRequest: Encodable {
    let nickname: String
    let profileImageId: Int?
}

private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void

    init(_ value: some Encodable) {
        encodeValue = value.encode(to:)
    }

    func encode(to encoder: Encoder) throws {
        try encodeValue(encoder)
    }
}

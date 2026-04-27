import Foundation

struct APIConfiguration: Equatable {
    let baseURL: URL

    static var current: APIConfiguration {
        let rawValue = ProcessInfo.processInfo.environment["NUGUSAUCE_API_BASE_URL"]
            ?? Bundle.main.object(forInfoDictionaryKey: "NUGUSAUCE_API_BASE_URL") as? String
            ?? "http://127.0.0.1:8080"

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

        return try await send(path: "/api/v1/recipes", queryItems: queryItems)
    }

    func fetchRecipeDetail(id: Int) async throws -> RecipeDetailDTO {
        try await send(path: "/api/v1/recipes/\(id)")
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

    func createRecipe(_ request: CreateRecipeRequestDTO) async throws -> RecipeDetailDTO {
        try await send(path: "/api/v1/recipes", method: "POST", body: AnyEncodable(request), requiresAuthentication: true)
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

    func updateMyMember(nickname: String) async throws -> MemberProfileDTO {
        try await send(
            path: "/api/v1/members/me",
            method: "PATCH",
            body: AnyEncodable(UpdateMemberRequest(nickname: nickname)),
            requiresAuthentication: true
        )
    }

    func authenticateWithKakao(idToken: String, nonce: String, kakaoAccessToken: String) async throws -> KakaoLoginResponseDTO {
        try await send(
            path: "/api/v1/auth/kakao/login",
            method: "POST",
            body: AnyEncodable(KakaoLoginRequest(idToken: idToken, nonce: nonce, kakaoAccessToken: kakaoAccessToken))
        )
    }

    func reissue(refreshToken: String) async throws -> TokenResponseDTO {
        try await send(
            path: "/api/v1/auth/reissue",
            method: "POST",
            body: AnyEncodable(ReissueRequest(refreshToken: refreshToken))
        )
    }

    private func send<Response: Decodable>(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem] = [],
        body: AnyEncodable? = nil,
        requiresAuthentication: Bool = false
    ) async throws -> Response {
        let request = try makeRequest(
            path: path,
            method: method,
            queryItems: queryItems,
            body: body,
            requiresAuthentication: requiresAuthentication
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
            requiresAuthentication: requiresAuthentication
        )
        let (data, response) = try await session.data(for: request)
        _ = try decodeEnvelope(EmptyResponse.self, from: data, response: response)
    }

    private func makeRequest(
        path: String,
        method: String,
        queryItems: [URLQueryItem],
        body: AnyEncodable?,
        requiresAuthentication: Bool
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
            guard let accessToken = authStore.accessToken, !accessToken.isEmpty else {
                throw APIClientError.missingAuthentication
            }
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
}

private struct KakaoLoginRequest: Encodable {
    let idToken: String
    let nonce: String
    let kakaoAccessToken: String
}

private struct ReissueRequest: Encodable {
    let refreshToken: String
}

private struct UpdateMemberRequest: Encodable {
    let nickname: String
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

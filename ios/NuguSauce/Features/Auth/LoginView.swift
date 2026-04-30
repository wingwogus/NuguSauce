import SwiftUI

struct LoginView: View {
    private static let kakaoLoginButtonAspectRatio: CGFloat = 600.0 / 90.0
    private static let kakaoLoginButtonMaxWidth: CGFloat = 300
    private static let kakaoLoginButtonMaxHeight: CGFloat = 45

    let apiClient: APIClientProtocol
    @ObservedObject var authStore: AuthSessionStore
    @Environment(\.dismiss) private var dismiss
    private let kakaoLoginService = KakaoLoginService()
    @State private var isLoggingIn = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                VStack(spacing: 14) {
                    Image("AppIconMark")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 92, height: 92)
                        .accessibilityHidden(true)
                    Text("NuguSauce")
                        .font(.largeTitle.weight(.black).italic())
                        .foregroundStyle(SauceColor.primaryContainer)
                    Text("로그인하고 소스 조합을 저장해보세요")
                        .font(.title3.weight(.black))
                        .foregroundStyle(SauceColor.onSurface)
                        .multilineTextAlignment(.center)
                    Text("카카오 계정으로 계속하면 찜, 프로필, 레시피 등록과 리뷰 작성 기능을 사용할 수 있어요.")
                        .font(.subheadline)
                        .foregroundStyle(SauceColor.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity)

                Button {
                    Task {
                        await loginWithKakao()
                    }
                } label: {
                    GeometryReader { proxy in
                        let buttonWidth = min(proxy.size.width, Self.kakaoLoginButtonMaxWidth)

                        Image("KakaoLoginLargeWide")
                            .resizable()
                            .scaledToFit()
                            .frame(
                                width: buttonWidth,
                                height: buttonWidth / Self.kakaoLoginButtonAspectRatio
                            )
                            .opacity(isLoggingIn ? 0.65 : 1)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                    .frame(height: Self.kakaoLoginButtonMaxHeight)
                }
                .buttonStyle(.plain)
                .disabled(isLoggingIn)
                .accessibilityLabel(isLoggingIn ? "카카오 로그인 중" : "카카오로 시작하기")

                if let errorMessage {
                    SauceStatusBanner(message: errorMessage)
                }
            }
            .frame(maxWidth: 430)
            .padding(.horizontal, SauceSpacing.screen)
            .padding(.top, 70)
            .padding(.bottom, 42)
            .frame(maxWidth: .infinity)
        }
        .background(SauceColor.surface.ignoresSafeArea())
        .navigationTitle("로그인")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("login-screen")
    }

    @MainActor
    private func loginWithKakao() async {
        guard !isLoggingIn else {
            return
        }

        isLoggingIn = true
        errorMessage = nil
        defer {
            isLoggingIn = false
        }

        do {
            let credential = try await kakaoLoginService.login()
            let tokens = try await apiClient.authenticateWithKakao(
                idToken: credential.idToken,
                nonce: credential.nonce,
                kakaoAccessToken: credential.kakaoAccessToken
            )
            if authStore.saveSession(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken, member: tokens.member) {
                errorMessage = nil
                dismiss()
            } else {
                errorMessage = authStore.persistenceFailure?.message ?? "로그인 세션을 안전하게 저장하지 못했어요. 다시 시도해주세요."
            }
        } catch {
            errorMessage = KakaoLoginErrorMessage.message(for: error)
        }
    }
}

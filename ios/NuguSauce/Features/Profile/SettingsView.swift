import SwiftUI

struct SettingsView: View {
    let apiClient: APIClientProtocol
    @ObservedObject var authStore: AuthSessionStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SauceThemePreference.storageKey) private var themePreferenceRawValue = SauceThemePreference.system.rawValue

    init(apiClient: APIClientProtocol, authStore: AuthSessionStore) {
        self.apiClient = apiClient
        self.authStore = authStore
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                SettingsSection {
                    NavigationLink(value: AppRoute.profileEdit) {
                        SettingsRow(title: "프로필 수정", subtitle: "닉네임, 프로필 사진 등", showsChevron: true)
                    }
                    .buttonStyle(.plain)

                    SettingsDivider()

                    Menu {
                        Picker("화면 모드", selection: themePreferenceBinding) {
                            ForEach(SauceThemePreference.allCases) { preference in
                                Text(preference.title).tag(preference)
                            }
                        }
                    } label: {
                        SettingsRow(title: "화면 모드", detail: themePreference.title, showsChevron: true)
                    }
                    .buttonStyle(.plain)
                }

                SettingsSection {
                    ForEach(legalDocuments) { document in
                        NavigationLink {
                            LegalDocumentView(document: document)
                        } label: {
                            SettingsRow(title: document.title, showsChevron: true)
                        }
                        .buttonStyle(.plain)

                        if document.id != legalDocuments.last?.id {
                            SettingsDivider()
                        }
                    }
                }

                SettingsSection {
                    Button {
                        authStore.clear()
                        dismiss()
                    } label: {
                        SettingsRow(title: "로그아웃", showsChevron: false)
                    }
                    .buttonStyle(.plain)
                }

                SettingsSection {
                    NavigationLink {
                        AccountDeletionChecklistView(apiClient: apiClient, authStore: authStore)
                    } label: {
                        SettingsRow(
                            title: "회원탈퇴",
                            titleColor: SauceColor.primaryContainer,
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 36)
        }
        .background(SauceColor.surface.ignoresSafeArea())
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var legalDocuments: [LegalPolicyDocument] {
        LegalPolicyContent.currentDocuments()
    }

    private var themePreference: SauceThemePreference {
        SauceThemePreference(rawValue: themePreferenceRawValue) ?? .system
    }

    private var themePreferenceBinding: Binding<SauceThemePreference> {
        Binding(
            get: { themePreference },
            set: { themePreferenceRawValue = $0.rawValue }
        )
    }
}

private struct AccountDeletionChecklistView: View {
    let apiClient: APIClientProtocol
    @ObservedObject var authStore: AuthSessionStore
    @StateObject private var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    init(apiClient: APIClientProtocol, authStore: AuthSessionStore) {
        self.apiClient = apiClient
        self.authStore = authStore
        _viewModel = StateObject(wrappedValue: SettingsViewModel(apiClient: apiClient, authStore: authStore))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("회원 탈퇴 신청 전에\n꼭 확인하세요.")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(SauceColor.onSurface)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text("탈퇴 후 복구 가능한 데이터")
                        .font(SauceTypography.body(.semibold))
                        .foregroundStyle(SauceColor.onSurfaceVariant)
                    Spacer()
                    Text("없음")
                        .font(SauceTypography.body(.bold))
                        .foregroundStyle(SauceColor.onSurface)
                }

                VStack(spacing: 0) {
                    ForEach(viewModel.deletionAcknowledgements) { acknowledgement in
                        DeletionAcknowledgementRow(
                            acknowledgement: acknowledgement,
                            isAccepted: viewModel.acceptedDeletionAcknowledgementIDs.contains(acknowledgement.id),
                            toggle: {
                                viewModel.toggleDeletionAcknowledgement(acknowledgement.id)
                            }
                        )

                        if acknowledgement.id != viewModel.deletionAcknowledgements.last?.id {
                            DeletionDivider()
                        }
                    }
                }
                .background(SauceColor.surfaceLowest)

                if let errorMessage = viewModel.errorMessage {
                    SauceStatusBanner(message: errorMessage)
                }
            }
            .padding(.horizontal, SauceSpacing.screen)
            .padding(.top, 22)
            .padding(.bottom, 120)
        }
        .background(SauceColor.surface.ignoresSafeArea())
        .navigationTitle("회원탈퇴")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                Task {
                    if await viewModel.deleteAccount() {
                        dismiss()
                    }
                }
            } label: {
                Text(viewModel.isDeletingAccount ? "탈퇴 처리 중..." : "탈퇴하기")
                    .font(SauceTypography.body(.bold))
                    .foregroundStyle(SauceColor.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(deleteButtonBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canDeleteAccount || viewModel.isDeletingAccount)
            .padding(.horizontal, SauceSpacing.screen)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(SauceColor.surface)
        }
    }

    private var deleteButtonBackground: Color {
        viewModel.canDeleteAccount && !viewModel.isDeletingAccount
            ? SauceColor.primaryContainer
            : SauceColor.surfaceContainer
    }
}

private struct DeletionAcknowledgementRow: View {
    let acknowledgement: AccountDeletionAcknowledgement
    let isAccepted: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 9) {
                    Text(acknowledgement.title)
                        .font(acknowledgement.isFinalConsent ? SauceTypography.body(.bold) : SauceTypography.body(.semibold))
                        .foregroundStyle(SauceColor.onSurface)
                        .fixedSize(horizontal: false, vertical: true)

                    if !acknowledgement.bulletPoints.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(acknowledgement.bulletPoints, id: \.self) { point in
                                Text("• \(point)")
                                    .font(SauceTypography.supporting())
                                    .foregroundStyle(SauceColor.onSurfaceVariant)
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                Spacer(minLength: 10)

                Image(systemName: isAccepted ? "checkmark.square.fill" : "square")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(isAccepted ? SauceColor.primaryContainer : SauceColor.muted)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(acknowledgement.title)
        .accessibilityValue(isAccepted ? "확인됨" : "미확인")
    }
}

private struct DeletionDivider: View {
    var body: some View {
        Rectangle()
            .fill(SauceColor.surfaceContainerLow)
            .frame(height: 1)
    }
}

private struct SettingsSection<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(SauceColor.surfaceLowest)
    }
}

private struct SettingsRow: View {
    let title: String
    var subtitle: String?
    var detail: String?
    var titleColor: Color = SauceColor.onSurface
    var showsChevron: Bool

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(SauceTypography.body(.regular))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let subtitle {
                    Text(subtitle)
                        .font(SauceTypography.supporting())
                        .foregroundStyle(SauceColor.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            Spacer(minLength: 12)

            if let detail {
                Text(detail)
                    .font(SauceTypography.supporting())
                    .foregroundStyle(SauceColor.onSurfaceVariant)
                    .lineLimit(1)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(SauceColor.muted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: subtitle == nil ? 58 : 66, alignment: .leading)
        .padding(.horizontal, SauceSpacing.screen)
        .contentShape(Rectangle())
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(SauceColor.surfaceContainerLow)
            .frame(height: 1)
            .padding(.leading, SauceSpacing.screen)
    }
}

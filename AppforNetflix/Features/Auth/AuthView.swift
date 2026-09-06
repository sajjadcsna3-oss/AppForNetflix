import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var isShowingResetConfirmation = false

    enum Mode { case signIn, signUp }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RadialGradient(
                colors: [Theme.accent.opacity(0.2), Theme.background],
                center: .center, startRadius: 10, endRadius: 600
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text(L10n.string("APP FOR NETFLIX", languageCode: settings.languageCode))
                        .wordmarkStyle(size: 22)
                    Text(L10n.string(
                        mode == .signIn ? "Welcome back" : "Create your account",
                        languageCode: settings.languageCode
                    ))
                        .font(Theme.Font.body(13))
                        .foregroundStyle(Theme.textSecondary)
                }

                VStack(spacing: 12) {
                    if mode == .signUp {
                        field(placeholder: L10n.string("Full name", languageCode: settings.languageCode), text: $name)
                    }

                    field(placeholder: L10n.string("Email address", languageCode: settings.languageCode), text: $email)

                    passwordField(
                        placeholder: L10n.string("Password", languageCode: settings.languageCode),
                        text: $password,
                        isVisible: $isPasswordVisible
                    )
                }
                .frame(width: 320)

                if mode == .signIn {
                    Button(L10n.string("Forgot Password?", languageCode: settings.languageCode)) {
                        Task {
                            await auth.sendPasswordReset(email: email)
                            isShowingResetConfirmation = auth.lastNoticeMessage != nil
                        }
                    }
                    .buttonStyle(.plain)
                    .font(Theme.Font.caption(12))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 320, alignment: .trailing)
                    .disabled(auth.isProcessing)
                }

                if let error = auth.lastErrorMessage {
                    Text(error)
                        .font(Theme.Font.caption(12))
                        .foregroundStyle(Theme.danger)
                        .frame(width: 320, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }

                Button {
                    Task { await submit() }
                } label: {
                    HStack(spacing: 8) {
                        if auth.isProcessing {
                            ProgressView()
                                .tint(.white)
                                .controlSize(.small)
                        }
                        Text(L10n.string(
                            mode == .signIn ? "Sign In" : "Create Account",
                            languageCode: settings.languageCode
                        ))
                            .font(Theme.Font.semibold(15))
                    }
                    .frame(width: 320)
                    .padding(.vertical, 13)
                    .background(Theme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(auth.isProcessing)
                .opacity(auth.isProcessing ? 0.7 : 1)

                Button {
                    auth.lastErrorMessage = nil
                    isPasswordVisible = false
                    mode = mode == .signIn ? .signUp : .signIn
                } label: {
                    Text(L10n.string(
                        mode == .signIn
                            ? "Don't have an account? Sign Up"
                            : "Already have an account? Sign In",
                        languageCode: settings.languageCode
                    ))
                        .font(Theme.Font.caption(13))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                auth.lastErrorMessage = nil
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 20)
            .padding(.top, 20)
        }
        .frame(minWidth: 480, minHeight: 560)
        .alert(
            L10n.string("Password Reset", languageCode: settings.languageCode),
            isPresented: $isShowingResetConfirmation
        ) {
            Button(L10n.string("OK", languageCode: settings.languageCode), role: .cancel) {
                auth.lastErrorMessage = nil
                auth.lastNoticeMessage = nil
            }
        } message: {
            Text(L10n.string("Password reset email sent.", languageCode: settings.languageCode))
        }
    }

    private func field(placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(Theme.Font.body(14))
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(Theme.textPrimary)
    }

    private func passwordField(placeholder: String, text: Binding<String>, isVisible: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Group {
                if isVisible.wrappedValue {
                    TextField(placeholder, text: text)
                } else {
                    SecureField(placeholder, text: text)
                }
            }
            .textFieldStyle(.plain)
            .font(Theme.Font.body(14))
            .foregroundStyle(Theme.textPrimary)

            Button {
                isVisible.wrappedValue.toggle()
            } label: {
                Image(systemName: isVisible.wrappedValue ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func submit() async {
        let succeeded: Bool
        switch mode {
        case .signIn:
            await auth.signIn(email: email, password: password, settings: settings)
            succeeded = auth.isAuthenticated && auth.lastErrorMessage == nil
        case .signUp:
            succeeded = await auth.signUp(
                name: name,
                email: email,
                password: password,
                settings: settings
            )
        }

        if succeeded {
            dismiss()
        }
    }
}

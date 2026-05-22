import DiscordKit
import SwiftUI

struct IOSAuthView: View {
    @Environment(IOSAppModel.self) private var model

    var body: some View {
        @Bindable var authFlow = model.authFlow

        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection

                    Picker("Login Method", selection: $authFlow.selectedPane) {
                        ForEach(AuthPane.allCases) { pane in
                            Text(pane.title).tag(pane)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    switch authFlow.selectedPane {
                    case .login:
                        passwordForm
                    case .webLogin:
                        webLoginForm
                    }

                    if authFlow.showsMFAChallenge {
                        mfaChallengeCard
                    }

                    if authFlow.showsCaptchaChallenge {
                        captchaChallengeCard
                    }

                    if let error = authFlow.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Text(authFlow.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("NotDiscordBut")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)

            Text("Sign In")
                .font(.title2.weight(.bold))
        }
        .padding(.top, 20)
    }

    private var passwordForm: some View {
        @Bindable var authFlow = model.authFlow

        return VStack(spacing: 12) {
            TextField("Email or Phone", text: $authFlow.login)
                .textContentType(.username)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                #endif
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.12)))

            SecureField("Password", text: $authFlow.password)
                .textContentType(.password)
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.12)))

            Button {
                Task { await model.signIn() }
            } label: {
                HStack {
                    if authFlow.isSubmitting {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Sign In")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(authFlow.canSubmitLogin ? Color.accentColor : Color.gray)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(!authFlow.canSubmitLogin)
        }
        .padding(.horizontal)
    }

    private var webLoginForm: some View {
        @Bindable var authFlow = model.authFlow

        return VStack(spacing: 12) {
            Text("Paste a Discord token from a web browser session:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("Token", text: $authFlow.login)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.12)))

            Button {
                Task { await model.importWebLoginToken(authFlow.login) }
            } label: {
                Text("Import Token")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(authFlow.login.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
    }

    private var mfaChallengeCard: some View {
        @Bindable var authFlow = model.authFlow

        return VStack(spacing: 12) {
            Text("Multi-Factor Authentication")
                .font(.headline)

            if authFlow.availableMFAAuthenticators.count > 1 {
                Picker("Method", selection: $authFlow.preferredMFA) {
                    ForEach(authFlow.availableMFAAuthenticators, id: \.self) { auth in
                        Text(auth.displayLabel).tag(auth)
                    }
                }
                .pickerStyle(.segmented)
            }

            if authFlow.selectedMFARequiresCodeEntry {
                TextField("Verification Code", text: $authFlow.mfaCode)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .textContentType(.oneTimeCode)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.12)))

                Button {
                    Task { await model.completeMFA() }
                } label: {
                    Text("Verify")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(authFlow.canSubmitMFA ? Color.accentColor : Color.gray)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(!authFlow.canSubmitMFA)
            }

            if authFlow.preferredMFA == .sms {
                Button("Send SMS Code") {
                    Task { await model.sendMFASMS() }
                }

                if let phone = authFlow.sentSMSPhone {
                    Text("Code sent to \(phone)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.12)))
        .padding(.horizontal)
    }

    private var captchaChallengeCard: some View {
        @Bindable var authFlow = model.authFlow

        return VStack(spacing: 12) {
            Text("Captcha Required")
                .font(.headline)

            TextField("Captcha Solution", text: $authFlow.captchaSolution)
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.12)))

            Button {
                Task { await model.submitCaptcha() }
            } label: {
                Text("Submit")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(authFlow.canSubmitCaptcha ? Color.accentColor : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(!authFlow.canSubmitCaptcha)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.12)))
        .padding(.horizontal)
    }
}

private extension MFAAuthenticatorType {
    var displayLabel: String {
        switch self {
        case .totp:
            return "Authenticator"
        case .sms:
            return "SMS"
        case .backup:
            return "Backup"
        case .webauthn:
            return "Security Key"
        }
    }
}

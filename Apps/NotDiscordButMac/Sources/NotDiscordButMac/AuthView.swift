import DiscordKit
import Observation
import SwiftUI

struct AuthView: View {
    @Bindable var model: AuthFlowModel
    let launchProfile: AppLaunchProfile
    let onSignIn: () -> Void
    let onImportWebLoginToken: (String) -> Void
    let onCompleteMFA: () -> Void
    let onSendMFASMS: () -> Void
    let onSubmitCaptcha: () -> Void
    let onResolveCaptcha: (String) -> Void
    let onStartPasswordless: () -> Void
    let onPrepareRemoteAuth: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            AuthSummaryPane(
                launchProfile: launchProfile,
                statusMessage: model.statusMessage,
                pendingMFAChallenge: model.pendingMFAChallenge,
                pendingCaptchaChallenge: model.pendingCaptchaChallenge
            )

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if model.showsMFAChallenge {
                        mfaChallengeCard
                    } else if model.showsCaptchaChallenge {
                        captchaChallengeCard
                    } else {
                        credentialsCard
                    }

                    if let errorMessage = model.errorMessage {
                        ContentUnavailableView {
                            Label("Authentication Error", systemImage: "exclamationmark.triangle")
                        } description: {
                            Text(errorMessage)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(.background)
    }

    private var credentialsCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Sign In")
                .font(.largeTitle.weight(.semibold))

            Text("Use the same account login flow the desktop client would use, then continue into dedicated server windows.")
                .foregroundStyle(.secondary)

            Picker("Mode", selection: $model.selectedPane) {
                ForEach(availablePanes) { pane in
                    Text(pane.title).tag(pane)
                }
            }
            .pickerStyle(.segmented)

            Group {
                switch model.selectedPane {
                case .login:
                    passwordLoginForm
                case .webLogin:
                    webLoginForm
                case .passwordless:
                    passwordlessForm
                case .remoteAuth:
                    remoteAuthForm
                }
            }
        }
        .frame(maxWidth: 520, alignment: .leading)
    }

    private var passwordLoginForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Email or phone", text: $model.login)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)

            SecureField("Password", text: $model.password)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)

            Button("Sign In", action: onSignIn)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!model.canSubmitLogin)
        }
    }

    private var passwordlessForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Passwordless is wired to the challenge-start endpoint. The final platform WebAuthn credential exchange is still a follow-up step.")
                .foregroundStyle(.secondary)

            TextField("Email or login", text: $model.passwordlessLogin)
                .textFieldStyle(.roundedBorder)
                .controlSize(.large)

            Button("Start Passwordless Login", action: onStartPasswordless)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!model.canStartPasswordless)
        }
    }

    private var webLoginForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Use Discord’s own web login as a fallback for password, captcha, or MFA-heavy flows, then import the resulting session into the app.")
                .foregroundStyle(.secondary)

            Text("Embedded passkey support for discord.com may still be limited by Apple’s WebAuthn rules for in-app web views, so this fallback is mainly for standard web login flows.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            DiscordWebLoginView(
                loginURL: URL(string: "https://discord.com/login")!,
                onAuthenticated: onImportWebLoginToken
            )
            .frame(minHeight: 560)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var remoteAuthForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Prepare a desktop handoff and use the generated fingerprint with another client.")
                .foregroundStyle(.secondary)

            Button("Prepare Remote Auth", action: onPrepareRemoteAuth)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            if let bootstrap = model.remoteAuthBootstrap {
                LabeledContent("Fingerprint", value: bootstrap.fingerprint.rawValue)
                LabeledContent("Public Key", value: bootstrap.encodedPublicKey)
                    .lineLimit(3)
                    .textSelection(.enabled)
                    .truncationMode(.middle)
            }
        }
    }

    private var mfaChallengeCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Multi-Factor Authentication")
                .font(.largeTitle.weight(.semibold))

            Text("Discord accepted the account password and is waiting for additional verification.")
                .foregroundStyle(.secondary)

            Picker("Authenticator", selection: $model.preferredMFA) {
                ForEach(model.availableMFAAuthenticators, id: \.self) { authenticator in
                    Text(authenticatorTitle(authenticator)).tag(authenticator)
                }
            }

            if model.selectedMFARequiresCodeEntry {
                TextField(verificationPlaceholder, text: $model.mfaCode)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
            } else {
                ContentUnavailableView {
                    Label("Passkey Verification", systemImage: "person.badge.key")
                } description: {
                    Text("This account also supports WebAuthn. A native passkey bridge is the next auth step; for now, switch to a code-based authenticator in the picker.")
                }
            }

            if let challenge = model.pendingMFAChallenge,
               let request = challenge.webauthnRequest,
               model.preferredMFA == .webauthn {
                GroupBox("WebAuthn Request") {
                    Text(request)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if model.preferredMFA == .sms {
                HStack(spacing: 12) {
                    Button("Send SMS Code", action: onSendMFASMS)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(model.isSubmitting)

                    if let sentSMSPhone = model.sentSMSPhone {
                        Text("Last sent to \(sentSMSPhone)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button("Complete MFA", action: onCompleteMFA)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!model.canSubmitMFA)

            if let challenge = model.pendingMFAChallenge {
                LabeledContent("Ticket", value: challenge.ticket.rawValue)
                    .font(.footnote)
                if let loginInstanceID = challenge.loginInstanceID {
                    LabeledContent("Login Instance", value: loginInstanceID)
                        .font(.footnote)
                }
            }
        }
        .frame(maxWidth: 560, alignment: .leading)
    }

    private var captchaChallengeCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Captcha Required")
                .font(.largeTitle.weight(.semibold))

            Text("Discord challenged this sign-in. Solve the captcha below, or paste a solved token manually and retry.")
                .foregroundStyle(.secondary)

            if let challenge = model.pendingCaptchaChallenge {
                if challenge.siteKey != nil {
                    CaptchaTokenWebView(
                        challenge: challenge,
                        onSolved: onResolveCaptcha
                    )
                    .frame(minHeight: 320)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 14) {
                    TextField("Captcha solution token", text: $model.captchaSolution)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)

                    Button("Continue Sign In", action: onSubmitCaptcha)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!model.canSubmitCaptcha)
                }

                GroupBox("Challenge Details") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Service", value: challenge.service.rawValue)
                        LabeledContent("Site Key", value: challenge.siteKey ?? "missing")
                        LabeledContent("Session ID", value: challenge.sessionID ?? "none")
                        LabeledContent("Request Token", value: challenge.requestToken ?? "none")
                        if let requestData = challenge.requestData {
                            LabeledContent("Request Data", value: requestData)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                    }
                    .font(.footnote)
                }
            }
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    private func authenticatorTitle(_ authenticator: MFAAuthenticatorType) -> String {
        switch authenticator {
        case .totp:
            return "Authenticator App"
        case .sms:
            return "SMS"
        case .backup:
            return "Backup Code"
        case .webauthn:
            return "WebAuthn"
        }
    }

    private var verificationPlaceholder: String {
        switch model.preferredMFA {
        case .totp:
            return "Authenticator code"
        case .sms:
            return "SMS verification code"
        case .backup:
            return "Backup code"
        case .webauthn:
            return "Verification code"
        }
    }

    private var availablePanes: [AuthPane] {
        guard launchProfile == .live else {
            return AuthPane.allCases.filter { $0 != .webLogin }
        }

        return AuthPane.allCases
    }
}

private struct AuthSummaryPane: View {
    let launchProfile: AppLaunchProfile
    let statusMessage: String
    let pendingMFAChallenge: MFALoginChallenge?
    let pendingCaptchaChallenge: CaptchaChallenge?

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("NotDiscordBut")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                Text(launchProfile.label)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(statusMessage)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                AuthFeatureRow(
                    title: "Native Multiwindow",
                    detail: "Open every server in its own window with independent channel selection."
                )
                AuthFeatureRow(
                    title: "Intentional State Flow",
                    detail: "Auth, store, and projections stay separate so the UI renders stable read models."
                )
                AuthFeatureRow(
                    title: "Challenge-Aware Login",
                    detail: challengeSummary
                )
            }

            Spacer(minLength: 0)
        }
        .padding(32)
        .frame(minWidth: 280, idealWidth: 320, maxWidth: 340, maxHeight: .infinity, alignment: .topLeading)
        .background(.thinMaterial)
    }

    private var challengeSummary: String {
        if pendingMFAChallenge != nil {
            return "The current login is waiting for MFA verification."
        }
        if pendingCaptchaChallenge != nil {
            return "The current login is waiting for a captcha solution."
        }
        return "Login can transition into MFA or captcha instead of collapsing into a generic error state."
    }
}

private struct AuthFeatureRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

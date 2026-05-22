import DiscordKit
import Foundation
import Observation

enum AuthPane: String, CaseIterable, Identifiable {
    case login
    case webLogin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .login:
            return "Password"
        case .webLogin:
            return "Web Login"
        }
    }
}

@MainActor
@Observable
final class AuthFlowModel {
    var selectedPane: AuthPane = .login
    var login: String = ""
    var password: String = ""
    var mfaCode: String = ""
    var captchaSolution: String = ""
    var preferredMFA: MFAAuthenticatorType = .totp
    var pendingMFAChallenge: MFALoginChallenge?
    var pendingCaptchaChallenge: CaptchaChallenge?
    var sentSMSPhone: String?
    var statusMessage: String = "Sign in with a Discord account."
    var errorMessage: String?
    var isSubmitting = false

    var canSubmitLogin: Bool {
        !login.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty && !isSubmitting
    }

    var canSubmitMFA: Bool {
        guard pendingMFAChallenge != nil, !isSubmitting else {
            return false
        }
        guard preferredMFA.requiresTextCode else {
            return false
        }
        return !mfaCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canSubmitCaptcha: Bool {
        pendingCaptchaChallenge != nil && !captchaSolution.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    var availableMFAAuthenticators: [MFAAuthenticatorType] {
        guard let pendingMFAChallenge else {
            return MFAAuthenticatorType.allCases
        }
        return MFAAuthenticatorType.recommendedLoginOrder.filter { pendingMFAChallenge.authenticators.contains($0) }
    }

    var showsMFAChallenge: Bool {
        pendingMFAChallenge != nil
    }

    var showsCaptchaChallenge: Bool {
        pendingCaptchaChallenge != nil
    }

    var selectedMFARequiresCodeEntry: Bool {
        preferredMFA.requiresTextCode
    }

    func signIn(using client: DiscordClient) async -> Bool {
        guard canSubmitLogin else {
            return false
        }
        return await performLogin(using: client)
    }

    func submitCaptcha(using client: DiscordClient) async -> Bool {
        guard let pendingCaptchaChallenge, canSubmitCaptcha else {
            return false
        }
        return await performLogin(
            using: client,
            captchaAnswer: pendingCaptchaChallenge.answer(captchaSolution.trimmingCharacters(in: .whitespacesAndNewlines))
        )
    }

    func completeMFA(using client: DiscordClient) async -> Bool {
        guard let challenge = pendingMFAChallenge, canSubmitMFA else {
            return false
        }

        isSubmitting = true
        errorMessage = nil
        statusMessage = "Completing MFA challenge…"
        defer { isSubmitting = false }

        do {
            _ = try await client.auth.completeMFA(
                ticket: challenge.ticket,
                authenticator: preferredMFA,
                code: mfaCode,
                loginInstanceID: challenge.loginInstanceID
            )
            clearChallenges()
            password = ""
            mfaCode = ""
            sentSMSPhone = nil
            statusMessage = "MFA accepted."
            return true
        } catch {
            errorMessage = describe(error)
            statusMessage = "MFA verification failed."
            return false
        }
    }

    func sendMFASMS(using client: DiscordClient) async {
        guard let challenge = pendingMFAChallenge, preferredMFA == .sms, !isSubmitting else {
            return
        }

        isSubmitting = true
        errorMessage = nil
        statusMessage = "Sending an SMS verification code…"
        defer { isSubmitting = false }

        do {
            let response = try await client.auth.sendMFASMS(ticket: challenge.ticket)
            sentSMSPhone = response.phone
            statusMessage = "An SMS code was sent to \(response.phone)."
        } catch {
            errorMessage = describe(error)
            statusMessage = "Sending the SMS code failed."
        }
    }

    func resetForSignedOut() {
        password = ""
        mfaCode = ""
        captchaSolution = ""
        sentSMSPhone = nil
        clearChallenges()
        statusMessage = "Session cleared."
        errorMessage = nil
    }

    private func performLogin(
        using client: DiscordClient,
        captchaAnswer: CaptchaAnswer? = nil
    ) async -> Bool {
        isSubmitting = true
        errorMessage = nil
        statusMessage = captchaAnswer == nil
            ? "Contacting Discord authentication…"
            : "Retrying login with captcha…"
        defer { isSubmitting = false }

        do {
            let result = try await client.auth.login(
                credentials: LoginCredentials(login: login, password: password),
                captchaAnswer: captchaAnswer
            )

            switch result {
            case .authenticated:
                clearChallenges()
                password = ""
                mfaCode = ""
                captchaSolution = ""
                statusMessage = "Session established."
                return true

            case let .challenge(.mfa(challenge)):
                pendingMFAChallenge = challenge
                pendingCaptchaChallenge = nil
                captchaSolution = ""
                sentSMSPhone = nil
                preferredMFA = challenge.recommendedAuthenticator ?? .totp
                password = ""
                statusMessage = "Additional verification is required for this account."
                return false

            case let .challenge(.captcha(challenge)):
                pendingCaptchaChallenge = challenge
                pendingMFAChallenge = nil
                captchaSolution = ""
                statusMessage = "Discord requires a captcha before continuing."
                return false
            }
        } catch {
            errorMessage = describe(error)
            statusMessage = "Sign in failed."
            return false
        }
    }

    private func clearChallenges() {
        pendingMFAChallenge = nil
        pendingCaptchaChallenge = nil
    }

    private func describe(_ error: some Error) -> String {
        if let localized = (error as? LocalizedError)?.errorDescription {
            return localized
        }
        return String(describing: error)
    }
}

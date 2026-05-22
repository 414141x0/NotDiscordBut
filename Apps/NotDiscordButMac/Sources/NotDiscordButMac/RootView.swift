import DiscordKit
import Observation
import SwiftUI

struct RootView: View {
    @Bindable var model: AppModel

    var body: some View {
        Group {
            switch model.phase {
            case .launching:
                progressSurface
            case .signedOut:
                signedOutContent
            case .connected:
                connectedContent
            case let .failed(message):
                failureSurface(message: message)
            }
        }
        .task {
            await model.bootstrap()
        }
    }

    private var signedOutContent: some View {
        VStack(spacing: 18) {
            AuthView(
                model: model.authFlow,
                launchProfile: model.launchProfile,
                onSignIn: {
                    Task {
                        await model.signIn()
                    }
                },
                onImportWebLoginToken: { token in
                    Task {
                        await model.importWebLoginToken(token)
                    }
                },
                onCompleteMFA: {
                    Task {
                        await model.completeMFA()
                    }
                },
                onSendMFASMS: {
                    Task {
                        await model.sendMFASMS()
                    }
                },
                onSubmitCaptcha: {
                    Task {
                        await model.submitCaptcha()
                    }
                },
                onResolveCaptcha: { solution in
                    Task {
                        await model.resolveCaptcha(solution)
                    }
                },
                onStartPasswordless: {
                    Task {
                        await model.startPasswordless()
                    }
                },
                onPrepareRemoteAuth: {
                    model.prepareRemoteAuthentication()
                }
            )

            if let runtimeNotice = model.settings.runtimeNotice {
                Text(runtimeNotice)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
            }
        }
    }

    private var connectedContent: some View {
        WorkspaceView(model: model)
    }

    private var progressSurface: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.09, green: 0.11, blue: 0.18), Color(red: 0.12, green: 0.16, blue: 0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 18) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text("NotDiscordBut")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(model.statusMessage)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.78))
            }
            .padding(36)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
    }

    private func failureSurface(message: String) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.2, green: 0.08, blue: 0.08), Color(red: 0.1, green: 0.08, blue: 0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 14) {
                Text("Startup Failed")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text(model.statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .frame(maxWidth: 560, alignment: .leading)
            .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
    }
}

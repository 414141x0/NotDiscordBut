enum AppPhase: Equatable {
    case launching
    case signedOut
    case connected
    case failed(String)
}

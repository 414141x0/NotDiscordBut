import Foundation
import DiscordPersistence
import DiscordPrimitives

public actor StoreRuntime {
    private var state: NormalizedState
    private let database: SQLiteDatabase
    private var continuations: [UUID: AsyncStream<NormalizedState>.Continuation] = [:]

    public init(database: SQLiteDatabase, initialState: NormalizedState = .empty) {
        self.database = database
        self.state = initialState
    }

    public func bootstrap() async throws {
        try await database.applyMigrations()
        if let persisted: NormalizedState = try await database.loadSnapshot(forKey: "normalized-state") {
            state = persisted
        }
    }

    public func snapshot() -> NormalizedState {
        state
    }

    public func apply(_ action: StateReducerAction) async throws {
        StateReducer.apply(action, to: &state)
        try await database.saveSnapshot(state, forKey: "normalized-state")
        broadcast()
    }

    public func reset() async throws {
        state = .empty
        try await database.saveSnapshot(state, forKey: "normalized-state")
        broadcast()
    }

    public func subscribe() -> AsyncStream<NormalizedState> {
        let id = UUID()
        return AsyncStream { continuation in
            continuation.yield(state)
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task {
                    await self?.removeContinuation(id: id)
                }
            }
        }
    }

    private func removeContinuation(id: UUID) {
        continuations.removeValue(forKey: id)
    }

    private func broadcast() {
        for continuation in continuations.values {
            continuation.yield(state)
        }
    }
}

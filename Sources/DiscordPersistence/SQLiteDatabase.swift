import Foundation
import SQLite3
import DiscordPrimitives

public enum SQLiteDatabaseError: Error, Sendable, Hashable {
    case openFailed(String)
    case executionFailed(String)
    case prepareFailed(String)
    case bindFailed(String)
    case stepFailed(String)
    case encodingFailed(String)
    case decodingFailed(String)
}

public actor SQLiteDatabase {
    private let path: String
    private nonisolated(unsafe) let handle: OpaquePointer?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(path: String) throws(SQLiteDatabaseError) {
        self.path = path

        var handle: OpaquePointer?
        if sqlite3_open(path, &handle) != SQLITE_OK {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(handle)
            throw .openFailed(message)
        }

        self.handle = handle
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    deinit {
        sqlite3_close(handle)
    }

    public static func temporary() throws(SQLiteDatabaseError) -> SQLiteDatabase {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        return try SQLiteDatabase(path: url.path)
    }

    public func applyMigrations() throws(SQLiteDatabaseError) {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS schema_version (
                version INTEGER NOT NULL
            );
            """
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS metadata (
                key TEXT PRIMARY KEY,
                value TEXT
            );
            """
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS snapshots (
                key TEXT PRIMARY KEY,
                value BLOB NOT NULL
            );
            """
        )

        if try schemaVersion() == 0 {
            try execute("INSERT INTO schema_version(version) VALUES (1);")
        }
    }

    public func schemaVersion() throws(SQLiteDatabaseError) -> Int {
        guard let handle else {
            throw .openFailed(path)
        }

        let sql = "SELECT version FROM schema_version ORDER BY rowid DESC LIMIT 1;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw .prepareFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        switch sqlite3_step(statement) {
        case SQLITE_ROW:
            return Int(sqlite3_column_int(statement, 0))
        case SQLITE_DONE:
            return 0
        default:
            throw .stepFailed(lastErrorMessage())
        }
    }

    public func putMetadata(_ value: String?, forKey key: String) throws(SQLiteDatabaseError) {
        let sql = "INSERT INTO metadata(key, value) VALUES(?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value;"
        try withStatement(sql) { (statement: OpaquePointer?) throws(SQLiteDatabaseError) in
            guard sqlite3_bind_text(statement, 1, key, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
                throw .bindFailed(lastErrorMessage())
            }

            if let value {
                guard sqlite3_bind_text(statement, 2, value, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
                    throw .bindFailed(lastErrorMessage())
                }
            } else {
                guard sqlite3_bind_null(statement, 2) == SQLITE_OK else {
                    throw .bindFailed(lastErrorMessage())
                }
            }

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw .stepFailed(lastErrorMessage())
            }
        }
    }

    public func metadataValue(forKey key: String) throws(SQLiteDatabaseError) -> String? {
        let sql = "SELECT value FROM metadata WHERE key = ? LIMIT 1;"
        return try withStatement(sql) { (statement: OpaquePointer?) throws(SQLiteDatabaseError) in
            guard sqlite3_bind_text(statement, 1, key, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
                throw .bindFailed(lastErrorMessage())
            }

            switch sqlite3_step(statement) {
            case SQLITE_ROW:
                guard let text = sqlite3_column_text(statement, 0) else {
                    return nil
                }
                return String(cString: text)
            case SQLITE_DONE:
                return nil
            default:
                throw .stepFailed(lastErrorMessage())
            }
        }
    }

    public func saveSnapshot<Value>(_ value: Value, forKey key: String) throws(SQLiteDatabaseError) where Value: Encodable & Sendable {
        let data: Data
        do {
            data = try encoder.encode(value)
        } catch {
            throw .encodingFailed(error.localizedDescription)
        }

        let sql = "INSERT INTO snapshots(key, value) VALUES(?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value;"
        try withStatement(sql) { (statement: OpaquePointer?) throws(SQLiteDatabaseError) in
            guard sqlite3_bind_text(statement, 1, key, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
                throw .bindFailed(lastErrorMessage())
            }

            let count = Int32(data.count)
            let status = data.withUnsafeBytes { buffer in
                sqlite3_bind_blob(statement, 2, buffer.baseAddress, count, SQLITE_TRANSIENT)
            }
            guard status == SQLITE_OK else {
                throw .bindFailed(lastErrorMessage())
            }

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw .stepFailed(lastErrorMessage())
            }
        }
    }

    public func loadSnapshot<Value>(forKey key: String, as type: Value.Type = Value.self) throws(SQLiteDatabaseError) -> Value? where Value: Decodable & Sendable {
        let sql = "SELECT value FROM snapshots WHERE key = ? LIMIT 1;"
        return try withStatement(sql) { (statement: OpaquePointer?) throws(SQLiteDatabaseError) in
            guard sqlite3_bind_text(statement, 1, key, -1, SQLITE_TRANSIENT) == SQLITE_OK else {
                throw .bindFailed(lastErrorMessage())
            }

            switch sqlite3_step(statement) {
            case SQLITE_ROW:
                guard let blob = sqlite3_column_blob(statement, 0) else {
                    return nil
                }
                let length = Int(sqlite3_column_bytes(statement, 0))
                let data = Data(bytes: blob, count: length)
                do {
                    return try decoder.decode(Value.self, from: data)
                } catch {
                    throw .decodingFailed(error.localizedDescription)
                }
            case SQLITE_DONE:
                return nil
            default:
                throw .stepFailed(lastErrorMessage())
            }
        }
    }

    private func execute(_ sql: String) throws(SQLiteDatabaseError) {
        guard let handle else {
            throw .openFailed(path)
        }

        guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else {
            throw .executionFailed(lastErrorMessage())
        }
    }

    private func withStatement<Result>(
        _ sql: String,
        _ body: (OpaquePointer?) throws(SQLiteDatabaseError) -> Result
    ) throws(SQLiteDatabaseError) -> Result {
        guard let handle else {
            throw .openFailed(path)
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw .prepareFailed(lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        return try body(statement)
    }

    private func lastErrorMessage() -> String {
        guard let handle, let message = sqlite3_errmsg(handle) else {
            return "unknown sqlite error"
        }
        return String(cString: message)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

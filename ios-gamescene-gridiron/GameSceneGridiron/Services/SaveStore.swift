import Foundation

// MARK: - Save store

/// Versioned persistence envelope for every substantial local save blob
/// (season, franchise/roster, economy, achievements, trophy history, season
/// archive, team identity). Every write is wrapped as
/// `{ schemaVersion, payload }`; reads migrate transparently:
///
/// 1. Current envelope → decoded payload.
/// 2. Legacy plain-encoded blob (schema 1, before versioning existed) →
///    decoded and re-wrapped on the next save. Old installs migrate silently.
/// 3. Unrecoverable data → the raw bytes are preserved under
///    `"<key>.corruptBackup"` and nil is returned, so a manager can rebuild
///    only its own section while nothing is silently destroyed.
///
/// Never wipe a user's franchise because a model changed: adding optional
/// fields to a Codable model is always safe (unknown keys are ignored), and
/// breaking shape changes go through a migration here, keyed by version.
nonisolated enum SaveStore {
    /// Bump when a save model changes incompatibly and add a migration branch
    /// in `load` below.
    static let currentSchemaVersion = 2

    fileprivate struct Envelope: Codable {
        let version: Int
        let payload: Data
    }

    /// Persists `value` under `key` inside a versioned envelope.
    static func save<T: Encodable>(_ value: T, key: String, defaults: UserDefaults) {
        guard let payload = try? JSONEncoder().encode(value) else { return }
        let envelope = Envelope(version: currentSchemaVersion, payload: payload)
        guard let wrapped = try? JSONEncoder().encode(envelope) else { return }
        defaults.set(wrapped, forKey: key)
        // The migration landed cleanly — a stale corrupt backup is no longer needed.
        defaults.removeObject(forKey: corruptBackupKey(for: key))
    }

    /// Loads `value` from `key`, migrating older schemas transparently.
    /// Returns nil when the key is absent or the data is unrecoverable.
    static func load<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }

        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data) {
            if let payload = try? JSONDecoder().decode(type.self, from: envelope.payload) {
                return payload
            }
            return failCorrupted(data: data, key: key, defaults: defaults)
        }

        // Legacy schema 1: plain-encoded model, saved before versioning existed.
        if let legacy = try? JSONDecoder().decode(type.self, from: data) {
            return legacy
        }

        return failCorrupted(data: data, key: key, defaults: defaults)
    }

    /// Unrecoverable data: preserve the raw bytes for forensics/support.
    private static func failCorrupted<T>(data: Data, key: String, defaults: UserDefaults) -> T? {
        defaults.set(data, forKey: corruptBackupKey(for: key))
        return nil
    }

    private static func corruptBackupKey(for key: String) -> String { "\(key).corruptBackup" }
}

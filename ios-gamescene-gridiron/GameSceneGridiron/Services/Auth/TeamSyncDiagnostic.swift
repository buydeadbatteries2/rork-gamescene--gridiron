import Foundation
import Supabase

/// Allowlisted diagnostics only: never retain server messages, hints, response bodies or URLs.
nonisolated enum TeamSyncDiagnostic {
    static func describe(_ error: Error) -> String {
        if let error = error as? PostgrestError {
            return databaseCode(error.code ?? "")
        }
        if error is DecodingError { return "decoding: PostgREST JSON does not match Row" }
        if let error = error as? URLError { return "network: URL error \(error.code.rawValue)" }
        return "other: unclassified error (details redacted)"
    }

    static func databaseCode(_ code: String) -> String {
        switch code {
        case "42P01", "PGRST205", "PGRST200", "PGRST202":
            return "table/schema cache: \(code)"
        case "42501": return "RLS/permission denied: \(code)"
        case "PGRST301", "PGRST302", "PGRST303", "28000", "28P01":
            return "authentication/JWT: \(code)"
        case "42703", "42804", "22P02", "22003", "PGRST204":
            return "column/type mismatch: \(code)"
        case "PGRST000", "PGRST001", "PGRST002", "PGRST003":
            return "database connectivity: \(code)"
        default:
            // Codes are structural identifiers, but still reject arbitrary input.
            let safe = code.range(of: "^(?:[0-9A-Z]{5}|PGRST[0-9]{3})$", options: .regularExpression) != nil
            return "other database error: \(safe ? code : "unknown code")"
        }
    }
}

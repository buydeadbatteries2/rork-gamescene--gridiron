#if DEBUG
import Foundation

/// Observes the SDK's actual transport request, not a reconstructed URL.
/// No headers or request payloads are ever logged. Release builds exclude this file.
nonisolated final class VersusDiagnosticProtocol: URLProtocol, @unchecked Sendable {
    private var forwardingTask: URLSessionDataTask?
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.path.contains("submit-versus") == true
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let id = UUID().uuidString
        VersusSubmissionDiagnostics.capture.clear()
        print("⟦versus-submit \(id)⟧ configured_host=\(SupabaseClientProvider.publicConfigURL.flatMap(URL.init(string:))?.host ?? "unset") method=\(request.httpMethod ?? "unknown") url=\(VersusSubmissionDiagnostics.safeURL(request.url)) function_path=\(request.url?.path ?? "unknown")")
        // Shared session does not install this protocol: no recursion. Forward the
        // original request unchanged, including its body and authentication.
        forwardingTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            if let response {
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                if status >= 400 {
                    let body = VersusSubmissionDiagnostics.sanitizedBody(data ?? Data())
                    let fields = (try? JSONSerialization.jsonObject(with: Data(body.utf8))) as? [String: String]
                    let code = fields?["reason"] ?? fields?["code"] ?? fields?["error"] ?? "not present"
                    let host = SupabaseClientProvider.publicConfigURL.flatMap(URL.init(string:))?.host ?? "unset"
                    VersusSubmissionDiagnostics.capture.set("Supabase host: \(host)\nFinal request URL: \(VersusSubmissionDiagnostics.safeURL(response.url))\nHTTP status: \(status)\nSanitized response body: \(body)\nParsed error code: \(code)")
                }
                print("⟦versus-submit \(id)⟧ final_url=\(VersusSubmissionDiagnostics.safeURL(response.url)) status=\(status) sanitized_body_and_parsed_codes=\(VersusSubmissionDiagnostics.sanitizedBody(data ?? Data()))")
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data { self.client?.urlProtocol(self, didLoad: data) }
            if let error {
                print("⟦versus-submit \(id)⟧ transport_failure; details omitted")
                self.client?.urlProtocol(self, didFailWithError: error)
            } else {
                self.client?.urlProtocolDidFinishLoading(self)
            }
        }
        forwardingTask?.resume()
    }
    override func stopLoading() { forwardingTask?.cancel() }
}

/// Memory-only, sanitized latest failure. Never persists credentials or raw data.
nonisolated final class VersusDiagnosticCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?
    func clear() { lock.lock(); defer { lock.unlock() }; value = nil }
    func set(_ text: String) { lock.lock(); defer { lock.unlock() }; value = text }
    func read() -> String? { lock.lock(); defer { lock.unlock() }; return value }
}

nonisolated enum VersusSubmissionDiagnostics {
    static let capture = VersusDiagnosticCapture()
    static func safeURL(_ url: URL?) -> String {
        guard let url, var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return "unknown" }
        parts.user = nil
        parts.password = nil
        parts.query = nil
        parts.fragment = nil
        return parts.string ?? "unknown"
    }

    /// Deliberately allowlists known diagnostic fields and values. Unknown text,
    /// nested objects, tokens, payloads and solutions cannot leak into console logs.
    static func sanitizedBody(_ data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "[non-JSON response omitted; \(data.count) bytes]"
        }
        var safe: [String: String] = [:]
        for key in ["status", "reason", "code", "error", "message"] {
            guard let value = json[key] as? String else { continue }
            let known = ["NOT_FOUND", "not_found", "Function not found", "Requested function was not found", "verified", "rejected", "Unauthorized", "Invalid JWT"]
            let appCode = value.range(of: "^versus_[a-z_]{1,60}$", options: .regularExpression) != nil
            safe[key] = known.contains(value) || appCode ? value : "[redacted]"
        }
        let encoded = (try? JSONSerialization.data(withJSONObject: safe, options: [.sortedKeys])) ?? Data()
        return String(data: encoded, encoding: .utf8) ?? "{}"
    }
}
#endif

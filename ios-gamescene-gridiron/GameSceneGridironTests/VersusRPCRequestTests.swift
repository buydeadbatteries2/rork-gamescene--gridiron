import Foundation
import Supabase
import Testing
@testable import GameSceneGridiron

/// Intercepts the real SDK request; never contacts a Supabase project.
private final class VersusRPCProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://versus-contract.supabase.co/rest/v1/rpc/my_versus_match")
        var data = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                guard count > 0 else { break }
                data.append(contentsOf: buffer.prefix(count))
            }
        }
        let body = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        #expect(body == ["p_match_id": "12345678-ABCD-4ABC-8DEF-123456789ABC"])
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("[]".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class VersusSubmitProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://versus-contract.supabase.co/functions/v1/submit-versus-result")
        let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"code":"NOT_FOUND","message":"Requested function was not found"}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor
struct VersusRPCRequestTests {
    @Test func submitUsesExactFunctionRouteAndPreserves404Fallback() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [VersusSubmitProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let client = SupabaseClient(
            supabaseURL: URL(string: "https://versus-contract.supabase.co")!,
            supabaseKey: "test-only",
            options: SupabaseClientOptions(global: .init(session: session))
        )
        let backend = SupabaseVersusBackend(client: client)
        let result = await backend.submit(VersusResultPayload(
            matchID: UUID(), startedAt: "2026-11-05T00:00:00Z",
            completedAt: "2026-11-05T00:01:00Z", caseResults: [],
            gameVersion: "test", versusProtocol: 1
        ))
        guard case .rejected(let reason) = result else {
            Issue.record("Expected HTTP 404 rejection"); return
        }
        #expect(reason == "rejected_404")
    }

    @Test func diagnosticsDoNotExposeSecretsOrSolutions() {
        let data = Data(#"{"code":"NOT_FOUND","message":"Bearer secret-token","authorization":"secret","expected_solutions":["answer"],"error":{"token":"secret"}}"#.utf8)
        let text = VersusSubmissionDiagnostics.sanitizedBody(data)
        #expect(text.contains("NOT_FOUND"))
        #expect(!text.contains("secret"))
        #expect(!text.contains("answer"))
        #expect(VersusSubmissionDiagnostics.safeURL(URL(string: "https://user:secret@example.com/functions/v1/submit-versus-result?key=secret")) == "https://example.com/functions/v1/submit-versus-result")
    }

    @Test func myMatchUsesExactRPCParameterAndUUID() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [VersusRPCProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let client = SupabaseClient(
            supabaseURL: URL(string: "https://versus-contract.supabase.co")!,
            supabaseKey: "test-only",
            options: SupabaseClientOptions(global: .init(session: session))
        )
        let backend = SupabaseVersusBackend(client: client)
        let result = try await backend.myMatch(matchID: UUID(uuidString: "12345678-abcd-4abc-8def-123456789abc")!)
        #expect(result == nil)
    }
}

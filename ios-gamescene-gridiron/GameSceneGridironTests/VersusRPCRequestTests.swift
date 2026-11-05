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

@MainActor
struct VersusRPCRequestTests {
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

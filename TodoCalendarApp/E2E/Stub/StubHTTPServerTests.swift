//
//  StubHTTPServerTests.swift
//  TodoCalendarAppE2E
//
//  Created by sudo.park on 2026/09/08.
//

import XCTest
import Network


final class StubHTTPServerTests: XCTestCase {
    
    private var server: StubHTTPServer!
    private var port: Int!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        self.server = StubHTTPServer()
        self.port = try self.server.start()
    }
    
    override func tearDown() {
        self.server.stop()
        self.server = nil
        self.port = nil
        super.tearDown()
    }
    
    private func requestBody(_ path: String) throws -> (body: String, statusCode: Int) {
        let url = URL(string: "http://127.0.0.1:\(self.port!)\(path)")!
        var result: (Data, HTTPURLResponse)?
        let expect = expectation(description: "wait response")
        URLSession.shared.dataTask(with: url) { data, response, _ in
            if let data, let response = response as? HTTPURLResponse {
                result = (data, response)
            }
            expect.fulfill()
        }
        .resume()
        wait(for: [expect], timeout: 5)
        
        let unwrapped = try XCTUnwrap(result)
        return (String(decoding: unwrapped.0, as: UTF8.self), unwrapped.1.statusCode)
    }
    
    private func sendChunkedRequest(firstChunk: String, secondChunk: String) throws -> String {
        let connection = NWConnection(
            host: "127.0.0.1", port: NWEndpoint.Port(rawValue: UInt16(self.port))!, using: .tcp
        )
        let expect = expectation(description: "wait chunked response")
        var received: Data?
        
        connection.stateUpdateHandler = { state in
            guard case .ready = state else { return }
            connection.send(content: Data(firstChunk.utf8), completion: .contentProcessed { _ in
                // 서버가 첫 조각만 받고 다시 대기 상태로 들어가도록 간격을 둔다
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
                    connection.send(content: Data(secondChunk.utf8), completion: .idempotent)
                }
            })
            connection.receiveMessage { content, _, _, _ in
                received = content
                expect.fulfill()
            }
        }
        connection.start(queue: .global())
        wait(for: [expect], timeout: 5)
        connection.cancel()
        
        return String(decoding: try XCTUnwrap(received), as: UTF8.self)
    }
}

extension StubHTTPServerTests {
    
    func test_whenRegisteredPathRequested_respondsRegisteredJSON() throws {
        // given
        self.server.register(path: "/v2/holiday", json: #"{"items":[]}"#)
        
        // when
        let response = try self.requestBody("/v2/holiday")
        
        // then
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.body, #"{"items":[]}"#)
        XCTAssertEqual(self.server.handledRequestPaths, ["/v2/holiday"])
        XCTAssertEqual(self.server.unhandledRequestPaths, [])
    }
    
    func test_whenPathHasQueryString_matchesByPathOnly() throws {
        // given
        self.server.register(path: "/v2/holiday", json: #"{"items":[{"id":"kr"}]}"#)
        
        // when
        let response = try self.requestBody("/v2/holiday?year=2026&locale=ko&code=KR")
        
        // then
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.body, #"{"items":[{"id":"kr"}]}"#)
        XCTAssertEqual(self.server.handledRequestPaths, ["/v2/holiday"])
    }
    
    // URLSession 은 헤더를 한 번에 보내 이 경로를 못 만든다 — raw TCP 로 조각내 보낸다
    func test_whenRequestHeaderArrivesInChunks_stillRespondsRegisteredJSON() throws {
        // given
        self.server.register(path: "/v2/holiday", json: #"{"items":[{"id":"chunked"}]}"#)
        
        // when
        let response = try self.sendChunkedRequest(
            firstChunk: "GET /v2/hol",
            secondChunk: "iday HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n"
        )
        
        // then
        XCTAssertTrue(response.hasPrefix("HTTP/1.1 200 OK"))
        XCTAssertTrue(response.hasSuffix(#"{"items":[{"id":"chunked"}]}"#))
        XCTAssertEqual(self.server.handledRequestPaths, ["/v2/holiday"])
    }
    
    func test_whenUnregisteredPathRequested_responds404AndRecordsPath() throws {
        // given
        self.server.register(path: "/v2/holiday", json: #"{"items":[]}"#)
        
        // when
        let response = try self.requestBody("/v2/unknown?q=1")
        
        // then
        XCTAssertEqual(response.statusCode, 404)
        XCTAssertEqual(response.body, "")
        XCTAssertEqual(self.server.handledRequestPaths, [])
        XCTAssertEqual(self.server.unhandledRequestPaths, ["/v2/unknown"])
    }
}

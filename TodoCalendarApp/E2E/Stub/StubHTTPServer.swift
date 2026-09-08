//
//  StubHTTPServer.swift
//  TodoCalendarAppE2E
//
//  Created by sudo.park on 2026/09/08.
//

import Foundation
import Network


enum StubHTTPServerFailure: Error {
    case listenerNotReady
}


final class StubHTTPServer {
    
    private let queue = DispatchQueue(label: "e2e.stub.http.server")
    private var listener: NWListener?
    private var routes: [String: String] = [:]
    private var handledPaths: [String] = []
    private var unhandledPaths: [String] = []
    
    func register(path: String, json: String) {
        self.queue.sync { self.routes[path] = json }
    }
    
    var handledRequestPaths: [String] {
        return self.queue.sync { self.handledPaths }
    }
    
    var unhandledRequestPaths: [String] {
        return self.queue.sync { self.unhandledPaths }
    }
}


// MARK: - life cycle

extension StubHTTPServer {
    
    // 포트를 OS 가 고르게 둔다 — 고정 포트는 병렬·연속 실행에서 바인딩 충돌을 만든다
    func start() throws -> Int {
        let listener = try NWListener(using: .tcp, on: .any)
        let ready = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { state in
            guard case .ready = state else { return }
            ready.signal()
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.start(queue: self.queue)
        self.listener = listener
        
        guard ready.wait(timeout: .now() + 5) == .success,
              let port = listener.port
        else {
            listener.cancel()
            self.listener = nil
            throw StubHTTPServerFailure.listenerNotReady
        }
        return Int(port.rawValue)
    }
    
    func stop() {
        self.listener?.cancel()
        self.listener = nil
    }
}


// MARK: - handle request

extension StubHTTPServer {
    
    private func accept(_ connection: NWConnection) {
        connection.start(queue: self.queue)
        self.receiveHeader(from: connection, received: Data())
    }
    
    private func receiveHeader(from connection: NWConnection, received: Data) {
        connection.receive(
            minimumIncompleteLength: 1, maximumLength: 8192
        ) { [weak self] content, _, isComplete, error in
            guard let self else { return }
            let accumulated = received + (content ?? Data())
            let text = String(decoding: accumulated, as: UTF8.self)
            
            guard text.contains("\r\n\r\n") else {
                guard error == nil, isComplete == false else { return connection.cancel() }
                return self.receiveHeader(from: connection, received: accumulated)
            }
            self.respond(to: connection, requestHeader: text)
        }
    }
    
    private func respond(to connection: NWConnection, requestHeader: String) {
        let path = self.requestPath(from: requestHeader)
        
        guard let json = self.routes[path] else {
            self.unhandledPaths.append(path)
            return self.send(statusLine: "HTTP/1.1 404 Not Found", body: "", to: connection)
        }
        self.handledPaths.append(path)
        self.send(statusLine: "HTTP/1.1 200 OK", body: json, to: connection)
    }
    
    // 연·로케일·국가코드가 실행마다 달라 경로만이 안정적인 매칭 축이다
    private func requestPath(from requestHeader: String) -> String {
        return requestHeader
            .components(separatedBy: "\r\n").first?
            .components(separatedBy: " ")
            .dropFirst().first?
            .components(separatedBy: "?").first ?? ""
    }
    
    private func send(statusLine: String, body: String, to connection: NWConnection) {
        let bodyData = Data(body.utf8)
        let header = [
            statusLine,
            "Content-Type: application/json",
            "Content-Length: \(bodyData.count)",
            "Connection: close",
            "", ""
        ].joined(separator: "\r\n")
        
        connection.send(
            content: Data(header.utf8) + bodyData,
            completion: .contentProcessed { _ in connection.cancel() }
        )
    }
}

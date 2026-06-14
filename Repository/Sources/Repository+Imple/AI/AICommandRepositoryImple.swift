//
//  AICommandRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 6/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


public final class AICommandRepositoryImple: AICommandRepository {

    private let remote: any RemoteAPI
    private let localStorage: any AICommandLocalStorage

    public init(
        remote: any RemoteAPI,
        localStorage: any AICommandLocalStorage
    ) {
        self.remote = remote
        self.localStorage = localStorage
    }
}


// MARK: - command processing (remote)

extension AICommandRepositoryImple {

    public func processCommand(
        _ commandText: String,
        timeZone: String
    ) async throws -> String {
        let body: [String: Any] = [
            "command_text": commandText,
            "timezone": timeZone
        ]
        let json = try await self.requestJson(.post, AIAPIEndpoints.command, parameters: body)
        return try AIJobIdResponseMapper(json: json).jobId
    }

    public func processConfirmCommand(
        _ action: AIConfirmCommandAction,
        timeZone: String
    ) async throws -> String {
        let json = try await self.requestJson(
            .post,
            AIAPIEndpoints.confirmCommand,
            parameters: action.asJson(timeZone: timeZone)
        )
        return try AIJobIdResponseMapper(json: json).jobId
    }

    public func rejectConfirmCommand(_ action: AIConfirmCommandAction) async throws {
        var body: [String: Any] = [:]
        body["job_id"] = action.parentJobId
        _ = try await self.requestJson(.post, AIAPIEndpoints.rejectCommand, parameters: body)
    }

    public func loadJob(_ jobId: String) async throws -> AIJob {
        let json = try await self.requestJson(.get, AIAPIEndpoints.job(id: jobId))
        return try AIJobMapper(json: json).job
    }
}


// MARK: - processing command persistence (local)

extension AICommandRepositoryImple {

    public func updateProcessingAICommand(_ cmd: ProcessingAICommand) async throws {
        try await self.localStorage.updateProcessingAICommand(cmd)
    }

    public func loadProcessingAICommand() async throws -> ProcessingAICommand? {
        return try await self.localStorage.loadProcessingAICommand()
    }

    public func clearProcessingAICommand() async throws {
        try await self.localStorage.clearProcessingAICommand()
    }
}


// MARK: - usage (remote)

extension AICommandRepositoryImple {

    public func loadUsage() async throws -> AIAgentUsage {
        let json = try await self.requestJson(.get, AIAPIEndpoints.usage)
        return try AIAgentUsageMapper(json: json).usage
    }
}


// MARK: - helpers

private extension AICommandRepositoryImple {

    func requestJson(
        _ method: RemoteAPIMethod,
        _ endpoint: any Endpoint,
        parameters: [String: Any] = [:]
    ) async throws -> [String: Any] {
        let data = try await self.remote.request(method, endpoint, with: nil, parameters: parameters)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw RuntimeError("invalid AI API response")
        }
        return json
    }
}

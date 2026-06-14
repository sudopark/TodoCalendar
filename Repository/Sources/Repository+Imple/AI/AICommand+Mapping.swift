//
//  AICommand+Mapping.swift
//  Repository
//
//  Created by sudo.park on 6/1/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain
import Extensions


// MARK: - request body

extension AIConfirmCommandAction {

    func asJson(timeZone: String) -> [String: Any] {
        var json: [String: Any] = [:]
        json["tool"] = self.tool
        json["confirm_token"] = self.confirmToken
        json["timezone"] = timeZone
        if let argsData = self.args,
           let argsObject = try? JSONSerialization.jsonObject(with: argsData) {
            json["args"] = argsObject
        }
        return json
    }
}


// MARK: - response: jobId

struct AIJobIdResponseMapper {

    let jobId: String

    init(json: [String: Any]) throws {
        guard let jobId = json["job_id"] as? String
        else { throw RuntimeError("invalid job_id response") }
        self.jobId = jobId
    }
}


// MARK: - response: AIJob

struct AIJobMapper {

    let job: AIJob

    init(json: [String: Any]) throws {
        guard let jobId = json["jobId"] as? String
        else { throw RuntimeError("invalid AIJob response") }

        let resultJson = json["result"] as? [String: Any]
        let result = resultJson.flatMap { try? AIJobResultMapper(json: $0).result }

        self.job = AIJob(jobId: jobId)
            |> \.command .~ (json["commandText"] as? String)
            |> \.status .~ (json["status"] as? String).flatMap { AIJob.Status(rawValue: $0) }
            |> \.mode .~ (json["mode"] as? String).flatMap { AIJob.Mode(rawValue: $0) }
            |> \.result .~ result
            |> \.createAt .~ AICommandDateParser.parse(json["createdAt"])
            |> \.updatedAt .~ AICommandDateParser.parse(json["updatedAt"])
    }
}


// MARK: - AIJobResult

struct AIJobResultMapper {

    let result: AIJobResult?

    init(json: [String: Any]) throws {
        let type = json["type"] as? String
        let mutations = (json["mutations"] as? [[String: Any]] ?? [])
            .compactMap { try? AIJobDataMutationMapper(json: $0).mutation }

        switch type {
        case "DONE":
            self.result = .done(
                AIJobResult.DoneResult()
                |> \.text .~ (json["text"] as? String)
                |> \.mutations .~ mutations
            )

        case "CONFIRM":
            let action = (json["action"] as? [String: Any])
                .map { AIConfirmCommandActionMapper(json: $0).action }
            self.result = .confirm(
                AIJobResult.ConfirmResult()
                |> \.text .~ (json["text"] as? String)
                |> \.action .~ action
                |> \.mutations .~ mutations
            )

        case "FAILED":
            self.result = .failed(
                AIJobResult.FailResult()
                |> \.reason .~ (json["reason"] as? String)
                |> \.errorCode .~ (json["errorCode"] as? String).flatMap { ServerErrorModel.ErrorCode(rawValue: $0) }
                |> \.mutations .~ mutations
            )

        default:
            self.result = nil
        }
    }
}


// MARK: - AIConfirmCommandAction (response)

struct AIConfirmCommandActionMapper {

    let action: AIConfirmCommandAction

    init(json: [String: Any]) {
        let argsData = json["args"].flatMap { try? JSONSerialization.data(withJSONObject: $0) }
        self.action = AIConfirmCommandAction()
            |> \.tool .~ (json["tool"] as? String)
            |> \.confirmToken .~ (json["confirmToken"] as? String)
            |> \.parentJobId .~ (json["parentJobId"] as? String)
            |> \.args .~ argsData
    }
}


// MARK: - AIJobDataMutation

struct AIJobDataMutationMapper {

    let mutation: AIJobDataMutation?

    init(json: [String: Any]) {
        let dataTypeRaw = json["dataType"] as? String
        let opRaw = json["op"] as? String
        guard let dataTypeRaw, let opRaw,
              let dataType = AIJobDataMutation.DataType(rawValue: dataTypeRaw),
              let op = AIJobDataMutation.Operation(rawValue: opRaw)
        else {
            self.mutation = nil
            return
        }
        self.mutation = AIJobDataMutation(dataType: dataType, operation: op)
    }
}


// MARK: - response: AIAgentUsage

struct AIAgentUsageMapper {

    let usage: AIAgentUsage

    init(json: [String: Any]) throws {
        guard let input = json["input_tokens"] as? Int,
              let output = json["output_tokens"] as? Int,
              let limit = json["daily_limit"] as? Int
        else { throw RuntimeError("invalid usage response") }

        self.usage = AIAgentUsage(input: input, output: output, limit: limit)
            |> \.date .~ (json["date"] as? String)
            |> \.updatedAt .~ AICommandDateParser.parse(json["updated_at"])
    }
}


// MARK: - date parser

enum AICommandDateParser {

    static func parse(_ value: Any?) -> Date? {
        guard let iso = value as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: iso)
    }
}

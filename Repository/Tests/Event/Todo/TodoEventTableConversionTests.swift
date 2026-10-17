//
//  TodoEventTableConversionTests.swift
//  RepositoryTests
//
//  Created by sudo.park on 9/27/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Testing
import Prelude
import Optics
import Domain
import Extensions

@testable import Repository


@Suite("TodoEventTableConversionTests")
final class TodoEventTableConversionTests {
    
    private func dummyTodo(_ endOption: EventRepeating.RepeatEndOption) -> TodoEvent {
        let option = EventRepeatingOptions.EveryWeek(TimeZone(abbreviation: "KST")!)
        let repeating = EventRepeating(repeatingStartTime: 100, repeatOption: option)
            |> \.repeatingEndOption .~ endOption
        return TodoEvent(uuid: "full", name: "some")
            |> \.creatTimeStamp .~ 2500
            |> \.eventTagId .~ .custom("tag")
            |> \.repeating .~ pure(repeating)
            |> \.repeatingTurn .~ 7
            |> \.notificationOptions .~ [.atTime]
    }
    
    private func encodedRepeatingOption() throws -> String {
        let option = EventRepeatingOptions.EveryWeek(TimeZone(abbreviation: "KST")!)
        let data = try JSONEncoder().encode(EventRepeatingOptionCodableMapper(option: option))
        return String(decoding: data, as: UTF8.self)
    }
}


// MARK: - 반복 옵션은 있는데 시작 시각이 빠진 행

extension TodoEventTableConversionTests {
    
    @Test func entity_whenRepeatingOptionExistsWithoutStart_throws() throws {
        // given
        let entity = TodoEventTable.Entity(uuid: "broken", name: "some")
            |> \.repeatingOption .~ (try self.encodedRepeatingOption())
        
        // when + then
        #expect(throws: RuntimeError.self) {
            try entity.asTodoEvent()
        }
    }
    
    @Test func entity_whenRepeatingOptionMissing_convertsWithoutRepeating() throws {
        // given
        let entity = TodoEventTable.Entity(uuid: "no-repeating", name: "some")
            |> \.repeatingStart .~ 100
            |> \.repeatingTurn .~ 7
        
        // when
        let todo = try entity.asTodoEvent()
        
        // then
        #expect(todo.repeating == nil)
        #expect(todo.repeatingTurn == nil)
    }
}


// MARK: - 컬럼을 늘렸는데 변환에 안 실은 경우

extension TodoEventTableConversionTests {
    
    @Test func serialize_fromConvertedEntity_leavesNoColumnUnmapped() throws {
        // given
        let untilTodo = self.dummyTodo(.until(4000))
        let countTodo = self.dummyTodo(.count(10))
        
        // when
        let untilValues = try TodoEventTable.serialize(entity: .init(untilTodo))
        let countValues = try TodoEventTable.serialize(entity: .init(countTodo))
        
        // then
        let mapped = zip(untilValues, countValues).map { $0 != nil || $1 != nil }
        #expect(mapped.count == TodoEventTable.Columns.allCases.count)
        #expect(mapped.isEmpty == false)
        #expect(mapped.allSatisfy { $0 })
    }
}

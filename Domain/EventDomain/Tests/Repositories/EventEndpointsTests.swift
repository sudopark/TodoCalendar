//
//  EventEndpointsTests.swift
//  EventDomainTests
//
//  Created by sudo.park on 10/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing
import RemoteInfraInterface
@testable import EventDomain



struct EventEndpointsTests {

    private let env = RemoteEnvironment(
        calendarAPIHost: "https://api.example.com",
        csAPI: "https://cs.example.com",
        deviceId: "device_id",
        acceptLanguage: { "en" }
    )

    struct EndpointExpectation: Sendable {
        let endpoint: any Endpoint
        let path: String
        let authorization: EndpointAuthorization
    }
}

extension EventEndpointsTests {

    @Test("엔드포인트가 자기 경로와 인증 종류를 낸다", arguments: [
        EndpointExpectation(endpoint: TodoAPIEndpoints.make, path: "https://api.example.com/v2/todos/todo", authorization: .calendarAPI),
        EndpointExpectation(endpoint: TodoAPIEndpoints.todo("id"), path: "https://api.example.com/v2/todos/todo/id", authorization: .calendarAPI),
        EndpointExpectation(endpoint: TodoAPIEndpoints.todos, path: "https://api.example.com/v2/todos", authorization: .calendarAPI),
        EndpointExpectation(endpoint: TodoAPIEndpoints.uncompleteds, path: "https://api.example.com/v2/todos/uncompleted", authorization: .calendarAPI),
        EndpointExpectation(endpoint: TodoAPIEndpoints.currentTodo, path: "https://api.example.com/v2/todos", authorization: .calendarAPI),
        EndpointExpectation(endpoint: TodoAPIEndpoints.complete("id"), path: "https://api.example.com/v2/todos/todo/id/complete", authorization: .calendarAPI),
        EndpointExpectation(endpoint: TodoAPIEndpoints.done("id"), path: "https://api.example.com/v2/todos/dones/id", authorization: .calendarAPI),
        EndpointExpectation(endpoint: TodoAPIEndpoints.dones, path: "https://api.example.com/v2/todos/dones", authorization: .calendarAPI),
        EndpointExpectation(endpoint: TodoAPIEndpoints.revertDone("id"), path: "https://api.example.com/v2/todos/dones/id/revert", authorization: .calendarAPI),
        EndpointExpectation(endpoint: TodoAPIEndpoints.replaceRepeating("id"), path: "https://api.example.com/v2/todos/todo/id/replace", authorization: .calendarAPI),
        EndpointExpectation(endpoint: TodoAPIEndpoints.cancelDone, path: "https://api.example.com/v2/todos/dones/cancel", authorization: .calendarAPI),
        EndpointExpectation(endpoint: ScheduleEventEndpoints.make, path: "https://api.example.com/v2/schedules/schedule", authorization: .calendarAPI),
        EndpointExpectation(endpoint: ScheduleEventEndpoints.schedule(id: "id"), path: "https://api.example.com/v2/schedules/schedule/id", authorization: .calendarAPI),
        EndpointExpectation(endpoint: ScheduleEventEndpoints.exclude(id: "id"), path: "https://api.example.com/v2/schedules/schedule/id/exclude", authorization: .calendarAPI),
        EndpointExpectation(endpoint: ScheduleEventEndpoints.branchRepeating(id: "id"), path: "https://api.example.com/v2/schedules/schedule/id/branch_repeating", authorization: .calendarAPI),
        EndpointExpectation(endpoint: ScheduleEventEndpoints.schedules, path: "https://api.example.com/v2/schedules", authorization: .calendarAPI),
        EndpointExpectation(endpoint: ForemostEventEndpoints.event, path: "https://api.example.com/v2/foremost/event", authorization: .calendarAPI),
        EndpointExpectation(endpoint: EventTagEndpoints.make, path: "https://api.example.com/v2/tags/tag", authorization: .calendarAPI),
        EndpointExpectation(endpoint: EventTagEndpoints.tag(id: "id"), path: "https://api.example.com/v2/tags/tag/id", authorization: .calendarAPI),
        EndpointExpectation(endpoint: EventTagEndpoints.tagAndEvents(id: "id"), path: "https://api.example.com/v2/tags/tag_and_events/id", authorization: .calendarAPI),
        EndpointExpectation(endpoint: EventTagEndpoints.tagWithEvents(id: "id"), path: "https://api.example.com/v2/tags/tag_with_events/id", authorization: .calendarAPI),
        EndpointExpectation(endpoint: EventTagEndpoints.tags, path: "https://api.example.com/v2/tags", authorization: .calendarAPI),
        EndpointExpectation(endpoint: EventTagEndpoints.allTags, path: "https://api.example.com/v2/tags/all", authorization: .calendarAPI),
        EndpointExpectation(endpoint: EventDetailEndpoints.detail(eventId: "id"), path: "https://api.example.com/v2/event_details/id", authorization: .calendarAPI),
        EndpointExpectation(endpoint: EventDetailEndpoints.doneTodoDetail(eventId: "id"), path: "https://api.example.com/v2/event_details/done/id", authorization: .calendarAPI),
        EndpointExpectation(endpoint: EventSyncEndPoints.check, path: "https://api.example.com/v2/sync/check", authorization: .calendarAPI),
        EndpointExpectation(endpoint: EventSyncEndPoints.start, path: "https://api.example.com/v2/sync/start", authorization: .calendarAPI),
        EndpointExpectation(endpoint: EventSyncEndPoints.continue, path: "https://api.example.com/v2/sync/continue", authorization: .calendarAPI)
    ])
    func endpoint_providesPathAndAuthorization(_ expectation: EndpointExpectation) {
        // given
        let endpoint = expectation.endpoint
        // when
        let path = self.env.path(endpoint)
        let authorization = endpoint.authorization
        // then
        #expect(path == expectation.path)
        #expect(authorization == expectation.authorization)
    }
}

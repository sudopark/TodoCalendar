//
//  PlaceSuggestUsecaseImpleTests.swift
//  Domain
//
//  Created by sudo.park on 11/11/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import UnitTestHelpKit
import Extensions

@testable import Domain


class PlaceSuggestUsecaseImpleTests: PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>! = []
    
    private func makeUsecase(
        mocking: PassthroughSubject<[Place], Never>? = nil
    ) -> PlaceSuggestUsecaseImple {
        let suggestEngine = StubPlaceSuggestEngine()
        suggestEngine.mocking = mocking
        return .init(
            suggestEngine: suggestEngine,
            throttleTime: .milliseconds(0)
        )
    }
}

extension PlaceSuggestUsecaseImpleTests {
    
    @Test func usecase_suggestPlaces_and_stop() async throws {
        // given
        let expect = expectConfirm("검색어에 따라 결과 반환하다 중지")
        expect.count = 4; expect.timeout = .seconds(1)
        let usecase = self.makeUsecase()
        
        // when
        let placeLists = try await self.outputs(expect, for: usecase.suggestPlaces) {
            
            usecase.starSuggest("q1")
            try await Task.sleep(for: .milliseconds(10))
            
            usecase.starSuggest("q12")
            try await Task.sleep(for: .milliseconds(10))
            
            usecase.stopSuggest()
        }
        
        // then
        let counts = placeLists.map { $0.count }
        #expect(counts == [0, 2, 3, 0])
    }
    
    // 중간에 에러 발생해도 무시하고 계속 결과 반환
    @Test func usecase_whenErrorOccurDuringSuggest_ignore() async throws {
        // given
        let expect = expectConfirm("중간에 에러 발생해도 무시하고 계속 결과 반환")
        expect.count = 3; expect.timeout = .seconds(1)
        let usecase = self.makeUsecase()
        
        // when
        let placeLists = try await self.outputs(expect, for: usecase.suggestPlaces) {
            
            usecase.starSuggest("q1")
            try await Task.sleep(for: .milliseconds(10))
            
            usecase.starSuggest("error")
            try await Task.sleep(for: .milliseconds(10))
            
            usecase.starSuggest("q12")
        }
        
        // then
        let counts = placeLists.map { $0.count }
        #expect(counts == [0, 2, 3])
    }
    
    // 검섹하다 중간에 중지하면 서제스트가 늦어도 결과 반환 안함
    @Test func usecase_whenSuggestResultHasLatencyAndStop_ignoreLateResult() async throws {
        // given
        let expect = expectConfirm("검섹하다 중간에 중지하면 서제스트가 늦어도 결과 반환 안함")
        expect.count = 3; expect.timeout = .seconds(1)
        let mocking = PassthroughSubject<[Place], Never>()
        let usecase = self.makeUsecase(mocking: mocking)
        
        // when
        let placeLists = try await self.outputs(expect, for: usecase.suggestPlaces) {
            
            usecase.starSuggest("q1")
            try await Task.sleep(for: .milliseconds(10))
            mocking.send([.init("q1")])
            try await Task.sleep(for: .milliseconds(10))
            
            usecase.starSuggest("late")
            try await Task.sleep(for: .milliseconds(10))
            
            usecase.stopSuggest()
            try await Task.sleep(for: .milliseconds(10))
            
            mocking.send([.init("late")])
        }
        
        // then
        let names = placeLists.map { ps in ps.map { $0.placeName } }
        #expect(names == [
            [], ["q1"], []
        ])
    }
    
}

private final class StubPlaceSuggestEngine: PlaceSuggestEngine {
    
    var mocking: PassthroughSubject<[Place], Never>?
    func suggest(query: String) -> AnyPublisher<[Place], any Error> {
        
        if let mocking = self.mocking {
            return mocking.mapAsAnyError().eraseToAnyPublisher()
        }
        
        if query == "error" {
            return Fail(error: RuntimeError("failed")).eraseToAnyPublisher()
        } else {
            let places = (0..<query.count).map { Place("\(query)-name:\($0)") }
            return Just(places).mapAsAnyError().eraseToAnyPublisher()
        }
    }
}

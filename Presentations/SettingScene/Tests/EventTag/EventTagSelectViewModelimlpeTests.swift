//
//  EventTagSelectViewModelimlpeTests.swift
//  SettingSceneTests
//
//  Created by sudo.park on 1/1/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import XCTest
import Combine
import Prelude
import Optics
import Domain
import UnitTestHelpKit
import TestDoubles

@testable import SettingScene


class EventTagSelectViewModelimlpeTests: BaseTestCase, PublisherWaitable {
    
    var cancelBag: Set<AnyCancellable>!
    private var spyRouter: SpyRouter!
    private var spySettingUsecase: StubEventSettingUsecase!
    
    override func setUpWithError() throws {
        self.cancelBag = .init()
        self.spyRouter = .init()
        self.spySettingUsecase = .init()
    }
    
    override func tearDownWithError() throws {
        self.cancelBag = nil
        self.spyRouter = nil
        self.spySettingUsecase = nil
    }
    
    func makeViewModel() -> EventTagSelectViewModelImple {
        
        let tags: [any EventTag] = (0..<10).map {
            return CustomEventTag(uuid: "id:\($0)", name: "name:\($0)", colorHex: "")
        }
        let tagUsecase = StubEventTagUsecase()
        tagUsecase.allTagsLoadResult = .success(tags)
        
        let viewModel = EventTagSelectViewModelImple(
            tagUsecase: tagUsecase,
            eventSettingUsecase: self.spySettingUsecase,
            googleCalendarUsecase: StubGoogleCalendarUsecase()
        )
        viewModel.router = self.spyRouter
        return viewModel
    }
}

extension EventTagSelectViewModelimlpeTests {
    
    // 리스트 로드
    func testViewModel_provideTagList() {
        // given
        let expect = expectation(description: "리스트 로드")
        let viewModel = self.makeViewModel()
        
        // when
        let tags = self.waitFirstOutput(expect, for: viewModel.cellViewModels) {
            viewModel.loadList()
        }
        
        // then
        let ids = tags?.map { $0.id }
        XCTAssertEqual(
            ids, [.default] + (0..<10).map { EventTagId.custom("id:\($0)") }
        )
    }
    
    // 선택된값 업데이트
    func testViewModel_updateSelect() {
        // given
        let expect = expectation(description: "선택된값 업데이트")
        expect.expectedFulfillmentCount = 2
        let viewModel = self.makeViewModel()
        
        // when
        let ids = self.waitOutputs(expect, for: viewModel.selectedId) {
            viewModel.loadList()
            
            viewModel.select(.custom("id:3"))
        }
        
        // then
        XCTAssertEqual(ids, [.default, .custom("id:3")])
    }
}


private class SpyRouter: BaseSpyRouter, EventTagSelectRouting, @unchecked Sendable {
    
    
}

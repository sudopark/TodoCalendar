//
//  DaysIntervalCountUsecaseImpleTests.swift
//  DomainTests
//
//  Created by sudo.park on 10/20/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Testing
import Combine
import Prelude
import Optics
import Extensions
import UnitTestHelpKit
import TestDoubles

@testable import Domain


final class DaysIntervalCountUsecaseImpleTests: PublisherWaitable {
    
    private let stubCalendarSettingUsecase = StubCalendarSettingUsecase()
    var cancelBag: Set<AnyCancellable>! = .init()
    
    init() {
        self.stubCalendarSettingUsecase.selectTimeZone(self.utc)
    }
    
    private func makeusecase() -> DaysIntervalCountUsecaseImple {
        return DaysIntervalCountUsecaseImple(
            calendarSettingUsecase: self.stubCalendarSettingUsecase
        )
    }
    
    private var utc: TimeZone { TimeZone(secondsFromGMT: 0)! }
    private var utc_m12: TimeZone { TimeZone(secondsFromGMT: -12*3600)! }
}

extension DaysIntervalCountUsecaseImpleTests {
    
    @Test("count days -N, 0, N", arguments: [-4, -1, 0, 1, 4])
    func usecase_countDays(_ intervalDays: Int) async throws {
        // given
        let now = Date().timeIntervalSince1970
        let expect = expectConfirm("count days: \(intervalDays)")
        let usecase = self.makeusecase()
        
        // when
        let time: EventTime = .at(
            now+TimeInterval(intervalDays)*24*3600
        )
        let interval = try await self.firstOutput(expect, for: usecase.countDays(to: time))
        
        // then
        #expect(interval == intervalDays)
    }
    
    @Test func usecase_whenTimeZoneChanged_reCountInterval() async throws {
        // given
        let now = Date().timeIntervalSince1970
        let expect = expectConfirm("timezone 변경시에 날짜 간격 다시 계산")
        expect.count = 2; expect.timeout = .milliseconds(100)
        let usecase = self.makeusecase()
        
        // when
        let time: EventTime = .at(now+12*3600)
        let intervals = try await self.outputs(expect, for: usecase.countDays(to: time)) {
            
            self.stubCalendarSettingUsecase.selectTimeZone(self.utc_m12)
        }
        
        // then
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ self.utc
        let isAm = (calendar.dateComponents([.hour], from: Date(timeIntervalSince1970: now)).hour ?? 0) < 12
        if isAm {
            // 오전에 돌리면 0, -1
            #expect(intervals == [0, -1])
        } else {
            // 오후에 돌리면 1, 0
            #expect(intervals == [1, 0])
        }
    }
    
    @Test func usecase_countHoliday() async throws {
        // given
        func tenDaysAfterHoliday(_ from: Date) -> Holiday {
            let after = from.addingTimeInterval(10*24*3600)
            let format = DateFormatter()
                |> \.timeZone .~ self.utc
                |> \.dateFormat .~ "yyyy-MM-dd"
            let dateText = format.string(from: after)
            return Holiday(uuid: "id", dateString: dateText, name: "hd")
        }
        let expect = expectConfirm("holiday 남은시간 카운트")
        let usecase = self.makeusecase()
        let now = Date(); let holiday = tenDaysAfterHoliday(now)
        
        // when
        let interval = try await self.firstOutput(expect, for: usecase.countDays(to: holiday))
        
        // then
        #expect(interval == 10)
    }
}

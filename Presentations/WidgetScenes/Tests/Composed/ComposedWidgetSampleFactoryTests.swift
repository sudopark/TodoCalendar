//
//  ComposedWidgetSampleFactoryTests.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Testing

@testable import WidgetScenes


struct ComposedWidgetSampleFactoryTests {
    
    private let factory = ComposedWidgetSampleFactory()
    
    @Test
    func sample_doubleMonth_hasCurrentAndNextMonth() {
        // given
        // when
        let model = self.factory.doubleMonth()
        
        // then
        #expect(model?.current.anchorDay.month == 3)
        #expect(model?.next.anchorDay.month == 4)
    }
    
    @Test
    func sample_eventAndForemost_fillsEventAndForemost() {
        // given
        // when
        let model = self.factory.eventAndForemost()
        
        // then
        #expect(model.event.pages.isEmpty == false)
        #expect(model.foremost.eventModel != nil)
    }
    
    @Test
    func sample_eventAndMonth_fillsEventAndMarchMonth() {
        // given
        // when
        let model = self.factory.eventAndMonth()
        
        // then
        #expect(model?.event.pages.isEmpty == false)
        #expect(model?.month.anchorDay.month == 3)
    }
    
    @Test
    func sample_todayAndMonth_fillsTodayAndMarchMonth() {
        // given
        // when
        let model = self.factory.todayAndMonth()
        
        // then
        #expect(model?.today.day == 14)
        #expect(model?.month.anchorDay.month == 3)
    }
}

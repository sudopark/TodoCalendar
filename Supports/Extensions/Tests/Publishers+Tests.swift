//
//  Publishers+Tests.swift
//  ExtensionsTests
//
//  Created by sudo.park on 5/31/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Testing

@testable import Extensions


struct PublishersTests {
    
    @Test func prefixPublisher_notincludeBoundValue() async throws {
        // given
        let source = [false, false, false, true, true, true].publisher
        
        // when
        let prefix = source.prefix(while: { !$0 })
        var outputs: [Bool] = []
        for try await output in prefix.values {
            outputs.append(output)
        }
        
        // then
        #expect(outputs == [false, false, false])
    }
    
    
    @Test func prefixPublisher_includeBoundValue() async throws {
        // given
        let source = [false, false, false, true, true, true].publisher
        
        // when
        let prefix = source.prefixWithInclude(firstMatch: { $0 })
        var outputs: [Bool] = []
        for try await output in prefix.values {
            outputs.append(output)
        }
        
        // then
        #expect(outputs == [false, false, false, true])
    }
}

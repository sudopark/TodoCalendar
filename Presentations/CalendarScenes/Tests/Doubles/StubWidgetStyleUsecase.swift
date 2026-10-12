//
//  StubWidgetStyleUsecase.swift
//  CalendarScenesTests
//
//  Created by sudo.park on 10/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain


final class StubWidgetStyleUsecase: WidgetStyleUsecase, @unchecked Sendable {

    private let customizeBlockedReason: PaidFeatureGateFailReason?
    init(customizeBlockedReason: PaidFeatureGateFailReason? = nil) {
        self.customizeBlockedReason = customizeBlockedReason
    }

    func checkCustomizable() throws {
        guard let reason = self.customizeBlockedReason else { return }
        throw reason
    }

    func refreshStyles(of variant: WidgetVariant) { }

    func styles(of variant: WidgetVariant) -> AnyPublisher<[WidgetStyle], Never> {
        return Empty().eraseToAnyPublisher()
    }

    func loadStyles(of variant: WidgetVariant) -> [WidgetStyle] { return [] }

    func updateStyle(_ style: WidgetStyle) throws { }

    func makeNewStyleId(for variant: WidgetVariant) -> WidgetStyleId {
        return .init(variant: variant, style: .default)
    }

    func removeStyle(_ id: WidgetStyleId) { }

    func makeDraftPhoto(from picked: Data) -> WidgetStylePhoto? { return nil }

    func makeDraftPhoto(copying photo: WidgetStylePhoto) -> WidgetStylePhoto? { return nil }
}

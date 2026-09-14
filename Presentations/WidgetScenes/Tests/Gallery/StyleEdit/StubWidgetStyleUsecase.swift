//
//  StubWidgetStyleUsecase.swift
//  WidgetScenesTests
//
//  Created by sudo.park on 9/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Domain


final class StubWidgetStyleUsecase: WidgetStyleUsecase, @unchecked Sendable {
    
    /// 프로덕션과 같이 갱신 요청 전에는 아무것도 내보내지 않는다 — 배선 누락이 테스트에서 드러나야 한다.
    private let styleSubject = CurrentValueSubject<[WidgetStyle<TodayStyleSetting>]?, Never>(nil)
    var stubStyles: [WidgetStyle<TodayStyleSetting>] = [] {
        didSet {
            guard self.styleSubject.value != nil else { return }
            self.styleSubject.send(self.stubStyles)
        }
    }
    
    private(set) var requestedVariant: WidgetVariant?
    private(set) var refreshedVariants: [WidgetVariant] = []
    private(set) var updatedStyles: [WidgetStyle<TodayStyleSetting>] = []
    private(set) var removedStyleIds: [WidgetStyleId] = []
    private var mintedStyleIdCount: Int = 0
    
    func refreshStyles<S: WidgetStyleSetting>(_ type: S.Type, of variant: WidgetVariant) {
        self.refreshedVariants.append(variant)
        self.styleSubject.send(self.stubStyles)
    }
    
    func styles<S: WidgetStyleSetting>(
        _ type: S.Type, of variant: WidgetVariant
    ) -> AnyPublisher<[WidgetStyle<S>], Never> {
        self.requestedVariant = variant
        return self.styleSubject
            .compactMap { $0 }
            .map { styles in
                return styles.filter { $0.id.variant == variant } as? [WidgetStyle<S>] ?? []
            }
            .eraseToAnyPublisher()
    }
    
    func loadStyles<S: WidgetStyleSetting>(
        _ type: S.Type, of variant: WidgetVariant
    ) -> [WidgetStyle<S>] {
        self.requestedVariant = variant
        return self.stubStyles as? [WidgetStyle<S>] ?? []
    }
    
    func updateStyle<S: WidgetStyleSetting>(_ style: WidgetStyle<S>) {
        guard let updated = style as? WidgetStyle<TodayStyleSetting> else { return }
        self.updatedStyles.append(updated)
        self.stubStyles = self.stubStyles.map { $0.id == updated.id ? updated : $0 }
    }
    
    func makeNewStyleId(for variant: WidgetVariant) -> WidgetStyleId {
        self.mintedStyleIdCount += 1
        return .init(variant: variant, style: .custom(id: "new\(self.mintedStyleIdCount)"))
    }
    
    func removeStyle<S: WidgetStyleSetting>(_ type: S.Type, _ id: WidgetStyleId) {
        self.removedStyleIds.append(id)
        self.stubStyles = self.stubStyles.filter { $0.id != id }
    }
}

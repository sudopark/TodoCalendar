//
//  WidgetStyleUsecase.swift
//  SettingDomainInterface
//
//  Created by sudo.park on 9/12/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import Prelude
import Optics
import Extensions

public protocol WidgetStyleUsecase: Sendable {

    func refreshStyles(of variant: WidgetVariant)

    func styles(of variant: WidgetVariant) -> AnyPublisher<[WidgetStyle], Never>

    func loadStyles(of variant: WidgetVariant) -> [WidgetStyle]

    func updateStyle(_ style: WidgetStyle) throws

    func makeNewStyleId(for variant: WidgetVariant) -> WidgetStyleId

    func removeStyle(_ id: WidgetStyleId)

    func makeDraftPhoto(from picked: Data) -> WidgetStylePhoto?

    func makeDraftPhoto(copying photo: WidgetStylePhoto) -> WidgetStylePhoto?
}

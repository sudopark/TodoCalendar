//
//  LegalNoticeUsecase.swift
//  SupportDomainInterface
//
//  Created by sudo.park on 8/23/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Combine
import CombineExt
import AsyncFlatMap
import Extensions


// MARK: - LegalNoticeUsecase

public protocol LegalNoticeUsecase: Sendable {
    func checkNoticeIsNeed()
    var pendingNoticeUpdates: AnyPublisher<[LegalNoticeUpdateInfo], Never> { get }
    func confirmNotice(_ documentType: LegalDocumentType)
}

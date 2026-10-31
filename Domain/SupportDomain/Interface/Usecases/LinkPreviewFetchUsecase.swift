//
//  LinkPreviewFetchUsecase.swift
//  SupportDomainInterface
//
//  Created by sudo.park on 8/10/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation


// MARK: - LinkPreviewFetchEngine

public protocol LinkPreviewFetchEngine: AnyObject, Sendable {

    func fetchPreview(_ url: URL) async throws -> LinkPreview
}


// MARK: - LinkPreviewFetchUsecase

public protocol LinkPreviewFetchUsecase: AnyObject, Sendable {

    func fetchPreview(_ url: URL) async throws -> LinkPreview
}

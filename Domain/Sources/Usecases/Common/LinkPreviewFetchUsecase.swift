//
//  LinkPreviewFetchUsecase.swift
//  Domain
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

public final class LinkPreviewFetchUsecaseImple: LinkPreviewFetchUsecase, @unchecked Sendable {

    private let previewEngine: any LinkPreviewFetchEngine
    public init(previewEngine: any LinkPreviewFetchEngine) {
        self.previewEngine = previewEngine
    }
}

extension LinkPreviewFetchUsecaseImple {

    public func fetchPreview(_ url: URL) async throws -> LinkPreview {
        return try await self.previewEngine.fetchPreview(url)
    }
}

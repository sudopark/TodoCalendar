//
//  LinkPreviewFetchUsecase.swift
//  Domain
//
//  Created by sudo.park on 8/10/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import SwiftLinkPreview


public protocol LinkPreviewFetchUsecase: AnyObject, Sendable {
    
    func fetchPreview(_ url: URL) async throws -> LinkPreview
}


public final class LinkPreviewFetchUsecaesImple: LinkPreviewFetchUsecase, @unchecked Sendable {
    
    private let previewEngine: SwiftLinkPreview
    public init(previewEngine: SwiftLinkPreview) {
        self.previewEngine = previewEngine
    }
}

extension LinkPreviewFetchUsecaesImple {
    
    final class FetchTask: @unchecked Sendable {
        let engine: SwiftLinkPreview
        let url: URL
        private var request: Cancellable?
        
        init(_ engine: SwiftLinkPreview, _ url: URL) {
            self.engine = engine
            self.url = url
        }
        
        func fetch() async throws -> LinkPreview {
            let path = self.url.absoluteString
            return try await withCheckedThrowingContinuation { [weak self] continuation in
                self?.request = self?.engine.preview(path) { response in
                    let preview = LinkPreview(
                        url: response.url,
                        title: response.title,
                        description: response.description,
                        mainImagePath: response.image,
                        images: response.images ?? []
                    )
                    continuation.resume(returning: preview)
                } onError: { error in
                    continuation.resume(throwing: error)
                }
            }
        }
        
        func cancel() {
            self.request?.cancel()
        }
    }
    
    public func fetchPreview(_ url: URL) async throws -> LinkPreview {
        let fetchTask = FetchTask(self.previewEngine, url)
        return try await withTaskCancellationHandler {
            return try await fetchTask.fetch()
        } onCancel: {
            fetchTask.cancel()
        }
    }
}

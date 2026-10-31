//
//  StubLinkPreviewFetchUsecase.swift
//  SupportDomainTesting
//
//  Created by sudo.park on 8/10/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import SupportDomainInterface


open class StubLinkPreviewFetchUsecase: LinkPreviewFetchUsecase, @unchecked Sendable {
    
    public init() { }
    
    open func fetchPreview(_ url: URL) async throws -> LinkPreview {
        let preview = LinkPreview(
            url: url, title: "title", description: "desc:\(url)", mainImagePath: "image", images: []
        )
        return preview
    }
}

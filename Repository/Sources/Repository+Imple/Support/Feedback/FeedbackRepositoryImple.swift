//
//  FeedbackRepositoryImple.swift
//  Repository
//
//  Created by sudo.park on 8/15/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


public final class FeedbackRepositoryImple: FeedbackRepository {
    
    private let remote: any RemoteAPI
    public init(remote: any RemoteAPI) {
        self.remote = remote
    }
}

extension FeedbackRepositoryImple {
    
    public func postFeedback(_ params: FeedbackMakeParams) async throws {
        let endpoint = FeedbackEndpoints.post
        let payload = params.asMessageJson()
        _ = try await self.remote.request(
            .post, endpoint, with: nil, parameters: payload
        )
    }
}

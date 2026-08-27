//
//  Error+ServerResponse.swift
//  Repository
//
//  Created by sudo.park on 8/28/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Alamofire
import Domain

extension Error {

    var isServerResponseNotReceived: Bool {
        switch self {
        case let serverError as ServerErrorModel:
            return serverError.statusCode == nil && serverError.code == .cancelled

        case let afError as AFError:
            if afError.isExplicitlyCancelledError {
                return true
            }
            guard let underlyingError = afError.underlyingError else { return false }
            return underlyingError.isServerResponseNotReceived

        default:
            let nsError = self as NSError
            if nsError.domain == NSURLErrorDomain {
                return true
            }
            guard let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error else {
                return false
            }
            return underlyingError.isServerResponseNotReceived
        }
    }
}

//
//  PaywallFailReason.swift
//  BillingScenes
//
//  Created by sudo.park on 8/10/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain
import Extensions


enum PaywallFailReason: Equatable {
    case purchaseFailed
    case invalidTransaction
    case unknownProduct
    case planChangeNotAllowed
    case reflectDelayed
}

extension PaywallFailReason {

    // nil = 알릴 게 없다 (요청 취소)
    init?(_ error: any Error) {
        let reflect = error as? BillingReflectFailure
        let serverCode = ((reflect?.underlying ?? error) as? ServerErrorModel)?.code
        guard serverCode != .cancelled else { return nil }

        guard reflect != nil else {
            self = .purchaseFailed
            return
        }
        switch serverCode {
        case .invalidTransaction: self = .invalidTransaction
        case .unknownProduct: self = .unknownProduct
        case .planChangeNotAllowed: self = .planChangeNotAllowed
        default: self = .reflectDelayed
        }
    }

    var message: String {
        switch self {
        case .purchaseFailed: return "billing::paywall::fail::purchase".localized()
        case .invalidTransaction: return "billing::paywall::fail::invalidTransaction".localized()
        case .unknownProduct: return "billing::paywall::fail::unknownProduct".localized()
        case .planChangeNotAllowed: return "billing::paywall::fail::planChangeNotAllowed".localized()
        case .reflectDelayed: return "billing::paywall::fail::reflectDelayed".localized()
        }
    }
}

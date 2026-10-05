//
//  ColorThemeLicense+Mapping.swift
//  Repository
//
//  Created by sudo.park on 10/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


struct ColorThemeLicenseMapper: Codable {

    private enum CodingKeys: String, CodingKey {
        case grantedAt = "granted_at"
    }

    let license: ColorThemeLicense

    init(license: ColorThemeLicense) {
        self.license = license
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.license = .init(grantedAt: try container.decode(Date.self, forKey: .grantedAt))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.license.grantedAt, forKey: .grantedAt)
    }
}

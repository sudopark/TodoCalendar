//
//  AppUpdateInfo+Mapping.swift
//  Repository
//

import Foundation
import Domain


struct AppUpdateInfoMapper: Decodable {

    let info: AppUpdateInfo

    private enum CodingKeys: String, CodingKey {
        case forceUpdateVersion = "force_update_version"
        case recommendUpdateVersion = "recommend_update_version"
        case latestVersion = "latest_version"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var info = AppUpdateInfo()
        info.forceUpdateVersion = try container.decodeIfPresent(String.self, forKey: .forceUpdateVersion)
        info.recommendUpdateVersion = try container.decodeIfPresent(String.self, forKey: .recommendUpdateVersion)
        info.latestVersion = try container.decodeIfPresent(String.self, forKey: .latestVersion)
        self.info = info
    }
}

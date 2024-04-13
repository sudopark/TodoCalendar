//
//  EventDetailData+Mapping.swift
//  Repository
//
//  Created by sudo.park on 4/7/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import Foundation
import Prelude
import Optics
import Domain


enum EventDetailDataCodingKeys: String, CodingKey {
    case eventId = "event_id"
    case place
    case placeLat = "lat"
    case placeCoordinate = "coordinate"
    case placeLong = "long"
    case placeName = "name"
    case placeAddress = "address"
    case url
    case memo
}

private typealias CodingKeys = EventDetailDataCodingKeys

private struct PlaceMapper: Decodable {
    let place: Place
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let coordinateContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .placeCoordinate)
        self.place = .init(
            try container.decode(String.self, forKey: .placeName),
            .init(
                try coordinateContainer.decode(Double.self, forKey: .placeLat),
                try coordinateContainer.decode(Double.self, forKey: .placeLong)
            )
        )
        |> \.addressText .~ (try? container.decode(String.self, forKey: .placeAddress))
    }
}

struct EventDetailDataMapper: Decodable {
    
    let data: EventDetailData
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.data = .init(
            try container.decode(String.self, forKey: .eventId)
        )
        |> \.place .~ (try? container.decode(PlaceMapper.self, forKey: .place).place)
        |> \.url .~ (try? container.decode(String.self, forKey: .url))
        |> \.memo .~ (try? container.decode(String.self, forKey: .memo))
    }
}


extension EventDetailData {
    
    func asJson() -> [String: Any] {
        var sender: [String: Any] = [
            CodingKeys.eventId.rawValue: self.eventId
        ]
        if let place = self.place {
            var placeJson: [String: Any] = [
                CodingKeys.placeName.rawValue: place.placeName,
                CodingKeys.placeCoordinate.rawValue: [
                    CodingKeys.placeLat.rawValue: place.coordinate.latttude,
                    CodingKeys.placeLong.rawValue: place.coordinate.longitude,
                ]
            ]
            placeJson[CodingKeys.placeAddress.rawValue] = place.addressText
            sender[CodingKeys.place.rawValue] = placeJson
        }
        sender[CodingKeys.url.rawValue] = self.url
        sender[CodingKeys.memo.rawValue] = self.memo
        return sender
    }
}

struct RemoveDetailResultMapper: Decodable {
    
    init(from decoder: any Decoder) throws { }
}

//
//  LegalNotice+Mapping.swift
//  Repository
//
//  Created by sudo.park on 8/23/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import Foundation
import Domain


struct LegalNoticeMapper: Decodable {

    let updates: LegalNoticeUpdates

    private struct DocumentCodingKey: CodingKey {
        let stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }

    private enum ItemCodingKeys: String, CodingKey {
        case id
        case effectiveDate = "effective_date"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DocumentCodingKey.self)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        let entries: [(LegalDocumentType, LegalNoticeUpdateInfo)] = LegalDocumentType.allCases
            .compactMap { documentType in
                guard let codingKey = DocumentCodingKey(stringValue: documentType.rawValue),
                      let itemContainer = try? container.nestedContainer(
                        keyedBy: ItemCodingKeys.self, forKey: codingKey
                      ),
                      let id = try? itemContainer.decode(String.self, forKey: .id),
                      let dateString = try? itemContainer.decode(String.self, forKey: .effectiveDate),
                      let effectiveDate = dateFormatter.date(from: dateString)
                else { return nil }
                let info = LegalNoticeUpdateInfo(
                    id: id, documentType: documentType, effectiveDate: effectiveDate
                )
                return (documentType, info)
            }
        self.updates = Dictionary(uniqueKeysWithValues: entries)
    }
}

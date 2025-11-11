//
//  EventDetailDataTable.swift
//  Repository
//
//  Created by sudo.park on 10/28/23.
//

import Foundation
import SQLiteService
import Domain


struct EventDetailDataTable: Table {
    
    enum Columns: String, TableColumn {
        case uuid
        case url
        case memo
        case placeName = "place_name"
        case placeAddress = "place_addr"
        case placeLatitude = "place_lat"
        case placeLongitude = "place_long"
        
        var dataType: ColumnDataType {
            switch self {
            case .uuid: return .text([.primaryKey(autoIncrement: false), .unique, .notNull])
            case .url: return .text([])
            case .memo: return .text([])
            case .placeName: return .text([])
            case .placeAddress: return .text([])
            case .placeLatitude: return .real([])
            case .placeLongitude: return .real([])
            }
        }
    }
    
    typealias ColumnType = Columns
    typealias EntityType = EventDetailData
    static var tableName: String { "EventDetailData" }
    
    static func scalar(_ entity: EntityType, for column: Columns) -> (any ScalarType)? {
        switch column {
        case .uuid: return entity.eventId
        case .url: return entity.url
        case .memo: return entity.memo
        case .placeName: return entity.place?.placeName
        case .placeAddress: return entity.place?.addressText
        case .placeLatitude: return entity.place?.coordinate?.latttude
        case .placeLongitude: return entity.place?.coordinate?.longitude
        }
    }
}

extension EventDetailData: RowValueType {
    
    public init(_ cursor: CursorIterator) throws {
        self.init(
            try cursor.next().unwrap()
        )
        self.url = cursor.next()
        self.memo = cursor.next()
        
        let placeName: String? = cursor.next()
        let placeAddr: String? = cursor.next()
        let placeLatt: Double? = cursor.next()
        let placeLong: Double? = cursor.next()
        guard let name = placeName else { return }
        
        self.place = .init(name)
        if let latt = placeLatt, let long = placeLong {
            self.place?.coordinate = .init(latt, long)
        }
        self.place?.addressText = placeAddr
    }
}

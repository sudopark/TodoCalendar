//
//  CustomEventTagTable.swift
//  EventDomain
//
//  Created by sudo.park on 2023/05/28.
//

import Foundation
import SQLiteServiceMacros
import Extensions
import EventDomainInterface


public typealias CustomEventTagTable = CustomEventTagTableV0

@Table("EventTags")
public struct CustomEventTagTableV0 {
    
    @Column(.primaryKey(autoIncrement: false), .unique, .notNull)
    public let uuid: String
    
    @Column(.unique, .notNull)
    public let name: String
    
    @Column(.notNull)
    public var colorHex: String?
}


// MARK: - CustomEventTag 변환

extension CustomEventTagTable.Entity {
    
    public init(_ tag: CustomEventTag) {
        self.init(uuid: tag.uuid, name: tag.name, colorHex: tag.colorHex)
    }
    
    func asCustomEventTag() throws -> CustomEventTag {
        return CustomEventTag(
            uuid: self.uuid,
            name: self.name,
            colorHex: try self.colorHex.unwrap()
        )
    }
}

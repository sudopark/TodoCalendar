//
//  CustomEventTagTable.swift
//  Repository
//
//  Created by sudo.park on 2023/05/28.
//

import Foundation
import SQLiteServiceMacros
import Domain
import Extensions


typealias CustomEventTagTable = CustomEventTagTableV0

@Table("EventTags")
struct CustomEventTagTableV0 {
    
    @Column(.primaryKey(autoIncrement: false), .unique, .notNull)
    let uuid: String
    
    @Column(.unique, .notNull)
    let name: String
    
    @Column(.notNull)
    var colorHex: String?
}


// MARK: - CustomEventTag 변환

extension CustomEventTagTable.Entity {
    
    init(_ tag: CustomEventTag) {
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

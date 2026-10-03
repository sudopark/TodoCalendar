//
//  GoogleCalendarEventTagTable.swift
//  Repository
//
//  Created by sudo.park on 2/17/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteServiceMacros
import Domain
import Extensions


// MARK: - EventTag 메인DB 스키마 (이관이 읽고 drop 한다)

@Table("google_calendar_list")
struct GoogleCalendarEventTagTableV0 {

    @Column(.primaryKey(autoIncrement: false), .unique, .notNull, name: "tag_id")
    let tagId: String

    @Column(.notNull)
    let name: String

    @Column()
    var description: String?

    @Column()
    var background: String?

    @Column()
    var foreground: String?

    @Column(name: "color_id")
    var colorId: String?

    @Column(name: "is_selected")
    var isSelected: Bool?
}


extension GoogleCalendarEventTagTableV0 {

    static func migrateStatement(for version: Int32) -> String? {
        switch version {
        case 2:
            return Self.addColumnStatement(.isSelected)
        default: return nil
        }
    }
}


// MARK: - EventTag 외부DB 0 스키마 (0 -> 1 에서 access_role 이 붙는다)

@Table("google_calendar_list")
struct GoogleCalendarEventTagTableV1 {

    @Column(.notNull, name: "account_id")
    let accountId: String

    @Column(.primaryKey(autoIncrement: false), .unique, .notNull, name: "tag_id")
    let tagId: String

    @Column(.notNull)
    let name: String

    @Column()
    var description: String?

    @Column()
    var background: String?

    @Column()
    var foreground: String?

    @Column(name: "color_id")
    var colorId: String?

    @Column(name: "is_selected")
    var isSelected: Bool?
}


// MARK: - EventTag (google_calendar.db 신규 테이블, accountId 포함)

typealias GoogleCalendarEventTagTable = GoogleCalendarEventTagTableV2

@Table("google_calendar_list")
struct GoogleCalendarEventTagTableV2 {

    @Column(.notNull, name: "account_id")
    let accountId: String

    @Column(.primaryKey(autoIncrement: false), .unique, .notNull, name: "tag_id")
    let tagId: String

    @Column(.notNull)
    let name: String

    @Column()
    var description: String?

    @Column()
    var background: String?

    @Column()
    var foreground: String?

    @Column(name: "color_id")
    var colorId: String?

    @Column(name: "is_selected")
    var isSelected: Bool?

    @Column(name: "access_role")
    var accessRole: String?
}


extension GoogleCalendarEventTagTable {

    static func migrateStatement(for version: Int32) -> String? {
        switch version {
        case 0:
            return Self.addColumnStatement(.accessRole)
        default: return nil
        }
    }
}


// MARK: - EventTag 변환

extension GoogleCalendarEventTagTableV0.Entity {

    init(_ tag: GoogleCalendar.Tag) {
        self.init(
            tagId: tag.id,
            name: tag.name,
            description: tag.description,
            background: tag.backgroundColorHex,
            foreground: tag.foregroundColorHex,
            colorId: tag.colorId,
            isSelected: tag.isSelected ?? false
        )
    }

    func asTag() -> GoogleCalendar.Tag {
        var tag = GoogleCalendar.Tag(id: self.tagId, name: self.name)
        tag.description = self.description
        tag.backgroundColorHex = self.background
        tag.foregroundColorHex = self.foreground
        tag.colorId = self.colorId
        tag.isSelected = self.isSelected
        return tag
    }
}

extension GoogleCalendarEventTagTableV1.Entity {

    init(accountId: String, _ tag: GoogleCalendar.Tag) {
        self.init(
            accountId: accountId,
            tagId: tag.id,
            name: tag.name,
            description: tag.description,
            background: tag.backgroundColorHex,
            foreground: tag.foregroundColorHex,
            colorId: tag.colorId,
            isSelected: tag.isSelected ?? false
        )
    }
}

extension GoogleCalendarEventTagTable.Entity {

    init(accountId: String, _ tag: GoogleCalendar.Tag) {
        self.init(
            accountId: accountId,
            tagId: tag.id,
            name: tag.name,
            description: tag.description,
            background: tag.backgroundColorHex,
            foreground: tag.foregroundColorHex,
            colorId: tag.colorId,
            isSelected: tag.isSelected ?? false,
            accessRole: tag.accessRole?.rawValue
        )
    }

    func asTag() -> GoogleCalendar.Tag {
        var tag = GoogleCalendar.Tag(id: self.tagId, name: self.name)
        tag.ownerId = self.accountId
        tag.description = self.description
        tag.backgroundColorHex = self.background
        tag.foregroundColorHex = self.foreground
        tag.colorId = self.colorId
        tag.isSelected = self.isSelected
        tag.accessRole = self.accessRole.flatMap { GoogleCalendar.AccessRole(rawValue: $0) }
        return tag
    }
}

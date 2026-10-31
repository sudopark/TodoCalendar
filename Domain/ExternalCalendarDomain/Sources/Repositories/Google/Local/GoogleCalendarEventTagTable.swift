//
//  GoogleCalendarEventTagTable.swift
//  ExternalCalendarDomain
//
//  Created by sudo.park on 2/17/25.
//  Copyright © 2025 com.sudo.park. All rights reserved.
//

import Foundation
import SQLiteServiceMacros
import Extensions
import ExternalCalendarDomainInterface


// MARK: - EventTag 메인DB 스키마 (이관이 읽고 drop 한다)

@Table("google_calendar_list")
public struct GoogleCalendarEventTagTableV0 {

    @Column(.primaryKey(autoIncrement: false), .unique, .notNull, name: "tag_id")
    public let tagId: String

    @Column(.notNull)
    public let name: String

    @Column()
    public var description: String?

    @Column()
    public var background: String?

    @Column()
    public var foreground: String?

    @Column(name: "color_id")
    public var colorId: String?

    @Column(name: "is_selected")
    public var isSelected: Bool?
}


extension GoogleCalendarEventTagTableV0 {

    public static func migrateStatement(for version: Int32) -> String? {
        switch version {
        case 2:
            return Self.addColumnStatement(.isSelected)
        default: return nil
        }
    }
}


// MARK: - EventTag 외부DB 0 스키마 (0 -> 1 에서 access_role 이 붙는다)

@Table("google_calendar_list")
public struct GoogleCalendarEventTagTableV1 {

    @Column(.notNull, name: "account_id")
    public let accountId: String

    @Column(.primaryKey(autoIncrement: false), .unique, .notNull, name: "tag_id")
    public let tagId: String

    @Column(.notNull)
    public let name: String

    @Column()
    public var description: String?

    @Column()
    public var background: String?

    @Column()
    public var foreground: String?

    @Column(name: "color_id")
    public var colorId: String?

    @Column(name: "is_selected")
    public var isSelected: Bool?
}


// MARK: - EventTag (google_calendar.db 신규 테이블, accountId 포함)

public typealias GoogleCalendarEventTagTable = GoogleCalendarEventTagTableV2

@Table("google_calendar_list")
public struct GoogleCalendarEventTagTableV2 {

    @Column(.notNull, name: "account_id")
    public let accountId: String

    @Column(.primaryKey(autoIncrement: false), .unique, .notNull, name: "tag_id")
    public let tagId: String

    @Column(.notNull)
    public let name: String

    @Column()
    public var description: String?

    @Column()
    public var background: String?

    @Column()
    public var foreground: String?

    @Column(name: "color_id")
    public var colorId: String?

    @Column(name: "is_selected")
    public var isSelected: Bool?

    @Column(name: "access_role")
    public var accessRole: String?
}


extension GoogleCalendarEventTagTable {

    public static func migrateStatement(for version: Int32) -> String? {
        switch version {
        case 0:
            return Self.addColumnStatement(.accessRole)
        default: return nil
        }
    }
}


// MARK: - EventTag 변환

extension GoogleCalendarEventTagTableV0.Entity {

    public init(_ tag: GoogleCalendar.Tag) {
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

    public func asTag() -> GoogleCalendar.Tag {
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

    public init(accountId: String, _ tag: GoogleCalendar.Tag) {
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

    public init(accountId: String, _ tag: GoogleCalendar.Tag) {
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

    public func asTag() -> GoogleCalendar.Tag {
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

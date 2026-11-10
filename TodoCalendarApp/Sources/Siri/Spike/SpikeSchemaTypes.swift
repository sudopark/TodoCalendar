import Foundation
import AppIntents
import CoreSpotlight
import GeoToolbox
import OSLog

let spikeLog = Logger(subsystem: "spike1157", category: "schema")

@available(iOS 27.0, *)
func spikeIndexSchemaEntities() {
    let titles = ["장보기", "회의"]
    let reminders = titles.map { title in
        var entity = SpikeReminderEntity(id: "spike-\(title)")
        entity.title = title
        return entity
    }
    let events = titles.map { title in
        var entity = SpikeEventEntity(id: "spike-\(title)")
        entity.title = title
        return entity
    }
    Task {
        do {
            try await CSSearchableIndex.default().indexAppEntities(reminders)
            try await CSSearchableIndex.default().indexAppEntities(events)
            spikeLog.notice("indexed reminders=\(reminders.count) events=\(events.count)")
        } catch {
            spikeLog.error("index failed \(error.localizedDescription)")
        }
    }
}


// MARK: - reminders

@available(iOS 27.0, *)
struct SpikeReminderQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SpikeReminderEntity] {
        identifiers.map { SpikeReminderEntity(id: $0) }
    }
    func entities(matching string: String) async throws -> [SpikeReminderEntity] {
        var entity = SpikeReminderEntity(id: "spike-\(string)")
        entity.title = string
        return [entity]
    }
    func suggestedEntities() async throws -> [SpikeReminderEntity] {
        ["장보기", "회의"].map { title in
            var entity = SpikeReminderEntity(id: "spike-\(title)")
            entity.title = title
            return entity
        }
    }
}

@available(iOS 27.0, *)
@AppEntity(schema: .reminders.reminder)
struct SpikeReminderEntity: IndexedEntity {
    static let defaultQuery = SpikeReminderQuery()
    let id: String
    var title: String
    var note: String?
    var dueDate: DateComponents?
    var creationDate: Date?
    var completionDate: Date?
    var isCompleted: Bool
    var isFlagged: Bool?
    var urls: [URL]
    var tags: Set<String>
    var recurrence: Calendar.RecurrenceRule?
    var list: SpikeListEntity
    var locationTrigger: SpikeLocationTriggerEntity?
    init(id: String) {
        self.id = id
        self.title = ""
        self.isCompleted = false
        self.urls = []
        self.tags = []
        self.list = SpikeListEntity(id: "")
    }
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
}

@available(iOS 27.0, *)
struct SpikeListQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SpikeListEntity] { [] }
    func entities(matching string: String) async throws -> [SpikeListEntity] { [] }
}

@available(iOS 27.0, *)
@AppEntity(schema: .reminders.list)
struct SpikeListEntity {
    static let defaultQuery = SpikeListQuery()
    let id: String
    var name: String
    var type: SpikeListType
    init(id: String) {
        self.id = id
        self.name = ""
        self.type = .standard
    }
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

@available(iOS 27.0, *)
@AppEnum(schema: .reminders.listType)
enum SpikeListType: String {
    case standard
    static let caseDisplayRepresentations: [SpikeListType: DisplayRepresentation] = [.standard: "standard"]
}

@available(iOS 27.0, *)
struct SpikeSectionQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SpikeSectionEntity] { [] }
    func entities(matching string: String) async throws -> [SpikeSectionEntity] { [] }
}

@available(iOS 27.0, *)
@AppEntity(schema: .reminders.section)
struct SpikeSectionEntity {
    static let defaultQuery = SpikeSectionQuery()
    let id: String
    var name: String
    var list: SpikeListEntity
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(id)") }
}

@available(iOS 27.0, *)
struct SpikeLocationTriggerQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SpikeLocationTriggerEntity] { [] }
    func entities(matching string: String) async throws -> [SpikeLocationTriggerEntity] { [] }
}

@available(iOS 27.0, *)
@AppEntity(schema: .reminders.locationTrigger)
struct SpikeLocationTriggerEntity {
    static let defaultQuery = SpikeLocationTriggerQuery()
    let id: String
    var event: SpikeLocationTriggerEvent
    var place: PlaceDescriptor
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(id)") }
}

@available(iOS 27.0, *)
@AppEnum(schema: .reminders.locationTriggerEvent)
enum SpikeLocationTriggerEvent: String {
    case arrive
    case depart
    static let caseDisplayRepresentations: [SpikeLocationTriggerEvent: DisplayRepresentation] = [.arrive: "arrive", .depart: "depart"]
}

@available(iOS 27.0, *)
@AppIntent(schema: .reminders.createReminder)
struct SpikeCreateReminderIntent {
    var title: String
    var note: String?
    var dueDate: DateComponents?
    var isFlagged: Bool?
    var urls: [URL]
    var tags: Set<String>
    var images: [IntentFile]
    var recurrence: Calendar.RecurrenceRule?
    var list: SpikeListEntity?
    var section: SpikeSectionEntity?
    var locationTrigger: SpikeLocationTriggerEntity?
    @Parameter(title: "Event Type") var eventTypeName: String?
    func perform() async throws -> some ReturnsValue<SpikeReminderEntity> & ProvidesDialog {
        spikeLog.notice("schema intent SpikeCreateReminderIntent \(title) due=\(String(describing: dueDate))")
        return .result(value: SpikeReminderEntity(id: "spike"), dialog: "[spike] SpikeCreateReminderIntent \(title) due=\(String(describing: dueDate))")
    }
}

@available(iOS 27.0, *)
@AppIntent(schema: .reminders.updateReminder)
struct SpikeUpdateReminderIntent {
    var target: SpikeReminderEntity
    var title: String?
    var note: String?
    var dueDate: DateComponents?
    var isCompleted: Bool?
    var isFlagged: Bool?
    var urls: [URL]?
    var tags: Set<String>?
    var recurrence: Calendar.RecurrenceRule?
    var list: SpikeListEntity?
    var locationTrigger: SpikeLocationTriggerEntity?
    func perform() async throws -> some ReturnsValue<SpikeReminderEntity> & ProvidesDialog {
        spikeLog.notice("schema intent SpikeUpdateReminderIntent \(target.id) done=\(String(describing: isCompleted))")
        return .result(value: SpikeReminderEntity(id: "spike"), dialog: "[spike] SpikeUpdateReminderIntent \(target.id) done=\(String(describing: isCompleted))")
    }
}

@available(iOS 27.0, *)
@AppIntent(schema: .reminders.deleteReminders)
struct SpikeDeleteRemindersIntent {
    var entities: [SpikeReminderEntity]
    func perform() async throws -> some IntentResult & ProvidesDialog {
        spikeLog.notice("schema intent SpikeDeleteRemindersIntent")
        return .result(dialog: "[spike] SpikeDeleteRemindersIntent \(entities.count)")
    }
}

// MARK: - calendar

@available(iOS 27.0, *)
@UnionValue
enum SpikeEventLocation {
    case place(PlaceDescriptor)
    case text(String)
}

@available(iOS 27.0, *)
@UnionValue
enum SpikeEventAlarm {
    case offset(Duration)
    case date(Date)
}

@available(iOS 27.0, *)
struct SpikeEventQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SpikeEventEntity] {
        identifiers.map { SpikeEventEntity(id: $0) }
    }
    func entities(matching string: String) async throws -> [SpikeEventEntity] {
        var entity = SpikeEventEntity(id: "spike-\(string)")
        entity.title = string
        return [entity]
    }
    func suggestedEntities() async throws -> [SpikeEventEntity] {
        ["장보기", "회의"].map { title in
            var entity = SpikeEventEntity(id: "spike-\(title)")
            entity.title = title
            return entity
        }
    }
}

@available(iOS 27.0, *)
@AppEntity(schema: .calendar.event)
struct SpikeEventEntity: IndexedEntity {
    static let defaultQuery = SpikeEventQuery()
    let id: String
    var title: String
    var note: String?
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var location: SpikeEventLocation?
    var virtualLocation: URL?
    var travelTime: Measurement<UnitDuration>?
    var status: SpikeEventStatus?
    var alarms: [SpikeEventAlarm]
    var attendees: [SpikeAttendeeEntity]
    var organizers: [IntentPerson]
    var recurrence: Calendar.RecurrenceRule?
    var calendar: SpikeCalendarEntity
    @Property(title: "Event Type") var eventTypeName: String?
    init(id: String) {
        self.id = id
        self.title = ""
        self.startDate = Date()
        self.endDate = Date()
        self.isAllDay = false
        self.alarms = []
        self.attendees = []
        self.organizers = []
        self.calendar = SpikeCalendarEntity(id: "")
    }
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
}

@available(iOS 27.0, *)
@AppEnum(schema: .calendar.eventStatus)
enum SpikeEventStatus: String {
    case confirmed
    case tentative
    case cancelled
    static let caseDisplayRepresentations: [SpikeEventStatus: DisplayRepresentation] = [
        .confirmed: "confirmed", .tentative: "tentative", .cancelled: "cancelled"
    ]
}

@available(iOS 27.0, *)
@AppEnum(schema: .calendar.eventSpan)
enum SpikeEventSpan: String {
    case this
    case future
    case all
    static let caseDisplayRepresentations: [SpikeEventSpan: DisplayRepresentation] = [
        .this: "this", .future: "future", .all: "all"
    ]
}

@available(iOS 27.0, *)
struct SpikeCalendarQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SpikeCalendarEntity] { [] }
    func entities(matching string: String) async throws -> [SpikeCalendarEntity] { [] }
}

@available(iOS 27.0, *)
@AppEntity(schema: .calendar.calendar)
struct SpikeCalendarEntity {
    static let defaultQuery = SpikeCalendarQuery()
    let id: String
    var title: String
    init(id: String) {
        self.id = id
        self.title = ""
    }
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
}

@available(iOS 27.0, *)
struct SpikeAttendeeQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [SpikeAttendeeEntity] { [] }
    func entities(matching string: String) async throws -> [SpikeAttendeeEntity] { [] }
}

@available(iOS 27.0, *)
@AppEntity(schema: .calendar.attendee)
struct SpikeAttendeeEntity {
    static let defaultQuery = SpikeAttendeeQuery()
    let id: String
    var person: IntentPerson
    var isAttendanceOptional: Bool
    var status: SpikeAttendeeStatus?
    var type: SpikeAttendeeType?
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(id)") }
}

@available(iOS 27.0, *)
@AppEnum(schema: .calendar.attendeeType)
enum SpikeAttendeeType: String {
    case person
    static let caseDisplayRepresentations: [SpikeAttendeeType: DisplayRepresentation] = [.person: "person"]
}

@available(iOS 27.0, *)
@AppEnum(schema: .calendar.attendeeStatus)
enum SpikeAttendeeStatus: String {
    case accepted
    case declined
    case tentative
    static let caseDisplayRepresentations: [SpikeAttendeeStatus: DisplayRepresentation] = [
        .accepted: "accepted", .declined: "declined", .tentative: "tentative"
    ]
}

@available(iOS 27.0, *)
@AppIntent(schema: .calendar.createEvent)
struct SpikeCreateEventIntent {
    var title: String
    var note: String?
    var startDate: Date
    var endDate: Date?
    var isAllDay: Bool
    var location: SpikeEventLocation?
    var recurrence: Calendar.RecurrenceRule?
    var attendees: [SpikeAttendeeEntity]
    var calendar: SpikeCalendarEntity
    func perform() async throws -> some ReturnsValue<SpikeEventEntity> & ProvidesDialog {
        spikeLog.notice("schema intent SpikeCreateEventIntent \(title) start=\(startDate)")
        return .result(value: SpikeEventEntity(id: "spike"), dialog: "[spike] SpikeCreateEventIntent \(title) start=\(startDate)")
    }
}

@available(iOS 27.0, *)
@AppIntent(schema: .calendar.updateEvent)
struct SpikeUpdateEventIntent {
    var event: SpikeEventEntity
    var span: SpikeEventSpan?
    var title: String?
    var note: String?
    var startDate: Date?
    var endDate: Date?
    var isAllDay: Bool?
    var location: SpikeEventLocation?
    var recurrence: Calendar.RecurrenceRule?
    var attendees: [SpikeAttendeeEntity]?
    var calendar: SpikeCalendarEntity?
    func perform() async throws -> some ReturnsValue<SpikeEventEntity> & ProvidesDialog {
        spikeLog.notice("schema intent SpikeUpdateEventIntent \(event.id) span=\(String(describing: span))")
        return .result(value: SpikeEventEntity(id: "spike"), dialog: "[spike] SpikeUpdateEventIntent \(event.id) span=\(String(describing: span))")
    }
}

@available(iOS 27.0, *)
@AppIntent(schema: .calendar.deleteEvent)
struct SpikeDeleteEventIntent {
    var entity: SpikeEventEntity
    var span: SpikeEventSpan?
    func perform() async throws -> some IntentResult & ProvidesDialog {
        spikeLog.notice("schema intent SpikeDeleteEventIntent")
        return .result(dialog: "[spike] SpikeDeleteEventIntent \(entity.id)")
    }
}

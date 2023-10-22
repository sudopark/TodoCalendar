//
//  
//  SelectEventRepeatOptionViewModel.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/22/23.
//
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Scenes


private typealias Options = EventRepeatingOptions

private enum SupportingOptions: Equatable {
    case everyDay
    case everyWeek(_ interval: Int)
    case everyMonth(_ day: Int)
    case everyYear
    case everyMonthLastAllWeekDays
    case everyMonthSomeWeekDay(_ seq: Int, weekDay: DayOfWeeks)
    case everyMonthLastWeekDay(_ weekDay: DayOfWeeks)
    
    init?(_ option: EventRepeatingOption) {
        switch option {
        case let day as Options.EveryDay where day.interval == 1:
            self = .everyDay
            
        case let week as Options.EveryWeek:
            self = .everyWeek(week.interval)
            
        case let month as Options.EveryMonth:
            guard let support = SupportingOptions(month: month)
            else { return nil }
            self = support
            
        case let year as Options.EveryYearSomeDay where year.interval == 1:
            self = .everyYear
            
        default: return nil
        }
    }
    
    private init?(month: Options.EveryMonth) {
        guard month.interval == 1 else { return nil }
        
        switch month.selection {
        case .days(let days):
            guard let day = days.first else { return nil }
            self = .everyMonth(day)
            
        case .week(let ordinals, let weekdays):
            guard let ordinal = ordinals.first, let firstWeekDay = weekdays.first else { return nil }
            if case let .seq(seq) = ordinal, weekdays.count == 1 {
                self = .everyMonthSomeWeekDay(seq, weekDay: firstWeekDay)
            } else if weekdays.count == 7 {
                self = .everyMonthLastAllWeekDays
            } else if weekdays.count == 1 {
                self = .everyMonthLastWeekDay(firstWeekDay)
            } else {
                return nil
            }
        }
    }
    
    static func supports(from startTime: Date, timeZone: TimeZone) -> [any EventRepeatingOption] {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let startDay = calendar.component(.day, from: startTime)
        guard let weekday = DayOfWeeks(rawValue: calendar.component(.weekday, from: startTime))
        else { return [] }
        return [
            EventRepeatingOptions.EveryDay(),
            EventRepeatingOptions.EveryWeek(timeZone),
            EventRepeatingOptions.EveryWeek(timeZone) |> \.interval .~ 2,
            EventRepeatingOptions.EveryWeek(timeZone) |> \.interval .~ 3,
            EventRepeatingOptions.EveryWeek(timeZone) |> \.interval .~ 4,
            EventRepeatingOptions.EveryMonth(timeZone: timeZone)
            |> \.selection .~ .days([startDay]),
            EventRepeatingOptions.EveryYearSomeDay(timeZone: timeZone),
            EventRepeatingOptions.EveryMonth(timeZone: timeZone)
            |> \.selection .~ .week([.last], [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]),
            EventRepeatingOptions.EveryMonth(timeZone: timeZone)
            |> \.selection .~ .week([.seq(1)], [weekday]),
            EventRepeatingOptions.EveryMonth(timeZone: timeZone)
            |> \.selection .~ .week([.seq(2)], [weekday]),
            EventRepeatingOptions.EveryMonth(timeZone: timeZone)
            |> \.selection .~ .week([.seq(3)], [weekday]),
            EventRepeatingOptions.EveryMonth(timeZone: timeZone)
            |> \.selection .~ .week([.seq(4)], [weekday]),
            EventRepeatingOptions.EveryMonth(timeZone: timeZone)
            |> \.selection .~ .week([.last], [weekday])
        ]
    }
}

struct SelectRepeatingOptionModel: Equatable {
    
    let id: String
    let text: String
    let option: EventRepeatingOption?
    
    init(_ text: String, _ option: EventRepeatingOption?) {
        self.id = UUID().uuidString
        self.text = text
        self.option = option
    }
    
    var isNotRepeat: Bool {
        return self.option == nil
    }
    
    init?(_ option: EventRepeatingOption, _ startTime: Date, _ timeZone: TimeZone) {
        guard let supportOption = SupportingOptions(option) else { return nil }
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        switch supportOption {
        case .everyDay:
            self = .init("Everyday".localized(), option)
            
        case .everyWeek(let seq) where seq == 1:
            self = .init("Every Week".localized(), option)
            
        case .everyWeek(let seq):
            self = .init("every \(seq) week".localized(), option)
            
        case .everyMonth(let day):
            let currentDay = calendar.component(.day, from: startTime)
            if currentDay == day {
                self = .init("Every Month".localized(), option)
            } else {
                self = .init("Every Month".localized() + "\(day)day".localized(), option)
            }
        case .everyYear:
            self = .init("Every Year".localized(), option)
            
        case .everyMonthLastAllWeekDays:
            self = .init("Every month last week all days".localized(), option)
            
        case .everyMonthSomeWeekDay(let seq, let weekDay):
            let text = "Every month".localized() + " "
                + "\(seq)" + "week_suffix".localized() + " "
                + "weekday_\(weekDay.rawValue)".localized()
            self = .init(text, option)
            
        case .everyMonthLastWeekDay(let weekDay):
            let text = "Every month last".localized()
                + " "
                + "weekday_\(weekDay.rawValue)".localized()
            self = .init(text, option)
        }
    }
    
    static func == (lhs: SelectRepeatingOptionModel, rhs: SelectRepeatingOptionModel) -> Bool {
        return lhs.id == rhs.id
    }
}

struct RepeatEndTime: Equatable {
    
    let text: String
    var isOn: Bool = false
    fileprivate let date: Date
    
    init(_ date: Date, from startTime: Date, timeZone: TimeZone) {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        
        self.date = calendar
            .dateBySetting(from: date) {
                $0.hour = calendar.component(.hour, from: startTime)
                $0.minute = calendar.component(.minute, from: startTime)
                $0.second = calendar.component(.second, from: startTime)
            } ?? date
            
        let formatter = DateFormatter() 
            |> \.timeZone .~ timeZone
            |> \.dateFormat .~ "yyyy.MM.dd".localized()
        self.text = formatter.string(from: self.date)
    }
    
    var endTimeIfOn: Date? {
        return self.isOn ? self.date : nil
    }
}

// MARK: - SelectEventRepeatOptionViewModel

protocol SelectEventRepeatOptionViewModel: AnyObject, Sendable, SelectEventRepeatOptionSceneInteractor {

    // interactor
    func prepare()
    func selectOption(_ id: String)
    func toggleHasRepeatEnd(isOn: Bool)
    func selectRepeatEndDate(_ date: Date)
    
    // presenter
    var options: AnyPublisher<[SelectRepeatingOptionModel], Never> { get }
    var selectedOptionId: AnyPublisher<String, Never> { get }
    var hasRepeatEnd: AnyPublisher<Bool, Never> { get }
    var repeatEndTimeText: AnyPublisher<String, Never> { get }
}


// MARK: - SelectEventRepeatOptionViewModelImple

final class SelectEventRepeatOptionViewModelImple: SelectEventRepeatOptionViewModel, @unchecked Sendable {
    
    private let startTime: Date
    private let previousSelectOption: EventRepeating?
    private let calendarSettingUsecase: any CalendarSettingUsecase
    
    var listener: (any SelectEventRepeatOptionSceneListener)?
    var router: (any SelectEventRepeatOptionRouting)?
    
    init(
        startTime: Date,
        previousSelected repeating: EventRepeating?,
        calendarSettingUsecase: any CalendarSettingUsecase
    ) {
        self.startTime = startTime
        self.previousSelectOption = repeating
        self.calendarSettingUsecase = calendarSettingUsecase
    }
    
    
    private struct OptionSeqMap {
        var storage: [String: (Int, SelectRepeatingOptionModel)] = [:]
        
        init() {
            self.storage = [:]
        }
        init(_ options: [SelectRepeatingOptionModel]) {
            self.storage = options.enumerated()
                .map { ($0.offset, $0.element) }
                .asDictionary { $0.1.id }
        }
    }
    
    private struct Subject {
        let timeZone = CurrentValueSubject<TimeZone?, Never>(nil)
        let options = CurrentValueSubject<OptionSeqMap, Never>(.init())
        let selectedOptionId = CurrentValueSubject<String?, Never>(nil)
        let repeatEndTime = CurrentValueSubject<RepeatEndTime?, Never>(nil)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
}


// MARK: - SelectEventRepeatOptionViewModelImple Interactor

extension SelectEventRepeatOptionViewModelImple {
    
    func prepare() {
        let previousSelectOption = self.previousSelectOption
        let setupValue: (TimeZone) -> Void = { [weak self] timeZone in
            self?.subject.timeZone.send(timeZone)
            self?.setupOptionModels(timeZone, previousSelectOption)
            self?.setupInitailEndTime(timeZone, previousSelectOption)
        }
        
        self.calendarSettingUsecase.currentTimeZone
            .first()
            .sink(receiveValue: setupValue)
            .store(in: &self.cancellables)
    }
    
    private func setupOptionModels(
        _ timeZone: TimeZone,
        _ previousSelectOption: EventRepeating?
    ) {
        
        let notRepeatOptionModel = SelectRepeatingOptionModel("not repeat".localized(), nil)
        let previousOptionModel = previousSelectOption.flatMap {
            SelectRepeatingOptionModel($0.repeatOption, self.startTime, timeZone)
        }
        let supportOptionModels = SupportingOptions.supports(from: self.startTime, timeZone: timeZone)
            .compactMap { SelectRepeatingOptionModel($0, self.startTime, timeZone) }
        
        let sameOptionWithPrevious = supportOptionModels.first(where: { $0.option?.compareHash == previousSelectOption?.repeatOption.compareHash })
        switch (previousOptionModel, sameOptionWithPrevious) {
        case (_, .some(let same)):
            self.subject.options.send(
                .init([notRepeatOptionModel] + supportOptionModels)
            )
            self.subject.selectedOptionId.send(same.id)
            
        case (let .some(prev), _):
            self.subject.options.send(
                .init([notRepeatOptionModel, prev] + supportOptionModels)
            )
            self.subject.selectedOptionId.send(prev.id)
            
        default:
            self.subject.options.send(
                .init([notRepeatOptionModel] + supportOptionModels)
            )
            self.subject.selectedOptionId.send(notRepeatOptionModel.id)
        }
    }
    
    private func setupInitailEndTime(
        _ timeZone: TimeZone,
        _ previousSelectOption: EventRepeating?
    ) {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        
        guard let targetDate = previousSelectOption?.repeatingEndTime.map ({ Date(timeIntervalSince1970: $0) })
                ?? calendar.lastDayOfMonth(from: self.startTime)
        else { return }
        
        let endTime = RepeatEndTime(targetDate, from: self.startTime, timeZone: timeZone)
        |> \.isOn .~ (previousSelectOption?.repeatingEndTime != nil)
        self.subject.repeatEndTime.send(endTime)
    }
    
    func selectOption(_ id: String) {
        self.subject.selectedOptionId.send(id)
        self.notifyOptionSelected()
    }
    
    func toggleHasRepeatEnd(isOn: Bool) {
        guard let time = self.subject.repeatEndTime.value else { return }
        let newTime = time |> \.isOn .~ isOn
        self.subject.repeatEndTime.send(newTime)
        self.notifyOptionSelected()
    }
    
    func selectRepeatEndDate(_ date: Date) {
        guard let timeZone = self.subject.timeZone.value else { return }
        let time = RepeatEndTime(date, from: self.startTime, timeZone: timeZone)
            |> \.isOn .~ true
        self.subject.repeatEndTime.send(time)
        self.notifyOptionSelected()
    }
    
    private func notifyOptionSelected() {
        guard let optionId = self.subject.selectedOptionId.value,
              let model = self.subject.options.value.storage[optionId]?.1
        else { return }
        
        if let option = model.option {
            let repeating = EventRepeating(
                repeatingStartTime: self.startTime.timeIntervalSince1970,
                repeatOption: option
            )
            |> \.repeatingEndTime .~ self.subject.repeatEndTime.value?.endTimeIfOn?.timeIntervalSince1970
            let result = EventRepeatingTimeSelectResult(text: model.text, repeating: repeating)
            self.listener?.selectEventRepeatOption(didSelect: result)
        } else {
            self.listener?.selectEventRepeatOptionNotRepeat()
        }
    }
}


// MARK: - SelectEventRepeatOptionViewModelImple Presenter

extension SelectEventRepeatOptionViewModelImple {
    
    var options: AnyPublisher<[SelectRepeatingOptionModel], Never> {
        let transform: (OptionSeqMap) -> [SelectRepeatingOptionModel] = { seqMap in
            return seqMap.storage.values
                .sorted(by: { $0.0 < $1.0 })
                .map { $0.1 }
        }
        return self.subject.options
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var selectedOptionId: AnyPublisher<String, Never> {
        return self.subject.selectedOptionId
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var repeatEndTimeText: AnyPublisher<String, Never> {
        return self.subject.repeatEndTime
            .compactMap { $0?.text }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var hasRepeatEnd: AnyPublisher<Bool, Never> {
        return self.subject.repeatEndTime
            .compactMap { $0?.isOn }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}

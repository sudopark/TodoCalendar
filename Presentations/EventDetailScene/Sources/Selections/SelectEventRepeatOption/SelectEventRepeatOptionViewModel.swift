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
import Extensions
import Scenes


private typealias Options = EventRepeatingOptions

private enum SupportingOptions: Equatable {
    case everyDay
    case everyWeek(_ interval: Int, _ weekDay: DayOfWeeks)
    case everyMonth(_ day: Int)
    case everyYear(_ month: Int, _ day: Int)
    case everyMonthLastAllWeekDays
    case everyMonthSomeWeekDay(_ seq: Int, weekDay: DayOfWeeks)
    case everyMonthLastWeekDay(_ weekDay: DayOfWeeks)
    
    init?(_ option: EventRepeatingOption) {
        switch option {
        case let day as Options.EveryDay where day.interval == 1:
            self = .everyDay
            
        case let week as Options.EveryWeek where week.dayOfWeeks.count == 1:
            self = .everyWeek(week.interval, week.dayOfWeeks[0])
            
        case let month as Options.EveryMonth:
            guard let support = SupportingOptions(month: month)
            else { return nil }
            self = support
            
        case let year as Options.EveryYearSomeDay where year.interval == 1:
            self = .everyYear(year.month, year.day)
            
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
    
    static func supports(from startTime: Date, timeZone: TimeZone) -> [[any EventRepeatingOption]] {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let month = calendar.component(.month, from: startTime)
        let startDay = calendar.component(.day, from: startTime)
        guard let weekday = DayOfWeeks(rawValue: calendar.component(.weekday, from: startTime))
        else { return [] }
        return [
            [
                EventRepeatingOptions.EveryDay(),
                EventRepeatingOptions.EveryWeek(timeZone)
                    |> \.dayOfWeeks .~ [weekday],
                EventRepeatingOptions.EveryWeek(timeZone) 
                    |> \.interval .~ 2
                    |> \.dayOfWeeks .~ [weekday],
                EventRepeatingOptions.EveryWeek(timeZone) 
                    |> \.interval .~ 3
                    |> \.dayOfWeeks .~ [weekday],
                EventRepeatingOptions.EveryWeek(timeZone) 
                    |> \.interval .~ 4
                    |> \.dayOfWeeks .~ [weekday],
                EventRepeatingOptions.EveryMonth(timeZone: timeZone)
                    |> \.selection .~ .days([startDay]),
                EventRepeatingOptions.EveryYearSomeDay(timeZone, month, startDay),
            ],
            [
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
            self = .init(R.String.EventDetail.Repeating.everyDayTitle, option)
            
        case .everyWeek(let seq, let weekDay) where seq == 1:
            if weekDay.rawValue == calendar.component(.weekday, from: startTime) {
                self = .init(
                    "eventDetail.repeating.everyWeek:title".localized(), option
                )
            } else {
                self = .init(
                    "eventDetail.repeating.everyWeekSomeDay:title".localized(with: weekDay.text), option
                )
            }
            
        case .everyWeek(let seq, let weekDay):
            if weekDay.rawValue == calendar.component(.weekday, from: startTime) {
                self = .init(
                    "eventDetail.repeating.everySomeWeek:title".localized(with: seq), option
                )
            } else {
                self = .init(
                    "eventDetail.repeating.everySomeWeekSomeDay:title".localized(with: seq, weekDay.text), option
                )
            }
            
        case .everyMonth(let day):
            let currentDay = calendar.component(.day, from: startTime)
            if currentDay == day {
                self = .init("eventDetail.repeating.everyMonth:title".localized(), option)
            } else {
                let ordinal = day.ordinal ?? "\(day)"
                self = .init(
                    "eventDetail.repeating.everyMonth_someDay:title".localized(with: ordinal), option
                )
            }
        case .everyYear(let month, let day):
            if calendar.component(.month, from: startTime) == month &&
               calendar.component(.day, from: startTime) == day {
                self = .init("eventDetail.repeating.everyYear:title".localized(), option)
            } else {
                let dateText = calendar.dateText(month, day)
                self = .init("eventDetail.repeating.everyYearSomeDay:title".localized(with: dateText), option)
            }
            
        case .everyMonthLastAllWeekDays:
            self = .init(R.String.EventDetail.Repeating.everyLastWeekDaysOfEveryMonthTitle, option)
            
        case .everyMonthSomeWeekDay(let seq, let weekDay):
            let text = "eventDetail.repeating.every\(seq)WeekOfEveryMonth::someday".localized(with: weekDay.text)
            self = .init(text, option)
            
        case .everyMonthLastWeekDay(let weekDay):
            let text = R.String.EventDetail.Repeating.everyLastWeekOfEveryMonthSomeday(weekDay.text)
            self = .init(text, option)
        }
    }
    
    static func == (lhs: SelectRepeatingOptionModel, rhs: SelectRepeatingOptionModel) -> Bool {
        return lhs.id == rhs.id
    }
}

struct RepeatEndTime: Equatable {
    
    let text: String
    let date: Date
    
    init(_ date: Date, timeZone: TimeZone) {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let lastTimeOfDate = calendar.endOfDay(for: date) ?? date
        let formatter = DateFormatter()
            |> \.timeZone .~ timeZone
            |> \.dateFormat .~ R.String.DateForm.yyyyMMDd
        self.text = formatter.string(from: lastTimeOfDate)
        self.date = lastTimeOfDate
    }
    
    static func defaultTime(_ startTime: Date, timeZone: TimeZone) -> RepeatEndTime {
        let calendar = Calendar(identifier: .gregorian) |> \.timeZone .~ timeZone
        let targetDate = calendar.lastDayOfMonth(from: startTime) ?? Date()
        return .init(targetDate, timeZone: timeZone)
    }
}

enum RepeatEndOptionModel: Equatable {
    case never
    case on(date: RepeatEndTime)
    case after(count: Int)
    
    var endDate: Date? {
        guard case .on(let date) = self else { return nil }
        return date.date
    }
    
    var asEndOption: EventRepeating.RepeatEndOption? {
        switch self {
        case .never: return nil
        case .on(let date): return .until(date.date.timeIntervalSince1970)
        case .after(let count): return .count(count)
        }
    }
}

// MARK: - SelectEventRepeatOptionViewModel

protocol SelectEventRepeatOptionViewModel: AnyObject, Sendable, SelectEventRepeatOptionSceneInteractor {

    // interactor
    func prepare()
    func selectOption(_ id: String)
    func removeRepeatEndOption()
    func selectRepeatEndDate(_ date: Date)
    func selectRepeatEndCount(_ count: Int)
    func close()
    
    // presenter
    var options: AnyPublisher<[[SelectRepeatingOptionModel]], Never> { get }
    var selectedOptionId: AnyPublisher<String, Never> { get }
    var repeatStartTimeText: AnyPublisher<String, Never> { get }
    var defaultRepeatEndDate: AnyPublisher<Date, Never> { get }
    var repeatEndOption: AnyPublisher<RepeatEndOptionModel, Never> { get }
}


// MARK: - SelectEventRepeatOptionViewModelImple

final class SelectEventRepeatOptionViewModelImple: SelectEventRepeatOptionViewModel, @unchecked Sendable {
    
    private let selectTime: Date
    private let previousSelectOption: EventRepeating?
    private let calendarSettingUsecase: any CalendarSettingUsecase
    
    var listener: (any SelectEventRepeatOptionSceneListener)?
    var router: (any SelectEventRepeatOptionRouting)?
    
    init(
        selectTime: Date,
        previousSelected repeating: EventRepeating?,
        calendarSettingUsecase: any CalendarSettingUsecase
    ) {
        self.selectTime = selectTime
        self.previousSelectOption = repeating
        self.calendarSettingUsecase = calendarSettingUsecase
    }
    
    
    private struct OptionSeqMap {
        private var idOptionMap: [String: SelectRepeatingOptionModel] = [:]
        private var optionIdList: [[String]] = []
        
        init() { }
        
        init(_ options: [[SelectRepeatingOptionModel]]) {
            self.idOptionMap = options.flatMap { $0 }.asDictionary { $0.id }
            self.optionIdList = options.map { list in list.map { $0.id } }
        }
        
        func option(_ id: String) -> SelectRepeatingOptionModel? {
            return self.idOptionMap[id]
        }
        
        var optionList: [[SelectRepeatingOptionModel]] {
            return self.optionIdList.map { ids in
                return ids.compactMap { idOptionMap[$0] }
            }
        }
    }
    
    private struct Subject {
        let timeZone = CurrentValueSubject<TimeZone?, Never>(nil)
        let options = CurrentValueSubject<OptionSeqMap, Never>(.init())
        let selectedOptionId = CurrentValueSubject<String?, Never>(nil)
        let defaultRepeatEndDate = CurrentValueSubject<Date?, Never>(nil)
        let endOption = CurrentValueSubject<RepeatEndOptionModel?, Never>(nil)
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
            self?.setupInitailEndOption(timeZone, previousSelectOption)
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
        
        let notRepeatOptionModel = SelectRepeatingOptionModel(R.String.EventDetail.Repeating.notRepeatingTitle, nil)
        let previousOptionModel = previousSelectOption.flatMap {
            SelectRepeatingOptionModel($0.repeatOption, self.selectTime, timeZone)
        }
        let supportOptionModels = SupportingOptions.supports(from: self.selectTime, timeZone: timeZone)
            .map { options in
                options.compactMap { SelectRepeatingOptionModel($0, self.selectTime, timeZone) }
            }
        
        let sameOptionWithPrevious = supportOptionModels.flatMap { $0 }.first(where: { $0.option?.compareHash == previousSelectOption?.repeatOption.compareHash })
        switch (previousOptionModel, sameOptionWithPrevious) {
        case (_, .some(let same)):
            self.subject.options.send(
                .init([[notRepeatOptionModel]] + supportOptionModels)
            )
            self.subject.selectedOptionId.send(same.id)
            
        case (let .some(prev), _):
            self.subject.options.send(
                .init([[notRepeatOptionModel, prev]] + supportOptionModels)
            )
            self.subject.selectedOptionId.send(prev.id)
            
        default:
            self.subject.options.send(
                .init([[notRepeatOptionModel]] + supportOptionModels)
            )
            self.subject.selectedOptionId.send(notRepeatOptionModel.id)
        }
    }
    
    private func setupInitailEndOption(
        _ timeZone: TimeZone,
        _ previousSelectOption: EventRepeating?
    ) {
        
        let defaultEndTime = RepeatEndTime.defaultTime(self.selectTime, timeZone: timeZone)
        self.subject.defaultRepeatEndDate.send(defaultEndTime.date)
        
        switch previousSelectOption?.repeatingEndOption {
        case .none:
            self.subject.endOption.send(.never)
            
        case .count(let count):
            self.subject.endOption.send(.after(count: count))
            
        case .until(let endDate):
            let time = RepeatEndTime(
                Date(timeIntervalSince1970: endDate), timeZone: timeZone
            )
            self.subject.endOption.send(.on(date: time))
            
        }
    }
    
    func selectOption(_ id: String) {
        self.subject.selectedOptionId.send(id)
        self.checkIsValidAndNotifyOptionSelected()
    }
    
    func removeRepeatEndOption() {
        self.subject.endOption.send(.never)
        self.checkIsValidAndNotifyOptionSelected()
    }
    
    func selectRepeatEndDate(_ date: Date) {
        guard let timeZone = self.subject.timeZone.value,
              self.subject.endOption.value?.endDate != date
        else { return }
        let time = RepeatEndTime(date, timeZone: timeZone)
        self.subject.endOption.send(.on(date: time))
        self.checkIsValidAndNotifyOptionSelected()
    }
    
    func selectRepeatEndCount(_ count: Int) {
        self.subject.endOption.send(.after(count: count))
        self.checkIsValidAndNotifyOptionSelected()
    }
    
    private func checkIsValidAndNotifyOptionSelected() {
        guard let optionId = self.subject.selectedOptionId.value,
              let model = self.subject.options.value.option(optionId)
        else { return }
        
        guard let option = model.option
        else {
            self.listener?.selectEventRepeatOptionNotRepeat()
            return
        }
        
        let endOption = self.subject.endOption.value
        
        let startTime = self.previousSelectOption?.repeatingStartTime ?? self.selectTime.timeIntervalSince1970
        let endTime = endOption?.endDate?.timeIntervalSince1970
        
        // 종료시간 선택된 경우, 올바른지 검사
        let isValidPeriod = endTime.map { startTime < $0 } ?? true
        guard isValidPeriod
        else {
            self.router?.showRepeatingEndTimeIsInvalid(
                startDate: Date(timeIntervalSince1970: startTime)
            )
            self.removeRepeatEndOption()
            return
        }
        
        let repeating = EventRepeating(
            repeatingStartTime: startTime, repeatOption: option
        ) |> \.repeatingEndOption .~ endOption?.asEndOption
        let result = EventRepeatingTimeSelectResult(text: model.text, repeating: repeating)
        self.listener?.selectEventRepeatOption(didSelect: result)
    }
    
    func close() {
        self.router?.closeScene(animate: true, nil)
    }
}


// MARK: - SelectEventRepeatOptionViewModelImple Presenter

extension SelectEventRepeatOptionViewModelImple {
    
    var options: AnyPublisher<[[SelectRepeatingOptionModel]], Never> {
        let transform: (OptionSeqMap) -> [[SelectRepeatingOptionModel]] = { seqMap in
            return seqMap.optionList
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
    
    var repeatStartTimeText: AnyPublisher<String, Never> {
        let transform: (TimeZone?) -> String? = { [weak self] timeZone in
            guard let self = self, let timeZone = timeZone else { return nil }
            let date = self.previousSelectOption
                .map { Date(timeIntervalSince1970: $0.repeatingStartTime ) }
            ?? self.selectTime
            return date.text(
                "eventDetail.repeating.starttime:form".localized(), timeZone: timeZone
            )
        }
        return self.subject.timeZone
            .compactMap(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var defaultRepeatEndDate: AnyPublisher<Date, Never> {
        return self.subject.defaultRepeatEndDate
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    var repeatEndOption: AnyPublisher<RepeatEndOptionModel, Never> {
        return self.subject.endOption
            .compactMap { $0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}

private extension Calendar {
    
    func dateText(_ month: Int, _ day: Int) -> String {
        guard let date = self.date(bySetting: .month, value: month, of: Date())
            .flatMap ({ self.date(bySetting: .day, value: day, of: $0) })
        else { return "\(month).\(day)" }
        return date.text("date_form::MMM_d".localized())
    }
}

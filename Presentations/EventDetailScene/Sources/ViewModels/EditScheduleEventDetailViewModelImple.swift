//
//  EditScheduleEventDetailViewModelImple.swift
//  EventDetailScene
//
//  Created by sudo.park on 11/12/23.
//

import Foundation
import Combine
import Prelude
import Optics
import Domain
import Extensions
import Scenes


final class EditScheduleEventDetailViewModelImple: EventDetailViewModel, @unchecked Sendable {
    
    private let scheduleId: String
    private let repeatingEventTargetTime: EventTime?
    private let scheduleUsecase: any ScheduleEventUsecase
    private let eventTagUsecase: any EventTagUsecase
    private let eventDetailDataUsecase: any EventDetailDataUsecase
    private let todoEventUsecase: any TodoEventUsecase
    private let calendarSettingUsecase: any CalendarSettingUsecase
    private let foremostEventUsecase: any ForemostEventUsecase
    private let ddayCandidateUsecase: any DDayCandidateUsecase
    var router: (any EventDetailRouting)?
    weak var listener: EventDetailSceneListener?
    
    init(
        scheduleId: String,
        repeatingEventTargetTime: EventTime?,
        scheduleUsecase: any ScheduleEventUsecase,
        eventTagUsecase: any EventTagUsecase,
        eventDetailDataUsecase: any EventDetailDataUsecase,
        todoEventUsecase: any TodoEventUsecase,
        calendarSettingUsecase: any CalendarSettingUsecase,
        foremostEventUsecase: any ForemostEventUsecase,
        ddayCandidateUsecase: any DDayCandidateUsecase
    ) {
        self.scheduleId = scheduleId
        self.repeatingEventTargetTime = repeatingEventTargetTime
        self.scheduleUsecase = scheduleUsecase
        self.eventTagUsecase = eventTagUsecase
        self.eventDetailDataUsecase = eventDetailDataUsecase
        self.todoEventUsecase = todoEventUsecase
        self.calendarSettingUsecase = calendarSettingUsecase
        self.foremostEventUsecase = foremostEventUsecase
        self.ddayCandidateUsecase = ddayCandidateUsecase

        self.internalBinding()
    }
    
    private struct Subject {
        typealias Basic = OriginalAndCurrent<EventDetailBasicData>
        typealias Addition = OriginalAndCurrent<EventDetailData>
        let basicData = CurrentValueSubject<Basic?, Never>(nil)
        let additionalData = CurrentValueSubject<Addition?, Never>(nil)
        let isLoading = CurrentValueSubject<Bool, Never>(false)
        let isSaving = CurrentValueSubject<Bool, Never>(false)
        let timeZone = CurrentValueSubject<TimeZone?, Never>(nil)
    }
    
    private var cancellables: Set<AnyCancellable> = []
    private let subject = Subject()
    private weak var inputInteractor: (any EventDetailInputInteractor)?
    
    private func internalBinding() {
        
        self.calendarSettingUsecase.currentTimeZone
            .sink(receiveValue: { [weak self] timeZone in
                self?.subject.timeZone.send(timeZone)
            })
            .store(in: &self.cancellables)
    }
}

extension EditScheduleEventDetailViewModelImple: EventDetailInputListener {
    
    private func handleError() -> (Error) -> Void {
        return { [weak self] error in
            self?.router?.showError(error)
        }
    }
    
    func attachInput() {
        self.inputInteractor = self.router?.attachInput(self)
    }
    
    func prepare() {
        
        self.subject.isLoading.send(true)
        // 플래그가 꺼져 있으면 후보 목록을 읽지 않는다 (#741 배포 보류)
        if FeatureFlag.isEnable(.ddayWidget) {
            self.ddayCandidateUsecase.refresh()
        }

        let handlePrepared: (EventDetailBasicData, EventDetailData) -> Void = { [weak self] basic, addition in
            self?.subject.basicData.send(
                .init(origin: basic)
            )
            self?.subject.additionalData.send(
                .init(origin: addition)
            )
            self?.inputInteractor?.prepared(basic: basic, additional: addition)
        }
        let handleCompleted: (Subscribers.Completion<Error>) -> Void = { [weak self] completed in
            self?.subject.isLoading.send(false)
            if case .failure(let error) = completed {
                self?.handleError()(error)
            }
        }
        
        Publishers.CombineLatest(
            self.prepareBasicData(),
            self.additionDataWithoutError().mapNever()
        )
        .sink(receiveCompletion: handleCompleted, receiveValue: handlePrepared)
        .store(in: &self.cancellables)
    }
    
    private func prepareBasicData() -> AnyPublisher<EventDetailBasicData, any Error> {
        let targetTime = self.repeatingEventTargetTime
        let transform: (ScheduleEvent, TimeZone) -> EventDetailBasicData = { schedule, timeZone in
            return EventDetailBasicData(schedule, targetTime, timeZone)
        }
        return Publishers.CombineLatest(
            self.scheduleUsecase.scheduleEvent(self.scheduleId).removeDuplicates(),
            self.subject.timeZone.compactMap { $0 }.mapNever().first()
        )
        .map(transform)
        .eraseToAnyPublisher()
    }
    
    private func additionDataWithoutError() -> AnyPublisher<EventDetailData, Never> {
        let id = self.scheduleId
        return self.eventDetailDataUsecase.loadDetail(id)
            .catch { _ in Just(.init(id)) }
            .replaceEmpty(with: .init(id))
            .eraseToAnyPublisher()
    }
    
    func handleMoreAction(_ action: EventDetailMoreAction) {
        switch action {
        case .remove(let onlyThisEvent):
            self.removeEventAfterConfirm(onlyThisTime: onlyThisEvent)
            
        case .toggleTo(let isForemost):
            self.toggleForemostAfterConfirm(toForemost: isForemost)

        case .toggleDDayCandidate(let isRegistered):
            self.toggleDDayCandidateAfterConfirm(isRegistered: isRegistered)

        case .copy:
            self.copyEvent()
            
        case .transformToTodo:
            self.transformToTodoAfterConfirm()
            
        case .addToTemplate:
            // TODO:
            break
        case .share:
            self.shareEvent()

        default: break
        }
    }

    private func shareEvent() {
        guard let basic = self.subject.basicData.value?.current,
              let name = basic.name
        else { return }

        let addition = self.subject.additionalData.value?.current
        let builder = EventDetailShareTextBuilder()
        let timeText = basic.selectedTime.map(builder.timeText(from:))

        self.eventTagUsecase.eventTag(id: basic.eventTagId)
            .first()
            .sink { [weak self] tag in
                let model = EventDetailShareModel(
                    name: name,
                    isTodo: false,
                    timeText: timeText,
                    repeatText: basic.eventRepeating?.text.emptyAsNil(),
                    tagName: tag?.name.emptyAsNil(),
                    placeName: addition?.place?.placeName.emptyAsNil(),
                    url: addition?.url?.emptyAsNil(),
                    memo: addition?.memo?.emptyAsNil()
                )
                let text = builder.build(model)
                guard !text.isEmpty else { return }
                self?.router?.showShareSheet(text: text)
            }
            .store(in: &self.cancellables)
    }
    
    private func removeEventAfterConfirm(onlyThisTime: Bool) {
        guard let timeZone = self.subject.timeZone.value,
              let time = self.subject.basicData.value?.origin.selectedTime?.eventTime(timeZone)
        else { return }
        let message = onlyThisTime
            ? R.String.calendarEventMoreActionRemoveOnlyThistimeMessage
            : R.String.calendarEventMoreActionRemoveMessage
        let onlyThisTime = onlyThisTime ? time : nil
        let info = ConfirmDialogInfo()
            |> \.message .~ pure(message)
            |> \.confirmText .~ R.String.Common.remove
            |> \.confirmed .~ pure(self.removeSchedule(onlyThisTime))
            |> \.withCancel .~ true
            |> \.cancelText .~ R.String.Common.cancel
        self.router?.showConfirm(dialog: info)
    }
    
    private func removeSchedule(_ onlyThistime: EventTime?) -> () -> Void {
        let scheduleId = self.scheduleId
        return { [weak self] in
            guard let self = self else { return }
            Task { [weak self] in
                do {
                    try await self?.scheduleUsecase.removeScheduleEvent(
                        scheduleId, onlyThisTime: onlyThistime
                    )
                    self?.router?.showToast(R.String.EventDetail.scheduleEventRemovedMessage)
                    self?.router?.closeScene()
                } catch {
                    self?.router?.showError(error)
                }
            }
            .store(in: &self.cancellables)
        }
    }
    
    private func toggleForemostAfterConfirm(toForemost: Bool) {
        
        let message = toForemost
            ? R.String.calendarEventMoreActionMarkAsForemost
            : R.String.calendarEventMoreActionUnmarkAsForemost
        let info = ConfirmDialogInfo()
            |> \.title .~ R.String.calendarEventMoreActionForemostEventTitle
            |> \.message .~ pure(message)
            |> \.confirmText .~ R.String.Common.confirm
            |> \.confirmed .~ pure(self.toggleFormost(toForemost))
            |> \.withCancel .~ true
            |> \.cancelText .~ R.String.Common.cancel
        self.router?.showConfirm(dialog: info)
    }
    
    private func toggleFormost(_ toForemost: Bool) -> () -> Void {
        let scheduleId = self.scheduleId
        return { [weak self] in
            guard let self = self else { return }
            Task { [weak self] in
                do {
                    if toForemost {
                        try await self?.foremostEventUsecase.update(foremost: .init(scheduleId, false))
                    } else {
                        try await self?.foremostEventUsecase.remove()
                    }
                } catch {
                    self?.router?.showError(error)
                }
            }
            .store(in: &self.cancellables)
        }
    }

    private func toggleDDayCandidateAfterConfirm(isRegistered: Bool) {

        let message = isRegistered
            ? "calendar::event::more_action:dday_candidate:unregister:message".localized()
            : "calendar::event::more_action:dday_candidate:register:message".localized()
        let info = ConfirmDialogInfo()
            |> \.title .~ "calendar::event::more_action:dday_candidate:title".localized()
            |> \.message .~ pure(message)
            |> \.confirmText .~ R.String.Common.confirm
            |> \.confirmed .~ pure(self.toggleDDayCandidate(isRegistered))
            |> \.withCancel .~ true
            |> \.cancelText .~ R.String.Common.cancel
        self.router?.showConfirm(dialog: info)
    }

    private func toggleDDayCandidate(_ isRegistered: Bool) -> () -> Void {
        let candidate = self.currentCandidate
        return { [weak self] in
            guard let usecase = self?.ddayCandidateUsecase else { return }
            isRegistered ? usecase.remove(candidate) : usecase.append(candidate)
        }
    }

    /// 상세가 열린 회차가 곧 등록 대상이다 — 반복이면 그 회차, 아니면 원본.
    private var currentCandidate: DDayCandidate {
        return DDayCandidate(
            scheduleId: self.scheduleId,
            targetTime: self.repeatingEventTargetTime,
            isRepeating: self.subject.basicData.value?.origin.isRepeatingEvent ?? false
        )
    }

    private func transformToTodoAfterConfirm() {
        
        guard let basic = self.subject.basicData.value,
              let name = basic.current.name
        else {
            self.router?.showToast("eventDetail.unavailto_transform_withoutName".localized())
            return
        }
        
        let info = ConfirmDialogInfo()
            |> \.title .~ pure("eventDetail.scheduleEvent::transform::todo".localized())
            |> \.message .~ pure("eventDetail.scheduleEvent::transform::todo_message".localized())
            |> \.confirmed .~ { [weak self] in self?.transformToTodo(basic, name) }
            |> \.withCancel .~ true
        self.router?.showConfirm(dialog: info)
    }
    
    private func transformToTodo(
        _ basic: Subject.Basic, _ name: String
    ) {
        guard let timeZone = self.subject.timeZone.value,
              let originScheduleTime = basic.origin.selectedTime?.eventTime(timeZone)
        else { return }
        
        let time = basic.current.selectedTime?.eventTime(timeZone)
        
        let params = TodoMakeParams()
            |> \.name .~ pure(name)
            |> \.time .~ time
            |> \.eventTagId .~ pure(basic.current.eventTagId)
            |> \.repeating .~ basic.current.eventRepeating?.repeating
            |> \.notificationOptions .~ pure(basic.current.eventNotifications)
        
        let scheduleId = self.scheduleId
        let isRepeating = basic.origin.eventRepeating != nil
        
        Task { [weak self] in
            guard let self = self else { return }
            self.subject.isSaving.send(true)
            
            do {
                let newTodo = try await self.todoEventUsecase.makeTodoEvent(params)
                await self.replaceEventDetailToTodo(scheduleId, newTodo.uuid)
                try? await self.scheduleUsecase.removeScheduleEvent(scheduleId, onlyThisTime: isRepeating ? originScheduleTime : nil)
                
                self.subject.isSaving.send(false)
                self.router?.closeScene(animate: false) {
                    self.listener?.eventDetail(transformTo: newTodo)
                }
            } catch {
                self.subject.isSaving.send(false)
                self.router?.showError(error)
            }
        }
        .store(in: &self.cancellables)
    }
    
    private func replaceEventDetailToTodo(_ scheduleId: String, _ newTodoId: String) async {
        let addition = self.subject.additionalData.value?.current
        let newDetail = EventDetailData(newTodoId)
            |> \.place .~ addition?.place
            |> \.memo .~ addition?.memo
            |> \.url .~ addition?.url
        _ = try? await self.eventDetailDataUsecase.saveDetail(newDetail)
        try? await self.eventDetailDataUsecase.removeDetail(scheduleId)
    }
    
    private func copyEvent() {
        guard let basic = self.subject.basicData.value?.current,
              let timeZone = self.subject.timeZone.value
        else { return }
        
        let params = ScheduleMakeParams(basic, timeZone)
        let additional = self.subject.additionalData.value?.current
        self.router?.closeScene(animate: true) { [weak self] in
            self?.listener?.eventDetail(copyFromSchedule: params, detail: additional)
        }
    }
    
    func close() {
        self.router?.showConfirmClose()
    }
    
    // do nothing
    func toggleIsTodo() { }
    
    func showTodoGuide() { }
    
    func showForemostEventGuide() {
        self.router?.showForemostEventGuide()
    }
    
    func eventDetail(didInput basic: EventDetailBasicData, additional: EventDetailData) {
        
        guard let oldBasic = self.subject.basicData.value,
              let oldAddition = self.subject.additionalData.value
        else { return }
        
        self.subject.basicData.send(
            oldBasic |> \.current .~ basic
        )
        self.subject.additionalData.send(
            oldAddition |> \.current .~ additional
        )
    }
    
    func save() {
        guard let basic = self.subject.basicData.value,
              let addition = self.subject.additionalData.value,
              let timeZone = self.subject.timeZone.value
        else { return }
        
        guard basic.isChanged || addition.isChanged
        else {
            self.router?.closeScene()
            return
        }
        
        let originalScheduleIsRepeating = basic.origin.eventRepeating != nil
        let params = self.scheduleEditParams(from: basic.current, timeZone)
        
        originalScheduleIsRepeating
            ? saveAfterShowConfirmEditRepeatingEvent(timeZone, params, addition.current)
            : editSchedule(params, addition.current)
    }
    
    private func saveAfterShowConfirmEditRepeatingEvent(
        _ timeZone: TimeZone,
        _ params: SchedulePutParams,
        _ addition: EventDetailData
    ) {
        
        let basic = self.subject.basicData.value
        let userSelectTime = basic?.userSelectedTime(timeZone)
        
        guard let repeatingStartTime = basic?.origin.originEventTime,
              let repeatingEventTargetTime = self.repeatingEventTargetTime
        else { return }
        
        var form = ActionSheetForm()
            |> \.title .~ pure("eventDetail.edit::repeating::confirm::ttile".localized())
            |> \.message .~ pure("eventDetail.edit::repeating::confirm::message".localized())
        
        let isEditingRepeatingStartTime = repeatingStartTime == repeatingEventTargetTime
        if isEditingRepeatingStartTime {
            let allAction = ActionSheetForm.Action("eventDetail.edit::repeating::confirm::all::button".localized()) { [weak self] in
                self?.editSchedule(
                    params
                        |> \.repeatingUpdateScope .~ .all
                        |> \.time .~ (userSelectTime ?? repeatingStartTime),
                    addition
                )
            }
            form.actions.append(allAction)
        } else {
            let fromNowAction = ActionSheetForm.Action("eventDetail.edit::repeating::confirm::fromNow::button".localized()) { [weak self] in
                self?.editSchedule(
                    params |> \.repeatingUpdateScope .~ .fromNow(repeatingEventTargetTime),
                    addition
                )
            }
            form.actions.append(fromNowAction)
        }
        
        let onlyThisTimeAction = ActionSheetForm.Action("eventDetail.edit::repeating::confirm::onlyThisTime::button".localized()) { [weak self] in
            self?.editSchedule(
                params
                    |> \.repeatingUpdateScope .~ .onlyThisTime(repeatingEventTargetTime)
                    |> \.repeating .~ nil,
                addition
            )
        }
        form.actions.append(onlyThisTimeAction)
        
        form.actions.append(.init("common.cancel".localized(), style: .cancel))
        
        self.router?.showActionSheet(form)
    }
    
    private func editSchedule(
        _ params: SchedulePutParams,
        _ addition: EventDetailData
    ) {
        
        let scheduleId = self.scheduleId
        self.subject.isSaving.send(true)
        Task { [weak self] in
            
            do {
                let updatedSchedule = try await self?.scheduleUsecase.updateScheduleEvent(scheduleId, params)
                let copyAddition = updatedSchedule.map { addition.copy($0.uuid) } ?? addition
                let _ = try? await self?.eventDetailDataUsecase.saveDetail(copyAddition)
                
                self?.router?.showToast("eventDetail.scheduleEvent_saved::message".localized())
                self?.router?.closeScene(animate: true, nil)
            } catch {
                self?.router?.showError(error)
            }
            self?.subject.isSaving.send(false)
        }
        .store(in: &self.cancellables)
    }
    
    private func scheduleEditParams(from basic: EventDetailBasicData, _ timeZone: TimeZone) -> SchedulePutParams {
        
        return SchedulePutParams()
            |> \.name .~ basic.name
            |> \.eventTagId .~ pure(basic.eventTagId)
            |> \.time .~ basic.selectedTime?.eventTime(timeZone)
            |> \.repeating .~ basic.eventRepeating?.repeating
            |> \.notificationOptions .~ pure(basic.eventNotifications)
            |> \.repeatingTimeToExcludes .~ pure(Array(basic.excludeTimes))
        
    }
}

extension EditScheduleEventDetailViewModelImple {
    
    var isForemost: AnyPublisher<Bool, Never> {
        let scheduleId = self.scheduleId
        return self.foremostEventUsecase.foremostEvent
            .map { $0?.eventId == scheduleId }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var isLoading: AnyPublisher<Bool, Never> {
        return self.subject.isLoading
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var eventDetailTypeModel: AnyPublisher<EventDetailTypeModel, Never> {
        return Just(EventDetailTypeModel.scheduleCase())
            .eraseToAnyPublisher()
    }
    
    var hasChanges: AnyPublisher<Bool, Never> {
        let transform: (Subject.Basic?, Subject.Addition?) -> Bool = { basic, addition in
            guard let basic, let addition else { return false }
            return basic.isChanged || addition.isChanged
        }
        
        return Publishers.CombineLatest(
            self.subject.basicData,
            self.subject.additionalData
        )
        .map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
    
    var isSavable: AnyPublisher<Bool, Never> {
        let transform: (EventDetailBasicData?) -> Bool = { basic in
            let nameIsNotEmpty = basic?.name?.isEmpty == false
            let validTimeSelected = basic?.selectedTime?.isValid == true
            return nameIsNotEmpty && validTimeSelected
        }
        
        return self.subject.basicData
            .map { $0?.current }
            .map(transform)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var isSaving: AnyPublisher<Bool, Never> {
        return self.subject.isSaving
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    var moreActions: AnyPublisher<[[EventDetailMoreAction]], Never> {
        let scheduleId = self.scheduleId
        let targetTime = self.repeatingEventTargetTime
        // #741 D-day 위젯이 배포 보류라 플래그가 꺼진 동안은 후보 등록 메뉴를 감춘다 —
        // 위젯 없이 후보만 등록하게 두면 갈 곳 없는 기능이 된다. 처리 로직은 살아 있다
        let isDDayWidgetEnabled = FeatureFlag.isEnable(.ddayWidget)
        let transform: (
            EventDetailBasicData, (any ForemostMarkableEvent)?, [DDayCandidate]
        ) -> [[EventDetailMoreAction]] = { basic, foremostEvent, candidates in
            let isRepeating = basic.isRepeatingEvent
            let isForemost = foremostEvent?.eventId == scheduleId
            let removeActions: [EventDetailMoreAction] = isRepeating
                ? [.remove(onlyThisEvent: true), .remove(onlyThisEvent: false)]
                : [.remove(onlyThisEvent: false)]
            let ddayActions: [EventDetailMoreAction] = isDDayWidgetEnabled
                ? [
                    .toggleDDayCandidate(
                        isRegistered: candidates.contains(
                            DDayCandidate(
                                scheduleId: scheduleId,
                                targetTime: targetTime,
                                isRepeating: isRepeating
                            )
                        )
                    )
                ]
                : []
            let otherActions: [EventDetailMoreAction] = isRepeating
                ? ddayActions + [.copy, .transformToTodo, .share]
                : [.toggleTo(isForemost: !isForemost)] + ddayActions + [.copy, .transformToTodo, .share]
            return [removeActions, otherActions]
        }
        return Publishers.CombineLatest3(
            self.subject.basicData.compactMap { $0?.origin },
            self.foremostEventUsecase.foremostEvent,
            // 플래그가 꺼져 있으면 후보 목록을 조회·구독하지 않는다
            isDDayWidgetEnabled
                ? self.ddayCandidateUsecase.candidates
                : Just<[DDayCandidate]>([]).eraseToAnyPublisher()
        )
        .map(transform)
        .removeDuplicates()
        .eraseToAnyPublisher()
    }
}

private extension EventDetailBasicData {

    var isRepeatingEvent: Bool {
        return self.selectedTime != nil && self.eventRepeating != nil
    }

    init(
        _ schedule: ScheduleEvent,
        _ repeatingEventTargetTime: EventTime?,
        _ timeZone: TimeZone
    ) {
        self.name = schedule.name
        self.originEventTime = schedule.time
        self.selectedTime = SelectedTime(
            repeatingEventTargetTime ?? schedule.time, timeZone
        )
        self.eventRepeating = EventRepeatingTimeSelectResult.make(schedule.time, schedule.repeating, timeZone)
        self.eventTagId = schedule.eventTagId ?? .default
        self.eventNotifications = schedule.notificationOptions
        self.excludeTimes = schedule.repeatingTimeToExcludes
    }
}

private extension OriginalAndCurrent where T == EventDetailBasicData {
    
    func userSelectedTime(_ timeZone: TimeZone) -> EventTime? {
        let isUserSelected = self.origin.selectedTime != self.current.selectedTime
        return isUserSelected ? self.current.selectedTime?.eventTime(timeZone) : nil
    }
}

private extension ScheduleMakeParams {
    
    init(_ basic: EventDetailBasicData, _ timeZone: TimeZone) {
        self.init()
        self.name = basic.name
        self.time = basic.selectedTime?.eventTime(timeZone)
        self.eventTagId = basic.eventTagId
        self.repeating = basic.eventRepeating?.repeating
        self.notificationOptions = basic.eventNotifications
    }
}


private extension DDayCandidate {

    /// 회차 키는 **반복 일정일 때만** 싣는다.
    ///
    /// 진입점(`EventListCellEventHanleViewModel.selectEvent`)이 비반복 일정에도 셀의 시각을
    /// 그대로 넘겨서 `repeatingEventTargetTime`은 비반복에도 채워져 있다. 이걸 그대로 회차 키로
    /// 쓰면 위젯이 반복 회차로 해석해(`fetchDDayTargetSchedule`) 조회에 실패하고 후보가 사라진다.
    init(scheduleId: String, targetTime: EventTime?, isRepeating: Bool) {
        self.init(
            scheduleId: scheduleId,
            turnKey: isRepeating ? targetTime?.customKey : nil
        )
    }
}

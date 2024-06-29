//
//  
//  AddEventView.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/15/23.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - EventDetailViewState

final class EventDetailViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    @Published var selectedTag: SelectedTag?
    @Published var enterName: String = ""
    @Published var eventDetailTypeModel: EventDetailTypeModel?
    @Published var isSaving: Bool = false
    @Published var isSavable: Bool = false
    @Published var selectedTime: SelectedTime?
    @Published var selectedRepeat: String?
    @Published var selectedNotificationTimeText: String?
    @Published var isAllDay: Bool = false
    @Published var availableMoreActions: [[EventDetailMoreAction]] = []
    @Published var isForemost: Bool = false
    
    @Published var selectedStartDate: Date = Date()
    @Published var selectedEndDate: Date = Date().addingTimeInterval(60)
    @Published var url: String = ""
    @Published var memo: String = ""
    
    func bind(
        _ viewModel: any EventDetailViewModel,
        _ inputViewModel: any EventDetailInputViewModel
    ) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
        viewModel.eventDetailTypeModel
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                self?.eventDetailTypeModel = model
            })
            .store(in: &self.cancellables)
        
        inputViewModel.initialName
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] name in
                self?.enterName = name ?? ""
            })
            .store(in: &self.cancellables)
        
        inputViewModel.selectedTime
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] time in
                self?.selectedTime = time
            })
            .store(in: &self.cancellables)
        
        inputViewModel.repeatOption
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] option in
                self?.selectedRepeat = option
            })
            .store(in: &self.cancellables)
        
        inputViewModel.selectedTag
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] tag in
                self?.selectedTag = tag
            })
            .store(in: &self.cancellables)
        
        inputViewModel.selectedNotificationTimeText
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] text in
                self?.selectedNotificationTimeText = text
            })
            .store(in: &self.cancellables)
        
        viewModel.isForemost
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] isForemost in
                self?.isForemost = isForemost
            })
            .store(in: &self.cancellables)
        
        viewModel.isSaving
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] isSaving in
                self?.isSaving = isSaving
            })
            .store(in: &self.cancellables)
        
        viewModel.isSavable
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] isSavable in
                self?.isSavable = isSavable
            })
            .store(in: &self.cancellables)
        
        viewModel.moreActions
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] actions in
                self?.availableMoreActions = actions
            })
            .store(in: &self.cancellables)
    }
}


// MARK: - EventDetailContainerView

struct EventDetailContainerView: View {
    
    @StateObject private var state: EventDetailViewState = .init()
    private let viewAppearance: ViewAppearance
    
    var onAppear: () -> Void = { }
    var stateBinding: (EventDetailViewState) -> Void = { _ in }
    var nameEntered: (String) -> Void = { _ in }
    var toggleIsTodo: () -> Void = { }
    var selectStartTime: ( Date) -> Void = { _ in }
    var selectEndTime: (Date) -> Void = { _ in }
    var removeTime: () -> Void = { }
    var removeEventEndTime: () -> Void = { }
    var toggleIsAllDay: () -> Void = { }
    var selectRepeatOption: () -> Void = { }
    var selectTag: () -> Void = { }
    var selectNotificationOption: () -> Void = { }
    var selectPlace: () -> Void = { }
    var enterUrl: (String) -> Void = { _ in }
    var enterMemo: (String) -> Void = { _ in }
    var save: () -> Void = { }
    var doMoreAction: (EventDetailMoreAction) -> Void = { _ in }
    
    init(viewAppearance: ViewAppearance) {
        self.viewAppearance = viewAppearance
    }
    
    var body: some View {
        return EventDetailView()
            .eventHandler(\.nameEntered, nameEntered)
            .eventHandler(\.toggleIsTodo, toggleIsTodo)
            .eventHandler(\.selectStartTime, selectStartTime)
            .eventHandler(\.selectEndTime, selectEndTime)
            .eventHandler(\.removeTime, removeTime)
            .eventHandler(\.removeEventEndTime, removeEventEndTime)
            .eventHandler(\.toggleIsAllDay, toggleIsAllDay)
            .eventHandler(\.selectRepeatOption, selectRepeatOption)
            .eventHandler(\.selectNotificationOption, selectNotificationOption)
            .eventHandler(\.selectTag, selectTag)
            .eventHandler(\.selectPlace, selectPlace)
            .eventHandler(\.enterUrl, enterUrl)
            .eventHandler(\.enterMemo, enterMemo)
            .eventHandler(\.save, save)
            .onAppear {
                self.stateBinding(self.state)
                self.onAppear()
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
    }
}

// MARK: - AddEventView

struct EventDetailView: View {
    
    @EnvironmentObject private var state: EventDetailViewState
    @EnvironmentObject private var appearance: ViewAppearance
    private enum InputFields {
        case name
        case url
        case memo
    }
    @FocusState private var isFocusInput: InputFields?
    
    private enum TimeSelecting {
        case start
        case end
    }
    @State private var isTimeSelecting: TimeSelecting?
    @State private var showEventDetailTypePopover: Bool = false
    
    fileprivate var nameEntered: (String) -> Void = { _ in }
    fileprivate var toggleIsTodo: () -> Void = { }
    fileprivate var selectStartTime: ( Date) -> Void = { _ in }
    fileprivate var selectEndTime: (Date) -> Void = { _ in }
    fileprivate var removeTime: () -> Void = { }
    fileprivate var removeEventEndTime: () -> Void = { }
    fileprivate var toggleIsAllDay: () -> Void = { }
    fileprivate var selectRepeatOption: () -> Void = { }
    fileprivate var selectTag: () -> Void = { }
    fileprivate var selectNotificationOption: () -> Void = { }
    fileprivate var selectPlace: () -> Void = { }
    fileprivate var enterUrl: (String) -> Void = { _ in }
    fileprivate var enterMemo: (String) -> Void = { _ in }
    fileprivate var save: () -> Void = { }
    var doMoreAction: (EventDetailMoreAction) -> Void = { _ in }

    private var selectedTagColor: Color? {
        return self.state.selectedTag?.color.color(with: self.appearance).asColor
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 25) {
                    self.moreActionView
                    self.nameInputView
                    if state.isForemost {
                        self.foremostEventView
                    }
                    self.eventDetailTypeView
                    self.timeSelectView
                    self.selectRepeatView
                    Spacer(minLength: 12)
                    self.selectTagView
                    self.selectNotificationView
                    Spacer(minLength: 12)
                    self.enterLinkView
                    self.enterMemokView
                }
                .padding(.top, 20)
                .padding(.horizontal, 12)
                .padding(.bottom, 120)
            }
            
            VStack {
                Spacer()
                
                BottomConfirmButton(
                    title: "Save".localized(), 
                    isEnable: self.$state.isSavable,
                    isProcessing: self.$state.isSaving
                )
                .eventHandler(\.onTap, self.save)
            }
        }
    }
    
    private var moreActionView: some View {
        HStack {
            Spacer()
            
            Menu {
                ForEach(0..<self.state.availableMoreActions.count, id: \.self) { sectionIndex in
                    Section {
                        ForEach(self.state.availableMoreActions[sectionIndex]) { action in
                            Button(role: action.isRemove ? .destructive : nil) {
                                self.doMoreAction(action)
                            } label: {
                                HStack {
                                    Text(action.text)
                                    Image(systemName: action.imageName)
                                }
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(self.appearance.colorSet.normalText.asColor)
                    .frame(width: 20, height: 20)
            }
        }
    }
    
    private var nameInputView: some View {
        HStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(self.selectedTagColor ?? .clear)
                .frame(width: 6)
            
            TextField(
                "Add new event name".localized(),
                text: self.$state.enterName,
                axis: .vertical
            )
            .onReceive(self.state.$enterName, perform: self.nameEntered)
            .focused($isFocusInput, equals: .name)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .font(self.appearance.fontSet.size(22, weight: .semibold).asFont)
            .foregroundStyle(self.appearance.colorSet.normalText.asColor)
            .onSubmit {
                self.isFocusInput = nil
            }
        }
    }
    
    private var eventDetailTypeView: some View {
        
        guard let model = self.state.eventDetailTypeModel
        else {
            return EmptyView().asAnyView()
        }
        
        switch model.selectType {
        case _ where model.isTogglable:
            return togglableEventTypeView(model: model).asAnyView()
        case .todo:
            return todoEventTypeView(model).asAnyView()
        default:
            return EmptyView().asAnyView()
        }
    }
    
    private var foremostEventView: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(self.appearance.colorSet.accentRed.asColor)
            
            Text("Foremost event".localized())
                .foregroundStyle(self.appearance.colorSet.normalText.asColor)
                .font(self.appearance.fontSet.normal.asFont)
            
            Button {
                self.showEventDetailTypePopover = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(self.appearance.fontSet.normal.asFont)
                    .foregroundStyle(self.appearance.colorSet.subNormalText.asColor)
            }
            .popover(isPresented: self.$showEventDetailTypePopover) {
                Text("[Todo] foremost event description")
            }
            
            Spacer()
        }
    }
    
    private func togglableEventTypeView(model: EventDetailTypeModel) -> some View {
        HStack {
            Image(systemName: "flag.fill")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(self.appearance.colorSet.normalText.asColor)
            Text(model.text)
                .foregroundStyle(self.appearance.colorSet.normalText.asColor)
                .font(self.appearance.fontSet.normal.asFont)
            
            Button {
                self.toggleIsTodo()
            } label: {
                Text(
                    model.selectType == .todo ? "Yes" : "No"
                )
                .font(appearance.fontSet.subNormal.asFont)
                .foregroundStyle(self.appearance.colorSet.normalText.asColor)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(self.appearance.colorSet.eventList.asColor)
                )
            }
            .padding(.leading, 12)
            
            Spacer()
        }
    }
    
    private func todoEventTypeView(_ model: EventDetailTypeModel) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "flag.fill")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(self.appearance.colorSet.normalText.asColor)
            
            Text(model.text)
                .foregroundStyle(self.appearance.colorSet.normalText.asColor)
                .font(self.appearance.fontSet.normal.asFont)

            if model.showHelpButton {
                Button {
                    self.showEventDetailTypePopover = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(self.appearance.fontSet.normal.asFont)
                        .foregroundStyle(self.appearance.colorSet.subNormalText.asColor)
                }
                .popover(isPresented: self.$showEventDetailTypePopover) {
                    Text("[Todo] event type description")
                }
            }
            
            Spacer()
        }
    }
    
    private func selectedTimeView() -> some View {
        
        func timeView(_ timeText: SelectTimeText, _ position: TimeSelecting, isInvalid: Bool) -> some View {
            
            let isSelecting = self.isTimeSelecting == position
            let textColor: Color = !isSelecting
                ? appearance.colorSet.normalText.asColor
                : appearance.colorSet.subNormalText.asColor
            
            return VStack(alignment: .leading) {
                
                if let year = timeText.year {
                    Text(year)
                        .strikethrough(isInvalid)
                        .font(self.appearance.fontSet.size(14).asFont)
                        .foregroundStyle(textColor)
                }
                
                Text(timeText.day)
                    .lineLimit(1)
                    .strikethrough(isInvalid)
                    .font(self.appearance.fontSet.size(14).asFont)
                    .foregroundStyle(textColor)
                
                if let time = timeText.time {
                    Text(time)
                        .strikethrough(isInvalid)
                        .font(self.appearance.fontSet.size(16, weight: .semibold).asFont)
                        .foregroundStyle(textColor)
                }
            }
            .onTapGesture {
                self.updateTimePickerShowing(position)
            }
        }
        
        func emptyLabelView(_ position: TimeSelecting) -> some View {
            return Text("--")
                .font(self.appearance.fontSet.size(16, weight: .semibold).asFont)
                .foregroundStyle(self.appearance.colorSet.normalText.asColor)
                .onTapGesture {
                    self.updateTimePickerShowing(position)
                }
                .frame(minWidth: 60)
        }
        let isInvalid = self.state.selectedTime?.isValid == false
        switch self.state.selectedTime {
        case .none:
            return HStack(spacing: 16) {
                emptyLabelView(.start)
                Image(systemName: "chevron.right")
                emptyLabelView(.end)
            }
            .asAnyView()
            
        case .at(let time):
            return HStack(spacing: 16) {
                timeView(time, .start, isInvalid: isInvalid)
                Image(systemName: "chevron.right")
                emptyLabelView(.end)
            }
            .asAnyView()
        case .period(let from, let to):
            return HStack(spacing: 16) {
                timeView(from, .start, isInvalid: isInvalid)
                Image(systemName: "chevron.right")
                timeView(to, .end, isInvalid: isInvalid)
            }
            .asAnyView()
            
        case .singleAllDay(let time):
            return HStack(spacing: 16) {
                timeView(time, .start, isInvalid: isInvalid)
                Image(systemName: "chevron.right")
                emptyLabelView(.end)
            }
            .asAnyView()
            
        case .alldayPeriod(let from, let to):
            return HStack(spacing: 16) {
                timeView(from, .start, isInvalid: isInvalid)
                Image(systemName: "chevron.right")
                timeView(to, .end, isInvalid: isInvalid)
            }
            .asAnyView()
        }
    }
    
    private var toggleAllDayView: some View {
        
        func backGroundView() -> some View {
            if self.state.isAllDay {
                return RoundedRectangle(cornerRadius: 16)
                    .fill(self.appearance.colorSet.normalText.asColor)
                    .asAnyView()
            } else {
                return RoundedRectangle(cornerRadius: 16)
                    .stroke(self.appearance.colorSet.subSubNormalText.asColor, lineWidth: 1)
                    .asAnyView()
            }
        }
        let textColor: Color = self.state.isAllDay ? .white : self.appearance.colorSet.subSubNormalText.asColor
        return Button {
            self.state.isAllDay.toggle()
            self.toggleIsAllDay()
            
        } label: {
            Text("Allday".localized())
                .foregroundStyle(textColor)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
        }
        .background(
            backGroundView()
        )
    }
    
    private var timeSelectView: some View {
        
        return VStack {
            HStack(spacing: 16) {
                Image(systemName: "clock")
                    .font(.system(size: 16, weight: .light))
                
                selectedTimeView()
                
                Spacer()
                
                toggleAllDayView
            }
            
            if let timeSelecting = self.isTimeSelecting {
                self.timePickerView(timeSelecting)
            }
        }
    }
    
    private func updateTimePickerShowing(_ selecting: TimeSelecting?) {
        
        guard self.isTimeSelecting != selecting
        else {
            withAnimation {
                self.isTimeSelecting = nil
            }
            return
        }
        
        switch selecting {
        case .start:
            self.state.selectedStartDate = self.state.selectedTime?.startTime ?? Date()
        case .end:
            guard let time = self.state.selectedTime else { return }
            self.state.selectedEndDate = time.endTime ?? time.startTime.addingTimeInterval(3600)
            
        default: break
        }
        self.isTimeSelecting = selecting
        self.isFocusInput = nil
    }

    private func timePickerView(_ selecting: TimeSelecting) -> some View {
        return VStack {
            DatePicker(
                "",
                selection: selecting == .start
                    ? self.$state.selectedStartDate : self.$state.selectedEndDate,
                displayedComponents: self.state.isAllDay ? [.date] : [.date, .hourAndMinute]
            )
            .datePickerStyle(.wheel)
            .onReceive(selecting == .start ? self.state.$selectedStartDate.dropFirst() : self.state.$selectedEndDate.dropFirst()) { date in
                if selecting == .start {
                    self.selectStartTime(date)
                } else {
                    self.selectEndTime(date)
                }
            }
            .labelsHidden()
            
            HStack {
                removeEventTimeView
                if selecting == .end {
                    removeEndTimeView
                }
            }
        }
    }
    
    private var removeEventTimeView: some View {
        Button {
            self.removeTime()
        } label: {
            Text("clear event time")
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(lineWidth: 1)
                )
        }
    }
    
    private var removeEndTimeView: some View {
        Button {
            self.removeEventEndTime()
        } label: {
            Text("no end time")
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(lineWidth: 1)
                )
        }
    }
    
    private var selectRepeatView: some View {
        HStack(spacing: 16) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 16, weight: .light))
            
            Text(self.state.selectedRepeat ?? "no repeat".localized())
                .font(self.appearance.fontSet.subNormal.asFont)
                .foregroundStyle(
                    self.state.selectedRepeat == nil
                    ? self.appearance.colorSet.subSubNormalText.asColor
                    : self.appearance.colorSet.normalText.asColor
                )
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            self.state.selectedRepeat == nil
                            ? .clear
                            : self.appearance.colorSet.eventList.asColor
                        )
                )
                .onTapGesture {
                    self.selectRepeatOption()
                }
            Spacer()
        }
    }
    
    private var selectTagView: some View {
        HStack(spacing: 16) {
            Image(systemName: "calendar")
                .font(.system(size: 16, weight: .light))
            
            HStack {
                Circle()
                    .frame(width: 4, height: 4)
                    .foregroundStyle(self.selectedTagColor ?? .clear)
                
                Text(self.state.selectedTag?.name ?? "")
                    .font(self.appearance.fontSet.subNormal.asFont)
                    .foregroundStyle(self.appearance.colorSet.normalText.asColor)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(self.appearance.colorSet.eventList.asColor)
            )
            .onTapGesture {
                self.selectTag()
            }
            Spacer()
        }
    }
    
    private var selectNotificationView: some View {
        HStack(spacing: 16) {
            Image(systemName: "bell.fill")
                .font(.system(size: 16, weight: .light))
            
            Text(
                self.state.selectedNotificationTimeText 
                ?? "event_notification_setting::option_title::no_notification".localized()
            )
                .font(self.appearance.fontSet.subNormal.asFont)
                .foregroundStyle(
                    self.state.selectedNotificationTimeText == nil
                    ? self.appearance.colorSet.subSubNormalText.asColor
                    : self.appearance.colorSet.normalText.asColor
                )
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            self.state.selectedNotificationTimeText == nil
                            ? .clear
                            : self.appearance.colorSet.eventList.asColor
                        )
                )
                .onTapGesture {
                    self.selectNotificationOption()
                }
            Spacer()
        }
    }
    
    private var enterLinkView: some View {
        HStack(spacing: 16) {
            Image(systemName: "link")
                .font(.system(size: 16, weight: .light))
            
            TextField("URL".localized(), text: self.$state.url)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .foregroundStyle(self.appearance.colorSet.normalText.asColor)
                .font(self.appearance.fontSet.size(14).asFont)
                .focused(self.$isFocusInput, equals: .url)
                .onSubmit {
                    self.isFocusInput = nil
                }
                .onReceive(self.state.$url, perform: self.enterUrl)
        }
    }
    
    private var enterMemokView: some View {
        HStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 16, weight: .light))
            
            TextField("Memo".localized(), text: self.$state.memo)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .foregroundStyle(self.appearance.colorSet.normalText.asColor)
                .font(self.appearance.fontSet.size(14).asFont)
                .focused(self.$isFocusInput, equals: .memo)
                .onSubmit {
                    self.isFocusInput = nil
                }
                .onReceive(self.state.$memo, perform: self.enterMemo)
        }
    }
}

private extension SelectedTime {
    
    var startTime: Date {
        switch self {
        case .at(let time): return time.date
        case .singleAllDay(let time): return time.date
        case .period(let start, _): return start.date
        case .alldayPeriod(let start, _): return start.date
        }
    }
    
    var endTime: Date? {
        switch self {
        case .period(_, let end): return end.date
        case .alldayPeriod(_, let end): return end.date
        default: return nil
        }
    }
}

extension EventDetailMoreAction: Identifiable {
    var id: String {
        switch self {
        case .remove(let onlyThisEvent): return "remove:\(onlyThisEvent)"
        case .copy: return "copy"
        case .addToTemplate: return "addToTemplate"
        case .share: return "share"
        }
    }
    
    
    var text: String {
        switch self {
        case .remove(let onlyThisEvent): 
            return onlyThisEvent
                ? "remove event only this time".localized()
                : "remove event".localized()
        case .copy: return "copy".localized()
        case .addToTemplate: return "add to template".localized()
        case .share: return "share".localized()
        }
    }
    
    var imageName: String {
        switch self {
        case .remove: return "trash"
        case .copy: return "doc.on.doc"
        case .addToTemplate: return "doc.plaintext"
        case .share: return "square.and.arrow.up"
        }
    }
    
    var isRemove: Bool {
        switch self {
        case .remove: return true
        default: return false
        }
    }
}

private extension Array where Element == [EventDetailMoreAction] {
    var compareKey: String {
        return self
            .map { actions in actions.map { $0.id } }
            .map { $0.joined(separator: ",") }
            .joined(separator: "_")
    }
}

// MARK: - preview

struct EventDetailViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting)
        let state = EventDetailViewState()
        state.isForemost = true
        state.selectedTag = .defaultTag
        state.selectedTime = .period(
            .init(Date().timeIntervalSince1970, .current),
            .init(Date().addingTimeInterval(+10).timeIntervalSince1970, .current)
        )
        state.selectedRepeat = "some"
        state.availableMoreActions = [
            [.remove(onlyThisEvent: true), .remove(onlyThisEvent: false)],
            [.copy, .addToTemplate, .share]
        ]
//        state.selectedNotificationTimeText = "some time"
        state.eventDetailTypeModel = .makeCase(true)
//        state.eventDetailTypeModel = .todoCase()
//        state.eventDetailTypeModel = .scheduleCase()
//        state.eventDetailTypeModel = .holidayCase("Korea")
        state.isSaving = false
//        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//            state.isSaving = true
//        }
        let eventView = EventDetailView()
            .environmentObject(viewAppearance)
            .environmentObject(state)
        return eventView
    }
}

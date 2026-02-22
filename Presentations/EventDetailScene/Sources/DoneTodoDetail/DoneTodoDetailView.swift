//
//  
//  DoneTodoDetailView.swift
//  EventDetailScene
//
//  Created by sudo.park on 2/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - DoneTodoDetailViewState

@Observable final class DoneTodoDetailViewState {
    
    @ObservationIgnored private var didBind = false
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    
    var name: String?
    var tag: SelectedTag?
    var timeModel: DoneAndOriginEventTimeModel?
    var notificationOptions: String?
    var url: String?
    var isValidURLEntered: Bool { self.url?.asURL() != nil }
    var memo: String?
    var placeModel: SelectedPlaceModel?
    
    var isReverting = false
    
    func bind(_ viewModel: any DoneTodoDetailViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        viewModel.eventName
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] name in
                self?.name = name
            })
            .store(in: &self.cancellables)
        
        viewModel.eventTag
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] tag in
                self?.tag = tag
            })
            .store(in: &self.cancellables)
        
        viewModel.timeModel
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] model in
                self?.timeModel = model
            })
            .store(in: &self.cancellables)
        
        viewModel.notificationTimeText
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] text in
                self?.notificationOptions = text
            })
            .store(in: &self.cancellables)
        
        viewModel.url
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] url in
                self?.url = url
            })
            .store(in: &self.cancellables)
        
        viewModel.memo
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] memo in
                self?.memo = memo
            })
            .store(in: &self.cancellables)
        
        viewModel.placeModel
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] place in
                self?.placeModel = place
            })
            .store(in: &self.cancellables)
        
        viewModel.isReverting
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] flag in
                self?.isReverting = flag
            })
            .store(in: &self.cancellables)
    }
}

// MARK: - DoneTodoDetailViewEventHandler

final class DoneTodoDetailViewEventHandler: Observable {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var close: () -> Void = { }
    var openMap: () -> Void = { }
    var openWeb: () -> Void = { }
    var revert: () -> Void = { }

    func bind(_ viewModel: any DoneTodoDetailViewModel) {
        self.onAppear = viewModel.prepare
        self.openMap = viewModel.openMap
        self.openWeb = viewModel.openWeb
        self.revert = viewModel.revert
    }
}


// MARK: - DoneTodoDetailContainerView

struct DoneTodoDetailContainerView: View {
    
    @State private var state: DoneTodoDetailViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: DoneTodoDetailViewEventHandler
    
    var stateBinding: (DoneTodoDetailViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: DoneTodoDetailViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return DoneTodoDetailView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environment(viewAppearance)
            .environment(state)
            .environment(eventHandlers)
    }
}

// MARK: - DoneTodoDetailView

struct DoneTodoDetailView: View {
    
    @Environment(ViewAppearance.self) private var appearance
    @Environment(DoneTodoDetailViewState.self) private var state
    @Environment(DoneTodoDetailViewEventHandler.self) private var eventHandlers
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                Spacer(minLength: 5)
                nameView
                doneTimeView
                eventTimeView
                
                Spacer(minLength: 12)
                eventTagView
                notificationView
                
                Spacer(minLength: 12)
                if let place = state.placeModel {
                    placeView(place)
                }
                if let link = state.url {
                    linkView(link)
                }
                if let memo = state.memo, !memo.isEmpty {
                    memoView(memo)
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 12)
            .padding(.bottom, 120)
        }
        .safeAreaInset(edge: .bottom) {
            revertButton
        }
        .background(appearance.colorSet.bg0.asColor)
    }
    
    private var nameView: some View {
        HStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(tagColor)
                .frame(width: 6)
            
            Text(state.name ?? "-")
                .font(appearance.fontSet.size(22, weight: .semibold).asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
            Spacer()
        }
    }
    
    private var doneTimeView: some View {
        HStack(spacing: 16) {
            Image(systemName: "flag.fill")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(appearance.colorSet.text0.asColor)
            
            Text("\("eventList::done_todos::doneAt".localized()) \(state.timeModel?.doneTime ?? "-")")
                .font(appearance.fontSet.subNormal.asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
        }
    }
    
    private var eventTimeView: some View {
        HStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(appearance.colorSet.text1.asColor)
            
            timeView(state.timeModel?.eventTime)
        }
    }
    
    private enum TimeSelecting {
        case start
        case end
    }
    private func timeView(_ time: SelectedTime?) -> some View {
        
        func timeLabelView(_ timeText: SelectTimeText, _ position: TimeSelecting) -> some View {
            
            let textColor: Color = appearance.colorSet.text0.asColor
            
            return VStack(alignment: .leading) {
                
                if let year = timeText.year {
                    Text(year)
                        .font(self.appearance.fontSet.size(14).asFont)
                        .foregroundStyle(textColor)
                }
                
                Text(timeText.day)
                    .lineLimit(1)
                    .font(self.appearance.fontSet.size(14).asFont)
                    .foregroundStyle(textColor)
                
                if let time = timeText.time {
                    Text(time)
                        .font(self.appearance.fontSet.size(16, weight: .semibold).asFont)
                        .foregroundStyle(textColor)
                }
            }
        }
        
        func emptyLabelView(_ position: TimeSelecting) -> some View {
            return Text("--")
                .font(self.appearance.fontSet.size(16, weight: .semibold).asFont)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
                .frame(minWidth: 60)
        }
        
        switch time {
        case .none:
            return HStack(spacing: 16) {
                emptyLabelView(.start)
                Image(systemName: "chevron.right")
                    .foregroundStyle(self.appearance.colorSet.text1.asColor)
                emptyLabelView(.end)
            }
            .asAnyView()
            
        case .at(let time):
            return HStack(spacing: 16) {
                timeLabelView(time, .start)
                Image(systemName: "chevron.right")
                    .foregroundStyle(self.appearance.colorSet.text1.asColor)
                emptyLabelView(.end)
            }
            .asAnyView()
            
        case .period(let from, let to):
            return HStack(spacing: 16) {
                timeLabelView(from, .start)
                Image(systemName: "chevron.right")
                    .foregroundStyle(self.appearance.colorSet.text1.asColor)
                timeLabelView(to, .end)
            }
            .asAnyView()
            
        case .singleAllDay(let time):
            return HStack(spacing: 16) {
                timeLabelView(time, .start)
                Image(systemName: "chevron.right")
                    .foregroundStyle(self.appearance.colorSet.text1.asColor)
                emptyLabelView(.end)
            }
            .asAnyView()
        case .alldayPeriod(let from, let to):
            return HStack(spacing: 16) {
                timeLabelView(from, .start)
                Image(systemName: "chevron.right")
                    .foregroundStyle(self.appearance.colorSet.text1.asColor)
                timeLabelView(to, .end)
            }
            .asAnyView()
        }
    }
    
    private var tagColor: Color {
        return appearance.color(state.tag?.tagId ?? .default).asColor
    }
    
    private var eventTagView: some View {
        HStack(spacing: 16) {
            Image(systemName: "calendar")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(appearance.colorSet.text1.asColor)
            
            HStack {
                Circle()
                    .frame(width: 6, height: 6)
                    .foregroundStyle(self.tagColor)
                
                Text(self.state.tag?.name ?? "eventTag.defaults.default::name".localized())
                    .font(self.appearance.fontSet.subNormal.asFont)
                    .foregroundStyle(self.appearance.colorSet.text0.asColor)
            }
            .padding(8)
        
            Spacer()
        }
    }
    
    private var notificationView: some View {
        HStack(spacing: 16) {
            Image(systemName: "bell.fill")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(self.appearance.colorSet.text1.asColor)
            
            Text(
                self.state.notificationOptions
                ?? "event_notification_setting::option_title::no_notification".localized()
            )
                .font(self.appearance.fontSet.subNormal.asFont)
                .foregroundStyle(
                    self.appearance.colorSet.text0.asColor
                )
                .padding(8)
                
            Spacer()
        }
    }
    
    private func placeView(_ place: SelectedPlaceModel) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "location.circle")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(self.appearance.colorSet.text1.asColor)
            
            switch place {
            case .landmark(let mark):
                self.landmarkView(mark)
            case .customPlace(let name):
                self.customPlaceView(name)
            }
            
            Spacer()
            Button {
                self.eventHandlers.openMap()
            } label: {
                Image(systemName: "map")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(self.appearance.colorSet.text0.asColor)
            }
        }
    }
    
    private func landmarkView(_ landmark: SelectedPlaceModel.LandmarkModel) -> some View {
        
        HStack {
            VStack(alignment: .leading) {
                Text(landmark.name)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(self.appearance.colorSet.text0.asColor)
                    .font(self.appearance.fontSet.size(14).asFont)
                
                if let address = landmark.address {
                    Text(address)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(self.appearance.colorSet.text2.asColor)
                        .font(self.appearance.fontSet.size(12).asFont)
                }
            }
            
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(self.appearance.colorSet.text2.asColor)
                .font(self.appearance.fontSet.size(14).asFont)
        }
    }
    
    private func customPlaceView(_ name: String) -> some View {
        return Text(name)
        .foregroundStyle(self.appearance.colorSet.text0.asColor)
        .font(self.appearance.fontSet.size(14).asFont)
    }
    
    private func linkView(_ url: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "link")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(self.appearance.colorSet.text1.asColor)
            
            @Bindable var state = self.state
            Text(url)
            .foregroundStyle(self.appearance.colorSet.text0.asColor)
            .font(self.appearance.fontSet.size(14).asFont)
            
            Spacer()
            
            Button {
                self.eventHandlers.openWeb()
            } label: {
                Image(systemName: "globe")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(self.appearance.colorSet.text0.asColor)
            }
        }
    }
    
    private func memoView(_ memo: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(self.appearance.colorSet.text1.asColor)
                .padding(.top, 8)
            
            Text(memo)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
                .font(self.appearance.fontSet.size(14).asFont)
                .frame(minHeight: 34)
                .padding(.leading, 0)
        }
    }
    
    
    private var revertButton: some View {
        ConfirmButton(
            title: "eventDetail::revert".localized(),
            isEnable: true,
            isProcessing: state.isReverting
        )
        .eventHandler(\.onTap, eventHandlers.revert)
        .padding()
    }
}


// MARK: - preview

struct DoneTodoDetailViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendarSetting = CalendarAppearanceSettings(
            colorSetKey: .defaultLight, fontSetKey: .systemDefault
        )
        let setting = AppearanceSettings(
            calendar: calendarSetting,
            defaultTagColor: .init(holiday: "#ff0000", default: "#ff00ff")
        )
        let viewAppearance = ViewAppearance(
            setting: setting, isSystemDarkTheme: false
        )
        let state = DoneTodoDetailViewState()
        state.name = "이벤트 이름"
        state.tag = .init(DefaultEventTag.default("some"))
        state.timeModel = .init(doneTime: "20:30", eventTime: .at(.init(100, .current)))
        state.notificationOptions = "notifications"
//        state.url = "https://www.naver.com"
        state.placeModel = .customPlace("some")
        let eventHandlers = DoneTodoDetailViewEventHandler()
        
        let view = DoneTodoDetailView()
            .environment(viewAppearance)
            .environment(state)
            .environment(eventHandlers)
        return view
    }
}


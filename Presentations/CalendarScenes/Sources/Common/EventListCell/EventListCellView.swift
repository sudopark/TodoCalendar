//
//  EventListCellView.swift
//  CalendarScenes
//
//  Created by sudo.park on 6/28/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//

import SwiftUI
import Combine
import Prelude
import Optics
import Domain
import Extensions
import CommonPresentation


// MARK: - state

final class PendingCompleteTodoState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    @Published var ids: Set<String> = []
    
    func bind(_ viewModel: EventListCellEventHanleViewModel, _ appearance: ViewAppearance) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        viewModel.doneTodoResult
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self, weak appearance] result in
                appearance?.withAnimationIfNeed {
                    guard let self = self else { return }
                    self.ids.remove(result.id)
                }
            })
            .store(in: &self.cancellables)
    }
}

// MARK: - event list cellView

struct EventListCellView: View {
    
    @EnvironmentObject private var pendingDoneState: PendingCompleteTodoState
    @EnvironmentObject private var appearance: ViewAppearance
    
    var requestDoneTodo: (String) -> Void = { _ in }
    var requestCancelDoneTodo: (String) -> Void = { _ in }
    var requestShowDetail: (any EventCellViewModel) -> Void = { _ in }
    var handleMoreAction: (any EventCellViewModel, EventListMoreAction) -> Void = { _, _ in }
    
    private let cellViewModel: any EventCellViewModel
    private let isUncompletedTodo: Bool
    init(
        cellViewModel: any EventCellViewModel,
        isUncompletedTodo: Bool = false
    ) {
        self.cellViewModel = cellViewModel
        self.isUncompletedTodo = isUncompletedTodo
    }
    
    var body: some View {
        let tagLineColor = {
            switch self.cellViewModel {
            case let google as GoogleCalendarEventCellViewModel:
                return self.appearance.googleEventColor(google.colorId, google.calendarId).asColor
            default:
                return self.appearance.color(cellViewModel.tagId).asColor
            }
        }()
        return HStack(spacing: 8) {
            // left
            self.eventLeftView(cellViewModel)
                .frame(width: 52)
                
            // tag line
            RoundedRectangle(cornerRadius: 3)
                .fill(tagLineColor)
                .frame(width: 6)
            
            // right
            self.eventRightView(cellViewModel)
        }
        .padding(.vertical, 4).padding(.horizontal, 8)
        .frame(idealHeight: 50)
        .backgroundAsRoundedRectForEventList(self.appearance)
        .onTapGesture {
            self.appearance.impactIfNeed()
            self.requestShowDetail(self.cellViewModel)
        }
        .contextMenu {
            if let moreActions = cellViewModel.moreActions {
                ForEach(0..<moreActions.basicActions.count, id: \.self) {
                    moreActionsView(moreActions.basicActions[$0])
                }
                
                Divider()
                
                ForEach(0..<moreActions.removeActions.count, id: \.self) {
                    moreActionsView(moreActions.removeActions[$0])
                }
            }
        }
    }
    
    private func moreActionsView(_ action: EventListMoreAction) -> some View {
        switch action {
        case .edit:
            return editEventButton().asAnyView()
        case .remove(let onlyThisTime):
            return removeButton(onlyThisTime).asAnyView()
        case .toggleTo(let isForemost):
            return toggleForemostButton(isForemost).asAnyView()
        case .skipTodo:
            return skipTodoButton().asAnyView()
        case .copy:
            return copyButton().asAnyView()
        case .editGoogleEvent:
            return editGoogleEventButton().asAnyView()
        }
    }
    
    private func removeButton(_ onlyThisTime: Bool) -> some View {
        return Button(role: .destructive) {
            self.handleMoreAction(
                self.cellViewModel, .remove(onlyThisTime: onlyThisTime)
            )
        } label: {
            HStack {
                Text(onlyThisTime
                     ? R.String.calendarEventMoreActionRemoveOnlyThistimeItemName
                     : R.String.calendarEventMoreActionRemoveItemName
                )
                Image(systemName: "trash")
            }
        }
    }
    
    private func toggleForemostButton(_ isForemost: Bool) -> some View {
        return Button {
            self.handleMoreAction(
                self.cellViewModel, .toggleTo(isForemost: !isForemost)
            )
        } label: {
            HStack {
                Text(isForemost
                     ? R.String.calendarEventMoreActionForemostUnmarkItemName
                     : R.String.calendarEventMoreActionForemostMarkItemName
                )
                Image(systemName: "exclamationmark.circle")
            }
        }
    }
    
    private func editEventButton() -> some View {
        return Button {
            self.requestShowDetail(self.cellViewModel)
        } label: {
            HStack {
                Text(R.String.calendarEventMoreActionEditItemName)
                Image(systemName: "pencil")
            }
        }
    }
    
    private func skipTodoButton() -> some View {
        return Button {
            self.handleMoreAction(self.cellViewModel, .skipTodo)
        } label: {
            HStack {
                Text("calednar::event::skip_todo".localized())
                Image(systemName: "forward")
            }
        }
    }
    
    private func copyButton() -> some View {
        return Button {
            self.handleMoreAction(self.cellViewModel, .copy)
        } label: {
            HStack {
                Text("calednar::event::copy".localized())
                Image(systemName: "doc.on.doc")
            }
        }
    }
    
    private func editGoogleEventButton() -> some View {
        return Button {
            self.handleMoreAction(self.cellViewModel, .editGoogleEvent)
        } label: {
            Text("calednar::event::google::edit".localized())
            Image("google_calendar_icon")
                .resizable()
                .scaledToFill()
        }
    }
    
    private func eventLeftView(_ cellViewModel: any EventCellViewModel) -> some View {
        
        func pmOrAmView(_ amOrPm: String) -> some View {
            Text(amOrPm)
                .minimumScaleFactor(0.7)
                .font(appearance.fontSet.size(8+appearance.eventTextAdditionalSize).asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
        }
        
        func singleText(_ text: EventTimeText) -> some View {
            return VStack(alignment: .center) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(text.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .font(
                            self.appearance.fontSet.size(15+appearance.eventTextAdditionalSize, weight: .regular).asFont
                        )
                        .foregroundColor(self.appearance.colorSet.text0.asColor)
                    
                    if let amPm = text.pmOram {
                        pmOrAmView(amPm)
                    }
                }
            }
        }
        func doubleText(_ top: EventTimeText, _ bottom: EventTimeText) -> some View {
            return VStack(alignment: .center, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(top.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .font(self.appearance.fontSet.size(15+appearance.eventTextAdditionalSize, weight: .regular).asFont)
                        .foregroundColor(self.appearance.colorSet.text0.asColor)
                    
                    if let amPm = top.pmOram {
                        pmOrAmView(amPm)
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                 
                    Text(bottom.text)
                        .minimumScaleFactor(0.7)
                        .font(self.appearance.fontSet.size(14+appearance.eventTextAdditionalSize).asFont)
                        .foregroundColor(self.appearance.colorSet.text1.asColor)
                    
                    if let amPm = bottom.pmOram {
                        pmOrAmView(amPm)
                    }
                }
            }
        }
        switch cellViewModel.periodText {
        case .singleText(let text):
            return singleText(text).asAnyView()
        case .doubleText(let topText, let bottomText):
            return doubleText(topText, bottomText).asAnyView()
        default:
            return EmptyView().asAnyView()
        }
    }
    
    private func eventRightView(_ cellViewModel: any EventCellViewModel) -> some View {
        let nameColor = self.isUncompletedTodo
            ? self.appearance.colorSet.uncompletedTodo
            : self.appearance.colorSet.text0
        return HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(cellViewModel.name)
                    .minimumScaleFactor(0.7)
                    .font(
                        self.appearance.eventTextFontOnList(isForemost: cellViewModel.isForemost).asFont
                    )
                    .foregroundColor(nameColor.asColor)
                
                if let periodDescription = cellViewModel.periodDescription {
                    Text(periodDescription)
                        .minimumScaleFactor(0.7)
                        .font(
                            self.appearance.fontSet.size(13+appearance.eventTextAdditionalSize).asFont
                        )
                        .foregroundColor(self.appearance.colorSet.text1.asColor)
                }
            }
            Spacer()
            if let todoId = cellViewModel.todoEventId {
                todoDoneButton(todoId)
            }
        }
    }
    
    private func todoDoneButton(_ todoId: String) -> some View {
        Button {
            let isUnderCompleteProcessing = self.pendingDoneState.ids.contains(todoId)
            if !isUnderCompleteProcessing {
                appearance.withAnimationIfNeed {
                    _ = self.pendingDoneState.ids.insert(todoId)
                    self.requestDoneTodo(todoId)
                }
            } else {
                appearance.withAnimationIfNeed { _ = self.pendingDoneState.ids.remove(todoId) }
                self.requestCancelDoneTodo(todoId)
            }
            
        } label: {
            if self.pendingDoneState.ids.contains(todoId) {
                Image(systemName: "circle.inset.filled")
            } else {
                Image(systemName: "circle")
            }
        }
    }
}


// MARK: - extensions

extension EventCellViewModel {
    
    var todoEventId: String? {
        return (self as? TodoEventCellViewModel)?.eventIdentifier
    }
}



extension View {
    
    func backgroundAsRoundedRectForEventList(_ appearance: ViewAppearance) -> some View {
        
        return self
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(appearance.colorSet.bg1.asColor)
            )
    }
}

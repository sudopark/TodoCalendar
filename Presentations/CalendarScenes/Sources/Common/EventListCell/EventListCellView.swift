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
import CommonPresentation


// MARK: - state

final class PendingCompleteTodoState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    @Published var ids: Set<String> = []
    
    func bind(_ viewModel: EventListCellEventHanleViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        viewModel.doneTodoResult
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] result in
                withAnimation {
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
    init(cellViewModel: any EventCellViewModel) {
        self.cellViewModel = cellViewModel
    }
    
    var body: some View {
        let tagLineColor = cellViewModel.tagColor?.color(with: self.appearance).asColor ?? .clear
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
            if cellViewModel.isSupportContextMenu {
                if cellViewModel.isRepeating {
                    removeButton(true)
                }
                removeButton(false)
                
                Divider()
                
                toggleForemostButton(cellViewModel.isForemost)
            }
        }
    }
    
    private func removeButton(_ onlyThisTime: Bool) -> some View {
        return Button(role: .destructive) {
            self.handleMoreAction(
                self.cellViewModel, .remove(onlyThisTime: onlyThisTime)
            )
        } label: {
            HStack {
                Text(onlyThisTime ? "remove event only this time".localized() : "remove event".localized())
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
                Text(isForemost ? "unmark as foremost".localized() : "mark as foremost".localized())
                Image(systemName: "exclamationmark.circle")
            }
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
        return HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(cellViewModel.name)
                    .minimumScaleFactor(0.7)
                    .font(
                        self.appearance.eventTextFontOnList(isForemost: cellViewModel.isForemost).asFont
                    )
                    .foregroundColor(self.appearance.colorSet.text0.asColor)
                
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
                withAnimation { _ = self.pendingDoneState.ids.insert(todoId) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    guard self.pendingDoneState.ids.contains(todoId) else { return }
                    self.requestDoneTodo(todoId)
                }
            } else {
                withAnimation { _ = self.pendingDoneState.ids.remove(todoId) }
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
    
    var isSupportContextMenu: Bool {
        switch self {
        case is TodoEventCellViewModel: return true
        case is ScheduleEventCellViewModel: return true
        default: return false
        }
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

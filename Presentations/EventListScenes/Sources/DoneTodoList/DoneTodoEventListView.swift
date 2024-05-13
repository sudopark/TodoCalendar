//
//  
//  DoneTodoEventListView.swift
//  EventListScenes
//
//  Created by sudo.park on 5/11/24.
//  Copyright © 2024 com.sudo.park. All rights reserved.
//
//


import SwiftUI
import Combine
import Prelude
import Optics
import Domain
import CommonPresentation


// MARK: - DoneTodoEventListViewState

final class DoneTodoEventListViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    @Published var isRemovingDoneTodos = false
    @Published var sections: [DoneTodoListSectionModel] = []
    @Published var pendingRevertDoneTodoIds: Set<String> = []
    
    func bind(_ viewModel: any DoneTodoEventListViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
        viewModel.isRemovingTodos
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] flag in
                self?.isRemovingDoneTodos = flag
            })
            .store(in: &self.cancellables)
        
        viewModel.sectionModels
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] sections in
                self?.sections = sections
            })
            .store(in: &self.cancellables)
    }
}

// MARK: - DoneTodoEventListViewEventHandler

final class DoneTodoEventListViewEventHandler: ObservableObject {
    
    // TODO: add handlers
    var onAppear: () -> Void = { }
    var close: () -> Void = { }
    var loadMoreList: () -> Void = { }
    var revertDoneTodo: (String) -> Void = { _ in }
    var cancelRevertDoneTodo: (String) -> Void = { _ in }
    var removeDoneTodos: () -> Void = { }

    func bind(_ viewModel: any DoneTodoEventListViewModel) {
        // TODO: bind handlers
        self.onAppear = viewModel.loadList
        self.close = viewModel.close
        self.loadMoreList = viewModel.loadMoreList
        self.revertDoneTodo = viewModel.revertDoneTodo(_:)
        self.cancelRevertDoneTodo = viewModel.cancelRevertDoneTodo(_:)
        self.removeDoneTodos = viewModel.removeDoneTodos
    }
}


// MARK: - DoneTodoEventListContainerView

struct DoneTodoEventListContainerView: View {
    
    @StateObject private var state: DoneTodoEventListViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: DoneTodoEventListViewEventHandler
    
    var stateBinding: (DoneTodoEventListViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: DoneTodoEventListViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return DoneTodoEventListView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
    }
}

// MARK: - DoneTodoEventListView

struct DoneTodoEventListView: View {
    
    @EnvironmentObject private var state: DoneTodoEventListViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: DoneTodoEventListViewEventHandler
        
    var body: some View {
        NavigationStack {
            List {
                ForEach(state.sections, id: \.compareKey) { section in
                    Section {
                        ForEach(section.cells, id: \.compareKey) { cell in
                            cellView(cell)
                        }
                    } header: {
                        sectionView(section)
                    }
                    .listSectionSeparator(.hidden)
                }
            }
            .background(appearance.colorSet.background.asColor)
            .listStyle(PlainListStyle())
            .navigationTitle(
                Text("Done Todos".localized())
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    self.deleteButton
                }
            }
        }
    }
    
    private func sectionView(_ section: DoneTodoListSectionModel) -> some View {
        HStack {
            Text(section.sectionTitle)
                .foregroundStyle(appearance.colorSet.normalText.asColor)
                .font(appearance.fontSet.big.asFont)
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
            Spacer()
        }
        .background(appearance.colorSet.background.asColor)
        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
    }
    
    private func cellView(_ cell: DoneTodoCellViewModel) -> some View {
        HStack(spacing: 16) {
            revertDoneButton(cell.uuid)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(cell.name)
                    .foregroundStyle(appearance.colorSet.subSubNormalText.asColor)
                    .font(appearance.fontSet.normal.asFont)
                
                if let eventTime = cell.eventTimeText {
                    HStack(spacing: 2) {
                        Text("event time:".localized())
                            .foregroundStyle(appearance.colorSet.subSubNormalText.asColor)
                            .font(appearance.fontSet.subNormal.asFont)
                        Text(eventTime)
                            .foregroundStyle(appearance.colorSet.subSubNormalText.asColor)
                            .font(appearance.fontSet.subNormal.asFont)
                    }
                }
                HStack(spacing: 2) {
                    Text("dont at:".localized())
                        .foregroundStyle(appearance.colorSet.subSubNormalText.asColor)
                        .font(appearance.fontSet.subNormal.asFont)
                    Text(cell.doneTimeText)
                        .foregroundStyle(appearance.colorSet.subSubNormalText.asColor)
                        .font(appearance.fontSet.subNormal.asFont)
                }
            }
            .padding(.bottom, 4)
        }
        .listRowBackground(appearance.colorSet.background.asColor)
        .onAppear {
            guard self.state.sections.last?.cells.last?.uuid == cell.uuid else { return }
            self.eventHandlers.loadMoreList()
        }
    }
    
    private func revertDoneButton(_ doneId: String) -> some View {
        return Button {
            let isPending = self.state.pendingRevertDoneTodoIds.contains(doneId)
            if !isPending {
                withAnimation { _ = self.state.pendingRevertDoneTodoIds.insert(doneId) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    guard self.state.pendingRevertDoneTodoIds.contains(doneId) else { return }
                    self.eventHandlers.revertDoneTodo(doneId)
                }
            } else {
                withAnimation { _ = self.state.pendingRevertDoneTodoIds.remove(doneId) }
                self.eventHandlers.cancelRevertDoneTodo(doneId)
            }
        } label: {
            Image(
                systemName: !state.pendingRevertDoneTodoIds.contains(doneId) ? "circle.inset.filled" : "circle"
            )
            .foregroundStyle(appearance.colorSet.accent.asColor)
        }
    }
    
    private var deleteButton: some View {
        return Button {
            self.eventHandlers.removeDoneTodos()
        } label: {
            Text("Remove")
        }
    }
}


extension DoneTodoCellViewModel {
    
    fileprivate var compareKey: String {
        return "\(self.uuid),\(self.name),\(self.eventTimeText ?? "nil"),\(self.doneTimeText)"
    }
}

extension DoneTodoListSectionModel {
    
    fileprivate var compareKey: String {
        let cells = self.cells.map { $0.compareKey }.joined(separator: "_")
        return "\(sectionTitle),\(sectionGroupTitle),\(self.shouldShowSectionGroupTitle),\(cells)"
    }
}


// MARK: - preview

struct DoneTodoEventListViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        
        let setting = AppearanceSettings(
            calendar: .init(colorSetKey: .defaultLight, fontSetKey: .systemDefault),
            defaultTagColor: .init(holiday: "#ff0000", default: "#ff00ff")
        )
        let viewAppearance = ViewAppearance(
            setting: setting
        )
        let state = DoneTodoEventListViewState()
        let eventHandlers = DoneTodoEventListViewEventHandler()
        
        let dones1 = (0..<10).map {
            DoneTodoEvent(uuid: "id:\($0)", name: "name:\($0)", originEventId: "some", doneTime: Date().addingTimeInterval(-TimeInterval($0)))
            |> \.eventTime .~ .period(
                TimeInterval($0)..<TimeInterval($0+3600)
            )
        }
        let dones2 = (10..<50).map {
            DoneTodoEvent(uuid: "id:\($0)", name: "name:\($0)", originEventId: "some", doneTime: Date().add(days: -1)!.addingTimeInterval(-TimeInterval($0)))
            |> \.eventTime .~ .at(-TimeInterval($0))
        }
        let sections = DoneTodoListSectionModel.builder(TimeZone(abbreviation: "KST")!, true).build(dones1 + dones2)
        state.sections = sections
        
        eventHandlers.loadMoreList = {
            guard state.sections.last?.cells.last?.uuid == "id:49" else { return }
            let dones3 = (50..<100).map {
                DoneTodoEvent(uuid: "id:\($0)", name: "name:\($0)", originEventId: "some", doneTime: Date().add(days: -100)!.addingTimeInterval(-TimeInterval($0)))
                |> \.eventTime .~ .at(-TimeInterval($0))
            }
            let sections = DoneTodoListSectionModel.builder(TimeZone(abbreviation: "KST")!, true).build(dones1 + dones2 + dones3)
            state.sections = sections
        }
        
        let view = DoneTodoEventListView()
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandlers)
        return view
    }
}


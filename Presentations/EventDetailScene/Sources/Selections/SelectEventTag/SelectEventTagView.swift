//
//  
//  SelectEventTagView.swift
//  EventDetailScene
//
//  Created by sudo.park on 10/22/23.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - SelectEventTagViewController

final class SelectEventTagViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    @Published var tags: [TagCellViewModel] = []
    @Published var selectedTagId: AllEventTagId?
    
    func bind(_ viewModel: any SelectEventTagViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
        viewModel.tags
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] tags in
                self?.tags = tags
            })
            .store(in: &self.cancellables)
        
        viewModel.selectedTagId
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] id in
                self?.selectedTagId = id
            })
            .store(in: &self.cancellables)
    }
}


final class SelectEventTagViewEventHandler: ObservableObject {
 
    var onAppear: () -> Void = { }
    var selectTag: (AllEventTagId) -> Void = { _ in }
    var addTag: () -> Void = { }
    var moveToTagSeting: () -> Void = { }
    var close: () -> Void = { }
    
    func bind(_ viewModel: any SelectEventTagViewModel) {
        self.onAppear = viewModel.refresh
        self.selectTag = viewModel.selectTag(_:)
        self.addTag = viewModel.addTag
        self.moveToTagSeting = viewModel.moveToTagSetting
        self.close = viewModel.close
    }
}


// MARK: - SelectEventTagContainerView

struct SelectEventTagContainerView: View {
    
    @StateObject private var state: SelectEventTagViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandler: SelectEventTagViewEventHandler
    
    var stateBinding: (SelectEventTagViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandler: SelectEventTagViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandler = eventHandler
    }
    
    var body: some View {
        return SelectEventTagView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandler.onAppear()
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
            .environmentObject(eventHandler)
    }
}

// MARK: - SelectEventTagView

struct SelectEventTagView: View {
    
    @EnvironmentObject private var state: SelectEventTagViewState
    @EnvironmentObject private var appearance: ViewAppearance
    @EnvironmentObject private var eventHandlers: SelectEventTagViewEventHandler
    
    var body: some View {
        NavigationStack {
            
            List {
                ForEach(self.state.tags, id: \.compareKey) {
                    self.tagCellView($0)
                }
                .listRowSeparator(.hidden)
                
                self.addTagView
                    .listRowSeparator(.hidden)
                
                self.seeAllEventTypesView
                    .listRowSeparator(.hidden)
            }
            .listStyle(.inset)
            .navigationTitle("Event Type".localized())
            .toolbar {
                CloseButton()
                    .eventHandler(\.onTap, eventHandlers.close)
            }
        }
    }
    
    private func tagCellView(_ tag: TagCellViewModel) -> some View {
        HStack(spacing: 12) {
            
            Circle()
                .frame(width: 8, height: 8)
                .foregroundStyle(tag.color.color(with: self.appearance).asColor)
            
            Text(tag.name)
                .font(self.appearance.fontSet.normal.asFont)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
                .lineLimit(1)
            
            Spacer()
            if self.state.selectedTagId == tag.id {
                Image(systemName: "checkmark")
                    .font(.system(size: 12))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(self.appearance.colorSet.bg1.asColor)
        }
        .onTapGesture {
            self.eventHandlers.selectTag(tag.id)
        }
    }
    
    private var addTagView: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
                .font(.system(size: 12))
            
            Text("Add new event type".localized())
                .font(self.appearance.fontSet.normal.asFont)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(self.appearance.colorSet.bg1.asColor)
        }
        .onTapGesture {
            self.eventHandlers.addTag()
        }
    }
    
    private var seeAllEventTypesView: some View {
        
        HStack {
            Spacer()
            Text("All event types >".localized())
                .foregroundStyle(self.appearance.colorSet.accent.asColor)
                .font(self.appearance.fontSet.normal.asFont)
                .onTapGesture {
                    self.eventHandlers.moveToTagSeting()
                }
        }
    }
}

private extension TagCellViewModel {
    
    var compareKey: String {
        return "id:\(id.hashValue)_\(name)_\(color)"
    }
}


// MARK: - preview

struct SelectEventTagViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        let state = SelectEventTagViewState()
        state.tags = [
            .init(.init(.default, "default", .default)),
            .init(.init(.custom("some"), "some", .custom(hex: "#00ffdd"))),
            .init(.init(.custom("some1"), "some1", .custom(hex: "#00ffdd"))),
            .init(.init(.custom("som2"), "some2", .custom(hex: "#00ffdd"))),
        ]
        let eventHandler = SelectEventTagViewEventHandler()
        let view = SelectEventTagView()
            .environmentObject(viewAppearance)
            .environmentObject(state)
            .environmentObject(eventHandler)
        return view
    }
}

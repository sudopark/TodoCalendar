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
import Extensions
import CommonPresentation


// MARK: - SelectEventTagViewController

@Observable final class SelectEventTagViewState {
    
    @ObservationIgnored private var didBind = false
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    
    var tags: [TagCellViewModel] = []
    var selectedTagId: EventTagId?
    
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


final class SelectEventTagViewEventHandler: Observable {
 
    var onAppear: () -> Void = { }
    var selectTag: (EventTagId) -> Void = { _ in }
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
    
    @State private var state: SelectEventTagViewState = .init()
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
            .environment(state)
            .environment(eventHandler)
            .environment(viewAppearance)
    }
}

// MARK: - SelectEventTagView

struct SelectEventTagView: View {
    
    @Environment(SelectEventTagViewState.self) private var state
    @Environment(SelectEventTagViewEventHandler.self) private var eventHandlers
    @Environment(ViewAppearance.self) private var appearance
    
    var body: some View {
        NavigationStack {
            
            List {
                ForEach(self.state.tags, id: \.compareKey) {
                    self.tagCellView($0)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(appearance.colorSet.bg0.asColor)
                
                self.addTagView
                    .listRowSeparator(.hidden)
                    .listRowBackground(appearance.colorSet.bg0.asColor)
                
                self.seeAllEventTypesView
                    .listRowSeparator(.hidden)
                    .listRowBackground(appearance.colorSet.bg0.asColor)
            }
            .listStyle(.plain)
            .background(appearance.colorSet.bg0.asColor)
            
            .navigationTitle(R.String.EventTag.title)
            .if(condition: ProcessInfo.isAvailiOS26()) {
                $0.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            }
            .toolbar {
                CloseButton()
                    .eventHandler(\.onTap, eventHandlers.close)
            }
        }
            .id(appearance.navigationBarId)
    }
    
    private func tagCellView(_ tag: TagCellViewModel) -> some View {
        HStack(spacing: 12) {
            
            Circle()
                .frame(width: 8, height: 8)
                .foregroundStyle(appearance.color(tag.id).asColor)
            
            Text(tag.name)
                .font(self.appearance.fontSet.normal.asFont)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
                .lineLimit(1)
            
            Spacer()
            if self.state.selectedTagId == tag.id {
                Image(systemName: "checkmark")
                    .font(.system(size: 12))
                    .foregroundStyle(appearance.colorSet.text0.asColor)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(self.appearance.colorSet.bg1.asColor)
        }
        .onTapGesture {
            self.appearance.impactIfNeed()
            self.eventHandlers.selectTag(tag.id)
        }
    }
    
    private var addTagView: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
                .font(.system(size: 12))
            
            Text(R.String.EventTag.addNewPlaceholder)
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
            self.appearance.impactIfNeed()
            self.eventHandlers.addTag()
        }
    }
    
    private var seeAllEventTypesView: some View {
        
        HStack {
            Spacer()
            Text(R.String.EventTag.allEventTypes)
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
        return "id:\(id.hashValue)_\(name)"
    }
}


// MARK: - preview

struct SelectEventTagViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultDark,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        let state = SelectEventTagViewState()
        state.tags = [
            .init(.init(.default, "default", "#ff00ff")),
            .init(.init(.custom("some"), "some", "#00ffdd")),
            .init(.init(.custom("some1"), "some1", "#00ffdd")),
            .init(.init(.custom("som2"), "some2", "#00ffdd")),
        ]
        let eventHandler = SelectEventTagViewEventHandler()
        let view = SelectEventTagView()
            .environment(state)
            .environment(eventHandler)
            .environment(viewAppearance)
        return view
    }
}

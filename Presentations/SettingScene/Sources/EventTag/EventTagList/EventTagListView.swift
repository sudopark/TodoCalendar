//
//  
//  EventTagListView.swift
//  SettingScene
//
//  Created by sudo.park on 2023/09/24.
//
//


import SwiftUI
import Combine
import Prelude
import Optics
import Domain
import CommonPresentation


// MARK: - EventTagListViewController

final class EventTagListViewState: ObservableObject {
    
    private var didBind = false
    private var cancellables: Set<AnyCancellable> = []
    
    @Published var cellviewModels: [BaseCalendarEventTagCellViewModel] = []
    @Published var externalCalendarTagSections: [ExternalCalendarEventTagListSectionModel] = []
    
    func bind(_ viewModel: any EventTagListViewModel, _ appearance: ViewAppearance) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
        viewModel.cellViewModels
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self, weak appearance] cellViewModels in
                appearance?.withAnimationIfNeed {
                    self?.cellviewModels = cellViewModels
                }
            })
            .store(in: &self.cancellables)
        
        viewModel.externalCalendarSections
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self, weak appearance] sections in
                appearance?.withAnimationIfNeed {
                    self?.externalCalendarTagSections = sections
                }
            })
            .store(in: &self.cancellables)
    }
}


// MARK: - EventTagListContainerView

struct EventTagListContainerView: View {
    
    @StateObject fileprivate var state: EventTagListViewState = .init()
    private let viewAppearance: ViewAppearance
    private let hasNavigation: Bool
    
    var stateBinding: (EventTagListViewState) -> Void = { _ in }
    var onAppear: () -> Void = { }
    var addTag: () -> Void = { }
    var closeScene: () -> Void = { }
    var toggleEventTagViewingIsOn: (EventTagId) -> Void = { _ in }
    var showTagDetail: (EventTagId) -> Void = { _ in }
    var integrateService: (String) -> Void = { _ in }
    
    init(
        hasNavigation: Bool,
        viewAppearance: ViewAppearance
    ) {
        self.hasNavigation = hasNavigation
        self.viewAppearance = viewAppearance
    }
    
    var body: some View {
        return EventTagListView(hasNavigation: hasNavigation)
            .eventHandler(\.addTag, self.addTag)
            .eventHandler(\.closeScene, self.closeScene)
            .eventHandler(\.toggleEventTagViewingIsOn, self.toggleEventTagViewingIsOn)
            .eventHandler(\.showTagDetail, self.showTagDetail)
            .eventHandler(\.integrateService, self.integrateService)
            .onAppear {
                self.stateBinding(self.state)
                self.onAppear()
            }
            .environmentObject(state)
            .environmentObject(viewAppearance)
    }
}

// MARK: - EventTagListView

struct EventTagListView: View {
    
    @EnvironmentObject private var state: EventTagListViewState
    @EnvironmentObject private var appearance: ViewAppearance
    
    private let hasNavigation: Bool
    fileprivate var addTag: () -> Void = { }
    fileprivate var closeScene: () -> Void = { }
    fileprivate var toggleEventTagViewingIsOn: (EventTagId) -> Void = { _ in }
    fileprivate var showTagDetail: (EventTagId) -> Void = { _ in }
    fileprivate var integrateService: (String) -> Void = { _ in }
    
    init(hasNavigation: Bool) {
        self.hasNavigation = hasNavigation
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(self.state.cellviewModels, id: \.compareKey) {
                    self.cellView($0)
                        .listRowSeparator(.hidden)
                        .listRowBackground(appearance.colorSet.bg0.asColor)
                }
                
                if !self.state.externalCalendarTagSections.isEmpty {
                    self.externalSectionList
                        .listRowSeparator(.hidden)
                        .listRowBackground(appearance.colorSet.bg0.asColor)
                }
            }
            .listStyle(.plain)
            .background(appearance.colorSet.bg0.asColor)
            .toolbar {
                if self.hasNavigation {
                 
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationBackButton {
                            self.closeScene()
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        self.addButton
                    }
                } else {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        HStack(spacing: 8) {
                            self.addButton
                            CloseButton()
                                .eventHandler(\.onTap, self.closeScene)
                        }
                    }
                }
            }
            .navigationTitle("eventTag.list::title".localized())
        }
            .id(appearance.navigationBarId)
    }
    
    private var addButton: some View {
        Button {
            self.addTag()
        } label: {
            Image(systemName: "plus.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    self.appearance.colorSet.eventText.asColor,
                    self.appearance.colorSet.bg1.asColor
                )
                .font(.system(size: 20))
        }
    }
    
    private func cellView(_ cellViewModel: BaseCalendarEventTagCellViewModel) -> some View {
        
        HStack {
            Image(systemName: cellViewModel.isOn ? "checkmark.circle.fill" : "checkmark.circle")
                .foregroundStyle(appearance.color(cellViewModel.id).asColor)
                .font(.title3)
                .onTapGesture {
                    self.appearance.impactIfNeed()
                    self.toggleEventTagViewingIsOn(cellViewModel.id)
                }
            Text(cellViewModel.name)
                .lineLimit(1)
                .font(self.appearance.fontSet.normal.asFont)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
            Spacer()
            Button {
                self.showTagDetail(cellViewModel.id)
            } label: {
                HStack {
                    RoundedRectangle(cornerRadius: 1).frame(width: 1)
                        .foregroundStyle(self.appearance.colorSet.text1.withAlphaComponent(0.1).asColor)
                    Image(systemName: "info.circle")
                        .foregroundStyle(self.appearance.colorSet.text1.withAlphaComponent(0.6).asColor)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(self.appearance.colorSet.bg1.asColor)
        )
    }
    
    private var externalSectionList: some View {
        ForEach(self.state.externalCalendarTagSections, id: \.compareKey) { section in
            self.externalSectionView(section)
        }
        .padding(.top, 16)
    }
    
    private func externalSectionView(_ section: ExternalCalendarEventTagListSectionModel) -> some View {
        
        VStack(alignment: .leading) {
            Text(section.serviceTitle)
                .font(appearance.fontSet.size(16, weight: .semibold).asFont)
                .foregroundStyle(appearance.colorSet.text0.asColor)
            
            if section.cellViewModels.isEmpty {
                serviceIntegrateView(section.serviceId)
            } else {
                ForEach(section.cellViewModels, id: \.compareKey) { cell in
                    self.externalCellView(cell)
                }
            }
        }
    }
    
    private func serviceIntegrateView(_ serviceId: String) -> some View {
        Button {
            self.integrateService(serviceId)
        } label: {
            HStack {
                Text("eventTag.externalCalendar::integrate_button".localized())
                    
                
                Spacer()
                
                Image(systemName: "chevron.right")
            }
            .font(appearance.fontSet.normal.asFont)
            .foregroundStyle(appearance.colorSet.primaryBtnBackground.asColor)
        }
        .padding(.top, 8)
    }

    private func externalCellView(_ cellViewModel: ExternalCalendarEventTagCellViewModel) -> some View {
        
        HStack {
            Image(systemName: cellViewModel.isOn ? "checkmark.circle.fill" : "checkmark.circle")
                .foregroundStyle(appearance.color(cellViewModel.id).asColor)
                .font(.title3)
                .onTapGesture {
                    self.appearance.impactIfNeed()
                    self.toggleEventTagViewingIsOn(cellViewModel.id)
                }
            
            Text(cellViewModel.name)
                .lineLimit(1)
                .font(self.appearance.fontSet.normal.asFont)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(self.appearance.colorSet.bg1.asColor)
        )
    }
}

private extension EventTagId {
    var compareKey: String {
        switch self {
        case .holiday: return "holiday"
        case .default: return "default"
        case .custom(let id): return id
        case .externalCalendar(let serviceId, let id): return "external::\(serviceId)::\(id)"
        }
    }
}

extension ExternalCalendarEventTagListSectionModel {
    
    var compareKey: String {
        let components = [
            self.serviceId, self.serviceTitle, self.icon ?? "nil", self.cellViewModels.map { $0.compareKey }.joined(separator: ",")
        ]
        return components.joined(separator: "-")
    }
}

extension ExternalCalendarEventTagCellViewModel {
    
    var compareKey: String {
        let components = [
            "\(self.id)", self.name, "\(self.isOn)"
        ]
        return components.joined(separator: "-")
    }
}


extension BaseCalendarEventTagCellViewModel {
    
    var compareKey: String {
        let components = [
            self.id.compareKey, self.name, self.colorHex, "\(self.isOn)"
        ]
        return components.joined(separator: "-")
    }
}



// MARK: - preview

struct EventTagListViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        let state = EventTagListViewState()
        state.cellviewModels = (0..<4).map {
            let tag = CustomEventTag(uuid: "id:\($0)", name: "name:\($0)", colorHex: "#ff0000")
            return BaseCalendarEventTagCellViewModel(tag)
        }
        let googles = (0..<5).map {
            ExternalCalendarEventTag(
                tagId: .externalCalendar(serviceId: GoogleCalendarService.id, id: "g:\($0)"),
                name: "name:\($0)",
                colorHex: "some"
            )
        }
        .map { ExternalCalendarEventTagCellViewModel($0) }
        state.externalCalendarTagSections = [
            .init(
                serviceId: GoogleCalendarService.id,
                serviceTitle: "Google Calendar",
                cellViewModels: [],
                offIds: []
            )
        ]
        return EventTagListView(hasNavigation: true)
            .eventHandler(\.toggleEventTagViewingIsOn) { id in
                if let index = state.cellviewModels.firstIndex(where: { $0.id == id }) {
                    
                    let newCells = state.cellviewModels |> ix(index) %~ {
                        $0 |> \.isOn .~ !$0.isOn
                    }
                    state.cellviewModels = newCells
                }
                if let index = state.externalCalendarTagSections.first?.cellViewModels.firstIndex(where: { $0.id == id }) {
                    var newCells = state.externalCalendarTagSections.first?.cellViewModels ?? []
                    newCells[index].isOn.toggle()
                    let section = ExternalCalendarEventTagListSectionModel(
                        serviceId: GoogleCalendarService.id,
                        serviceTitle: "Google Calendar",
                        cellViewModels: newCells,
                        offIds: [newCells[index].id]
                    )
                    state.externalCalendarTagSections = [section]
                }
            }
            .eventHandler(\.integrateService) { _ in
                state.externalCalendarTagSections = [
                    .init(
                        serviceId: GoogleCalendarService.id,
                        serviceTitle: "Google Calendar",
                        cellViewModels: googles,
                        offIds: []
                    )
                ]
            }
            .environmentObject(viewAppearance)
            .environmentObject(state)
    }
}

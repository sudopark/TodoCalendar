//
//  
//  SettingItemListView.swift
//  SettingScene
//
//  Created by sudo.park on 11/21/23.
//
//


import SwiftUI
import Combine
import Domain
import CommonPresentation


// MARK: - SettingItemListViewState

@Observable final class SettingItemListViewState {
    
    @ObservationIgnored private var didBind = false
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    var sections: [any SettingSectionModelType] = []
    
    func bind(_ viewModel: any SettingItemListViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        // TODO: bind state
        viewModel.sectionModels
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] sections in
                self?.sections = sections
            })
            .store(in: &self.cancellables)
    }
}

// MARK: - SettingItemListViewEventHandler

final class SettingItemListViewEventHandler: Observable {

    var onAppear: () -> Void = { }
    var selectItem: (any SettingItemModelType) -> Void = { _ in }
    var close: () -> Void = { }
    var openAppUpdate: () -> Void = { }

    func bind(_ viewModel: any SettingItemListViewModel) {

        self.onAppear = viewModel.prepare
        self.selectItem = viewModel.selectItem
        self.close = viewModel.close
        self.openAppUpdate = viewModel.openAppUpdate
    }
}


// MARK: - SettingItemListContainerView

struct SettingItemListContainerView: View {
    
    @State private var state: SettingItemListViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: SettingItemListViewEventHandler
    
    var stateBinding: (SettingItemListViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: SettingItemListViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return SettingItemListView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environment(state)
            .environment(eventHandlers)
            .environment(viewAppearance)
    }
}

// MARK: - SettingItemListView

struct SettingItemListView: View {
    
    @Environment(SettingItemListViewState.self) private var state
    @Environment(SettingItemListViewEventHandler.self) private var eventHandlers
    @Environment(ViewAppearance.self) private var appearance
    
    var body: some View {
        NavigationStack {
            
            List {
                ForEach(0..<state.sections.count, id: \.self) { index in
                    sectionView(state.sections[index])
                        .listRowSeparator(.hidden)
                        .listRowBackground(appearance.colorSet.bg0.asColor)
                }
            }
            .listStyle(.plain)
            .background(appearance.colorSet.bg0.asColor)
            .toolbar {
                CloseButton()
                    .eventHandler(\.onTap, self.eventHandlers.close)
            }
            .navigationTitle("setting.title".localized())
            .if(condition: ProcessInfo.isAvailiOS26()) {
                $0.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            }
        }
        .id(appearance.navigationBarId)
    }
    
    private func sectionView(_ section: any SettingSectionModelType) -> some View {
        VStack(alignment: .leading){
            if let headerText = section.headerText {
                HStack(alignment: .bottom) {
                    Text(headerText)
                        .font(self.appearance.fontSet.size(16, weight: .semibold).asFont)
                        .foregroundStyle(self.appearance.colorSet.text0.asColor)
                    
                    if let appInfoSection = section as? AppInfoSectionModel,
                       let appVersion = appInfoSection.version {

                        Spacer()

                        Text(appVersion)
                            .font(self.appearance.fontSet.size(14, weight: .semibold).asFont)
                            .foregroundStyle(self.appearance.colorSet.text2.asColor)

                        if appInfoSection.isUpdateAvailable {
                            self.updateBadge
                        }
                    }
                }
                .padding(.top, 8)
            }
            ForEach(section.items, id: \.compareKey) { item in
                switch item {
                case let normalItem as SettingItemModel:
                    normalItemView(normalItem).asAnyView()
                case let accountItem as AccountSettingItemModel:
                    accountItemView(accountItem).asAnyView()
                case let suggestItem as SuggestAppItemModel:
                    suggestAppItemView(suggestItem).asAnyView()
                default:
                    EmptyView().asAnyView()
                }
            }
        }
    }
    
    private var itemFont: Font {
        return self.appearance.fontSet.subNormal.asFont
    }

    private var updateBadge: some View {
        HStack(spacing: 2) {
            Text("new")
                .font(self.appearance.fontSet.size(12, weight: .semibold).asFont)
            Image(systemName: "chevron.right")
                .font(self.appearance.fontSet.size(10, weight: .semibold).asFont)
        }
        .foregroundStyle(self.appearance.colorSet.primaryBtnText.asColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(self.appearance.colorSet.primaryBtnBackground.asColor)
        )
        .onTapGesture {
            self.eventHandlers.openAppUpdate()
        }
    }
    
    private func normalItemView(_ item: SettingItemModel) -> some View {
        HStack {
            Image(systemName: item.iconNamge)
                .font(self.itemFont)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
                .frame(minWidth: 25)
            
            Text(item.text)
                .font(self.itemFont)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(self.appearance.fontSet.size(8).asFont)
                .foregroundStyle(self.appearance.colorSet.text1.asColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(self.appearance.colorSet.bg1.asColor)
        )
        .onTapGesture {
            self.eventHandlers.selectItem(item)
        }
    }
    
    private func accountItemView(_ item: AccountSettingItemModel) -> some View{
        HStack {
            Image(systemName: item.iconName)
                .font(self.itemFont)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
                .frame(minWidth: 25)
            
            Text(item.title)
                .font(self.itemFont)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
            
            Spacer()
            
            if let method = item.signInMethod {
                Text(method)
                    .lineLimit(1)
                    .font(self.appearance.fontSet.subNormal.asFont)
                    .foregroundStyle(self.appearance.colorSet.text1.asColor)
            }
            
            Image(systemName: "chevron.right")
                .font(self.appearance.fontSet.size(8).asFont)
                .foregroundStyle(self.appearance.colorSet.text1.asColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(self.appearance.colorSet.bg1.asColor)
        )
        .onTapGesture {
            self.appearance.impactIfNeed()
            self.eventHandlers.selectItem(item)
        }
    }
    
    private func suggestAppItemView(_ item: SuggestAppItemModel) -> some View {
        HStack(spacing: 12) {
            RemoteImageView(item.imagePath, targetSize: .init(width: 100, height: 100))
                .resize()
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading) {
                Text(item.name)
                    .font(self.appearance.fontSet.size(14).asFont)
                    .foregroundStyle(self.appearance.colorSet.text0.asColor)
                
                if let description = item.description {
                    Text(description)
                        .font(self.appearance.fontSet.subNormal.asFont)
                        .foregroundStyle(self.appearance.colorSet.text1.asColor)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(self.appearance.fontSet.size(8).asFont)
                .foregroundStyle(self.appearance.colorSet.text1.asColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(self.appearance.colorSet.bg1.asColor)
        )
        .onTapGesture {
            self.appearance.impactIfNeed()
            self.eventHandlers.selectItem(item)
        }
    }
}


// MARK: - preview

struct SettingItemListViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultDark,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        let state = SettingItemListViewState()
        let eventHandlers = SettingItemListViewEventHandler()
        let baseSection = SettingSectionModel(
            headerText: nil,
            items: [
                SettingItemModel(.appearance),
                SettingItemModel(.editEvent),
                SettingItemModel(.holidaySetting),
                AccountSettingItemModel(nil)
            ]
        )
        let supportSection = SettingSectionModel(
            headerText: "setting.section.support::name".localized(),
            items: [
                SettingItemModel(.feedback),
                SettingItemModel(.help)
            ]
        )
        let appInfoSection = AppInfoSectionModel(
            headerText: "setting.section.app::name".localized(),
            version: "v2.9.2",
            isUpdateAvailable: true,
            items: [
                SettingItemModel(.shareApp),
                SettingItemModel(.addReview),
                SettingItemModel(.sourceCode)
            ]
        )
        let suggestSection = SettingSectionModel(
            headerText: "setting.section.suggest::name".localized(),
            items: [SuggestAppItemModel.readmind()]
        )
        state.sections = [baseSection, supportSection, appInfoSection, suggestSection]
        
        let view = SettingItemListView()
            .environment(state)
            .environment(eventHandlers)
            .environment(viewAppearance)
        return view
    }
}


//
//  WidgetAppearanceSettingView.swift
//  SettingScene
//
//  Created by sudo.park on 2/2/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Combine
import Domain
import CommonPresentation


@Observable final class WidgetAppearanceSettingViewState {
    
    @ObservationIgnored private var didBind = false
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    
    var background: WidgetAppearanceSettings.Background = .system
    var isSystemTheme = true
    var customBackground: Color?
    
    func bind(_ viewModel: any WidgetAppearanceSettingViewModel) {
        guard self.didBind == false else { return }
        self.didBind = true
        
        viewModel.background
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] background in
                self?.background = background
                switch background {
                case .system:
                    self?.isSystemTheme = true
                case .custom(let hex):
                    self?.customBackground = UIColor.from(hex: hex)?.asColor
                }
            })
            .store(in: &self.cancellables)
    }
}

final class WidgetAppearanceSettingViewEventHandler: Observable {
    
    var onAppear: () -> Void = { }
    var selectSystemTheme: () -> Void = { }
    var selectCustomColorHex: (String) -> Void = { _ in }
    var close: () -> Void = { }
    
    func bind(_ viewModel: any WidgetAppearanceSettingViewModel) {
        self.selectSystemTheme = viewModel.selectSystemTheme
        self.selectCustomColorHex = viewModel.selectCustomBackground(hex:)
        self.close = viewModel.close
    }
}


// MARK: - WidgetAppearnaceSettingContainerView

struct WidgetAppearanceSettingContainerView: View {
    
    @State private var state: WidgetAppearanceSettingViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandler: WidgetAppearanceSettingViewEventHandler
    
    var stateBinding: (WidgetAppearanceSettingViewState) -> Void = { _ in }
    
    init(
        eventHandler: WidgetAppearanceSettingViewEventHandler,
        viewAppearance: ViewAppearance
    ) {
        self.eventHandler = eventHandler
        self.viewAppearance = viewAppearance
    }
    
    var body: some View {
        WidgetAppearanceSettingView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandler.onAppear()
            }
            .environment(state)
            .environment(eventHandler)
            .environment(viewAppearance)
    }
}

// MARK: - WidgetAppearanceSettingView

struct WidgetAppearanceSettingView: View {
    
    @Environment(\.self) var environment
    @Environment(WidgetAppearanceSettingViewState.self) private var state
    @Environment(WidgetAppearanceSettingViewEventHandler.self) private var eventHandlers
    @Environment(ViewAppearance.self) private var appearance
    
    var body: some View {
        NavigationStack {
            ScrollView {
             
                VStack {
                 
                    WidgetAppearanceSampleView(background: state.background)
                        .padding(.vertical, 20)
                    
                    VStack {
                        
                        AppearanceRow(
                            "setting.appearance.widget::useSystemTheme::title".localized(),
                            subTitle: "setting.appearance.widget::useSystemTheme::background".localized(),
                            systemThemeToggleView
                        )
                        
                        if !state.isSystemTheme {
                            AppearanceRow("setting.appearance.widget::useCustomTheme::title".localized(), colorSelectView)
                        }
                        
                    }
                    .padding(.horizontal, 20)
                }
            }
            .background(
                appearance.colorSet.bg0.asColor
            )
            .navigationTitle("setting.appearance.widget::title".localized())
            .if(condition: ProcessInfo.isAvailiOS26()) {
                $0.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationBackButton {
                        self.eventHandlers.close()
                    }
                }
            }
        }
        .id(appearance.navigationBarId)
    }
    
    private var systemThemeToggleView: some View {
        @Bindable var state = self.state
        return Toggle("", isOn: $state.isSystemTheme)
            .controlSize(.small)
            .labelsHidden()
            .onChange(of: state.isSystemTheme) { old, new in
                guard old != new, new else { return }
                eventHandlers.selectSystemTheme()
            }
    }
    
    private var colorSelectView: some View {
        ColorSelectView(
            state.customBackground ?? appearance.colorSet.bg0.asColor
        )
        .eventHandler(\.colorSelected) { newColor in
            guard let hex = newColor.hex(environment) else { return }
            eventHandlers.selectCustomColorHex(hex)
        }
    }
}

// MARK: - widget sample view

struct WidgetAppearanceSampleView: View {
    
    private let background: WidgetAppearanceSettings.Background
    @Environment(ViewAppearance.self) private var appearance
    
    init(background: WidgetAppearanceSettings.Background) {
        self.background = background
    }
    
    private var colorSet: any ColorSet {
        switch background {
        case .system: return appearance.colorSet
        case .custom(let hex):
            guard let color = UIColor.from(hex: hex) else { return appearance.colorSet }
            return color.isLight ? DefaultLightColorSet() : DefaultDarkColorSet()
        }
    }
    
    private var backgroundShape: some ShapeStyle {
        let color = switch background {
        case .system: UIColor.secondarySystemBackground.asColor
        case .custom(let hex): UIColor.from(hex: hex)?.asColor ?? appearance.colorSet.bg0.asColor
        }
        
        return color
            .gradient
            .shadow(
                .drop(
                    color: appearance.colorSet.text0.withAlphaComponent(0.4).asColor, radius: 10
                )
            )
    }
    
    var body: some View {
        HStack {
            
            Spacer()
            
            HStack {
                Text("13:00")
                    .lineLimit(1)
                    .font(.system(size: 12))
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(colorSet.text1.asColor)
                
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(appearance.tagColors.defaultColor.asColor)
                    .frame(width: 3, height: 16)
                
                Text("setting.appearance.widget::sample::eventName".localized())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .font(.system(size: 13))
                    .foregroundStyle(colorSet.text0.asColor)
                
                Spacer().frame(width: 24)
                
                Image(systemName: "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(colorSet.accent.asColor)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(backgroundShape, in: RoundedRectangle(cornerRadius: 10))
            
            Spacer()
            
        }
        .padding()
    }
}

// MARK: - preview

struct WidgetAppearanceSettingViewPreview_Provider: PreviewProvider {
    
    static var previews: some View {
        
        let state = WidgetAppearanceSettingViewState()
        let handler = WidgetAppearanceSettingViewEventHandler()
        handler.selectSystemTheme = {
            state.background = .system
            state.isSystemTheme = true
        }
        handler.selectCustomColorHex = { hex in
            state.background = .custom(hex: hex)
            state.customBackground = UIColor.from(hex: hex)?.asColor
        }
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultDark,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        return WidgetAppearanceSettingView()
            .environment(state)
            .environment(handler)
            .environment(viewAppearance)
            .preferredColorScheme(.dark)
    }
}

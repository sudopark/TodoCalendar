//
//  OpenSourceLicenseView.swift
//  SettingScene
//
//  Created by sudo.park on 8/22/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//


import SwiftUI
import Combine
import Domain
import Extensions
import CommonPresentation


// MARK: - OpenSourceLicenseViewState

@Observable final class OpenSourceLicenseViewState {
    
    @ObservationIgnored private var didBind = false
    @ObservationIgnored private let cancellables = CancelBag()
    var libraries: [OpenSourceLibrary] = []
    var licenses: [OpenSourceLicenseText] = []
    
    func bind(_ viewModel: any OpenSourceLicenseViewModel) {
        
        guard self.didBind == false else { return }
        self.didBind = true
        
        viewModel.libraries
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] libraries in
                self?.libraries = libraries
            })
            .store(in: self.cancellables)
        
        viewModel.licenses
            .receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] licenses in
                self?.licenses = licenses
            })
            .store(in: self.cancellables)
    }
}

// MARK: - OpenSourceLicenseViewEventHandler

final class OpenSourceLicenseViewEventHandler: Observable {
    
    var onAppear: () -> Void = { }
    var selectLibrary: (String) -> Void = { _ in }
    var close: () -> Void = { }
}


// MARK: - OpenSourceLicenseContainerView

struct OpenSourceLicenseContainerView: View {
    
    @State private var state: OpenSourceLicenseViewState = .init()
    private let viewAppearance: ViewAppearance
    private let eventHandlers: OpenSourceLicenseViewEventHandler
    
    var stateBinding: (OpenSourceLicenseViewState) -> Void = { _ in }
    
    init(
        viewAppearance: ViewAppearance,
        eventHandlers: OpenSourceLicenseViewEventHandler
    ) {
        self.viewAppearance = viewAppearance
        self.eventHandlers = eventHandlers
    }
    
    var body: some View {
        return OpenSourceLicenseView()
            .onAppear {
                self.stateBinding(self.state)
                self.eventHandlers.onAppear()
            }
            .environment(state)
            .environment(eventHandlers)
            .environment(viewAppearance)
    }
}

// MARK: - OpenSourceLicenseView

struct OpenSourceLicenseView: View {
    
    @Environment(OpenSourceLicenseViewState.self) private var state
    @Environment(OpenSourceLicenseViewEventHandler.self) private var eventHandlers
    @Environment(ViewAppearance.self) private var appearance
    
    var body: some View {
        NavigationStack {
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Metric.Spacing.small) {
                    
                    ForEach(self.state.libraries, id: \.name) { library in
                        libraryView(library)
                    }
                    
                    ForEach(self.state.licenses, id: \.name) { license in
                        licenseTextView(license)
                    }
                }
                .padding(.horizontal, spacing: .xlarge)
                .padding(.vertical, spacing: .large)
            }
            .navigationTitle("setting.openSourceLicense::name".localized())
            .if(condition: ProcessInfo.isAvailiOS26()) {
                $0.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            }
            .background(appearance.colorSet.bg0.asColor)
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
    
    private func libraryView(_ library: OpenSourceLibrary) -> some View {
        
        HStack(spacing: Metric.Spacing.small) {
            
            VStack(alignment: .leading, spacing: Metric.Spacing.xxsmall) {
                Text(library.name)
                    .font(self.appearance.fontSet.normal.asFont)
                    .foregroundStyle(self.appearance.colorSet.text0.asColor)
                
                Text(library.copyright)
                    .font(self.appearance.fontSet.subSubNormal.asFont)
                    .foregroundStyle(self.appearance.colorSet.text1.asColor)
                
                Text(library.license)
                    .font(self.appearance.fontSet.subSubNormal.asFont)
                    .foregroundStyle(self.appearance.colorSet.text2.asColor)
            }
            
            Spacer()
            
            Image(systemName: "arrow.up.right")
                .font(self.appearance.fontSet.subNormal.asFont)
                .foregroundStyle(self.appearance.colorSet.text2.asColor)
        }
        .padding(.vertical, spacing: .regular)
        .padding(.horizontal, spacing: .large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Metric.Radius.regular)
                .fill(self.appearance.colorSet.bg1.asColor)
        )
        .onTapGesture {
            self.appearance.impactIfNeed()
            self.eventHandlers.selectLibrary(library.name)
        }
    }
    
    private func licenseTextView(_ license: OpenSourceLicenseText) -> some View {
        
        VStack(alignment: .leading, spacing: Metric.Spacing.small) {
            
            Text(license.name)
                .font(self.appearance.fontSet.normal.asFont)
                .foregroundStyle(self.appearance.colorSet.text0.asColor)
            
            Text(license.text)
                .font(self.appearance.fontSet.subSubNormal.asFont)
                .foregroundStyle(self.appearance.colorSet.text1.asColor)
                .textSelection(.enabled)
        }
        .padding(.vertical, spacing: .large)
        .padding(.horizontal, spacing: .large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Metric.Radius.regular)
                .fill(self.appearance.colorSet.bg1.asColor)
        )
    }
}


// MARK: - preview

struct OpenSourceLicenseViewPreviewProvider: PreviewProvider {

    static var previews: some View {
        let calendar = CalendarAppearanceSettings(
            colorSetKey: .defaultLight,
            fontSetKey: .systemDefault
        )
        let tag = DefaultEventTagColorSetting(holiday: "#ff0000", default: "#ff00ff")
        let setting = AppearanceSettings(calendar: calendar, defaultTagColor: tag)
        let viewAppearance = ViewAppearance(setting: setting, isSystemDarkTheme: false)
        let state = OpenSourceLicenseViewState()
        let eventHandlers = OpenSourceLicenseViewEventHandler()
        
        state.libraries = (0..<5).map {
            return OpenSourceLibrary(
                name: "Library \($0)",
                copyright: "Copyright (c) 2026 some author \($0)",
                license: "MIT License",
                sourceURL: "https://github.com/some/library\($0)"
            )
        }
        state.licenses = [
            .init(name: "MIT License", text: "Permission is hereby granted, free of charge, to any person obtaining a copy of this software...")
        ]
        
        let view = OpenSourceLicenseView()
            .environment(state)
            .environment(eventHandlers)
            .environment(viewAppearance)
        return view
    }
}

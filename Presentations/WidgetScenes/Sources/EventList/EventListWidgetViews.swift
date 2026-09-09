//
//  EventListWidgetViews.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Prelude
import Optics
import Domain
import Extensions
import CommonPresentation
import CalendarPresentation


// MARK: - EventListView

public struct EventListView: View {
    
    @Environment(\.colorScheme) var colorScheme
    var colorSet: any ColorSet {
        return model.widgetSetting.background.colorSet(colorScheme == .light)
    }
    
    private let model: EventListWidgetViewModel
    private let todoToggle: (TodoEventCellViewModel) -> AnyView

    public init(
        model: EventListWidgetViewModel,
        todoToggle: @escaping (TodoEventCellViewModel) -> AnyView
    ) {
        self.model = model
        self.todoToggle = todoToggle
    }
    
    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(0..<model.pages.count, id: \.self) { pageIndex in
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(0..<model.pages[pageIndex].sections.count, id: \.self) { index in
                        eventListPerDayView(model.pages[pageIndex].sections[index])
                    }
                    
                    if model.pages[pageIndex].needBottomSpace {
                        Spacer()
                    }
                }
            }
        }
        .invalidatableContent()
    }
    
    private func eventListPerDayView(
        _ model: EventListWidgetViewModel.SectionModel
    ) -> some View {
        
        VStack(alignment: .leading, spacing: 2.5) {
            if let title = model.sectionTitle {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(
                        model.shouldAccentTitle
                        ? colorSet.text0.asColor : colorSet.text2.asColor
                    )
            }
            
            if model.isCurrentDay && model.events.isEmpty {
                Text("widget.events.noEvents::message".localized())
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .font(.system(size: 13))
                    .foregroundStyle(colorSet.text1.asColor)
                    
            } else {
                ForEach(0..<model.events.count, id: \.self) { index in
                    eventView(model.events[index])
                        .frame(height: 25)
                }
            }
        }
    }
    
    private func eventView(_ model: any EventCellViewModel) -> some View {
        HStack(spacing: 2) {
            
            timeTextView(model.periodText)
                .frame(width: 30)
            
            tagLineView(model)
            
            nameAndActionView(model)
        }
    }
    
    private func timeTextView(_ periodText: EventPeriodText?) -> some View {
        
        func singleText(_ text: EventTimeText) -> some View {
            return HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(text.singleLineAttrText())
                    .lineLimit(1)
                    .font(.system(size: 12))
                    .minimumScaleFactor(0.4)
                    .foregroundColor(colorSet.text1.asColor)
            }
        }
        
        func doubleText(_ top: EventTimeText, _ bottom: EventTimeText) -> some View {
            return VStack(alignment: .center, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(top.singleLineAttrText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .font(.system(size: 12))
                        .foregroundColor(colorSet.text1.asColor)
                }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                 
                    Text(bottom.singleLineAttrText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .font(.system(size: 12))
                        .foregroundColor(colorSet.text1.asColor)
                }
            }
        }
        
        switch periodText {
        case .singleText(let text): return singleText(text).asAnyView()
        case .doubleText(let topText, let bottomText): return doubleText(topText, bottomText).asAnyView()
        default: return EmptyView().asAnyView()
        }
    }
    
    private func tagLineView(_ cvm: any EventCellViewModel) -> some View {
        let color = self.model.colorPalette.color(for: cvm.colorSource)
        
        return RoundedRectangle(cornerRadius: 1.5)
            .fill(color.asColor)
            .frame(width: 3)
            .padding(.vertical, 2)
    }
    
    private func nameAndActionView(_ model: any EventCellViewModel) -> some View {
        return HStack {
            Text(model.name)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .font(.system(size: 13))
                .foregroundStyle(colorSet.text0.asColor)
                .asLinkIfPossible(model.widgetURL)
                
            Spacer()
            
            if let todo = model as? TodoEventCellViewModel {
                todoToggle(todo)
            }
        }
    }
}


// MARK: - TodoToggleStyle

public struct TodoToggleStyle: ToggleStyle {
    
    private let colorSet: ColorSet
    private let size: CGFloat
    private let customColor: Color?

    public init(colorSet: ColorSet, size: CGFloat = 18, customColor: Color? = nil) {
        self.colorSet = colorSet
        self.size = size
        self.customColor = customColor
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        Image(systemName: configuration.isOn ? "circle.inset.filled" : "circle")
            .font(.system(size: self.size))
            .foregroundStyle(customColor ?? colorSet.accent.asColor)
    }
}

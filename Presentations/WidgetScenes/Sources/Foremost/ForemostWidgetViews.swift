//
//  ForemostWidgetViews.swift
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


// MARK: - ForemostEventView

public struct InlineSizeForemostEventView: View {
    
    private let model: ForemostEventWidgetViewModel
    public init(model: ForemostEventWidgetViewModel) {
        self.model = model
    }
    
    public var body: some View {
        if let event = self.model.eventModel {
            Text(event.name)
        } else {
            Text("widget.events.foremost::allFinished::message".localized())
        }
    }
}

public struct SystemSizeForemostEventView: View {
    
    @Environment(\.colorScheme) var colorScheme
    var colorSet: any ColorSet {
        return model.widgetSetting.background.colorSet(colorScheme == .light)
    }
    
    private struct Metric {
        let emptyMessageFontSize: CGFloat
        let eventNameFontSize: CGFloat
        let eventNameNumberOfLines: Int
        let tagLineWidth: CGFloat
        let timeInfoFontSize: CGFloat
        init(_ isSmallSize: Bool) {
            self.emptyMessageFontSize = isSmallSize ? 16 : 20
            self.eventNameFontSize = isSmallSize ? 18 : 40
            self.eventNameNumberOfLines = isSmallSize ? 2 : 1
            self.tagLineWidth = isSmallSize ? 4 : 6
            self.timeInfoFontSize = isSmallSize ? 12 : 14
        }
    }
    
    private let model: ForemostEventWidgetViewModel
    private let isSmallSize: Bool
    private let metric: Metric
    private let todoToggle: (TodoEventCellViewModel) -> AnyView

    public init(
        model: ForemostEventWidgetViewModel,
        isSmallSize: Bool,
        todoToggle: @escaping (TodoEventCellViewModel) -> AnyView
    ) {
        self.model = model
        self.isSmallSize = isSmallSize
        self.metric = .init(isSmallSize)
        self.todoToggle = todoToggle
    }
    
    public var body: some View {
        if let event = model.eventModel {
            eventView(event)
                .invalidatableContent()
        } else {
            emptyForemostEventView()
        }
    }
    
    private func eventTypeView() -> some View {
        Text("calendar::foremostevent:title".localized())
            .font(.system(size: 12))
            .foregroundStyle(colorSet.text2.asColor)
    }
    
    private func emptyForemostEventView() -> some View {
        VStack(alignment: .leading) {
            
            eventTypeView()
            
            Spacer(minLength: 12)
            
            HStack(spacing: 0) {
                Spacer()
                VStack(spacing: 8) {
                    
                    Text(String.randomEmoji)
                 
                    Text("widget.events.foremost::allFinished::message".localized())
                        .font(.system(size: metric.emptyMessageFontSize, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(colorSet.text1.asColor)
                }
                Spacer()
            }
            
            Spacer(minLength: 8)
        }
    }
    
    private func eventView(_ event: any EventCellViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            
            eventTypeView()
            
            VStack(alignment: .leading, spacing: 8) {
                eventTimeView(event.periodText, isTodo: event is TodoEventCellViewModel)
                
                nameAndActionView(event)
                
                if let todo = event as? TodoEventCellViewModel {
                    todoToggle(todo)
                } else {
                    Spacer().frame(height: 4)
                }
            }
        }
    }
    

    private func nameAndActionView(_ event: any EventCellViewModel) -> some View {
        HStack {
            
            Spacer().frame(width: metric.tagLineWidth+8)
            
            Text(event.name)
                .lineLimit(metric.eventNameNumberOfLines)
                .minimumScaleFactor(0.7)
                .font(.system(size: metric.eventNameFontSize, weight: .semibold))
                .foregroundStyle(colorSet.text0.asColor)
                .asLinkIfPossible(event.widgetURL)
            
            Spacer()
        }
        .background(
            HStack(alignment: .center) {
                tagLineView()
                Spacer()
            }
        )
    }
    
    private func eventTimeView(_ periodText: EventPeriodText?, isTodo: Bool) -> some View {
        
        func singleText(_ text: EventTimeText) -> some View {
            return HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(text.singleLineAttrText(fontSize: metric.timeInfoFontSize))
                    .lineLimit(1)
                    .font(.system(size: metric.timeInfoFontSize))
                    .minimumScaleFactor(0.4)
                    .foregroundColor(colorSet.text1.asColor)
            }
        }
        
        func doubleText(_ top: EventTimeText, _ bottom: EventTimeText) -> some View {
            let seperator = isTodo ? "-" : "~"
            let topText = top.singleLineAttrText(fontSize: metric.timeInfoFontSize)
            let bottomText = bottom.singleLineAttrText(fontSize: metric.timeInfoFontSize)
            return Text("\(topText)\(seperator)\(bottomText)")
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .font(.system(size: metric.timeInfoFontSize))
                .foregroundColor(colorSet.text1.asColor)
        }
        
        switch periodText {
        case .singleText(let text): return singleText(text).asAnyView()
        case .doubleText(let topText, let bottomText): return doubleText(topText, bottomText).asAnyView()
        default: return EmptyView().asAnyView()
        }
    }
    
    private func tagLineView() -> some View {
        let defColors = EventTagColorSet(model.defaultTagColorSetting)
        let tagId = model.eventModel?.colorSource as? EventTagId
        let color = switch tagId {
        case .holiday: defColors.holiday
        case .default: defColors.defaultColor
        case .custom: model.tag?.colorHex.flatMap { UIColor.from(hex: $0) } ?? defColors.defaultColor
        default: defColors.defaultColor
        }
        
        let width = metric.tagLineWidth
        
        return RoundedRectangle(cornerRadius: width / 2)
            .fill(color.asColor)
            .frame(width: width)
            .padding(.vertical, 6)
    }
}


// MARK: - ForemostTodoToggleStyle

public struct ForemostTodoToggleStyle: ToggleStyle {
    private let colorSet: ColorSet

    public init(colorSet: ColorSet) {
        self.colorSet = colorSet
    }
    public func makeBody(configuration: Configuration) -> some View {
        HStack {
            Spacer()
            Text(configuration.isOn ? "common.cancel".localized() : "common.done".localized())
                .font(.callout)
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(colorSet.accent.asColor)
                .opacity(configuration.isOn ? 0.8 : 1.0)
        )
    }
}

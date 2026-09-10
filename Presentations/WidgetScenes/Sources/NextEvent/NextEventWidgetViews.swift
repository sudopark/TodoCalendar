//
//  NextEventWidgetViews.swift
//  WidgetScenes
//
//  Created by sudo.park on 9/9/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import Domain
import Extensions
import CommonPresentation
import CalendarPresentation


// MARK: - NextEventWidgetView

public struct NextEventWidgetInlineView: View {
    
    private let model: NextEventWidgetViewModel
    public init(model: NextEventWidgetViewModel) {
        self.model = model
    }
    
    public var body: some View {
        VStack {
            Text(
                model.timeText.map { "\($0.singleLineText) - \(model.eventTitle)" } ?? model.eventTitle
            )
        }
    }
}

public struct NextEventRectangleWidgetView: View {
    
    private let model: NextEventWidgetViewModel
    public init(model: NextEventWidgetViewModel) {
        self.model = model
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 2) {
                Image("small_icon", bundle: .module)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 24, height: 24)
                
                Text("widget.next.rect_widget::title".localized())
                    .font(.footnote)
            }
            .foregroundStyle(.primary)
            .opacity(0.8)
            
            VStack(alignment: .leading) {
                VStack(alignment: .leading) {
                    if let time = model.timeText {
                        Text(time.singleLineAttrText())
                    }
                    if let location = model.locationText {
                        Text(location)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                
                HStack {
                    Text(model.eventTitle)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                }
            }
            .padding(.leading, 4)
        }
    }
}


// MARK: - NextRemainEventView

public struct NextRemainEventVListiew: View {
    
    private let model: NextEventListWidgetViewModel
    public init(model: NextEventListWidgetViewModel) {
        self.model = model
    }
    
    public var body: some View {
        if model.models.isEmpty {
            NextEventRectangleWidgetView(model: .empty)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(0..<model.models.count, id: \.self) {
                    rowView(model.models[$0])
                }
            }
        }
    }
    
    private func rowView(_ model: NextEventWidgetViewModel) -> some View {
        HStack {
            if let time = model.timeText {
                Text(time.singleLineAttrText())
                    .font(.callout)
                    .minimumScaleFactor(0.4)
            }
            Text(model.eventTitle)
                .font(.body)
                .minimumScaleFactor(0.4)
                .asLinkIfPossible(model.eventLink)
            Spacer()
        }
    }
}

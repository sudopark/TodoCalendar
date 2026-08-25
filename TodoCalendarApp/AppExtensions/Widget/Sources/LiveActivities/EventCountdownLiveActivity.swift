//
//  EventCountdownLiveActivity.swift
//  TodoCalendarAppWidget
//
//  Created by sudo.park on 8/17/26.
//  Copyright © 2026 com.sudo.park. All rights reserved.
//

import SwiftUI
import WidgetKit
import ActivityKit


// MARK: - EventCountdownLiveActivity

struct EventCountdownLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EventCountdownActivityAttributes.self) { context in
            EventCountdownLockScreenView(
                model: EventCountdownActivityViewModel(context.attributes, context.state),
                isStale: context.isStale
            )
        } dynamicIsland: { context in
            let model = EventCountdownActivityViewModel(context.attributes, context.state)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    EventCountdownSymbolBadge(diameter: 26)
                        // 아일랜드 좌측 라운딩에 배지가 물려 잘린다 — 안쪽으로 들여 피한다.
                        .padding(.leading, 6)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    EventCountdownTimerText(
                        model: model, isStale: context.isStale,
                        liveFont: .system(size: 22, weight: .semibold),
                        staleFont: .system(size: 14)
                    )
                    // 아일랜드 우측 라운딩에 문구가 물려 잘린다 — 안쪽으로 들여 피한다.
                    .padding(.trailing, 6)
                }

                // leading·trailing은 카메라 하우징 양옆이라 폭이 좁다 — 말줄임이 나는 텍스트는 전체 폭인 bottom에 둔다.
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        EventCountdownTitleBlock(model: model)

                        EventCountdownProgressBar(model: model)

                        EventCountdownActionButtonRow(model: model)
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
            } compactLeading: {
                EventCountdownRingBadge(model: model, diameter: 26)
            } compactTrailing: {
                Text(model.eventName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
            } minimal: {
                // 최소 표시 영역이 배지보다 작아 링이 잘린다 — 지름을 줄여 영역 안쪽에 들인다.
                EventCountdownRingBadge(model: model, diameter: 27)
            }
            .widgetURL(model.deepLink)
        }
    }
}


// MARK: - Previews

private let previewDefaultTagState = EventCountdownActivityAttributes.State(
    eventName: "팀 회의 준비", eventTimeText: "오후 3:00",
    tagColorHex: "#2FB457", eventDate: .now.addingTimeInterval(5047), startDate: .now.addingTimeInterval(-2000),
    placeName: "강남 사옥 3층 회의실"
)
/// 장소 없이 메모만 있어 부제가 메모로 폴백되는 케이스.
private let previewBrightTagState = EventCountdownActivityAttributes.State(
    eventName: "장보기", eventTimeText: "오후 5:00",
    tagColorHex: "#F2D64B", eventDate: .now.addingTimeInterval(3600), startDate: .now.addingTimeInterval(-1200),
    memo: "우유, 계란, 식빵, 커피 원두 그리고 세제까지"
)
/// 장소·메모가 둘 다 없어 부제 줄이 빠지는 케이스.
private let previewNoSubtitleState = EventCountdownActivityAttributes.State(
    eventName: "광복절", eventTimeText: "오전 12:00",
    tagColorHex: "#003D82", eventDate: .now.addingTimeInterval(30000), startDate: .now.addingTimeInterval(-600)
)
/// eventDate만 지나고 isStale은 아직 false인 크래시 회귀 케이스.
private let previewPastEventState = EventCountdownActivityAttributes.State(
    eventName: "지난 회의", eventTimeText: "오후 2:00",
    tagColorHex: "#2FB457", eventDate: .now.addingTimeInterval(-600), startDate: .now.addingTimeInterval(-4000)
)

/// 진행 바가 실제로 차오르는 게 몇 초 안에 보이는 짧은 케이스.
private let previewShortRemainState = EventCountdownActivityAttributes.State(
    eventName: "타이머 확인", eventTimeText: "곧",
    tagColorHex: "#2FB457", eventDate: .now.addingTimeInterval(30), startDate: .now.addingTimeInterval(-30),
    placeName: "진행 바 테스트"
)

#Preview("잠금화면", as: .content, using: EventCountdownActivityAttributes(target: .todo(id: "preview"))) {
    EventCountdownLiveActivity()
} contentStates: {
    previewDefaultTagState
    previewBrightTagState
    previewNoSubtitleState
    previewShortRemainState
    previewPastEventState
}

#Preview("확장", as: .dynamicIsland(.expanded), using: EventCountdownActivityAttributes(target: .todo(id: "preview"))) {
    EventCountdownLiveActivity()
} contentStates: {
    previewDefaultTagState
    previewBrightTagState
    previewNoSubtitleState
    previewShortRemainState
    previewPastEventState
}

#Preview("컴팩트", as: .dynamicIsland(.compact), using: EventCountdownActivityAttributes(target: .todo(id: "preview"))) {
    EventCountdownLiveActivity()
} contentStates: {
    previewDefaultTagState
    previewBrightTagState
    previewNoSubtitleState
    previewShortRemainState
    previewPastEventState
}

#Preview("최소", as: .dynamicIsland(.minimal), using: EventCountdownActivityAttributes(target: .todo(id: "preview"))) {
    EventCountdownLiveActivity()
} contentStates: {
    previewDefaultTagState
    previewBrightTagState
}

#Preview("확장 - Schedule(완료 버튼 없음)", as: .dynamicIsland(.expanded), using: EventCountdownActivityAttributes(target: .schedule(id: "preview", turnKey: nil))) {
    EventCountdownLiveActivity()
} contentStates: {
    previewDefaultTagState
}

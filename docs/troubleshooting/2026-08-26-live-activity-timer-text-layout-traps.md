---
issue: "#994"
subdomain: Event
symptoms: [라이브액티비티 잠금화면 크래시, WidgetRenderer_Activities, EXC_BREAKPOINT, LayoutSubview.place, GeometryReaderLayout.placeSubviews, 카운트다운 1:15:--, Text(timerInterval:), fixedSize]
resolution: fixed
---

# `Text(timerInterval:)` 을 좁은 행에 넣으면 크래시하거나 자릿수가 `--` 로 빠진다

- **증상**: 잠금화면 라이브 액티비티를 한 행 구성(로고·이벤트명·카운트다운)으로 바꾸자 두 증상이 순서대로 났다.

  1. `WidgetRenderer_Activities` 가 렌더 시점에 크래시. 앱 코드 프레임이 하나도 안 찍히는 순수 레이아웃 트랩이다.

     ```
     Exception Type: EXC_BREAKPOINT (SIGTRAP)
     0 libswiftCore.dylib  _assertionFailure(_:_:file:line:flags:)
     1 SwiftUICore         LayoutSubview.place(at:anchor:dimensions:)
     2 SwiftUICore         specialized GeometryReaderLayout.placeSubviews(in:proposal:subviews:cache:)
     ```

  2. 크래시를 걷어내자 카운트다운이 `1:15:--` 로 렌더. 초 자리가 말줄임(`…`)이 아니라 `--` 로 나온다.

- **근본 원인**: `Text(timerInterval:)` 은 자릿수가 매초 바뀌는 걸 시스템이 대신 그리는 특수 텍스트라, 일반 `Text` 와 두 가지가 다르다.

  1. **미지정 제안을 못 받는다.** `.fixedSize()` 는 자식에게 "크기 미지정" 을 제안하는데, 이 텍스트의 내부 geometry 기반 레이아웃은 그 제안에서 유한 폭을 못 정한다. non-finite 치수가 `LayoutSubview.place` 로 들어가 어서션이 터진다.
  2. **폭이 모자라면 말줄임이 아니라 `--` 로 대체한다.** 자릿수를 표시 시점에 시스템이 채우므로, 확보된 폭에 안 들어가는 자리는 잘리는 대신 플레이스홀더로 남는다. 그래서 "말줄임이 안 나니 폭은 충분하다" 는 판단이 성립하지 않는다.

  `.frame(maxWidth: .infinity)` 를 얻은 이벤트명과 한 `HStack` 에서 남은 폭을 나눠 갖는 구성이라, 타이머 몫이 `23:59:59` 를 그릴 폭에 못 미쳤다.

- **해결**: `EventCountdownLockScreenView` 1행에서
  - `.fixedSize()` 를 쓰지 않는다 — 폭 보장은 `.frame(minWidth:)` 로 한다.
  - 카운트다운에 `.frame(minWidth: 104, alignment: .trailing)` 로 최대 표기(`23:59:59`, 24pt monospaced digit) 폭을 바닥으로 깐다.
  - 이벤트명에만 `.frame(maxWidth: .infinity, alignment: .leading)` 을 줘 남는 폭을 흡수시킨다.

- **기각 방향**: 카운트다운에 `.layoutPriority(1)` — 이 텍스트가 제안된 폭을 크게 먹어서 이벤트명이 말줄임 기호만 남는 폭으로 눌린다. 우선순위는 둘 중 하나를 통째로 굶기는 레버라 이 배분엔 안 맞는다.
- **기각 방향**: 이벤트명과 카운트다운 사이 `Spacer` — Spacer 가 이벤트명과 남은 폭을 또 나눠 가져 이름 몫이 한 번 더 깎인다.

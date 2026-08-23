---
description: TodoCalendarApp composition root(Factories·Root) 조립 시 지킬 규칙
paths:
  - "TodoCalendarApp/Sources/Factories/**"
  - "TodoCalendarApp/Sources/Root/**"
---

# Composition Root 규칙

## 1. ApplicationBase 멤버 추가 금지

`ApplicationBase`는 프로세스 전역 인프라 싱글톤(DB·리모트 세션·store·SDK 서비스)만 보유한다. 저장소 구현체·usecase·라우터 같은 조립 산물을 멤버로 추가하지 말 것 — usecase factory에서 제공하거나 사용처 팩토리 메서드에서 그때그때 생성한다 (선례: `CalendarSettingRepositoryImple`을 `makeCalendarSettingUsecase()`가 직접 생성).

- **멤버 추가는 종류 불문 전부 사전 유저 확인 대상이다** — "인프라 싱글톤이니 괜찮다"는 자기 판단으로 게이트를 건너뛰지 않는다. 확인을 요청한 시점이 이 조항의 이행이다 (PR #986 리뷰).
- 기존 `googleCalendarRepositoryPool`·`appleCalendarPermissionChecker`·`appleCalendarRepository`는 이 조항 이전의 레거시다 — 신규 추가의 선례로 삼지 말 것.

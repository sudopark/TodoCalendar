# [#563] Apple Calendar 연동 — 진행 현황

> 플랜: `/Users/sudo.park/.claude/plans/jaunty-orbiting-nebula.md`
> 베이스 브랜치: `features/563-base`
> 워크트리: `.worktrees/feature-563-apple-calendar`

---

## Phase 진행 상태

| Phase | 브랜치 | 상태 |
|---|---|---|
| Phase 1: Domain 모델 & 프로토콜 | `feature/563-apple-calendar` | ✅ 완료 (PR #564 머지) |
| Phase 2: Integration Usecase 확장 | `features/563-phase2-integration` | ✅ 완료 (PR #566) |
| Phase 3: Repository — EventKit + DB 캐시 | `features/563-phase3-repository` | ✅ 완료 |
| Phase 4: AppEnvironment & DB 설정 | `features/563-phase4-app-env` | ✅ 완료 |
| Phase 5: Presentation — 이벤트 표시 & 색상 | `features/563-phase5-presentation` | ✅ 완료 (PR #569) |
| Phase 6: Settings UI | `features/563-phase6-...` | ⬜ 예정 |
| Phase 7: Factory / Assembly | `features/563-phase7-...` | ⬜ 예정 |
| Phase 8: 이벤트 상세 (후속) | — | ⬜ 예정 |

---

## Phase 1 완료 내역

- [x] `AppleCalendarService` 추가 (`ExternalService.swift`)
- [x] `AppleCalendarCredential` 추가 (`OAuth2.swift`)
- [x] `AppleCalendar.Tag` / `AppleCalendar.Event` 모델 (`AppleCalendarEvent.swift`)
- [x] `AppleCalendarPermissionChecker` 프로토콜
- [x] `AppleCalendarRepository` 프로토콜 (캐시→refresh Publisher 방식)
- [x] `SharedDataStore` 키 추가: `appleCalendarTags`, `appleCalendarEvents`
- [x] `AppleCalendarUsecase` 프로토콜 + `AppleCalendarUsecaseImple`
- [x] `AppleCalendarViewAppearanceStore` 프로토콜
- [x] `StubAppleCalendarRepository` / `StubAppleCalendarUsecase` (TestDoubles)
- [x] `AppleCalendarUsecaseImpleTests`

---

## Phase 2 완료 내역

- [x] **2-1.** `AppleCalendarPermissionUsecaseImple` 신규 (`OAuth2ServiceUsecase` 준수)
- [x] **2-2.** `ExternalCalendarOAuthUsecaseProviderImple` 수정 — Apple case + `checkPermission(for:)` 추가
- [x] **2-3.** `ExternalCalendarIntegrateRepositoryImple.save()` — `AppleCalendarCredential` case 추가
- [x] **2-4.** `prepareIntegratedAccounts()` — 권한 해제 Apple Calendar 계정 자동 disconnected
- [x] **2-5.** 테스트 추가 (`AppleCalendarPermissionUsecaseImpleTests`, 기존 테스트 케이스 확장)
- [x] **bugfix** `AppleCalendarUsecaseImple.clearCache()` — `resetExternalCalendarOffTagId` 사용으로 off 태그 정리 버그 수정

---

## Phase 3 완료 내역

- [x] **3-1.** `AppleCalendarRepositoryImple` — `EKEventStoreWrapper` 기반, 캐시→refresh Publisher 방식
- [x] **3-2.** `AppleCalendar+EventKit.swift` — `EKCalendar`→Tag, `EKEvent`→Event 매핑, CGColor→hex
- [x] **3-3.** DB 캐시 레이어 — `AppleCalendarTables.swift`, `AppleCalendarLocalStorage.swift`
- [x] **3-4.** `AppleCalendarLocalAggregatedRepositoryImple` (위젯용 read-only, 권한 해제 시 빈 배열)
- [x] **3-5.** 테스트: Mapping, LocalStorage, LocalAggregated, RepositoryImple

---

## Phase 4 완료 내역

- [x] **4-1.** `AppEnvironment.swift` — `appleCalendarService`, `appleCalendarDBVersion`, DB path 추가
- [x] **4-2.** `ApplicationBase.swift` — `appleCalendarPermissionChecker`, `appleCalendarRepository` lazy 프로퍼티 추가
- [x] **4-3.** `Info.plist` — `NSCalendarsFullAccessUsageDescription` 추가

---

## Phase 5 완료 내역 — Presentation

- [x] **5-1.** `AppleCalendarEventColorSource` 추가
- [x] **5-2.** `EventTagColorView` 업데이트
- [x] **5-3.** `ViewAppearance` 업데이트 — `appleCalendarTagMap`, `AppleCalendarViewAppearanceStore` 구현
- [x] **5-4.** `AppleCalendarEvent: CalendarEvent` 추가
- [x] **5-5.** `CalendarEventListhUsecase` 업데이트 — Apple Calendar 이벤트 merge
- [x] **5-6.** `ExternalCalendarUsecaseFactory.makeAppleCalendarUsecase()` + 팩토리 구현 (NonLogin/Login)
- [x] **5-7.** `ApplicationViewAppearanceStoreImple`: `AppleCalendarViewAppearanceStore` 준수

---

## Phase 6 할 일 — Settings UI

- [ ] **6-1.** `ExternalCalendarServiceModel` 업데이트 (AppleCalendar 분기)
- [ ] **6-2.** `connectExternalCalendar` — 기존 통일 흐름 확인
- [ ] **6-3.** `EventTagListViewUsecase` — Apple Calendar 태그 섹션 추가

---

## Phase 7 할 일 — Factory / Assembly

- [ ] **7-1.** `Scenes/Factories.swift` — `makeAppleCalendarUsecase()` 추가
- [ ] **7-2.** `Factories+Usecase.swift` — `makeAppleCalendarUsecase()` 구현
- [ ] **7-3.** 위젯 팩토리 업데이트 (WidgetUsecaseFactory, CalendarEventFetchUsecase, AppExtensionBase)

---

## TBD — 앱 레벨 처리 항목

- [ ] **앱 시작 시 Apple Calendar 권한 확인 및 연동 해제 처리** (앱 레벨에서 구현)
  - `prepareIntegratedAccounts()`에서 제거됨 — 런타임 권한 해제는 앱 레벨 책임
  - `AppleCalendarPermissionChecker.checkAccessStatus()` 사용하여 앱 foreground 복귀 시 또는 시작 시 체크

---

## Phase 8 할 일 — 이벤트 상세 (후속)

- [ ] `AppleCalendarEventDetailView` + ViewModel
- [ ] 이벤트 클릭 라우팅

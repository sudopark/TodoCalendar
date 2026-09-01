# 맞춤형 제품 페이지 (Custom Product Page)

App Store 맞춤형 제품 페이지의 원고·설정·산출물이 사는 자리다. 절차 정본은 `custom-product-page` 스킬,
합성 규칙 정본은 유저 문서 `CPP지침-맞춤형-제품-페이지-3종-명세.md` 다.

**이 README 말고는 전부 gitignore 대상이다** (`.gitignore` 의 `fastlane/custom_product_pages/*`).
마케팅 원고와 산출 이미지를 public 레포에 두지 않는다.

## 구조

```
custom_product_pages/
  README.md                                        # 이 파일 (유일한 커밋 대상)
  captions.json                                    # 장면 → 언어별 캡션. 스냅샷 테스트의 입력
  pages.json                                       # 페이지 → ASC id + 장면 배치 순서
  <page_id>/<ASC로케일>/promotional_text.txt        # 프로모션 문구 (170자 이내)
  <page_id>/images/<ASC로케일>/<NN>_<장면>.png       # 업로드 산출물 (1320×2868, 알파 없음)
```

로케일 코드는 lproj 가 아니라 **ASC 코드**다 — 6개가 다르고 매핑표는 `fastlane/metadata/README.md`.

## captions.json

최상위 키가 장면 id, 그 아래가 **lproj 언어 코드**다 (`-testLanguage` 가 lproj 코드를 넘긴다).

```json
{
  "C1": { "ko": "잠금화면에서 오늘 할일을 바로", "en": "Today's to-dos, right on the Lock Screen" },
  "C2": { "ko": "…", "en": "…" }
}
```

`AppStoreCaptionSnapshots.test_customProductPageCaptions` 가 이 파일을 읽어 캡션 이미지를 그린다.
파일이 없으면 그 케이스는 `XCTSkip` 으로 건너뛴다 — 신선한 클론·CI 에는 이 파일이 없다.

## pages.json

`scenes` 는 정확히 6개, 순서가 곧 스토어 라인업 순서다. `ascPageId` 는 `create` 가 채운다.

```json
{
  "cpp-widget": { "ascPageId": "", "scenes": ["C1", "C2", "C3", "C4", "C5", "C6"] }
}
```

장면 id → 실제 화면의 대응은 코드에 있다 (`scripts/cpp_scenes.py` 의 `SCENES`).

## 돌리는 순서

```sh
scripts/capture-appstore-screenshots.sh ko          # 먼저 한 언어로 확인
python3 scripts/compose-cpp-screenshots.py --locale ko
# 유저 확인 후
scripts/capture-appstore-screenshots.sh --all
python3 scripts/compose-cpp-screenshots.py --all-locales

export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
bundle exec ruby scripts/asc-custom-product-page.rb create
bundle exec ruby scripts/asc-custom-product-page.rb push-text   --all-pages --all-locales
bundle exec ruby scripts/asc-custom-product-page.rb push-images --all-pages --all-locales
```

**텍스트가 먼저다** — 이미지는 로케일에 매달리므로 부모가 없으면 못 올린다.
심사 제출은 콘솔에서 유저가 한다.

# 크리에이티브 에셋 (Creative Assets)

App Store 제품 페이지 헤더와 검색 결과에 쓰는 가로 이미지의 원고·설정·산출물이 사는 자리다.
절차 정본은 `creative-assets` 스킬이다.

**이 README 말고는 전부 gitignore 대상이다** (`.gitignore` 의 `fastlane/creative_assets/*`).
마케팅 원고와 산출 이미지를 public 레포에 두지 않는다.

## 구조

```
creative_assets/
  README.md                              # 이 파일 (유일한 커밋 대상)
  captions.json                          # 배치 → 언어별 캡션. 스냅샷 테스트의 입력
  assets.json                            # 배치 → 캡션 키 + 장면 순서
  images/<ASC로케일>/header.png           # 제품 페이지 헤더 — 3840×1646 (21:9), PNG
  images/<ASC로케일>/search.png           # 검색 결과 — 3840×2560 (3:2), PNG
```

두 이미지 모두 알파 채널이 없어야 한다. 로케일 코드는 lproj 가 아니라 **ASC 코드**다 —
6개가 다르고 매핑표는 `fastlane/metadata/README.md` 에 있다.

## captions.json

최상위 키가 캡션 키(`header`·`search`), 그 아래가 **lproj 언어 코드**다 (`-testLanguage` 가 lproj 코드를 넘긴다).

```json
{
  "header": { "ko": "…", "en": "…" },
  "search": { "ko": "…", "en": "…" }
}
```

`AppStoreCaptionSnapshots.test_creativeAssetCaptions` 가 이 파일을 읽어 가로 캡션 이미지를 그린다.
파일이 없으면 그 케이스는 `XCTSkip` 으로 건너뛴다 — 신선한 클론·CI 에는 이 파일이 없다.
촬영 스크립트는 기본 스토어·CPP·크리에이티브 캡션을 한 실행에 뜨므로, 촬영하려면 이 파일과
`fastlane/custom_product_pages/captions.json` 둘 다 그 언어 원고를 담고 있어야 한다.

## assets.json

`scenes` 는 기기 세 대에 들어갈 장면이고, 순서가 곧 배치 순서다.

```json
{
  "header": { "captionKey": "header", "scenes": ["C2", "C3", "C4"] },
  "search": { "captionKey": "search", "scenes": ["C2", "C3", "C4"] }
}
```

장면 id → 실제 화면의 대응은 코드에 있다 (`scripts/cpp_scenes.py` 의 `SCENES`).

## 돌리는 순서

```sh
scripts/capture-appstore-screenshots.sh ko          # 먼저 한 언어로 확인
python3 scripts/compose-creative-assets.py --locale ko
# 유저 확인 후
scripts/capture-appstore-screenshots.sh --all
python3 scripts/compose-creative-assets.py --all-locales

export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
bundle exec ruby scripts/asc-creative-assets.rb push --all-locales --dry-run
bundle exec ruby scripts/asc-creative-assets.rb push --all-locales
```

올리는 대상은 심사 제출 전(PREPARE_FOR_SUBMISSION) 버전의 로케일이다. 심사 제출은 콘솔에서 유저가 한다.

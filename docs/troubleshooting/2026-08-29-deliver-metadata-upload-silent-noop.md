---
issue: "#996"
subdomain: Infra
symptoms: [fastlane deliver 업로드 무반응, ASC 로케일 활성화 안 됨, Preview.html 이 비어 있음, precheck found google, 레인 가드는 통과, metadata_path 상대경로]
resolution: fixed
---

# `upload_app_store_metadata` 가 에러 없이 아무것도 안 올린다

- **증상**: lane 이 55초 돌고 실패 없이 deliver 를 통과했는데 ASC 는 그대로였다. 31개 로케일이 활성화되지 않고 en-US·ko 의 옛 문구가 남았다. 뒤이은 precheck 가 그 옛 ko 설명의 `Google 캘린더` 를 잡아 `found: google` 로 실패해, 원고 문제처럼 보였다.
- **근본 원인**: `FastlaneCore::FastlaneFolder.path` 는 상대경로를 돌려준다. 레인 본문은 cwd 가 `fastlane/` 이라 `"./"` 를 받아 `./metadata` 를 만들고, 가드 3종은 그 자리에서 `fastlane/metadata` 를 보고 통과한다. 그런데 fastlane 은 액션을 `Dir.chdir("..")` 로 프로젝트 루트에서 실행해 같은 문자열이 `<root>/metadata` 를 가리킨다. deliver 는 없는 그 디렉토리를 만들고 로케일 0개를 읽어, 올릴 값이 없으니 에러 없이 끝났다.
- **해결**: `app_store_metadata_path`·`app_store_screenshots_path` 를 `File.expand_path` 로 감싸 레인 본문에서 절대경로로 굳힌다. 가드와 액션이 같은 디렉토리를 보게 되어 "가드는 통과하고 업로드는 no-op" 조합 자체가 성립하지 않는다.
- **판정 단서**: `fastlane/Preview.html` 이 4.8KB 껍데기였다 — 로케일 섹션 2개에 description·keywords·name 이 한 줄도 없었다. deliver 가 무엇을 읽었는지는 이 파일이 그대로 보여준다. `<root>/metadata` 가 lane 실행 시각에 빈 디렉토리로 생성돼 있던 것도 같은 증거다.
- **기각 방향**: precheck `other_platforms` 룰 대응으로 원고의 구글 언급을 손보기 — 검사 대상이 새 원고가 아니라 ASC 에 남아 있던 옛 문구였다

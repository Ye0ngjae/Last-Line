# 웹 배포 (GitHub Pages)

Godot 에디터에서 웹으로 내보낸 정적 파일을 `gh-pages` 브랜치에 올려서 GitHub Pages로 배포한다. (GitHub Actions는 쓰지 않는다.)

- 배포 스크립트: [deploy-web.sh](../deploy-web.sh)
- 내보내기 프리셋: [last-line/export_presets.cfg](../last-line/export_presets.cfg) (Web, **스레드 지원 끔**)
- 결과 주소: `https://ye0ngjae.github.io/Last-Line/`

## 배포하기

1. Godot 에디터 → **Project → Export → Web → Export Project**로 `last-line/build/web/index.html`에 내보낸다.
2. 레포 루트에서 `./deploy-web.sh`를 실행한다. (`build/web`을 `gh-pages` 브랜치에 강제 푸시한다.)

## 처음 한 번만 할 설정

- 처음으로 `./deploy-web.sh`를 실행한 뒤 GitHub 레포 → **Settings → Pages → Source: Deploy from a branch → `gh-pages` / `(root)`** 로 저장한다.
- 1~2분 뒤 위 주소로 접속한다.

> Pages는 무료 계정이면 **공개 레포**에서만 쓸 수 있다.

## 왜 별도 서버 설정이 필요 없나

- 스레드를 끈 단일 스레드 빌드라 `SharedArrayBuffer`와 COOP/COEP 헤더가 필요 없어, GitHub Pages처럼 헤더를 못 바꾸는 정적 호스팅에서 그대로 동작한다.
- 렌더러는 GL Compatibility(WebGL 2)라 대부분의 최신 브라우저에서 돌아간다.

## 내 컴퓨터에서 웹 빌드 시험하기

1. Godot 에디터 → **Editor → Manage Export Templates**에서 4.7.2 템플릿을 설치한다.
2. **Project → Export → Web → Export Project**로 `last-line/build/web/`에 내보낸다(또는 `godot --headless --path last-line --export-release "Web" build/web/index.html`).
3. 그 폴더에서 `python3 -m http.server 8000` 실행 후 `http://localhost:8000` 접속. (파일을 더블클릭해서 `file://`로 열면 동작하지 않는다.)

## 알아둘 점

- **소리**: 브라우저는 첫 클릭 전에는 소리를 막는다. 시작 화면의 START 클릭 이후부터 무전과 효과음이 나온다.
- **용량**: 무전 음성과 폰트를 포함해 대략 수 MB~십수 MB. 첫 로딩 때 한 번 내려받는다.
- **한국어 자막**: 시스템 폰트가 없는 웹에서도 보이도록 폰트를 프로젝트에 포함했다(`fonts/`).
- **화면 비율/전체화면**: 옵션 화면에서 바꿀 수 있다. 브라우저 전체화면은 클릭 직후에만 허용된다.
- **저장**: 옵션 값은 브라우저 저장소(IndexedDB)에 저장된다. 사이트 데이터를 지우면 초기화된다.
- **내보내기 템플릿**: 에디터 → **Editor → Manage Export Templates**에서 에디터와 같은 버전(현재 4.7.2)의 템플릿을 설치해야 내보낼 수 있다.

## 다른 호스팅

| 방법 | 방법 요약 |
|---|---|
| itch.io | `build/web/` 폴더를 zip으로 묶어 "HTML" 프로젝트로 업로드, "SharedArrayBuffer support"는 꺼도 된다 |
| Netlify / Cloudflare Pages | `build/web/`을 정적 사이트로 배포(빌드 명령 없이 폴더 업로드) |
| 자체 서버 | `build/web/`를 정적 파일로 서빙. `.wasm`의 MIME 타입(`application/wasm`)만 맞추면 된다 |

# Sudoku 프로젝트 인수인계

이 문서는 다른 컴퓨터나 새 Codex 채팅에서 개발을 이어가기 위한 현재 상태 요약이다.

## 프로젝트 목표

- Flutter로 만든 개인용 스도쿠 앱
- Windows와 웹에서 빠르게 테스트하고, 최종적으로 iPhone에서 실행
- 문제는 오픈소스 퍼즐 데이터에서 가져오며 앱 안에서 새 문제를 생성하지 않음
- 참고 앱의 사용 흐름은 참고하되 소스 코드, 이미지, 문구 등 저작물은 복제하지 않음

## 확정된 범위

포함:

- 9×9 스도쿠 플레이
- 문제 난이도 6단계: `beginner`, `easy`, `medium`, `hard`, `expert`, `master`
- 오답 즉시 표시 및 실수 횟수 기록
- 같은 칸에 동일한 오답을 다시 입력할 때는 추가 입력이나 실수 증가 없음
- 실행 취소를 해도 이미 기록된 실수 횟수는 줄어들지 않음
- 일반 숫자 및 메모 입력
- 선택 숫자와 같은 메모는 3×3 메모 위치 단위로 강조
- 선택한 칸의 행·열·박스 강조와 숫자색 강조
- 컴퓨터 숫자키 입력
- 힌트, 자동 저장, 이어하기, 설정, 라이트·다크 테마

제외:

- 일일 도전
- Zen 모드
- 게임 리플레이와 코치 리포트
- 플레이 결과를 기반으로 한 풀이 기법 난이도 판정
- 튜토리얼 및 풀이 기법 라이브러리
- 통계와 업적

## 퍼즐 데이터

- 출처: Sudoku Exchange Puzzle Bank
- 원본 저장소: <https://github.com/grantm/sudoku-exchange-puzzle-bank>
- 라이선스: Public Domain
- 라이선스 고지: `THIRD_PARTY_NOTICES.md`
- 총 10,000문제
  - beginner 2,000
  - easy 2,000
  - medium 2,000
  - hard 2,000
  - expert 1,530
  - master 470
- 세부 생성 정보: `assets/puzzles/manifest.json`

## 힌트 엔진

힌트는 정답을 단순히 공개하는 대신 논리 기법을 순서대로 탐색한다. 후보 제거형 힌트는 제거 내용을 적용한 뒤 다음 논리 단계를 계속 찾을 수 있다.

현재 구현 기법:

- Naked Single, Hidden Single
- Locked Candidates: Pointing, Claiming
- Naked Pair/Triple/Quad
- Hidden Pair/Triple/Quad
- X-Wing, Swordfish, Jellyfish
- Skyscraper
- Two-String Kite
- XY-Wing, XYZ-Wing
- Simple Coloring

힌트 엔진 핵심 코드는 `lib/game/sudoku_logic.dart`, 관련 테스트는 `test/hint_engine_test.dart`에 있다.

## 주요 코드 위치

- 앱 진입점: `lib/main.dart`
- 홈 및 설정: `lib/screens/home_page.dart`
- 게임 화면과 입력 처리: `lib/screens/game_page.dart`
- 스도쿠 풀이 및 힌트: `lib/game/sudoku_logic.dart`
- 실행 취소 이력: `lib/game/game_history.dart`
- 퍼즐 로딩: `lib/data/puzzle_repository.dart`
- 자동 저장: `lib/data/game_save_store.dart`
- 사용자 설정: `lib/data/game_preferences_store.dart`
- 테마 설정: `lib/data/appearance_store.dart`

## 완료된 검증

- `flutter analyze` 통과
- `flutter test` 통과
- Windows Release 빌드 성공
- 다음 화면 크기에서 라이트·다크 및 큰 글자 레이아웃 테스트 완료
  - 375×667
  - 393×852
  - 430×932
  - 768×1024
  - 1280×800

새 환경에서는 아래 명령으로 현재 상태를 다시 검증한다.

```bash
flutter pub get
flutter analyze
flutter test
```

## Mac에서 이어갈 작업

권장 순서:

1. 저장소를 clone하고 Flutter 및 Xcode 환경을 확인한다.
2. 위 분석과 테스트를 다시 실행한다.
3. `flutter devices`로 iOS Simulator를 확인한다.
4. iPhone Simulator에서 앱을 실행하고 실제 렌더링, 키보드, Safe Area, 회전 및 다크 모드를 확인한다.
5. 화면 검증을 시작하기 전에 사용자에게 검증 대상과 방식을 먼저 알린다.
6. 발견된 iOS 전용 문제만 수정하고 전체 테스트를 재실행한다.
7. 실제 iPhone 연결 후 Apple 서명 설정, Bundle Identifier, 앱 이름과 아이콘을 정리한다.
8. 실제 기기에서 저장 복원, 힌트, 메모, 오답, 실행 취소, 다크 모드를 최종 확인한다.

## 새 Codex 채팅의 첫 요청 예시

> `PROJECT_HANDOFF.md`, README와 현재 코드를 먼저 읽고 테스트를 실행해 프로젝트 상태를 확인해줘. 기존 요구사항을 유지하면서 Mac의 iPhone Simulator 검증부터 이어서 진행하되, 화면 검증을 시작하기 전에 검증 계획을 먼저 알려줘.

## 작업 원칙

- 기존 요구사항을 임의로 넓히지 않는다.
- 퍼즐 데이터와 제3자 라이선스 고지를 유지한다.
- 힌트 기법 변경 시 관련 단위 테스트를 함께 추가한다.
- UI 변경 시 휴대폰 최소 화면과 큰 글자 환경을 함께 확인한다.
- 변경 후 `flutter analyze`와 `flutter test`를 통과시킨다.

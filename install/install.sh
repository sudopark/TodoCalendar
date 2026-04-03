#!/bin/bash

# install 디렉토리 기준으로 상대 경로 설정
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cp -r "$SCRIPT_DIR/InfoPlist_Secrets.swift" "$PROJECT_DIR/Tuist/ProjectDescriptionHelpers/InfoPlist_Secrets.swift"
cp -r "$SCRIPT_DIR/GoogleService-Info.plist" "$PROJECT_DIR/TodoCalendarApp/Resources/GoogleService-Info.plist"
cp -r "$SCRIPT_DIR/secrets.json" "$PROJECT_DIR/TodoCalendarApp/Resources/secrets.json"

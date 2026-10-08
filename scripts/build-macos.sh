#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
artifact_dir="$project_root/artifacts"
derived_dir="${FREEBIKE_DERIVED_DATA:-$artifact_dir/DerivedData-macOS}"
mkdir -p "$artifact_dir"

xcodebuild -project "$project_root/freeBikeControl.xcodeproj" \
  -scheme freeBikeControl -configuration Release -destination 'platform=macOS' \
  -derivedDataPath "$derived_dir" CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES build

app_path="$derived_dir/Build/Products/Release/freeBikeControl.app"
codesign --verify --deep --strict "$app_path"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$artifact_dir/FreeBikeControl-macOS.zip"
printf 'Artifact: %s\n' "$artifact_dir/FreeBikeControl-macOS.zip"

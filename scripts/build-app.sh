#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="${BUILD_DIR:-${project_root}/.build-app}"
output_dir="${OUTPUT_DIR:-${project_root}/dist}"
app_name="VPS Gözcü"
executable_name="VPSGozcu"
bundle_identifier="${BUNDLE_IDENTIFIER:-com.vpsgozcu.app}"
app_version="${APP_VERSION:-0.1.0}"
build_number="${BUILD_NUMBER:-1}"
signing_identity="${CODESIGN_IDENTITY:--}"
app_path="${output_dir}/${app_name}.app"

swift test --scratch-path "${build_dir}"
swift build -c release --scratch-path "${build_dir}"
binary_dir="$(swift build -c release --scratch-path "${build_dir}" --show-bin-path)"
binary_path="${binary_dir}/${executable_name}"

if [[ ! -x "${binary_path}" ]]; then
    echo "Release executable bulunamadı: ${binary_path}" >&2
    exit 1
fi

mkdir -p "${output_dir}"
rm -rf "${app_path}"
mkdir -p "${app_path}/Contents/MacOS" "${app_path}/Contents/Resources"

cp "${binary_path}" "${app_path}/Contents/MacOS/${executable_name}"
cp "${project_root}/Resources/Info.plist" "${app_path}/Contents/Info.plist"
cp "${project_root}/Resources/AppIcon.icns" "${app_path}/Contents/Resources/AppIcon.icns"

/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${bundle_identifier}" "${app_path}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${app_version}" "${app_path}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${build_number}" "${app_path}/Contents/Info.plist"

if [[ "${signing_identity}" == "-" ]]; then
    codesign --force --sign - "${app_path}"
    signature_kind="ad-hoc"
else
    codesign --force --options runtime --timestamp --sign "${signing_identity}" "${app_path}"
    signature_kind="Developer ID"
fi

codesign --verify --strict --verbose=2 "${app_path}"
plutil -lint "${app_path}/Contents/Info.plist"

echo "App hazır: ${app_path}"
echo "İmza türü: ${signature_kind}"

if [[ "${signing_identity}" == "-" ]]; then
    echo "Dağıtım için CODESIGN_IDENTITY ile Developer ID Application kimliği verin ve notarize-app.sh çalıştırın."
fi

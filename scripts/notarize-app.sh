#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_path="${1:-${project_root}/dist/VPS Gözcü.app}"
notary_profile="${NOTARY_PROFILE:-}"
archive_path="${project_root}/dist/VPS-Gozcu-notarization.zip"

if [[ -z "${notary_profile}" ]]; then
    echo "NOTARY_PROFILE tanımlanmalı; parola veya API anahtarını script içine yazmayın." >&2
    exit 1
fi

if [[ ! -d "${app_path}" ]]; then
    echo "App bulunamadı: ${app_path}" >&2
    exit 1
fi

signature_details="$(codesign -dv --verbose=4 "${app_path}" 2>&1 || true)"
if ! grep -Fq "Authority=Developer ID Application" <<<"${signature_details}"; then
    echo "Notarization için Developer ID Application imzalı app gerekir." >&2
    exit 1
fi

rm -f "${archive_path}"
ditto -c -k --keepParent "${app_path}" "${archive_path}"
xcrun notarytool submit "${archive_path}" --keychain-profile "${notary_profile}" --wait
xcrun stapler staple "${app_path}"
xcrun stapler validate "${app_path}"
spctl --assess --type execute --verbose=2 "${app_path}"

echo "Notarization tamamlandı: ${app_path}"

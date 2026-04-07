#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
pkgbuild="${repo_root}/windsurf/PKGBUILD"

release_json="$(curl -fsSL 'https://windsurf-stable.codeium.com/api/update/linux-x64/stable/0')"
pkgver="$(jq -r '.windsurfVersion' <<<"${release_json}")"
source_url="$(jq -r '.url' <<<"${release_json}")"
sha256="$(jq -r '.sha256hash' <<<"${release_json}")"

if [[ "${source_url}" != *.tar.gz ]]; then
  echo "unexpected windsurf release URL: ${source_url}" >&2
  exit 1
fi

if [[ -z "${pkgver}" || "${pkgver}" == "null" || -z "${sha256}" || "${sha256}" == "null" ]]; then
  echo "windsurf release metadata is incomplete" >&2
  exit 1
fi

archive="$(mktemp)"
trap 'rm -f "${archive}"' EXIT
curl -fsSLo "${archive}" "${source_url}"
tar -tzf "${archive}" \
  Windsurf/bin/windsurf \
  Windsurf/resources/app/resources/linux/code.png \
  Windsurf/resources/app/LICENSE.txt >/dev/null

perl -0pi -e "s/^pkgver=.*/pkgver=${pkgver}/m" "${pkgbuild}"
perl -0pi -e 's|^_source_url=.*|_source_url="'"${source_url}"'"|m' "${pkgbuild}"
perl -0pi -e "s/^  '[0-9a-f]{64}'$/  '${sha256}'/m" "${pkgbuild}"

"${repo_root}/scripts/render-srcinfo.sh" "${repo_root}/windsurf"

#!/usr/bin/env bash
set -euo pipefail

optional=false
if (($# > 1)); then
  echo "usage: $0 [--optional]" >&2
  exit 1
fi
if (($# == 1)); then
  if [[ "$1" != "--optional" ]]; then
    echo "usage: $0 [--optional]" >&2
    exit 1
  fi
  optional=true
fi

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
package_dir="${repo_root}/scryu-bin"
pkgbuild="${package_dir}/PKGBUILD"
release_base_url="${SCRYU_RELEASE_BASE_URL:-https://install.scryu.com/releases}"
manifest_url="${release_base_url%/}/latest.json"

skip_optional() {
  if [[ "${optional}" == "true" ]]; then
    echo "Skipping scryu-bin: $1" >&2
    exit 0
  fi
  echo "scryu-bin: $1" >&2
  exit 1
}

verify_sha256() {
  local expected="$1"
  local file="$2"
  local actual

  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "${file}" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "${file}" | awk '{print $1}')"
  else
    echo "Unable to verify SHA-256: neither sha256sum nor shasum is available." >&2
    exit 1
  fi

  if [[ "${actual}" != "${expected}" ]]; then
    echo "SHA-256 mismatch for ${file}: expected ${expected}, got ${actual}." >&2
    exit 1
  fi
}

manifest="$(mktemp)"
if ! curl -fsSL "${manifest_url}" -o "${manifest}"; then
  skip_optional "latest release manifest is not available at ${manifest_url}"
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}" "${manifest}"' EXIT

pkgver="$(jq -r '.version | ltrimstr("v")' "${manifest}")"
asset_json="$(jq -c '
  .assets
  | map(select(.name | test("_linux_amd64\\.tar\\.gz$")))
  | first
' "${manifest}")"
asset_name="$(jq -r '.name // empty' <<<"${asset_json}")"
asset_url="$(jq -r '.url // empty' <<<"${asset_json}")"
sha256="$(jq -r '.sha256 // empty' <<<"${asset_json}")"

if [[ -z "${pkgver}" || "${pkgver}" == "null" ]]; then
  skip_optional "latest release manifest is missing version"
fi
if [[ -z "${asset_name}" || "${asset_name}" == "null" || -z "${asset_url}" || "${asset_url}" == "null" ]]; then
  skip_optional "latest release manifest is missing a linux amd64 archive"
fi
if [[ -z "${sha256}" || "${sha256}" == "null" ]]; then
  skip_optional "latest release manifest is missing a linux amd64 checksum"
fi

curl -fsSL "${asset_url}" -o "${tmpdir}/${asset_name}"
(
  cd "${tmpdir}"
  verify_sha256 "${sha256}" "${asset_name}"
  tar -tzf "${asset_name}" \
    "scryu_v${pkgver}_linux_amd64/scryu" >/dev/null
)

mkdir -p "${package_dir}"
cat > "${pkgbuild}" <<'EOF'
# Maintainer: Anand Pant

pkgname=scryu-bin
pkgver=__PKGVER__
pkgrel=1
pkgdesc="SCRYU terminal client"
arch=('x86_64')
url="https://scryu.com"
install="${pkgname}.install"
provides=('scryu')
conflicts=('scryu')
source=('__ASSET_URL__')
sha256sums=('__SHA256__')

package() {
  install -Dm755 "scryu_v${pkgver}_linux_amd64/scryu" \
    "${pkgdir}/usr/bin/scryu"
}
EOF

PKGVER="${pkgver}" ASSET_URL="${asset_url}" SHA256="${sha256}" perl -0pi \
  -e 's/__PKGVER__/$ENV{PKGVER}/g; s/__ASSET_URL__/$ENV{ASSET_URL}/g; s/__SHA256__/$ENV{SHA256}/g' \
  "${pkgbuild}"

cat > "${package_dir}/scryu-bin.install" <<'EOF'
post_install() {
  cat <<'MSG'
SCRYU installed.

First run:
  scryu login
  scryu

Installed scryu stores local objective run state under ~/.scryu.
MSG
}
EOF

"${repo_root}/scripts/render-srcinfo.sh" "${package_dir}"

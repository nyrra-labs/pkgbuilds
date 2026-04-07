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
pkgbuild="${repo_root}/nyrra-signals-bin/PKGBUILD"

if [[ -n "${NYRRA_GH_TOKEN:-}" ]]; then
  release_json="$(GH_TOKEN="${NYRRA_GH_TOKEN}" gh api repos/nyrra-labs/nyrra-signals/releases/latest)"
elif [[ -n "${GITHUB_ACTIONS:-}" ]]; then
  if [[ "${optional}" == "true" ]]; then
    echo "Skipping nyrra-signals-bin: NYRRA_GH_TOKEN is not configured in GitHub Actions." >&2
    exit 0
  fi
  echo "NYRRA_GH_TOKEN is required in GitHub Actions to read the private nyrra-signals release." >&2
  exit 1
else
  release_json="$(gh api repos/nyrra-labs/nyrra-signals/releases/latest)"
fi

pkgver="$(jq -r '.tag_name | ltrimstr("v")' <<<"${release_json}")"
asset_json="$(jq -c '
  .assets
  | map(select((.name == "artifact") or (.name | test("_linux_amd64\\.tar\\.gz$"))))
  | first
' <<<"${release_json}")"
release_asset="$(jq -r '.name // empty' <<<"${asset_json}")"
sha256="$(jq -r '.digest // empty' <<<"${asset_json}")"

if [[ -z "${release_asset}" || "${release_asset}" == "null" ]]; then
  if [[ "${optional}" == "true" ]]; then
    echo "Skipping nyrra-signals-bin: latest release is missing a usable archive asset." >&2
    exit 0
  fi
  echo "nyrra-signals latest release is missing the expected artifact asset" >&2
  exit 1
fi

if [[ -z "${sha256}" || "${sha256}" == "null" ]]; then
  if [[ "${optional}" == "true" ]]; then
    echo "Skipping nyrra-signals-bin: latest release is missing an asset digest." >&2
    exit 0
  fi
  echo "nyrra-signals latest release is missing an asset digest" >&2
  exit 1
fi

sha256="${sha256#sha256:}"

perl -0pi -e "s/^pkgver=.*/pkgver=${pkgver}/m" "${pkgbuild}"
perl -0pi -e "s/^_release_asset=.*/_release_asset='${release_asset}'/m" "${pkgbuild}"
perl -0pi -e "s/^_sha256=.*/_sha256='${sha256}'/m" "${pkgbuild}"

"${repo_root}/scripts/render-srcinfo.sh" "${repo_root}/nyrra-signals-bin"

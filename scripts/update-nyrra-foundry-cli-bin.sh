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
pkgbuild="${repo_root}/nyrra-foundry-cli-bin/PKGBUILD"
repo="nyrra-labs/nyrra-foundry-cli"

if [[ -n "${NYRRA_GH_TOKEN:-}" ]]; then
  release_json="$(GH_TOKEN="${NYRRA_GH_TOKEN}" gh api "repos/${repo}/releases/latest")"
elif [[ -n "${GITHUB_ACTIONS:-}" ]]; then
  if [[ "${optional}" == "true" ]]; then
    echo "Skipping nyrra-foundry-cli-bin: NYRRA_GH_TOKEN is not configured in GitHub Actions." >&2
    exit 0
  fi
  echo "NYRRA_GH_TOKEN is required in GitHub Actions to read the private nyrra-foundry-cli release." >&2
  exit 1
else
  release_json="$(gh api "repos/${repo}/releases/latest")"
fi

pkgver="$(jq -r '.tag_name | ltrimstr("v")' <<<"${release_json}")"
asset_json="$(jq -c '
  .assets
  | map(select(.name | test("_linux_amd64\\.tar\\.gz$")))
  | first
' <<<"${release_json}")"
asset_name="$(jq -r '.name // empty' <<<"${asset_json}")"
sha256="$(jq -r '.digest // empty' <<<"${asset_json}")"

if [[ -z "${asset_name}" || "${asset_name}" == "null" ]]; then
  if [[ "${optional}" == "true" ]]; then
    echo "Skipping nyrra-foundry-cli-bin: latest release is missing a linux amd64 archive." >&2
    exit 0
  fi
  echo "nyrra-foundry-cli latest release is missing a linux amd64 archive" >&2
  exit 1
fi

if [[ -z "${sha256}" || "${sha256}" == "null" ]]; then
  if [[ "${optional}" == "true" ]]; then
    echo "Skipping nyrra-foundry-cli-bin: latest release is missing an asset digest." >&2
    exit 0
  fi
  echo "nyrra-foundry-cli latest release is missing an asset digest" >&2
  exit 1
fi

sha256="${sha256#sha256:}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

if [[ -n "${NYRRA_GH_TOKEN:-}" ]]; then
  GH_TOKEN="${NYRRA_GH_TOKEN}" gh release download "v${pkgver}" --repo "${repo}" --pattern "${asset_name}" --dir "${tmpdir}" --clobber >/dev/null
else
  gh release download "v${pkgver}" --repo "${repo}" --pattern "${asset_name}" --dir "${tmpdir}" --clobber >/dev/null
fi

(
  cd "${tmpdir}"
  echo "${sha256}  ${asset_name}" | sha256sum -c
  tar -tzf "${asset_name}" \
    nyrra-foundry-cli \
    LICENSE \
    NOTICE \
    README.md \
    templates/compute-module-ts/package.json >/dev/null
)

perl -0pi -e "s/^pkgver=.*/pkgver=${pkgver}/m" "${pkgbuild}"
perl -0pi -e "s/^_asset=.*/_asset='${asset_name}'/m" "${pkgbuild}"
perl -0pi -e "s/^_sha256=.*/_sha256='${sha256}'/m" "${pkgbuild}"

"${repo_root}/scripts/render-srcinfo.sh" "${repo_root}/nyrra-foundry-cli-bin"

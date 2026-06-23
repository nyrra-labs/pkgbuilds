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
package_dir="${repo_root}/foundry-cli-bin"
pkgbuild="${package_dir}/PKGBUILD"
repo="nyrra-labs/nyrra-foundry-cli"
asset_prefix="foundry-cli"
release_tag="${FOUNDRY_CLI_RELEASE_TAG:-}"

verify_release_archive() {
  local archive="$1"
  local listing

  listing="$(tar -tzf "${archive}")"

  grep -Fxq "foundry-cli" <<<"${listing}"
  grep -Fxq "LICENSE" <<<"${listing}"
  grep -Fxq "README.md" <<<"${listing}"

  if ! grep -Eq '^templates/(compute-module-ts|compute-modules/typescript)/package\.json$' <<<"${listing}"; then
    echo "Release archive ${archive} is missing a recognized compute module template package.json." >&2
    exit 1
  fi
}

fetch_release_by_tag() {
  local tag="$1"

  if [[ -n "${NYRRA_GH_TOKEN:-}" ]]; then
    GH_TOKEN="${NYRRA_GH_TOKEN}" gh api "repos/${repo}/releases/tags/${tag}"
  else
    gh api "repos/${repo}/releases/tags/${tag}"
  fi
}

fetch_release_with_assets() {
  local include_prereleases="$1"

  if [[ -n "${NYRRA_GH_TOKEN:-}" ]]; then
    GH_TOKEN="${NYRRA_GH_TOKEN}" gh api --paginate "repos/${repo}/releases"
  else
    gh api --paginate "repos/${repo}/releases"
  fi | jq -s -c --arg asset_prefix "${asset_prefix}" --argjson include_prereleases "${include_prereleases}" '
    add
    | map(select(.draft | not))
    | map(select($include_prereleases or (.prerelease | not)))
    | map(select(any(.assets[]?; (.name | test("^" + $asset_prefix + "_.*_linux_amd64\\.tar\\.gz$")))))
    | first // empty
  '
}

if [[ -n "${release_tag}" ]]; then
  release_json="$(fetch_release_by_tag "${release_tag}")"
elif [[ -n "${NYRRA_GH_TOKEN:-}" || -z "${GITHUB_ACTIONS:-}" ]]; then
  release_json="$(fetch_release_with_assets false)"
  if [[ -z "${release_json}" || "${release_json}" == "null" ]]; then
    release_json="$(fetch_release_with_assets true)"
  fi
elif [[ -n "${GITHUB_ACTIONS:-}" ]]; then
  if [[ "${optional}" == "true" ]]; then
    echo "Skipping foundry-cli-bin: NYRRA_GH_TOKEN is not configured in GitHub Actions." >&2
    exit 0
  fi
  echo "NYRRA_GH_TOKEN is required in GitHub Actions to read the private foundry-cli release." >&2
  exit 1
fi

if [[ -z "${release_json}" || "${release_json}" == "null" ]]; then
  if [[ "${optional}" == "true" ]]; then
    echo "Skipping foundry-cli-bin: no release contains foundry-cli linux amd64 archives." >&2
    exit 0
  fi
  echo "foundry-cli has no release with linux amd64 archives" >&2
  exit 1
fi

pkgver="$(jq -r '.tag_name | ltrimstr("v")' <<<"${release_json}")"
asset_json="$(jq -c --arg asset_prefix "${asset_prefix}" '
  .assets
  | map(select(.name | test("^" + $asset_prefix + "_.*_linux_amd64\\.tar\\.gz$")))
  | first
' <<<"${release_json}")"
asset_name="$(jq -r '.name // empty' <<<"${asset_json}")"
sha256="$(jq -r '.digest // empty' <<<"${asset_json}")"

if [[ -z "${asset_name}" || "${asset_name}" == "null" ]]; then
  if [[ "${optional}" == "true" ]]; then
    echo "Skipping foundry-cli-bin: selected release is missing a linux amd64 archive." >&2
    exit 0
  fi
  echo "foundry-cli selected release is missing a linux amd64 archive" >&2
  exit 1
fi

if [[ -z "${sha256}" || "${sha256}" == "null" ]]; then
  if [[ "${optional}" == "true" ]]; then
    echo "Skipping foundry-cli-bin: selected release is missing an asset digest." >&2
    exit 0
  fi
  echo "foundry-cli selected release is missing an asset digest" >&2
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
  verify_release_archive "${asset_name}"
)

mkdir -p "${package_dir}"
cat > "${pkgbuild}" <<'EOF'
# Maintainer: Anand Pant

pkgname=foundry-cli-bin
pkgver=__PKGVER__
pkgrel=1
pkgdesc="Foundry DevOps automation CLI"
arch=('x86_64')
url="https://github.com/nyrra-labs/nyrra-foundry-cli"
license=('Apache-2.0')
install="${pkgname}.install"
makedepends=('github-cli')
provides=('foundry-cli')
conflicts=('foundry-cli')

_asset='__ASSET_NAME__'
_sha256='__SHA256__'

prepare() {
  gh release download "v${pkgver}" \
    --repo nyrra-labs/nyrra-foundry-cli \
    --pattern "${_asset}" \
    --dir . --clobber

  echo "${_sha256}  ${_asset}" | sha256sum -c
  tar xzf "${_asset}"
}

package() {
  install -dm755 "${pkgdir}/usr/lib/foundry-cli"
  install -Dm755 "foundry-cli" \
    "${pkgdir}/usr/lib/foundry-cli/foundry-cli"
  cp -R templates "${pkgdir}/usr/lib/foundry-cli/"

  # Some historical release archives omitted templates/README.md, but the CLI
  # requires that sentinel file to resolve packaged templates at runtime.
  install -Dm644 /dev/stdin \
    "${pkgdir}/usr/lib/foundry-cli/templates/README.md" <<'EOT'
# templates
EOT

  install -Dm644 LICENSE "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE"
  if [[ -f NOTICE ]]; then
    install -Dm644 NOTICE "${pkgdir}/usr/share/licenses/${pkgname}/NOTICE"
  fi
  install -Dm644 README.md "${pkgdir}/usr/share/doc/${pkgname}/README.md"

  install -dm755 "${pkgdir}/usr/bin"
  ln -s ../lib/foundry-cli/foundry-cli \
    "${pkgdir}/usr/bin/foundry-cli"
}
EOF

PKGVER="${pkgver}" ASSET_NAME="${asset_name}" SHA256="${sha256}" perl -0pi \
  -e 's/__PKGVER__/$ENV{PKGVER}/g; s/__ASSET_NAME__/$ENV{ASSET_NAME}/g; s/__SHA256__/$ENV{SHA256}/g' \
  "${pkgbuild}"

cat > "${package_dir}/foundry-cli-bin.install" <<'EOF'
post_install() {
  cat <<'MSG'
==> foundry-cli-bin: package-manager installs do not edit your shell config.
==> To add shell completion in zsh:
    printf '\nsource <(foundry-cli completion --code zsh)\n' >> ~/.zshrc
==> To add it in bash:
    printf '\nsource <(foundry-cli completion --code bash)\n' >> ~/.bashrc
==> Restart your shell after adding the snippet.
MSG
}

post_upgrade() {
  post_install
}
EOF

"${repo_root}/scripts/render-srcinfo.sh" "${package_dir}"

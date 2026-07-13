#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
filter="${repo_root}/scripts/filter-publish-packages.sh"

mkdir -p "${repo_root}/.memory"
workdir="$(mktemp -d "${repo_root}/.memory/publish-routing.XXXXXX")"
trap 'rm -rf "${workdir}"' EXIT

mkdir -p "${workdir}/live-package" "${workdir}/windsurf"
touch "${workdir}/live-package/PKGBUILD" "${workdir}/live-package/.SRCINFO"
touch "${workdir}/windsurf/PKGBUILD" "${workdir}/windsurf/.SRCINFO"

removed_only="$(cd "${workdir}" && printf '%s\n' removed-package | "${filter}")"
if [[ -n "${removed_only}" ]]; then
  echo "deletion-only routing should produce no packages, got: ${removed_only}" >&2
  exit 1
fi

mixed="$(
  cd "${workdir}"
  printf '%s\n' removed-package live-package windsurf | "${filter}"
)"
if [[ "${mixed}" != "live-package" ]]; then
  echo "publish routing should select only live-package, got: ${mixed}" >&2
  exit 1
fi

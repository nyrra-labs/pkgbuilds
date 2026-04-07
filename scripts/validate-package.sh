#!/usr/bin/env bash
set -euo pipefail

if (($# != 1)); then
  echo "usage: $0 <package-dir>" >&2
  exit 1
fi

package_dir="$1"
tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

cp -a "${package_dir}" "${tmpdir}/pkg"
bash -n "${package_dir}/PKGBUILD"

(
  cd "${tmpdir}/pkg"
  makepkg --packagelist >/dev/null
  makepkg --printsrcinfo > .SRCINFO.generated
)

diff -u "${package_dir}/.SRCINFO" "${tmpdir}/pkg/.SRCINFO.generated"

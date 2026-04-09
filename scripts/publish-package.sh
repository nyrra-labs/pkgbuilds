#!/usr/bin/env bash
set -euo pipefail

if (($# != 1)); then
  echo "usage: $0 <package-dir>" >&2
  exit 1
fi

package_dir="$1"
package_name="$(basename "${package_dir}")"
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "${repo_root}/${package_dir}/PKGBUILD" || ! -f "${repo_root}/${package_dir}/.SRCINFO" ]]; then
  echo "package directory is missing PKGBUILD or .SRCINFO: ${package_dir}" >&2
  exit 1
fi

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

git clone "ssh://aur@aur.archlinux.org/${package_name}.git" "${workdir}/${package_name}"
rsync -a --delete \
  "${repo_root}/${package_dir}/PKGBUILD" \
  "${repo_root}/${package_dir}/.SRCINFO" \
  "${workdir}/${package_name}/"

(
  cd "${workdir}/${package_name}"

  git config user.name "${AUR_USERNAME}"
  git config user.email "${AUR_EMAIL}"
  git add PKGBUILD .SRCINFO

  if git diff --cached --quiet; then
    echo "No AUR changes for ${package_name}"
    exit 0
  fi

  git commit -m "Update ${package_name}"
  git push origin HEAD
)

#!/usr/bin/env bash
set -euo pipefail

if (($# != 1)); then
  echo "usage: $0 <package-dir>" >&2
  exit 1
fi

package_dir="$1"

(
  cd "${package_dir}"
  makepkg --printsrcinfo > .SRCINFO
)

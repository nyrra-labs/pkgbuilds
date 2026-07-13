#!/usr/bin/env bash
set -euo pipefail

while IFS= read -r package; do
  [[ -n "${package}" ]] || continue
  [[ "${package}" != "windsurf" ]] || continue

  if [[ -f "${package}/PKGBUILD" && -f "${package}/.SRCINFO" ]]; then
    printf '%s\n' "${package}"
  fi
done

# A deletion-only input is valid and intentionally produces no matrix entries.
exit 0

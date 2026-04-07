#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

if (($# == 0)); then
  set -- auto
fi

if [[ "$1" == "auto" ]]; then
  packages=(
    windsurf
  )
  if [[ -n "${NYRRA_GH_TOKEN:-}" || -z "${GITHUB_ACTIONS:-}" ]]; then
    packages+=(nyrra-signals-bin)
  fi
elif [[ "$1" == "all" ]]; then
  packages=(
    nyrra-signals-bin
    windsurf
  )
else
  packages=("$@")
fi

for package in "${packages[@]}"; do
  case "${package}" in
    nyrra-signals-bin)
      if [[ "$1" == "auto" ]]; then
        "${repo_root}/scripts/update-nyrra-signals-bin.sh" --optional
      else
        "${repo_root}/scripts/update-nyrra-signals-bin.sh"
      fi
      ;;
    windsurf)
      "${repo_root}/scripts/update-windsurf.sh"
      ;;
    *)
      echo "unknown package: ${package}" >&2
      exit 1
      ;;
  esac
done

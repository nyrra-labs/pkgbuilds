# NYRRA Arch Packages

Arch Linux package definitions for NYRRA-maintained software and a small set of third-party tools we want to track in one place.

## Packages

| Package | Upstream | Notes |
|---|---|---|
| `nyrra-foundry-cli-bin` | `nyrra-labs/nyrra-foundry-cli` GitHub Releases | Private release assets. Package installs bundled templates and patches the missing template-root sentinel file from the current release archive. |
| `nyrra-signals-bin` | `nyrra-labs/nyrra-signals` GitHub Releases | The PKGBUILD is public, but installation requires GitHub access to the private release artifacts. |
| `windsurf` | Windsurf Linux stable tarball API | Updated from the upstream version API and packaged from the published Linux tarball. |

## Automation

- `.github/workflows/version-bumps.yml` runs on a schedule or manual dispatch, updates package versions/checksums via repo-owned scripts, regenerates `.SRCINFO`, and opens or updates a PR.
- `.github/workflows/validate.yml` is non-mutating PR validation. It checks PKGBUILD syntax and confirms `.SRCINFO` is in sync.
- `.github/workflows/publish.yml` publishes every changed package directory to the AUR after changes land on `main`, but cleanly skips publishing until AUR secrets exist.

## Local Usage

Update all packages:

```bash
./scripts/update-packages.sh auto
```

Validate package metadata:

```bash
./scripts/validate-packages.sh
```

Build a package locally:

```bash
cd <package-dir>
makepkg -si
```

For `nyrra-foundry-cli-bin` and `nyrra-signals-bin`, `gh auth login` must be configured with access to the `nyrra-labs` org before `makepkg` can download the private release assets.

## Temporary Mode

- You can use this repo immediately without creating the AUR repository or AUR secrets.
- The scheduled/manual bump workflow uses the repository `GITHUB_TOKEN` for branch and PR operations in this repo.
- Without `NYRRA_GH_TOKEN`, the workflow skips `nyrra-foundry-cli-bin` and `nyrra-signals-bin` and still updates `windsurf`.
- Without AUR secrets, the publish workflow exits successfully without pushing anywhere.
- `NYRRA_GH_TOKEN` now exists as an org-level secret in `nyrra-labs`, but it must be attached to each repo that should read the private release.

## Secrets

- `NYRRA_GH_TOKEN` is optional. Add it when you want GitHub Actions to update private NYRRA packages from private GitHub releases.
- `AUR_USERNAME`, `AUR_EMAIL`, `AUR_SSH_PRIVATE_KEY` are optional until you actually want to publish.

## Local Auth

- Local scripts use your normal `gh auth login` session when you run them from your machine.
- GitHub-hosted Actions cannot reuse your personal interactive `gh` login session. They only get the repository `GITHUB_TOKEN` plus any secrets you explicitly configure.

## Adding a New Package

1. Create a directory with the package name and add a `PKGBUILD`.
2. Add a dedicated updater script in `scripts/` if the package needs live version discovery.
3. Regenerate `.SRCINFO` with `./scripts/render-srcinfo.sh <package-dir>`.
4. Extend `./scripts/update-packages.sh` if the package should be included in automated bump PRs.

## Ultimate Setup

1. Create the GitHub repository and enable Actions.
2. In `Settings -> Actions -> General`, set workflow permissions to read and write, and enable GitHub Actions to create pull requests.
3. Attach the org-level `NYRRA_GH_TOKEN` secret to the repos that should bump `nyrra-signals-bin`.
4. When the AUR repos exist, add `AUR_USERNAME`, `AUR_EMAIL`, and `AUR_SSH_PRIVATE_KEY`.
5. Run `version-bumps` manually once, confirm the PR output, then merge.
6. After the first merge, `publish.yml` will start pushing package updates to AUR only if those AUR secrets are present.

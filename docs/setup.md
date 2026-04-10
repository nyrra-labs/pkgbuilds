# Setup

## Temporary, No-Publish Mode

Use this first.

1. Push the repo to GitHub.
2. Enable GitHub Actions for the repo.
3. In `Settings -> Actions -> General`:
   - set workflow permissions to `Read and write`
   - enable `Allow GitHub Actions to create and approve pull requests`
4. Do not add any AUR secrets yet.
5. Optionally attach `NYRRA_GH_TOKEN` if you want Actions to bump the private NYRRA packages too.
6. Run the `version-bumps` workflow manually.

Result:

- branch and PR creation use the repo `GITHUB_TOKEN`
- `windsurf` can update automatically
- `nyrra-foundry-cli-bin` and `nyrra-signals-bin` update only if the repo has access to `NYRRA_GH_TOKEN`
- AUR publishing is skipped without failing
- upstream `nyrra-signals` and `nyrra-foundry-cli` release workflows can also trigger this workflow automatically with `gh workflow run version-bumps.yml`, but that depends on `NYRRA_WORKFLOW_DISPATCH_TOKEN` being configured in those producer repos

## Org-Level Secret

This org secret is already created:

```bash
NYRRA_GH_TOKEN
```

Current state:

- org: `nyrra-labs`
- visibility: `selected`
- initially attached to no repos

Attach it to specific repos with:

```bash
gh secret set NYRRA_GH_TOKEN \
  --org nyrra-labs \
  --repos repo1,repo2,repo3 \
  --body "$(gh auth token)"
```

Example:

```bash
gh secret set NYRRA_GH_TOKEN \
  --org nyrra-labs \
  --repos pkgbuilds,nyrra-emulate \
  --body "$(gh auth token)"
```

If you later want to remove repo access without changing the secret value, rerun the same command with the smaller repo list.

## Local Operator Flow

If you are logged into GitHub locally with `gh auth login`, you can run:

```bash
./scripts/update-packages.sh all
./scripts/validate-packages.sh
```

That uses your local GitHub CLI session for private release access.

## Package-Manager Install Behavior

The AUR packages intentionally do less shell mutation than the upstream installers:

- `nyrra-foundry-cli-bin` installs `/usr/bin/nyrra-foundry-cli`, but it does not create a global `/usr/bin/npc` binary because that name is already taken elsewhere on Arch. The package prints the exact shell snippet to add `alias npc=nyrra-foundry-cli` plus completion setup in `post_install`.
- `nyrra-signals-bin` installs `/usr/bin/nyrra-signals`, but it does not auto-open the first-run UI. Run `nyrra-signals setup` from a real terminal after install.

## Full Publish Setup

When you are ready to publish:

1. Create the target AUR package repos.
2. Generate an SSH key that can push to those AUR repos.
3. Add these repo secrets:
   - `AUR_USERNAME`
   - `AUR_EMAIL`
   - `AUR_SSH_PRIVATE_KEY`
4. Merge a PR that changes `PKGBUILD` or `.SRCINFO` on `main`.
5. `publish.yml` will detect each changed package directory and push it to the matching AUR repo.

## Token Model

- Same-repo automation uses the built-in `GITHUB_TOKEN`.
- Cross-repo private release access for `nyrra-foundry-cli-bin` and `nyrra-signals-bin` needs a separate credential in Actions, because the workflow token is scoped to the repository that contains the workflow.
- Local runs can use your normal `gh auth login` session instead of any exported token.
- The current org secret value was created from your active `gh auth login` token. That works, but it is broader than ideal because it inherits that token's scopes.

## Recommended Follow-Up

For now, the org secret is usable. Longer term, replace it with a narrower machine credential.

Options:

1. Create a dedicated machine user token with only the repo access needed for private release reads.
2. Use a GitHub App installation token flow if you want the cleanest long-term setup.

# CLAUDE.md

## Layout

- Apps live at `kubernetes/apps/<namespace>/<app>/`: a Flux Kustomization in `ks.yaml`, with manifests (HelmRelease, kustomization.yaml, resources/) under `app/`.
- Each namespace directory has a `kustomization.yaml` listing its apps' `ks.yaml` files, plus a `namespace.yaml`.

## Secrets and hostnames

- Prefer `${SECRET_DOMAIN}` over the real domain in issues, PRs and committed files, including when pasting logs. It's not strictly enforced, so a missed occurrence isn't critical.

## Git

- Never run `git commit`. Committing is always left to the developer.
- When changes are ready, suggest a one-line Conventional Commits message, e.g. `fix(karma): proxy silence requests through karma`.

## GitHub issues

- Keep issues brief: one paragraph describing the problem and fix, plus one code example.
- Keep each issue small and discrete. If the work spans several concerns, propose multiple issues and create them only after approval.

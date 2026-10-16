# registry-login-action

<!-- The CUE Labs private common guidance is imported below, managed
     by porcuepine. If the referenced file is missing on your machine,
     run "porcuepine version update" to write it. Note there is no
     error if it is absent: an unresolvable @-import yields no content
     and no warning, so a session simply runs without the shared
     guidance. Install porcuepine with:
         go env -w GOPRIVATE=cuelabs.dev/private
         go install cuelabs.dev/private/aiops/cmd/porcuepine@latest -->
@~/.cache/porcuepine/common-guidance.md

## Project-specific instructions

A composite GitHub Action which exchanges a GitHub OIDC token for a CUE
registry access token, and writes it to the runner's CUE `logins.json`.
It is a single `actions/github-script` step; there is no build or bundle.

## Layout

    action.js     the script run by actions/github-script
    action.cue    the action definition, embedding action.js; generates action.yml
    internal/ci/  the CI workflow definitions; generate .github/workflows/

`action.yml` and `.github/workflows/*.yaml` are generated. Never edit them by
hand; change the source and run `go generate ./...`, which uses the `cue`
version pinned as a Go tool in `go.mod`.

`action.js` is not a standalone module: github-script runs it inside an async
function, providing `core`, `require` and others, and `${{ inputs.* }}` is
substituted before it runs.

## CI

The trybot fails if the tree is dirty after `go generate`, so a commit
touching a `.cue` file or `action.js` must include its regenerated output.
It then runs the action from the checkout against the Central Registry, uses
the written `logins.json` with `cue`, and checks in a second job that the
access token was masked in the logs.

## Versioning and releasing

Follow semver. A new major version is needed whenever a workflow which worked
on the previous tag might stop working, such as renaming or removing an input
or output, or a github-script upgrade which raises the node runtime.

Users reference the moving major tag, `v1`. Releases are lightweight tags on
`main`, without GitHub release notes. Check that CI is green on the commit,
then push the tags to Gerrit as the `chiefporcuepine` account, which has
permission to create tags. Gerrit replicates them to GitHub.

    remote=https://chiefporcuepine@cue.gerrithub.io/a/cue-labs/registry-login-action
    git tag vX.Y.Z <commit> && git push $remote vX.Y.Z
    git tag -f vX vX.Y.Z && git push -f $remote vX

Changes are reviewed on Gerrit; see `codereview.cfg`. Issues live in the main
cue-lang/cue repository, not here.

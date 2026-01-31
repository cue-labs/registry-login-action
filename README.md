# Login to CUE Registry via GitHub OIDC

A GitHub Action that authenticates to a CUE registry using GitHub's OIDC tokens.

## Features

- Authenticates using GitHub's OIDC provider (no static credentials needed)
- Optionally, automatically configures `cue` CLI `logins.json` file with
  registry credentials

## Prerequisites

Your CUE Central Registry must be
[configured](https://registry.cue.works/account/oidc) to trust the registry's
OIDC endpoint.

The workflow job must contain a
[`permissions`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#permissions)
entry enabling access to the GitHub OIDC token:

```yaml
permissions:
  id-token: write
```

## Usage

### Basic usage

```yaml
- name: Login to CUE registry
  uses: cue-labs/registry-login-action@v1
```

Once this is in place, the subsequent steps can use the `cue` CLI commands
logged-in as specified in the CUE Central Registry trust configuration.

### Using the access token

By default no additional steps are needed as the `cue` command is automatically
authenticated after the login step.

For other use-cases, the action outputs an `access_token` that can be used as a
bearer token for direct API calls:

```yaml
- name: Login to CUE registry
  id: oidc
  uses: cue-labs/registry-login-action@v1

- name: Test registry access
  run: |
    curl -sSL https://registry.cue.works/v2/ \
      -H "Authorization: Bearer ${{ steps.oidc.outputs.access_token }}"
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `registry` | CUE registry hostname | No | `registry.cue.works` |
| `update_logins` | Whether to update the local CUE logins.json file | No | `true` |

## Outputs

| Output | Description |
|--------|-------------|
| `access_token` | The access token obtained from the registry |

## How it works

1. Obtains a GitHub OIDC token with the registry URL as the audience
2. Exchanges the OIDC token for a registry access token
3. Optionally configures the `cue` CLI with the registry credentials in `~/.config/cue/logins.json`

## Example workflow

```yaml
name: Publish CUE module

on:
  # Example
  push:
    tags:
    - 'v*'

jobs:
  publish:
    runs-on: ubuntu-latest

    # Enable GitHub OIDC token
    permissions:
      id-token: write

    steps:
      - name: Checkout code
      - uses: actions/checkout@v6

      # Log into the registry using OIDC
      - name: Login to CUE registry
        id: oidc
        uses: cue-labs/registry-login-action@v1

      - name: Install Go
        uses: actions/setup-go@v6
        with:
          go-version: '1.25'

      - name: Install Cue
        run: go install cuelang.org/go/cmd/cue@latest

      - name: Publish module
        run: |
          cue mod publish ${{ github.ref_name }}
```

# Login to CUE Registry via GitHub OIDC

This GitHub Action authenticates to the [CUE Central
Registry](https://registry.cue.works) (or a self-hosted registry) using GitHub's
OIDC tokens.

By default, it automatically configures the `cue` CLI credentials, allowing
subsequent steps to run `cue mod publish` or other commands without manual
authentication setup.

## Features

* **Zero-secret authentication:** Uses GitHub OIDC (OpenID Connect) to exchange
  a temporary GitHub token for a CUE Registry token. No long-lived secrets are
  required.
* **Secure by default:** The generated access token is automatically masked as a
  secret in workflow logs to prevent accidental leakage.
* **Automatic CLI configuration:** Updates `~/.config/cue/logins.json` by
  default, so the `cue` command works immediately.
* **Flexible:** Can be configured to output a raw access token for use with
  `curl` or other API clients.

## Prerequisites

### 1. Configure Registry Trust

Your CUE Central Registry namespace must be configured to trust your GitHub
repository.

* **[Configure CUE Central Registry
  OIDC](https://registry.cue.works/account/oidc)**

### 2. Workflow Permissions

The workflow job must have permission to request an OIDC token. Add the
following `permissions` block to your job:

```yaml
permissions:
  id-token: write
```

## Usage

### Basic Usage (CUE Central Registry)

This is the standard pattern. It authenticates with `registry.cue.works` and
sets up the `cue` CLI.

```yaml
- name: Login to CUE registry
  uses: cue-labs/registry-login-action@v1

```

### Advanced Usage

#### Using a Custom Registry

If you are using a registry other than the CUE Central Registry:

```yaml
- name: Login to custom registry
  uses: cue-labs/registry-login-action@v1
  with:
    registry: registry.example.com

```

#### Using the Access Token directly (API Mode)

If you do not want to update the `logins.json` file (for example, to use the
token with `curl`):

```yaml
- name: Login to CUE registry
  id: oidc
  uses: cue-labs/registry-login-action@v1
  with:
    update_logins: false

- name: Call Registry API
  run: |
    curl -sSL https://registry.cue.works/v2/ \
      -H "Authorization: Bearer ${{ steps.oidc.outputs.access_token }}"

```

## Inputs

| Input | Description | Required | Default |
| --- | --- | --- | --- |
| `registry` | The hostname of the CUE registry. | No | `registry.cue.works` |
| `update_logins` | If `true`, writes credentials to the standard CUE `logins.json` file. | No | `true` |

## Outputs

| Output | Description |
| --- | --- |
| `access_token` | The short-lived OAuth access token obtained from the registry. **This value is masked as a secret in logs.** |

## Complete Workflow Example

This example demonstrates a full release pipeline that publishes a module when a
tag is pushed.

```yaml
name: Publish CUE module

on:
  push:
    tags: ['v*']

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      # Required for OIDC authentication
      id-token: write
      contents: read

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      # Log into the registry (updates ~/.config/cue/logins.json)
      - name: Login to CUE registry
        uses: cue-labs/registry-login-action@v1

      - name: Install Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.25'

      - name: Install CUE
        run: go install cuelang.org/go/cmd/cue@latest

      - name: Publish module
        # The 'cue' command is already authenticated by the login action
        run: cue mod publish ${{ github.ref_name }}

```


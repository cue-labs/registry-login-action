// package repo contains data values that are common to all CUE configurations
// in this repo. This not only includes GitHub workflows, but also things like
// gerrit configuration etc.
package repo

import (
	"github.com/cue-lang/tmp/internal/ci/base"
)

base

githubRepositoryPath: "cue-labs/registry-login-action"

botGitHubUser:      "porcuepine"
botGitHubUserEmail: "cue.porcuepine@gmail.com"

defaultBranch: "main"

cueCommand: "go tool cue"

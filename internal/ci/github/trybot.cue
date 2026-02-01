// Copyright 2026 CUE Labs
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package github

import (
	"list"
)

workflows: trybot: _repo.bashWorkflow & {
	on: {
		push: {
			branches: list.Concat([[_repo.testDefaultBranch], _repo.protectedBranchPatterns]) // do not run PR branches
			"tags-ignore": [_repo.releaseTagPattern]
		}
		pull_request: {}
	}

	jobs: test: {
		"runs-on": _repo.linuxMachine
		permissions: "id-token": "write"

		steps: [
			for v in _repo.checkoutCode {v},

			for v in _installGo {v},

			{
				name: "Verify"
				run:  "go mod verify"
			},
			{
				name: "Generate"
				run:  "go generate ./..."
			},
			{
				name: "Test"
				run:  "go test ./..."
			},
			{
				name: "Race test"
				run:  "go test -race ./..."
			},
			_repo.goChecks,
			_repo.checkGitClean,

			// Only now that we have check git is clean should we test
			// the action itself. This ensures we don't have any skew
			// between generated files.
			{
				name: "Login to CUE Central Registry"
				uses: "./"
			},
		]
	}
}

_installGo: _repo.installGo & {
	#setupGo: with: "go-version": _repo.latestGo
	_
}

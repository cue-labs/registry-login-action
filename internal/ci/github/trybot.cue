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
		outputs: access_token:   "${{ steps.login.outputs.access_token }}"

		steps: [
			for v in _repo.checkoutCode {v},

			for v in _installGo {v},
			for v in _repo.setupCaches {v},

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
				id:   "login"
				uses: "./"
			},

			{
				name: "Ensure the access token is masked"
				run: """
					echo "The secret is: <${{ steps.login.outputs.access_token }}>"
					"""
			},
		]
	}

	// Verify that the masking in the previous job worked in practise
	jobs: verify: {
		"runs-on": _repo.linuxMachine
		needs:     "test"
		permissions: actions: "read"

		steps: [
			{
				name: "Check logs for leak"
				env: {

					// We need the GitHub Token to call the API
					GH_TOKEN: "${{ secrets.GITHUB_TOKEN }}"
					// We import the actual secret value from Job A to search for it
					SECRET_TO_FIND: "${{ needs.test.outputs.access_token }}"
				}
				run: """
					 # 1. Download the logs for this workflow run
					 # "gh run view" gets details for the current run
					 # "--log" downloads the log archive
					 gh run view ${{ github.run_id }} --log > full_logs.txt

					 # 2. Grep the logs for the plaintext secret
					 # We use 'grep -F' for fixed string search (no regex)
					 # We use 'grep -q' for quiet mode (exit 0 if found, 1 if not)

					 EXPECTED_MASKED_STRING="The secret is: <***>"

					 if grep -Fq "$EXPECTED_MASKED_STRING" full_logs.txt; then
						echo "✅ PASS: Found expected masked log line: '$EXPECTED_MASKED_STRING'"
					 else
						echo "❌ FAIL: Could not find the masked log line. Did the job run?"
						exit 1
					 fi

					 if grep -Fq "$SECRET_TO_FIND" full_logs.txt; then
						echo "❌ FAILURE: Found the plaintext secret in the logs!"
						exit 1
					 else
						echo "✅ SUCCESS: The secret was NOT found in the logs (masking worked)."
					 fi
					"""
			},
		]
	}
}

_installGo: _repo.installGo & {
	#setupGo: with: "go-version": _repo.latestGo
	_
}

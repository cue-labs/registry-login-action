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

	let testJob = "test"

	jobs: (testJob): {
		"runs-on": _repo.linuxMachine
		permissions: "id-token": "write"

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
		needs:     testJob
		permissions: actions: "read"

		steps: [
			{
				name: "Check logs for leak"
				env: {
					// We need the GitHub Token to call the API
					GH_TOKEN: "${{ secrets.GITHUB_TOKEN }}"

					TARGET_JOB_NAME:        testJob
					EXPECTED_MASKED_STRING: "The secret is: <***>"
				}
				run: #"""
					echo "🔍 Looking for job named: '$TARGET_JOB_NAME'"

					# 1. Get the specific Job ID
					# We use the API to list all jobs in this run, then use jq to filter by name and get the ID.
					JOB_ID=$(gh api "/repos/${{ github.repository }}/actions/runs/${{ github.run_id }}/jobs" \
					  --jq ".jobs[] | select(.name == \"$TARGET_JOB_NAME\") | .id" | head -n 1)

					if [ -z "$JOB_ID" ]; then
					  echo "❌ Error: Could not find a job named '$TARGET_JOB_NAME'"
					  echo "Available jobs:"
					  gh api "/repos/${{ github.repository }}/actions/runs/${{ github.run_id }}/jobs" --jq '.jobs[].name'
					  exit 1
					fi

					echo "✅ Found Job ID: $JOB_ID"

					# 2. Download the log for ONLY that job
					# This endpoint works instantly once the specific job is done.
					gh api "/repos/${{ github.repository }}/actions/jobs/$JOB_ID/logs" > full_logs.txt

					# 3. Grep the logs for the expected masked string.
					# We use 'grep -F' for fixed string search (no regex)
					# We use 'grep -q' for quiet mode (exit 0 if found, 1 if not)


					if grep -Fq "$EXPECTED_MASKED_STRING" full_logs.txt; then
					  echo "✅ PASS: Found expected masked log line: '$EXPECTED_MASKED_STRING'"
					else
					  echo "❌ FAIL: Could not find the masked log line. Did the job run?"
					  exit 1
					fi
					"""#
			},
		]
	}
}

_installGo: _repo.installGo & {
	#setupGo: with: "go-version": _repo.latestGo
	_
}

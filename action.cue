@extern(embed)

package action

name:        "Login to CUE Registry via GitHub OIDC"
description: "Authenticate to a CUE registry using GitHub OIDC tokens"
branding: {
	icon:  "log-in"
	color: "blue"
}
inputs: {
	registry: {
		description: "CUE registry"
		required:    false
		default:     "registry.cue.works"
	}
	update_logins: {
		description: "Whether to update the local CUE logins.json file"
		required:    false
		default:     "true"
	}
}
outputs: access_token: {
	description: "The access token obtained from the registry"
	value:       "${{ steps.oidc.outputs.access_token }}"
}
runs: {
	using: "composite"
	steps: [{
		name: "Get OIDC token and login"
		id:   "oidc"
		uses: "actions/github-script@v8"
		with: {
			script: _ @embed(file=action.js,type=text)
		}
	}]
}

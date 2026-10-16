module: "github.com/cue-labs/registry-login-action"
language: {
	version: "v0.17.0"
}
deps: {
	"cue.dev/x/githubactions@v0": {
		v:       "v0.11.0"
		default: true
	}
	"github.com/cue-lang/tmp/internal/ci@v0": {
		v:       "v0.0.19"
		default: true
	}
}

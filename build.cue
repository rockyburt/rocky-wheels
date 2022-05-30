package rentalsapi

import (
	"dagger.io/dagger/core"
	"universe.dagger.io/docker"
)

_base: core.#Source & {
	path: "."
}

#PythonImageBuild: {
	pyVersion:  string
	tag:        string
	dockerfile: *{
		path: string | *"Dockerfile"
	} | {
		contents: string
	}

	_build: docker.#Dockerfile & {
		source:       _base.output
		"dockerfile": dockerfile
		buildArg: "PYTHON_EXACT_VERSION": pyVersion
	}
	output: _build.output
}

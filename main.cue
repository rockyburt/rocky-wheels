package rentalsapi

import (
	"dagger.io/dagger"
	"dagger.io/dagger/core"
)

dagger.#Plan & {
	_base: core.#Source & {
		path: "."
		exclude: ["cue.mod"]
	}
	actions: {
		makeBuilder: #PythonImageBuild & {
			source:    _base.output
			pyVersion: "3.11-rc"
			dockerfile: path: "Dockerfile.build"
			tag: "app:build-py3.11-rc"
		}
		buildWheels: #BuildWheels & {
			input:  makeBuilder.output
			source: _base.output
		}
	}
}

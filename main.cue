package rentalsapi

import (
	"dagger.io/dagger"
	"dagger.io/dagger/core"
	"universe.dagger.io/bash"
	"universe.dagger.io/docker"
)

dagger.#Plan & {
	_base: core.#Source & {
		path: "."
		exclude: ["cue.mod", "README.md", "*.cue"]
	}
	actions: {
		makeBuilder: #PythonImageBuild & {
			source:    _base.output
			pyVersion: "3.11-rc"
			dockerfile: path: "Dockerfile.build"
			tag: "builder:build-py3.11-rc"
		}
		buildWheels: #BuildWheels & {
			input:  makeBuilder.output
			source: _base.output
		}
		makeApp: docker.#Build & {
			steps: [
				#PythonImageBuild & {
					source:    _base.output
					pyVersion: "3.11-rc"
					dockerfile: path: "Dockerfile.app"
					tag: "app:build-py3.11-rc"
				},
				bash.#Run & {
					always: true
					script: contents: """
						python3 -m venv /app
						"""
				},
				bash.#Run & {
					mounts: {
						project: {
							dest:     "/app/src"
							contents: _base.output
						}
						wheels: {
							dest:     "/whl"
							contents: buildWheels.output
						}
					}
					always: true
					script: contents: """
						/app/bin/python -m pip install --upgrade pip
						/app/bin/pip install -r /whl/requirements.txt -f /whl/wheels
						"""
				},
			]
		}
		publishApp: docker.#Push & {
			image: makeApp.output
			dest:  "localhost:5042/pythonapp:1"
		}
	}
}

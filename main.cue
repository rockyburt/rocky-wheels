package rentalsapi

import (
	"dagger.io/dagger"
	"dagger.io/dagger/core"
	"universe.dagger.io/bash"
	"universe.dagger.io/docker"
	"universe.dagger.io/docker/cli"
)

dagger.#Plan & {
	client: network: "unix:///var/run/docker.sock": connect: dagger.#Socket
	client: filesystem: "./.build": write: contents: actions.buildWheels.output
	_base: core.#Source & {
		path: "."
		exclude: ["cue.mod", "README.md", "*.cue"]
	}
	_pyVersion: "3.11-rc"
	actions: {
		makeBuilder: #PythonImageBuild & {
			source:    _base.output
			pyVersion: _pyVersion
			dockerfile: path: "Dockerfile.build"
		}
		buildWheels: #BuildWheels & {
			input:  makeBuilder.output
			source: _base.output
		}
		makeApp: docker.#Build & {
			steps: [
				#PythonImageBuild & {
					source:    _base.output
					pyVersion: _pyVersion
					dockerfile: path: "Dockerfile.app"
				},
				bash.#Run & {
					mounts: {
						wheels: {
							dest:     "/app/build"
							contents: buildWheels.output
						}
					}
					script: contents: """
						/app/.venv/bin/pip install -r /app/build/requirements.txt -f /app/build/wheels
						"""
				},
			]
		}

		runTests: bash.#Run & {
			input: makeApp.output
			always: true
			script: contents: """
				python -m unittest discover -s /app/src/tests
				"""
		}
		
		saveLocal: cli.#Load & {
			// save to local docker environment as a debugging artifact
			image: makeApp.output
			host: client.network."unix:///var/run/docker.sock".connect
			tag: "pythonapp:py" + _pyVersion + "-1"
		}

		publishApp: docker.#Push & {
			image: makeApp.output
			dest:  "localhost:5042/pythonapp:1"
		}
	}
}

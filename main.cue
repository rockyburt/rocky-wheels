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
		saveLocal: cli.#Load & {
			// save to local docker environment as a debugging artifact
			image: makeApp.output
			host: client.network."unix:///var/run/docker.sock".connect
			tag: "pythonapp:1"
		}

		publishApp: docker.#Push & {
			image: makeApp.output
			dest:  "localhost:5042/pythonapp:1"
		}
	}
}

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
		exclude: ["cue.mod", "README.md", "*.cue", ".build"]
	}
	_pyVersion: "3.11-rc"
	_revision: "1"
	_tag: "pythonapp:py\(_pyVersion)-\(_revision)"

	actions: {
		// Build the builder image
		makeBuilder: #PythonImageBuild & {
			source:    _base.output
			dockerfile: path: "Dockerfile.build"
			buildArg: "PYTHON_EXACT_VERSION": _pyVersion
		}
		
		// Build all dependent Python wheels
		buildWheels: #PythonWheelsBuild & {
			source: _base.output
			input:  makeBuilder.output
		}
		
		// Create a container image with source code and dependencies installed
		makeApp: #PythonAppInstall & {
			_virtualenv: "\(buildWheels.config.rootDir)/.venv"
			source: _base.output
			buildArg: {
				"PYTHON_EXACT_VERSION": makeBuilder.buildArg.PYTHON_EXACT_VERSION
				"VENV": _virtualenv
			}
			dockerfile: path: "Dockerfile.app"
			input: buildWheels.output
			config: buildWheels.config
			pip: "\(_virtualenv)/bin/pip"
		}

		// Run all Python-based unit tests
		runTests: bash.#Run & {
			input: makeApp.output
			always: true
			script: contents: "python -m unittest discover -s \(buildWheels.config.rootDir)/src/tests"
		}
		
		// export/save the built container image into the local docker runtime
		saveLocal: cli.#Load & {
			// save to local docker environment as a debugging artifact
			image: makeApp.output
			host: client.network."unix:///var/run/docker.sock".connect
			tag: _tag
		}

		// publish the built container image to an image registry
		publishApp: docker.#Push & {
			image: makeApp.output
			dest:  "localhost:5042/\(_tag)"
		}
	}
}

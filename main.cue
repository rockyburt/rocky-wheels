package rentalsapi

import (
	"dagger.io/dagger"
	"dagger.io/dagger/core"
	"universe.dagger.io/bash"
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
			tag: "app:build-py3.11-rc"
		}
		buildWheels: #BuildWheels & {
			input:  makeBuilder.output
			source: _base.output
		}
		app: {
			_venv: bash.#Run & {
				input:  buildWheels.output
				always: true
				script: contents: """
					python3 -m venv /app
					"""
			}
			_run: bash.#Run & {
				input: _venv.output
				mounts: project: {
					dest:     "/app/src"
					contents: _base.output
				}
				always: true
				script: contents: """
					/app/bin/pip install quart
					/app/bin/python /app/src/app.py
					ls -alr /app/*
					"""
			}
		}
	}
}

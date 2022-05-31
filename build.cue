package rentalsapi

import (
	"dagger.io/dagger"
	"dagger.io/dagger/core"
	"universe.dagger.io/docker"
	"universe.dagger.io/bash"
)

#PythonImageBuild: {
	source:     dagger.#FS
	pyVersion:  string
	dockerfile: *{
		path: string | *"Dockerfile"
	} | {
		contents: string
	}

	_build: docker.#Dockerfile & {
		"source":     source
		"dockerfile": dockerfile
		buildArg: "PYTHON_EXACT_VERSION": pyVersion
	}
	output: _build.output
}

#BuildWheels: {
	input:  docker.#Image
	source: dagger.#FS

	_buildDir: "/app/build"
	_wheelsDir: "\(_buildDir)/wheels"
	_reqFile: "\(_buildDir)/requirements.txt"

	_wheels: docker.#Build & {
		steps: [
			bash.#Run & {
				"input": input
				script: contents: """
					set -e
					mkdir -p \(_wheelsDir)
					pip wheel -w \(_wheelsDir) poetry wheel setuptools
					pip install -f \(_wheelsDir) poetry wheel setuptools
					"""
			},
			bash.#Run & {
				mounts: src: {
					dest:     "/app/src"
					contents: source
				}
				workdir: "/app/src"
				script: contents: "poetry export --dev --without-hashes --format=requirements.txt > \(_reqFile)"
			},
			bash.#Run & {
				workdir: "/app/src"
				script: contents: "pip wheel -w \(_wheelsDir) -r \(_reqFile)"
			}
		]
	}

	_export: {
		contents: dagger.#FS & _subdir.output
		_subdir: core.#Subdir & {
			input: _wheels.output.rootfs
			"path": _buildDir
		}
	}

	output: _export.contents
}

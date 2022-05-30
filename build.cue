package rentalsapi

import (
	"dagger.io/dagger"
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
	_reqFile: "\(_buildDir)/requirements.txt"

	_wheels: docker.#Build & {
		steps: [
			bash.#Run & {
				"input": input
				script: contents: """
					set -e
					mkdir -p \(_buildDir)/wheels
					pip wheel -w \(_buildDir)/wheels poetry wheel setuptools
					pip install -f \(_buildDir)/wheels poetry wheel setuptools
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
				script: contents: "pip wheel -w \(_buildDir)/wheels -r \(_reqFile)"
			}
		]
	}

	_export: docker.#Run & {
		input: _wheels.output
		export: {
			directories: "\(_buildDir)": _
		}					
	}

	output: _export.export.directories["\(_buildDir)"]
}

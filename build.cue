package rentalsapi

import (
	"dagger.io/dagger"
	"universe.dagger.io/docker"
	"universe.dagger.io/bash"
)

#PythonImageBuild: {
	source:     dagger.#FS
	pyVersion:  string
	tag:        string
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
	_run:   bash.#Run & {
		"input": input
		mounts: project: {
			dest:     "/app/src"
			contents: source
		}
		workdir: "/app/src"
		script: contents: """
			set -e
			mkdir -p /app/build/wheels
			pip wheel -w /app/build/wheels poetry wheel setuptools
			pip install -f /app/build/wheels poetry wheel setuptools
			poetry export --dev --without-hashes --format=requirements.txt > /app/build/requirements.txt
			pip wheel -w /app/build/wheels -r /app/build/requirements.txt
			"""
		export: {
			directories: "/app/build": _
		}
	}
	output: _run.export.directories."/app/build"
}

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
		always:  true
		workdir: "/app/src"
		script: contents: """
			mkdir -p /whl
			poetry export --dev --without-hashes --format=requirements.txt > /whl/requirements.txt
			pip wheel -w /whl/wheels -r /whl/requirements.txt
			"""
		export: {
			directories: "/whl": {}
		}
	}
	output: _run.export.directories."/whl"
}

package rentalsapi

import (
	"dagger.io/dagger"
	"dagger.io/dagger/core"
	"universe.dagger.io/docker"
	//"universe.dagger.io/docker/cli"
)

dagger.#Plan & {
	_base: core.#Source & {
		path: "."
	}
	actions: {
		makeBuilder: #PythonImageBuild & {
			pyVersion: "3.11-rc"
			dockerfile: path: "Dockerfile.build"
			tag: "app:build-py3.11-rc"
		}
		buildWheels: docker.#Build & {
			steps: [
				makeBuilder,
				docker.#Run & {
					mounts: project: {
						dest:     "/app/src"
						contents: _base.output
					}
					always:  true
					workdir: "/app/src"
					command: {
						name: "sh"
						args: ["-c", "mkdir -p .build && poetry export --dev --without-hashes --format=requirements.txt > .build/requirements.txt && pip wheel -w /app/build/wheels -r .build/requirements.txt"]
					}
				},
			]
		}
	}
}

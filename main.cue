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
			tag: "XXXXXXXXXXXX.dkr.ecr.ca-central-1.amazonaws.com/rentals/api:build-py3.11-rc"
		}
		buildWheels: docker.#Build & {
			steps: [
				makeBuilder,
				docker.#Run & {
					mounts: project: {
						dest:     "/rentals/api/src/Rentals-API"
						contents: _base.output
					}
					always:  true
					workdir: "/rentals/api/src/Rentals-API"
					command: {
						name: "sh"
						args: ["-c", "mkdir -p .build && poetry export --dev --without-hashes --format=requirements.txt > .build/requirements.txt && cat .build/requirements.txt"]
					}
				},
			]
		}
	}
}

package rentalsapi

import (
	"dagger.io/dagger"
	"dagger.io/dagger/core"
	"universe.dagger.io/docker"
	"universe.dagger.io/bash"
)

#PythonImageBuild: {
	source:     dagger.#FS
	buildArg: [string]: string
	dockerfile: *{
		path: string | *"Dockerfile"
	} | {
		contents: string
	}

	_build: docker.#Dockerfile & {
		"source":     source
		"dockerfile": dockerfile
		"buildArg":   buildArg
	}
	output: _build.output
}

#PythonWheelsBuildConfig: {
	rootDir: string
	buildDir: string
	wheelsDir: string
	reqFile: string
}

#PythonWheelsBuild: {
	input:  docker.#Image
	source: dagger.#FS

	_rootDir: "/app"
	_buildDir: "\(_rootDir)/build"
	
	config: #PythonWheelsBuildConfig & {
		rootDir: _rootDir
		buildDir: _buildDir
		wheelsDir: "\(_buildDir)/wheels"
		reqFile: "\(_buildDir)/requirements.txt"
	}

	_wheels: docker.#Build & {
		steps: [
			bash.#Run & {
				"input": input
				script: contents: """
					set -e
					mkdir -p \(config.wheelsDir)
					pip wheel -w \(config.wheelsDir) poetry wheel setuptools
					pip install -f \(config.wheelsDir) poetry wheel setuptools
					"""
			},
			bash.#Run & {
				mounts: src: {
					dest:     "\(config.rootDir)/src"
					contents: source
				}
				workdir: "\(config.rootDir)/src"
				script: contents: "poetry export --dev --without-hashes --format=requirements.txt > \(config.reqFile)"
			},
			bash.#Run & {
				workdir: "\(config.rootDir)/src"
				script: contents: "pip wheel -w \(config.wheelsDir) -r \(config.reqFile)"
			}
		]
	}

	_export: {
		contents: dagger.#FS & _subdir.output
		_subdir: core.#Subdir & {
			input: _wheels.output.rootfs
			"path": config.buildDir
		}
	}

	output: _export.contents
}

#PythonAppInstall: {
	dockerfile: *{
		path: string | *"Dockerfile"
	} | {
		contents: string
	}
	config: #PythonWheelsBuildConfig
	input: dagger.#FS
	source: dagger.#FS
	buildArg: [string]: string
	pip: string

	app: docker.#Build & {
		steps: [
			#PythonImageBuild & {
				"source":     source
				"dockerfile": dockerfile
				"buildArg":   buildArg
			},
			bash.#Run & {
				mounts: {
					"buildDir": {
						dest:     config.buildDir
						contents: input
					}
				}
				script: contents: """
					\(pip) install --no-index --upgrade -f \(config.wheelsDir) pip
					\(pip) install --no-index -r \(config.reqFile) -f \(config.wheelsDir)
					"""
			},
		]
	}

	output: app.output
}

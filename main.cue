package pythonapp

import (
	"github.com/rockyburt/rocky-wheels/pythonext"
	"dagger.io/dagger"
	"dagger.io/dagger/core"
	"universe.dagger.io/docker"
	"universe.dagger.io/docker/cli"
)

dagger.#Plan & {
	client: network: "unix:///var/run/docker.sock": connect: dagger.#Socket
	client: network: "localhost:8000": connect: dagger.#Socket
	client: filesystem: "./.build": write: contents: actions.exportBuildArtifacts.output
	_base: core.#Source & {
		path: "."
		exclude: ["cue.mod", "README.md", "*.cue", ".build", ".git", ".gitignore"]
	}

	actions: {
		_config: {
			projectVersion:		sourceVersion.output.version
			projectName:		sourceVersion.output.name

			imageRepo: 			""
			imageTagSuffix: 	"\(projectName):\(projectVersion)"
			imageTag: 			"\(imageRepo)\(imageTagSuffix)"
		}

		_app: pythonext.#AppConfig & {
			path:		"/pythonapp"
			buildPath:	"/build"
		}

		// setup the initial image for building
		startBuildImage: pythonext.#Image & {}

		// get python version of poetry source package
		sourceVersion: pythonext.#GetPackageVersionByPoetry & {
			source: startBuildImage.output
			project: _base.output
		}

		// setup the baseImage with a Python virtualenv
		createVirtualenv: pythonext.#CreateVirtualenv & {
			app: _app
			source: startBuildImage.output
		}

		// install Poetry-derived requirements-based dependencies
		installRequirements: pythonext.#InstallPoetryRequirements & {
			app: _app
			source: createVirtualenv.output
			project: _base.output
			name: _config.projectName
		}

		// build the source package as wheel/sdist
		buildSource: pythonext.#BuildPoetrySourcePackage & {
			app: _app
			source: installRequirements.output
			project: _base.output
			name: _config.projectName
		}

		// install the built wheel
		installSource: pythonext.#InstallWheelFile & {
			app: _app
			source: buildSource.output
			wheel: buildSource.export.dist.bdistWheel.path
		}

		// export the build artifacts
		exportBuildArtifacts: core.#Nop & {
			input: buildSource.export.build
		}

		// build destination runnable image
		buildRunnableImage: docker.#Build & {
			steps: [
				docker.#Pull & {
					source: startBuildImage.baseImageTag
				},
				docker.#Copy & {
					contents: installSource.export.app
					dest: _app.path
				},
				docker.#Set & {
                	config: cmd: ["\(_app.venvDir)/bin/python", "-m", "rockywheels.app"]
            	},				
			]
		}

		// run the python tests
		runTests: docker.#Run & {
			input: buildRunnableImage.output
			always: true
			workdir: "/test"
			mounts: projectMount: {
				dest:     workdir
				contents: _base.output
			}
			command: {
				name: "\(_app.venvDir)/bin/python"
				args: ["-m", "unittest", "discover", "-s", "tests"]
			}
		}

		// run the dev app in development mode
		runDevApp: docker.#Run & {
			input: buildRunnableImage.output
			always: true
			env: {
				"QUART_ENV": "development"
			}
			command: {
				name: "\(_app.venvDir)/bin/python"
				args: ["-m", "rockywheels.app"]
			}
			ports: webApp: {
				frontend: client.network."localhost:5000"
				backend: address: "localhost:5000"
			}
		}

		// export the built image into the local docker runtime
		loadIntoDocker: cli.#Load & {
			image: buildRunnableImage.output
			host: client.network."unix:///var/run/docker.sock".connect
			tag: _config.imageTag
		}

		// publish the built image to a registry
		publisToRegistry: docker.#Push & {
			image: buildRunnableImage.output
			dest:  "localhost:5042/\(_config.imageTag)"
		}
	}
}

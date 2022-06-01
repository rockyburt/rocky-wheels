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
	client: filesystem: "./.build": write: contents: actions.exportBuildArtifacts.output
	_base: core.#Source & {
		path: "."
		exclude: ["cue.mod", "README.md", "*.cue", ".build"]
	}

	_project: "pythonapp"
	_version: "1.0"
	_imageRepo: ""
	_tagSuffix: "\(_project):\(_version)"
	_tag: "\(_imageRepo)\(_tagSuffix)"

	_app: pythonext.#AppConfig & {
		path: "/\(_project)"
		buildPath: "/build"
	}

	actions: {
		_baseImage: pythonext.#Image & {}

		// setup the baseImage with a Python virtualenv
		_createVirtualenv: pythonext.#CreateVirtualenv & {
			app: _app
			source: _baseImage.output
		}

		// install Poetry-derived requirements-based dependencies
		_buildImage: pythonext.#InstallPoetryRequirements & {
			app: _app
			source: _createVirtualenv.output
			project: _base.output
		}

		_makePythonDist: pythonext.#BuildPoetrySourcePackage & {
			app: _app
			source: _buildImage.output
			project: _base.output
		}

		installWheel: pythonext.#InstallWheelFile & {
			app: _app
			source: _makePythonDist.output
			wheel: _makePythonDist.export.dist.bdistWheel.path
		}

		// export the build artifacts
		exportBuildArtifacts: core.#Nop & {
			input: _makePythonDist.export.build
		}


		// build final image
		image: docker.#Build & {
			steps: [
				docker.#Pull & {
					source: _baseImage.baseImageTag
				},
				docker.#Copy & {
					contents: installWheel.export.app
					dest: _app.path
				},
				// docker.#Copy & {
				// 	contents: _base.output
				// 	dest: "\(_app.path)/src"
				// },
				docker.#Set & {
                	config: cmd: ["\(_app.venvDir)/bin/python", "-m", "pythonapp.app"]
            	},				
			]
		}

		// export the built image into the local docker runtime
		load: cli.#Load & {
			// save to local docker environment as a debugging artifact
			"image": image.output
			host: client.network."unix:///var/run/docker.sock".connect
			tag: _tag
		}

		// publish the built image to a registry
		publish: docker.#Push & {
			"image": image.output
			dest:  "localhost:5042/\(_tag)"
		}
	}
}

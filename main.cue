package pythonsupport

import (
	"dagger.io/dagger"
	"dagger.io/dagger/core"
	"universe.dagger.io/bash"
	"universe.dagger.io/docker"
	"universe.dagger.io/docker/cli"
)

dagger.#Plan & {
	client: network: "unix:///var/run/docker.sock": connect: dagger.#Socket
	client: filesystem: "./.build": write: contents: actions._buildImage.export.build
	_base: core.#Source & {
		path: "."
		exclude: ["cue.mod", "README.md", "*.cue", ".build"]
	}

	_project: "pythonapp"
	_version: "1.0"
	_imageRepo: ""
	_tagSuffix: "\(_project):\(_version)"
	_tag: "\(_imageRepo)\(_tagSuffix)"

	actions: {
		_baseImage: #PythonImage & {}

		// setup the baseImage with a Python virtualenv
		_createVirtualenv: #PythonCreateVirtualenv & {
			app: #PythonApp & {
				path: "/\(_project)"
				buildPath: "/build"
			}
			source: _baseImage.output
		}

		// install Poetry-derived requirements-based dependencies
		_buildImage: #PythonInstallPoetryRequirements & {
			app: _createVirtualenv.app
			source: _createVirtualenv.output
			project: _base.output
		}

		buildWheel: bash.#Run & {
			input: _buildImage.output
			mounts: projectMount: {
				dest:     _buildImage.app._projectDir
				contents: _base.output
			}
			workdir: "\(_buildImage.app._projectDir)"
			script: contents: """
				set -e
				rm -Rf dist
				poetry build
				cp dist/*.whl \(_buildImage.app._wheelsDir)/
				\(_buildImage.app.venvDir)/bin/python -m pip install dist/*.whl
			"""
		}

		_appExport: {
			contents: dagger.#FS & _subdir.output
			_subdir: core.#Subdir & {
				input: buildWheel.output.rootfs
				"path": _buildImage.app.path
			}
		}

		// build final image
		image: docker.#Build & {
			steps: [
				docker.#Pull & {
					source: _baseImage.baseImageTag
				},
				docker.#Copy & {
					contents: _appExport.contents
					dest: _buildImage.app.path
				},
				docker.#Copy & {
					contents: _base.output
					dest: "\(_buildImage.app.path)/src"
				},
				docker.#Set & {
                	config: cmd: ["\(_buildImage.app.venvDir)/bin/python", "-m", "pythonapp.app"]
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

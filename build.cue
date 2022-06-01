package pythonsupport

import (
	"dagger.io/dagger"
	"dagger.io/dagger/core"
	"universe.dagger.io/docker"
	"universe.dagger.io/bash"
)

#PythonImage: {
	baseImageTag: *"public.ecr.aws/docker/library/python:3.10-slim-bullseye" | string
	output:       _build.output

	_build: docker.#Build & {
		steps: [
			docker.#Pull & {
				source: baseImageTag
			},
			docker.#Run & {
				command: {
					name: "pip",
					args: ["install", "--upgrade", "pip"]
				}
			}
		]
	}
}

#PythonApp: {
	path: string
	buildPath: string

	venvDir:     *"\(path)/venv" | string
	_projectDir: "\(path)/project"
	_reqFile:    "\(buildPath)/requirements.txt"
	_wheelsDir:  "\(buildPath)/wheels"
}

#PythonCreateVirtualenv: {
	app: #PythonApp
	source: docker.#Image

	_build: docker.#Build & {
		steps: [
			bash.#Run & {
				input: source
				script: contents: """
					set -e
					python -m venv \(app.venvDir)
					\(app.venvDir)/bin/pip install --upgrade pip
					\(app.venvDir)/bin/pip install --upgrade wheel
				"""
			}
		]
	}

	output: _build.output
}

#PythonInstallPoetryRequirements: {
	app: #PythonApp
	source:     docker.#Image
	project:    dagger.#FS

	_reqFile:    "\(app.buildPath)/requirements.txt"
	
	_build: docker.#Build & {
		steps: [
			docker.#Run & {
				input: source
				command: {
					name: "/usr/local/bin/pip"
					args: ["install", "poetry"]
				}
			},
			bash.#Run & {
				mounts: projectMount: {
					dest:     app._projectDir
					contents: project
				}			
				workdir: app._projectDir
				script: contents: """
					set -e
					mkdir -p \(app.buildPath)
					/usr/local/bin/poetry export --format requirements.txt --dev --without-hashes > \(_reqFile)
				"""
			},
			bash.#Run & {
				script: contents: """
					set -e
					mkdir -p \(app._wheelsDir)
					\(app.venvDir)/bin/pip wheel -w \(app._wheelsDir) -r \(_reqFile)
					\(app.venvDir)/bin/pip install --no-index -f \(app._wheelsDir) -r \(_reqFile)
				"""
			},
		]
	}

	_appExport: {
		contents: dagger.#FS & _subdir.output
		_subdir: core.#Subdir & {
			input: _build.output.rootfs
			"path": app.path
		}
	}

	_buildExport: {
		contents: dagger.#FS & _subdir.output
		_subdir: core.#Subdir & {
			input: _build.output.rootfs
			"path": app.buildPath
		}
	}

	export: {
		build: _buildExport.contents
		app:   _appExport.contents
	}

	output: _build.output
}

// #PythonInstallRequirements: {
// 	virtualenv: #PythonVirtualenv
// 	source:     dagger.#FS
	
// 	_reqFile: "\(virtualenv.path)/requirements.txt"
	
// 	_build: docker.#Build & {
// 		steps: [
// 			docker.#Copy & {
// 				source: source
// 				dest:   _reqFile
// 			},
// 			docker.#Run & {
// 				input: virtualenv.output
// 				command: {
// 					name: "\(virtualenv.path)/bin/pip",
// 					args: ["-r", _reqFile]
// 				}
// 			}
// 		]
// 	}

// 	output: _build.output
// }


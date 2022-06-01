package pythonext

import (
	"dagger.io/dagger"
	"dagger.io/dagger/core"
	"universe.dagger.io/docker"
	"universe.dagger.io/bash"
)

#Image: {
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

#AppConfig: {
	path:        string
	buildPath:   string

	venvDir:     "\(path)/venv"
	projectDir:  "\(path)/project"
	wheelsDir:   "\(buildPath)/wheels"
	
	_reqFile:    "\(buildPath)/requirements.txt"
}

#Run: {
	app:        #AppConfig
	source:     docker.#Image
	workdir:    *"\(app.path)" | string
	mounts:     [name=string]: core.#Mount

	output:     _run.output

	command?: {
		name: *"\(app.venvDir)/bin/python" | string
		args: [...string]
		flags: [string]: (string | true)
	}

	_run: docker.#Run & {
		input:     source
		"workdir": workdir
		"command": command
		"mounts":  mounts
	}
}

#MakeWheel: {
	app:     #AppConfig
	source:  docker.#Image
    project: dagger.#FS

	_build: docker.#Build & {
		steps: [
			docker.#Run & {
				input: source
			}
		]
	}
}

#CreateVirtualenv: {
	app: #AppConfig
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

#ExportArtifacts: {
	app:     #AppConfig
	source:  docker.#Image

	_appExport: {
		contents: dagger.#FS & _subdir.output
		_subdir: core.#Subdir & {
			input: source.rootfs
			"path": app.path
		}
	}

	_buildExport: {
		contents: dagger.#FS & _subdir.output
		_subdir: core.#Subdir & {
			input: source.rootfs
			"path": app.buildPath
		}
	}

	export: {
		build: _buildExport.contents
		app:   _appExport.contents
	}
}

#InstallPoetryRequirements: {
	app:      #AppConfig
	source:   docker.#Image
	project:  dagger.#FS

	_reqFile: "\(app.buildPath)/requirements.txt"
	
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
					dest:     app.projectDir
					contents: project
				}			
				workdir: app.projectDir
				script: contents: """
					set -e
					mkdir -p \(app.buildPath)
					/usr/local/bin/poetry export --format requirements.txt --dev --without-hashes > \(_reqFile)
				"""
			},
			bash.#Run & {
				script: contents: """
					set -e
					mkdir -p \(app.wheelsDir)
					\(app.venvDir)/bin/pip wheel -w \(app.wheelsDir) -r \(_reqFile)
					\(app.venvDir)/bin/pip install --no-index -f \(app.wheelsDir) -r \(_reqFile)
				"""
			},
		]
	}

	_artifacts: #ExportArtifacts & {
		"app": app
		"source": source
	}

	export: {
		build: _artifacts.export.build
		app:   _artifacts.export.app
	}

	output: _build.output
}

// #InstallRequirements: {
// 	virtualenv: #Virtualenv
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

#InstallPoetryPackage: {
	app:     #AppConfig
	source:  docker.#Image
	project: dagger.#FS

	output: _install.output

	_install: bash.#Run & {
		input: source
		mounts: projectMount: {
			dest:     app.projectDir
			contents: project
		}
		workdir: app.projectDir
		script: contents: """
			set -e
			rm -Rf dist
			poetry build
			cp dist/*.whl \(app.wheelsDir)/
			\(app.venvDir)/bin/python -m pip install dist/*.whl
		"""
	}

	_artifacts: #ExportArtifacts & {
		"app": app
		"source": source
	}
	export: {
		build: _artifacts.export.build
		app:   _artifacts.export.app
	}
}

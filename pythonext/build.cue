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
	depsDir:     "\(buildPath)/deps"
	distDir:     "\(buildPath)/dist"
	srcDir:      "\(path)/src"
	
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
	name:     string

	_reqFile: "\(app.buildPath)/requirements.txt"
	
	_run: docker.#Build & {
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
					dest:     workdir
					contents: project
				}			
				workdir: "\(app.srcDir)/\(name)"
				script: contents: """
					set -e
					mkdir -p \(app.buildPath)
					/usr/local/bin/poetry export --format requirements.txt --dev --without-hashes > \(_reqFile)
				"""
			},
			bash.#Run & {
				script: contents: """
					set -e
					mkdir -p \(app.depsDir)
					\(app.venvDir)/bin/pip wheel -w \(app.depsDir) -r \(_reqFile)
					\(app.venvDir)/bin/pip install --no-index -f \(app.depsDir) -r \(_reqFile)
				"""
			},
		]
	}

	_artifacts: #ExportArtifacts & {
		"app": app
		"source": _run.output
	}

	export: {
		build: _artifacts.export.build
		app:   _artifacts.export.app
	}

	output: _run.output
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

#FileRef: {
	input:	dagger.#FS
	source:	string
	
	_targetName: core.#ReadFile & {
		"input":		input
		"path":			source
	}

	targetPath: 		_targetName.contents

	target: core.#ReadFile & {
		"input":		input
		"path":			targetPath
	}
}

#ListGlobSingle: {
	glob:		string
	input: 		docker.#Image

	_loc: "/tmp/tmp-listglobsingle"

	_run: bash.#Run & {
		"input": input
		script: contents: """
			set -e
			cd /
			echo -n `ls \(glob)` > \(_loc)
		"""
	}

	ref: #FileRef & {
		"input":		_run.output.rootfs
		"source":		_loc
	}
}

#BuildPoetrySourcePackage: {
	app:		#AppConfig
	source:		docker.#Image
	project:	dagger.#FS
	name:		string

	output:		_run.output

	bdistWheel: #ListGlobSingle & {
		glob: "\(app.distDir)/\(name)/*.whl"
		input: _run.output
	}
	sdist: #ListGlobSingle & {
		glob: "\(app.distDir)/\(name)/*.tar.gz"
		input: _run.output
	}

	_run: bash.#Run & {
		input: source
		mounts: projectMount: {
			dest:     workdir
			contents: project
		}
		workdir: "\(app.srcDir)/\(name)"
		script: contents: """
			set -e
			rm -Rf dist
			poetry build
			mkdir -p \(app.distDir)/\(name)
			cp dist/* \(app.distDir)/\(name)/
		"""
	}

	_artifacts: #ExportArtifacts & {
		"app": app
		"source": _run.output
	}
	export: {
		build: _artifacts.export.build
		app:   _artifacts.export.app
		dist: {
			"bdistWheel": bdistWheel.ref.target
			"sdist":      sdist.ref.target
		}
	}
}

#GetPackageVersionByPoetry: {
	source:		docker.#Image
	project:	dagger.#FS

	output: {
		name: _outputName.contents
		version: _outputVersion.contents
	}

	_outputName: core.#ReadFile & {
		"input":		_run.output.rootfs
		"path":			"/tmp/PACKAGE_NAME"
	}
	_outputVersion: core.#ReadFile & {
		"input":		_run.output.rootfs
		"path":			"/tmp/PACKAGE_VERSION"
	}

	_run: bash.#Run & {
		input: source
		workdir: "/package"
		mounts: projectMount: {
			dest:     workdir
			contents: project
		}
		script: contents: """
			echo -n `poetry version` > /tmp/full-version
			cat /tmp/full-version | sed -e 's/\\([a-zA-Z0-9_-]\\+\\)\\(.*\\)/\\1/' > /tmp/PACKAGE_NAME
			cat /tmp/full-version | sed -e 's/\\([a-zA-Z0-9_-]\\+\\) *\\(.*\\)/\\2/' > /tmp/PACKAGE_VERSION
		"""
	}
	"image": _run.output
}

#InstallWheelFile: {
	app:     #AppConfig
	source:  docker.#Image
	wheel:   string

	output: _run.output

	_run: docker.#Run & {
		input: source
		command: {
			name: "\(app.venvDir)/bin/pip"
			args: ["install", "--no-index", wheel]
		}
	}

	_artifacts: #ExportArtifacts & {
		"app": app
		"source": _run.output
	}

	export: {
		build: _artifacts.export.build
		app:   _artifacts.export.app
	}
}

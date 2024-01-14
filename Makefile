MAKEFLAGS += --silent
FOLDER=$(shell cd Binaries/PrefireBinary.artifactbundle/; ls -d */|head -n 1)
CUR_VERSION=$(shell echo $(FOLDER) | cut -d "-" -f 2)

build:
	set -o pipefail && xcodebuild -scheme Prefire -destination 'generic/platform=iOS'

binary:
	swift run --package-path PrefireExecutable/ -c release prefire
	rm -rf Binaries/PrefireBinary.artifactbundle/prefire-2.0.0-macos/bin/*
	cp PrefireExecutable/.build/arm64-apple-macosx/release/prefire Binaries/PrefireBinary.artifactbundle/prefire-2.0.0-macos/bin

test:
	cd PrefireExecutable; swift test

update:
	echo "New version: $(version)"
	echo "Old version: $(CUR_VERSION)"

	mv Binaries/PrefireBinary.artifactbundle/prefire-$(CUR_VERSION)-macos/ Binaries/PrefireBinary.artifactbundle/prefire-$(version)-macos/
	cd Binaries/PrefireBinary.artifactbundle; sed -i '' -e '6 s/.*/            "version": "$(version)",/g' info.json
	cd Binaries/PrefireBinary.artifactbundle; sed -i '' -e '9 s/.*/                    "path": "prefire-$(version)-macos\/bin\/prefire",/g' info.json
	cd Binaries/PrefireBinary.artifactbundle; sed -i '' -e '9 s/.*/                    "path": "prefire-$(version)-macos\/bin\/prefire",/g' info.json
	cd PrefireExecutable/Sources/PrefireExecutable/Commands/Version/; sed -i '' -e '8 s/.*/        static var value: String = "$(version)"/g' Version.swift

MAKEFLAGS += --silent
FOLDER=$(shell cd Binaries/PrefireBinary.artifactbundle/; ls -d */|head -n 1)
CUR_VERSION=$(shell echo $(FOLDER) | cut -d "-" -f 2)

build:
	set -o pipefail && xcodebuild -scheme Prefire -destination 'generic/platform=iOS'

binary:
	(cd PrefireExecutable; swift build -c release --arch arm64 --arch x86_64)
	rm -rf Binaries/PrefireBinary.artifactbundle/prefire-${CUR_VERSION}-macos/bin/*
	cp PrefireExecutable/.build/apple/products/release/prefire Binaries/PrefireBinary.artifactbundle/prefire-${CUR_VERSION}-macos/bin

test:
	cd PrefireExecutable; swift test

update:
	@[ "${version}" ] || ( echo "You have to pass version. For example: \"version=1.0.0\""; exit 1 )
	echo "New version: $(version)"
	echo "Old version: $(CUR_VERSION)"

	mv Binaries/PrefireBinary.artifactbundle/prefire-$(CUR_VERSION)-macos/ Binaries/PrefireBinary.artifactbundle/prefire-$(version)-macos/
	cd Binaries/PrefireBinary.artifactbundle; sed -i '' -e '6 s/.*/            "version": "$(version)",/g' info.json
	cd Binaries/PrefireBinary.artifactbundle; sed -i '' -e '9 s/.*/                    "path": "prefire-$(version)-macos\/bin\/prefire",/g' info.json
	cd Binaries/PrefireBinary.artifactbundle; sed -i '' -e '9 s/.*/                    "path": "prefire-$(version)-macos\/bin\/prefire",/g' info.json
	cd PrefireExecutable/Sources/prefire/Commands/Version/; sed -i '' -e '8 s/.*/        static let value: String = "$(version)"/g' Version.swift

archive:
	cp /Users/m.grishutin/Documents/Projects/Prefire/Templates/PreviewTests.stencil Binaries/PrefireBinary.artifactbundle/prefire-${CUR_VERSION}-macos/bin/
	cp /Users/m.grishutin/Documents/Projects/Prefire/Templates/PreviewModels.stencil Binaries/PrefireBinary.artifactbundle/prefire-${CUR_VERSION}-macos/bin/
	tar -czf prefire.tar.gz -C Binaries/PrefireBinary.artifactbundle/prefire-${CUR_VERSION}-macos/bin/ prefire PreviewTests.stencil PreviewModels.stencil
	rm Binaries/PrefireBinary.artifactbundle/prefire-${CUR_VERSION}-macos/bin/PreviewTests.stencil
	rm Binaries/PrefireBinary.artifactbundle/prefire-${CUR_VERSION}-macos/bin/PreviewModels.stencil

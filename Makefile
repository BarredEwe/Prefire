build:
	set -o pipefail && xcodebuild -scheme Prefire -destination 'generic/platform=iOS'

binary:
	swift run --package-path PrefireExecutable/ -c release prefire
	rm -rf Binaries/PrefireBinary.artifactbundle/prefire-2.0.0-macos/bin/*
	cp PrefireExecutable/.build/arm64-apple-macosx/release/prefire Binaries/PrefireBinary.artifactbundle/prefire-2.0.0-macos/bin

test:
	cd PrefireExecutable; swift test

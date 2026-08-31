# Prefire development tasks.
# Run `make` or `make help` to list available targets.

SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c
.DELETE_ON_ERROR:
.DEFAULT_GOAL := help

VERSION_FILE := PrefireExecutable/Sources/prefire/Commands/Version/Version.swift
ARTIFACT_BUNDLE := Binaries/PrefireBinary.artifactbundle
CUR_VERSION = $(shell sed -n 's/.*static let value: String = "\([^"]*\)".*/\1/p' $(VERSION_FILE))
BUNDLE_DIR = $(ARTIFACT_BUNDLE)/prefire-$(CUR_VERSION)-macos
BUNDLE_BIN = $(BUNDLE_DIR)/bin

# Build destination. Unversioned, so the build uses whichever iOS Simulator SDK the selected
# Xcode provides; `OS=` resolves against the SDK version and fails when it is not installed.
# Override for other platforms: make build DESTINATION='generic/platform=iOS'
DESTINATION ?= generic/platform=iOS Simulator

.PHONY: help build binary cli test test-cli update archive clean

##@ General

help: ## Show this help
	@awk 'BEGIN { \
		FS = ":.*##"; \
		printf "\n\033[1mPrefire\033[0m  version %s\n\nUsage:\n  make \033[36m<target>\033[0m\n", "$(CUR_VERSION)"; \
	} \
	/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } \
	/^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo

clean: ## Remove local SwiftPM build products and prefire.tar.gz
	rm -rf PrefireExecutable/.build .build prefire.tar.gz

##@ Build

build: ## Build Prefire (iOS Simulator, Release)
	xcodebuild \
		-scheme Prefire \
		-destination '$(DESTINATION)' \
		-configuration Release \
		-skipMacroValidation \
		-skipPackagePluginValidation \
		build \
	|| { \
		status=$$?; \
		echo ""; \
		echo "make build failed."; \
		echo "If the log above says an iOS platform is not installed, the selected Xcode"; \
		echo "($$(xcode-select -p)) is missing the iOS platform component."; \
		echo "Note that 'xcodebuild -showsdks' still lists an iOS SDK in that case: it is a stub."; \
		echo "Install the platform with:"; \
		echo "    xcodebuild -downloadPlatform iOS"; \
		echo "or point xcode-select at an Xcode that already has it."; \
		exit $$status; \
	}

binary: ## Build a universal CLI binary and copy it into the artifact bundle
	$(call require-version)
	cd PrefireExecutable && swift build -c release --arch arm64 --arch x86_64
	mkdir -p "$(BUNDLE_BIN)"
	rm -rf "$(BUNDLE_BIN)"/*
	cp PrefireExecutable/.build/apple/products/release/prefire "$(BUNDLE_BIN)/prefire"

cli: ## Build the PrefireCLI wrapper (embeds the artifact bundle)
	swift build -c release --product prefire

##@ Test

test: ## Run PrefireExecutable unit tests
	cd PrefireExecutable && swift test

test-cli: ## Run PrefireCLI unit tests
	swift test --filter PrefireCLITests

##@ Release

update: ## Bump version and rebuild the bundled CLI (make update version=x.y.z)
	$(call require-version)
	$(if $(version),,$(error Pass version, e.g. make update version=1.0.0))
	@echo "New version: $(version)"
	@echo "Old version: $(CUR_VERSION)"
	mv "$(BUNDLE_DIR)" "$(ARTIFACT_BUNDLE)/prefire-$(version)-macos"
	sed -i '' \
		-e 's/"version": "[^"]*"/"version": "$(version)"/' \
		-e 's|prefire-[^/"]*-macos|prefire-$(version)-macos|g' \
		"$(ARTIFACT_BUNDLE)/info.json"
	sed -i '' 's/static let value: String = "[^"]*"/static let value: String = "$(version)"/' "$(VERSION_FILE)"
	$(MAKE) binary

archive: ## Pack the bundled CLI into prefire.tar.gz
	$(call require-version)
	tar -czf prefire.tar.gz -C "$(BUNDLE_BIN)" prefire

define require-version
$(if $(CUR_VERSION),,$(error Could not read version from $(VERSION_FILE)))
endef

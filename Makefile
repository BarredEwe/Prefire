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

# MCP Bundle of `prefire mcp` for the MCP Registry, which wants "mcp" in the file name.
MCPB_CLI := npx --yes @anthropic-ai/mcpb@2.1.2
MCPB_STAGE := .build/mcpb
MCPB_FILE = prefire-mcp-$(CUR_VERSION).mcpb

# Build destination. Unversioned, so the build uses whichever iOS Simulator SDK the selected
# Xcode provides; `OS=` resolves against the SDK version and fails when it is not installed.
# Override for other platforms: make build DESTINATION='generic/platform=iOS'
DESTINATION ?= generic/platform=iOS Simulator

# Simulator for `make test-ios`. Picked by UDID: device names differ between Xcode versions.
IOS_SIMULATOR_ID ?= $(shell xcrun simctl list devices available iPhone | grep -oE '[0-9A-F]{8}(-[0-9A-F]{4}){3}-[0-9A-F]{12}' | head -1)

# Simulator services `make slim-sim` turns off on CI: widgets, Siri, Spotlight, iCloud, the
# stores, health, photos and the like, which a freshly booted simulator starts and the tests do
# not use. The list is the default profile of simslim (https://github.com/MobAI-App/simslim).
IOS_SIMULATOR_SLIM_JOBS := \
	com.apple.FamilyControlsAgent com.apple.GameController.gamecontrollerd \
	com.apple.MapKit.SnapshotService com.apple.Maps.geocorrectiond com.apple.Maps.mapspushd \
	com.apple.Maps.mapssyncd com.apple.PosterBoard com.apple.Safari.History \
	com.apple.Safari.SafeBrowsing.Service com.apple.Safari.passwordbreachd \
	com.apple.SafariBookmarksSyncAgent com.apple.ScreenTimeAgent com.apple.ScreenTimeSettingsAgent \
	com.apple.SecureBackupDaemon com.apple.StatusKitAgent com.apple.TrustedPeersHelper \
	com.apple.UsageTrackingAgent com.apple.WebBookmarks.webbookmarksd com.apple.activityawardsd \
	com.apple.activitysharingd com.apple.akd com.apple.amsaccountsd com.apple.amsengagementd \
	com.apple.amsondevicestoraged com.apple.announced com.apple.ap.adprivacyd \
	com.apple.ap.promotedcontentd com.apple.appleaccountd com.apple.appleaccounttransparencyd \
	com.apple.appleidsetupd com.apple.appstorecomponentsd com.apple.appstored com.apple.apsd \
	com.apple.askpermissiond com.apple.asktod com.apple.assetsd com.apple.assetsd.nebulad \
	com.apple.assetsubscriptiond com.apple.assistant_cdmd com.apple.assistant_service \
	com.apple.avatarsd com.apple.bird com.apple.businessservicesd com.apple.calaccessd \
	com.apple.carkitd com.apple.cdpd com.apple.chronod com.apple.ckdiscretionaryd com.apple.cloudd \
	com.apple.cloudphotod com.apple.cloudsettingssyncagent com.apple.communicationtrustd \
	com.apple.companiond com.apple.contacts.postersyncd com.apple.contactsd com.apple.coreidvd \
	com.apple.corespeechd com.apple.corespotlightservice com.apple.countryd \
	com.apple.dataaccess.dataaccessd com.apple.deviceaccessd com.apple.devicecheckd \
	com.apple.diagnosticextensionsd com.apple.email.maild com.apple.exchangesyncd \
	com.apple.facetimemessagestored com.apple.familycircled com.apple.familynotification \
	com.apple.feedbackd com.apple.financed com.apple.findmy.findmylocated com.apple.finhealthd \
	com.apple.fitcore com.apple.fitcore.session com.apple.fitnesscoachingd \
	com.apple.fitnessintelligenced com.apple.followupd com.apple.gamesaved \
	com.apple.generativeexperiencesd com.apple.geoanalyticsd com.apple.healthappd \
	com.apple.healthcontentd com.apple.healthd com.apple.healtheventsd com.apple.healthrecordsd \
	com.apple.homed com.apple.homeeventsd com.apple.icloudmailagent \
	com.apple.icloudsubscriptionoptimizerd com.apple.identityservicesd com.apple.ids_simd \
	com.apple.imautomatichistorydeletionagent com.apple.imcore.imtransferagent \
	com.apple.imdpersistence.IMDPersistenceAgent com.apple.ind com.apple.intelligencecontextd \
	com.apple.intelligenceflowd com.apple.intelligenceplatformd com.apple.intelligencetasksd \
	com.apple.itunescloudd com.apple.itunesstored com.apple.jetpackassetd \
	com.apple.knowledgeconstructiond com.apple.linkd com.apple.liveactivitiesd \
	com.apple.managedconfiguration.passcodenagd com.apple.maps.destinationd com.apple.mediaanalysisd \
	com.apple.mediaanalysisd.service com.apple.medialibraryd com.apple.mediastream.mstreamd \
	com.apple.merchantd com.apple.mlhostd com.apple.mlruntimed com.apple.mobileassetd \
	com.apple.modelcatalogd com.apple.modelmanagerd com.apple.musicd com.apple.naturallanguaged \
	com.apple.navd com.apple.newsd com.apple.parsec-fbf com.apple.parsecd com.apple.passd \
	com.apple.peopled com.apple.photoanalysisd com.apple.photosface com.apple.proactiveeventtrackerd \
	com.apple.protectedcloudstorage.protectedcloudkeysyncing com.apple.purplebuddy.budd \
	com.apple.rapportd com.apple.remindd com.apple.replicatord com.apple.rtcreportingd \
	com.apple.safarifetcherd com.apple.searchd com.apple.searchtoold com.apple.securityuploadd \
	com.apple.siri.acousticsignature com.apple.siri.context.service com.apple.siriactionsd \
	com.apple.siriinferenced com.apple.siriknowledged com.apple.sirittsd com.apple.sociallayerd \
	com.apple.sosd com.apple.speechmodeltrainingd com.apple.spotlightknowledged \
	com.apple.spotlightknowledged.updater com.apple.stickersd com.apple.storagedatad \
	com.apple.storekitd com.apple.suggestd com.apple.swcd com.apple.syncdefaultsd \
	com.apple.telephonyutilities.callservicesd com.apple.textunderstandingd com.apple.tipsd \
	com.apple.triald com.apple.tvremoted com.apple.videosubscriptionsd com.apple.voicebankingd \
	com.apple.voiced com.apple.wcd com.apple.weatherd com.apple.webkit.adattributiond \
	com.apple.webkit.webpushd com.apple.webprivacyd

# Where launchd_sim keeps a simulator's disabled services; it reads the file when the simulator
# boots (iOS 18.5 and later). CoreSimulator keeps services of its own in it, so only the ones of
# `make slim-sim` are added and removed. It survives `simctl erase`.
IOS_SIMULATOR_DISABLED_STORE = /private/var/tmp/com.apple.CoreSimulator.SimDevice.$(IOS_SIMULATOR_ID)/disabled.plist

.PHONY: help build binary cli test test-cli test-ios slim-sim restore-sim update archive mcpb clean

##@ General

help: ## Show this help
	@awk 'BEGIN { \
		FS = ":.*##"; \
		printf "\n\033[1mPrefire\033[0m  version %s\n\nUsage:\n  make \033[36m<target>\033[0m\n", "$(CUR_VERSION)"; \
	} \
	/^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } \
	/^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo

clean: ## Remove local SwiftPM build products, prefire.tar.gz and .mcpb files
	rm -rf PrefireExecutable/.build PrefireSnapshotTests/.build .build prefire.tar.gz prefire-mcp-*.mcpb

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

test-ios: ## Run the Prefire library tests on an iPhone simulator
	cd PrefireSnapshotTests && xcodebuild test \
		-scheme PrefireSnapshotTests-Package \
		-destination 'platform=iOS Simulator,id=$(IOS_SIMULATOR_ID)' \
		-clonedSourcePackagesDirPath .build/SourcePackages \
		-parallel-testing-enabled NO \
		-test-timeouts-enabled YES \
		-default-test-execution-time-allowance 60 \
		-skipMacroValidation \
		-skipPackagePluginValidation

slim-sim: ## CI: turn off simulator services the tests do not use (undo: make restore-sim)
	@# The services stay off on this simulator, even after it is erased, until `make restore-sim`.
	@if [ -z "$${CI:-}" ] && [ -z "$${FORCE:-}" ]; then \
		echo "make slim-sim turns off Safari, Siri, Spotlight, iCloud and more on simulator $(IOS_SIMULATOR_ID)"; \
		echo "until you run make restore-sim, even after erasing it. It is meant for CI."; \
		echo "Run it with FORCE=1 to do it here anyway."; \
		exit 1; \
	fi
	@echo "Disabling $(words $(IOS_SIMULATOR_SLIM_JOBS)) services in $(IOS_SIMULATOR_DISABLED_STORE)"
	@mkdir -p "$(dir $(IOS_SIMULATOR_DISABLED_STORE))"
	@/usr/libexec/PlistBuddy $(foreach job,$(IOS_SIMULATOR_SLIM_JOBS),-c "Delete :$(job)" -c "Add :$(job) bool true") \
		"$(IOS_SIMULATOR_DISABLED_STORE)" 2>&1 | { grep -v 'Does Not Exist' || true; }

restore-sim: ## Turn the services of `make slim-sim` back on (takes effect on the next boot)
	@[ ! -f "$(IOS_SIMULATOR_DISABLED_STORE)" ] || /usr/libexec/PlistBuddy \
		$(foreach job,$(IOS_SIMULATOR_SLIM_JOBS),-c "Delete :$(job)") \
		"$(IOS_SIMULATOR_DISABLED_STORE)" 2>&1 | { grep -v 'Does Not Exist' || true; }

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

mcpb: ## Pack the bundled CLI into prefire-mcp-<version>.mcpb and point server.json at it (needs Node)
	$(call require-version)
	rm -rf "$(MCPB_STAGE)"
	mkdir -p "$(MCPB_STAGE)/server"
	cp "$(BUNDLE_BIN)/prefire" "$(MCPB_STAGE)/server/prefire"
	cp LICENSE "$(MCPB_STAGE)/LICENSE"
	jq --arg v "$(CUR_VERSION)" '.version = $$v' mcpb/manifest.json > "$(MCPB_STAGE)/manifest.json"
	$(MCPB_CLI) validate "$(MCPB_STAGE)/manifest.json"
	$(MCPB_CLI) pack "$(MCPB_STAGE)" "$(MCPB_FILE)"
	sha=$$(shasum -a 256 "$(MCPB_FILE)" | cut -d' ' -f1); \
	jq --arg v "$(CUR_VERSION)" --arg sha "$$sha" \
		--arg url "https://github.com/BarredEwe/Prefire/releases/download/$(CUR_VERSION)/$(MCPB_FILE)" \
		'.version = $$v | .packages[0].version = $$v | .packages[0].identifier = $$url | .packages[0].fileSha256 = $$sha' \
		server.json > server.json.tmp
	mv server.json.tmp server.json

define require-version
$(if $(CUR_VERSION),,$(error Could not read version from $(VERSION_FILE)))
endef

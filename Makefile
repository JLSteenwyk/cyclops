.PHONY: build test app universal-app verify-app dmg install release update-fixture run

CYCLOPS_VERSION ?= $(shell plutil -extract CFBundleShortVersionString raw Resources/Info.plist)
CYCLOPS_BUILD_NUMBER ?= $(shell plutil -extract CFBundleVersion raw Resources/Info.plist)

build:
	swift build

test:
	swift test

app:
	CYCLOPS_VERSION="$(CYCLOPS_VERSION)" \
	CYCLOPS_BUILD_NUMBER="$(CYCLOPS_BUILD_NUMBER)" \
	./scripts/build-app.sh

universal-app:
	CYCLOPS_VERSION="$(CYCLOPS_VERSION)" \
	CYCLOPS_BUILD_NUMBER="$(CYCLOPS_BUILD_NUMBER)" \
	CYCLOPS_ARCHITECTURES="arm64 x86_64" \
	./scripts/build-app.sh

verify-app:
	CYCLOPS_EXPECTED_VERSION="$(CYCLOPS_VERSION)" \
	CYCLOPS_EXPECTED_BUILD_NUMBER="$(CYCLOPS_BUILD_NUMBER)" \
	./scripts/verify-app.sh

dmg: universal-app
	CYCLOPS_EXPECTED_VERSION="$(CYCLOPS_VERSION)" \
	CYCLOPS_EXPECTED_BUILD_NUMBER="$(CYCLOPS_BUILD_NUMBER)" \
	CYCLOPS_EXPECTED_ARCHITECTURES="arm64 x86_64" \
	./scripts/verify-app.sh
	./scripts/create-dmg.sh

install: universal-app
	CYCLOPS_EXPECTED_VERSION="$(CYCLOPS_VERSION)" \
	CYCLOPS_EXPECTED_BUILD_NUMBER="$(CYCLOPS_BUILD_NUMBER)" \
	CYCLOPS_EXPECTED_ARCHITECTURES="arm64 x86_64" \
	./scripts/verify-app.sh
	./scripts/install-app.sh

release:
	./scripts/release.sh

update-fixture:
	./scripts/create-update-fixture.sh

run: app
	open dist/Cyclops.app

.PHONY: build test app universal-app verify-app update-fixture run

POCUS_VERSION ?= $(shell plutil -extract CFBundleShortVersionString raw Resources/Info.plist)
POCUS_BUILD_NUMBER ?= $(shell plutil -extract CFBundleVersion raw Resources/Info.plist)

build:
	swift build

test:
	swift test

app:
	POCUS_VERSION="$(POCUS_VERSION)" \
	POCUS_BUILD_NUMBER="$(POCUS_BUILD_NUMBER)" \
	./scripts/build-app.sh

universal-app:
	POCUS_VERSION="$(POCUS_VERSION)" \
	POCUS_BUILD_NUMBER="$(POCUS_BUILD_NUMBER)" \
	POCUS_ARCHITECTURES="arm64 x86_64" \
	./scripts/build-app.sh

verify-app:
	POCUS_EXPECTED_VERSION="$(POCUS_VERSION)" \
	POCUS_EXPECTED_BUILD_NUMBER="$(POCUS_BUILD_NUMBER)" \
	./scripts/verify-app.sh

update-fixture:
	./scripts/create-update-fixture.sh

run: app
	open dist/Pocus.app

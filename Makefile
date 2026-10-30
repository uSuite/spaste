# sPaste build entry points. Every command a session needs is a target here.

VERSION := $(shell cat VERSION)
BUILD_NUMBER := $(shell git rev-list --count HEAD 2>/dev/null || echo 1)
CLT := /Library/Developer/CommandLineTools

# Use Xcode when it is usable (licence accepted), else fall back to the
# Command Line Tools, whose Swift Testing macros need an explicit plugin path.
XCODE_OK := $(shell xcrun swift --version >/dev/null 2>&1 && echo yes)
ifeq ($(XCODE_OK),yes)
SWIFT := swift
TEST_FLAGS :=
else
SWIFT := DEVELOPER_DIR=$(CLT) swift
TEST_FLAGS := -Xswiftc -plugin-path -Xswiftc $(CLT)/usr/lib/swift/host/plugins/testing
endif
XCODEGEN := $(shell command -v xcodegen 2>/dev/null)

.PHONY: gen build test test-common app run smoke clean version

gen:
	@test -n "$(XCODEGEN)" || { echo "xcodegen missing: brew install xcodegen"; exit 1; }
	xcodegen generate

build:
	$(SWIFT) build

# swift test does not run a dependency's tests, so the shared code's run first
# when it is checked out beside this repository.
test: test-common
	$(SWIFT) test $(TEST_FLAGS)

test-common:
	@if [ -f ../scommon/Package.swift ]; then $(MAKE) -C ../scommon test; else echo "test-common: no ../scommon, its tests run in its own repository"; fi

# An SPM build wrapped into an ad hoc signed bundle by scripts/bundle.sh, the
# same path on every machine; the XcodeGen project is for debugging in Xcode.
app:
	SWIFT="$(SWIFT)" VERSION=$(VERSION) BUILD_NUMBER=$(BUILD_NUMBER) scripts/bundle.sh

run: app
	-pkill -x sPaste
	open -n build/sPaste.app

smoke: app
	scripts/smoke.sh

clean:
	rm -rf .build build

version:
	@echo $(VERSION)

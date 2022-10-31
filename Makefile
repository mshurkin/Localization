TEMPORARY_FOLDER = $(CURDIR)/tmp
TARGET_NAME = localization

SWIFT_BUILD_FLAGS = -c release --arch arm64 --arch x86_64
BUILD_FOLDER = $(shell swift build $(SWIFT_BUILD_FLAGS) --show-bin-path)

EXECUTABLE = $(BUILD_FOLDER)/$(TARGET_NAME)
ARTIFACT_BUNDLE_PATH = $(TEMPORARY_FOLDER)/$(TARGET_NAME).artifactbundle

LICENSE_PATH = $(CURDIR)/LICENSE

.PHONY: all build spm clean help

## all: Create the binary file for SPM with given version and then clean up the project directory
all: spm
	@$(MAKE) clean

## build: Build the executable file
build: clean
	swift build $(SWIFT_BUILD_FLAGS)

## spm: Create the binary file for SPM with given version
spm: build
	mkdir -p "$(ARTIFACT_BUNDLE_PATH)/$(TARGET_NAME)-$(version)-macos/bin"
	sed 's/___VERSION___/$(version)/g' Templates/info.json > "$(ARTIFACT_BUNDLE_PATH)/info.json"
	cp -f "$(EXECUTABLE)" "$(ARTIFACT_BUNDLE_PATH)/$(TARGET_NAME)-$(version)-macos/bin"
	cp -f "$(LICENSE_PATH)" "$(ARTIFACT_BUNDLE_PATH)"
#	zip -yr - "$(ARTIFACT_BUNDLE_PATH)" > "./$(TARGET_NAME).artifactbundle.zip"
	rm -rf "Binaries/$(TARGET_NAME).artifactbundle"
	cp -R "$(ARTIFACT_BUNDLE_PATH)" "Binaries"

## clean: Clean up the project directory
clean:
	rm -rf "$(TEMPORARY_FOLDER)"
#	rm -f "./*.zip"
	swift package clean

## help: Print this message
help:
	@echo "Usage:"
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed 's/^/ /' | sort

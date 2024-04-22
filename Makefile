BIN_PATH = $(shell swift build --show-bin-path)
XCTEST_PATH = $(shell find "$(BIN_PATH)" -name '*.xctest')
COV_BIN = "$(XCTEST_PATH)"/Contents/MacOs/$(shell basename "$(XCTEST_PATH)" .xctest)

PLATFORM_IOS = iOS Simulator,name=iPhone 14 Pro
PLATFORM_MACOS = macOS
PLATFORM_MAC_CATALYST = macOS,variant=Mac Catalyst
PLATFORM_TVOS = tvOS Simulator,name=Apple TV
PLATFORM_WATCHOS = watchOS Simulator,name=Apple Watch Series 8 (45mm)

CONFIG := debug

clean:
	rm -rf .build

test-macos: clean
		set -o pipefail && \
		xcodebuild test \
				-skipMarcoValidation \
				-scheme swift-tca-loadable-Package \
				-destination platform="$(PLATFORM_MACOS)"

test-ios: clean
		set -o pipefail && \
		xcodebuild test \
				-skipMarcoValidation \
				-scheme swift-tca-loadable-Package \
				-destination platform="$(PLATFORM_IOS)"

test-mac-catalyst: clean
		set -o pipefail && \
		xcodebuild test \
				-skipMarcoValidation \
				-scheme swift-tca-loadable-Package \
				-destination platform="$(PLATFORM_MAC_CATALYST)"

test-tvos: clean
		set -o pipefail && \
		xcodebuild test \
				-skipMarcoValidation \
				-scheme swift-tca-loadable-Package \
				-destination platform="$(PLATFORM_TVOS)"

test-watchos: clean
		set -o pipefail && \
		xcodebuild test \
				-skipMarcoValidation \
				-scheme swift-tca-loadable-Package \
				-destination platform="$(PLATFORM_WATCHOS)"

test-swift: clean
	swift test --enable-code-coverage

test-library: test-macos test-ios test-mac-catalyst test-tvos test-watchos

code-cov-report:
		@xcrun llvm-cov report \
			$(COV_BIN) \
			-instr-profile=.build/debug/codecov/default.profdata \
			-ignore-filename-regex=".build|Tests" \
			-use-color

format:
	swift format \
		--ignore-unparsable-files \
		--in-place \
		--recursive \
		./Package.swift \
		./Sources

build-documentation:
	swift package \
		--allow-writing-to-directory ./docs \
		generate-documentation \
		--target Loadable \
		--disable-indexing \
		--transform-for-static-hosting \
		--hosting-base-path swift-tca-loadable \
		--output-path ./docs

preview-documentation:
	swift package \
		--disable-sandbox \
		preview-documentation \
		--target Loadable

BIN_PATH = $(shell swift build --show-bin-path)
XCTEST_PATH = $(shell find "$(BIN_PATH)" -name '*.xctest')
COV_BIN = "$(XCTEST_PATH)"/Contents/MacOs/$(shell basename "$(XCTEST_PATH)" .xctest)
PLATFORM_IOS = iOS Simulator,name=iPhone 14 Pro
PLATFORM_MACOS = macOS
CONFIG := debug

test-macos:
		set -o pipefail && \
		xcodebuild test \
				-scheme swift-tca-loadable-Package \
				-destination platform="macOS"

test-ios:
		set -o pipefail && \
		xcodebuild test \
				-scheme swift-tca-loadable-Package \
				-destination platform="iOS Simulator,name=iPhone 11 Pro Max"

test-swift:
	swift test --enable-code-coverage

test-all: test-macos test-ios

test-library:
	for platform in "$(PLATFORM_IOS)" "$(PLATFORM_MACOS)"; do \
		xcodebuild test \
			-configuration $(CONFIG) \
			-workspace Loadable.xcworkspace \
			-scheme swift-tca-loadable \
			-destination platform="$$platform" || exit 1; \
	done;

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

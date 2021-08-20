BIN_PATH = $(shell swift build --show-bin-path)
XCTEST_PATH = $(shell find "$(BIN_PATH)" -name '*.xctest')
COV_BIN = "$(XCTEST_PATH)"/Contents/MacOs/$(shell basename "$(XCTEST_PATH)" .xctest)

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

code-cov-report:
		@xcrun llvm-cov report \
			$(COV_BIN) \
			-instr-profile=.build/debug/codecov/default.profdata \
			-ignore-filename-regex=".build|Tests" \
			-use-color

format:
	@docker run \
		--rm \
		--workdir "/work" \
		--volume "$(PWD):/work" \
		--platform linux/amd64 \
		mhoush/swift-format:latest \
		format \
		--in-place \
		--recursive \
		./Package.swift \
		./Sources/

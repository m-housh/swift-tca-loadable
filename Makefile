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

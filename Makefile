NAME = ImageLoader
WORKSPACE = $(NAME).xcworkspace

test:
	xcodebuild \
		clean test \
		-workspace $(WORKSPACE) \
		-scheme $(NAME) test \
		-sdk iphonesimulator \
		-configuration Debug \
		OBJROOT=build \
		TEST_AFTER_BUILD=YES \
		GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES \
		GCC_GENERATE_TEST_COVERAGE_FILES=YES

pod:
	rm -rf Pods $(WORKSPACE)
	pod install

send-coverage:
	coveralls \
		-e ImageLoaderTests -e Pods -e ImageLoaderExample -e ImageLoader/UIImageView+ImageLoader.h

NAME = ImageLoader
PROJECT = $(NAME).xcodeproj
WORKSPACE = $(NAME).xcworkspace

clean:
	xcodebuild \
		-workspace $(WORKSPACE) \
		-scheme $(NAME) \
		clean

test:
	xcodebuild \
		-workspace $(WORKSPACE) \
		GCC_INSTRUMENT_PROGRAM_FLOW_ARCS=YES \
		GCC_GENERATE_TEST_COVERAGE_FILES=YES

pod:
	rm -rf Pods $(WORKSPACE)
	pod install

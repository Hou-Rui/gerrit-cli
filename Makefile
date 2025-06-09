.PHONY: all build clean

all: build
build: gerrit.pl
	mkdir -p build
	fatpack pack $^ > build/gerrit
clean:
	rm -rf build fatlib
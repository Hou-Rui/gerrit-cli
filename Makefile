.PHONY: all clean

all: gerrit
gerrit: gerrit.pl
	mkdir -p build
	pp $^ -o build/gerrit
clean:
	$(RM) -r build
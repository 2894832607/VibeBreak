.PHONY: build test app install uninstall clean

build:
	swift build

test:
	./Scripts/test.sh

app:
	./Scripts/build-app.sh

install:
	./Scripts/install.sh

uninstall:
	./Scripts/uninstall.sh

clean:
	swift package clean
	rm -rf dist

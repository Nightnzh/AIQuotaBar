.PHONY: all build run test clean

all: build

build:
	@./scripts/build_app.sh

run: build
	@open AIQuotaBar.app

test:
	@swift test --scratch-path .build

clean:
	@rm -rf .build AIQuotaBar.app

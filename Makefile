.PHONY: build test test-fe test-forge docs clean

# Build Fe contracts and convert hex artifacts to binary
build:
	cd contracts && fe build
	@for f in contracts/out/*.bin; do \
		xxd -r -p "$$f" "$$f.tmp" && mv "$$f.tmp" "$$f"; \
	done

# Run all tests (Fe + Forge)
test: test-fe test-forge

# Run Fe tests only
test-fe:
	cd contracts && fe test

# Build Fe contracts, then run Forge tests against fresh artifacts
test-forge: build
	forge test

# Generate Fe documentation (docs.json, fe-web.js, index.html)
docs:
	cd contracts && fe doc -o ../web/static/api json
	cd contracts && fe doc -o ../web/static/api bundle
	cd contracts && fe doc -o ../web/static/api static

# Remove all build artifacts
clean:
	rm -rf contracts/out
	rm -rf forge-out
	rm -rf cache
	rm -rf web/static/api

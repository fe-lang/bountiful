.PHONY: build test test-fe test-forge deploy docs clean

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

# Deploy contracts and write manifest
# Local:   make deploy RPC_URL=http://localhost:8545
# Mainnet: make deploy RPC_URL=https://... LEDGER=1 DEPLOYER_ADDRESS=0x...
deploy: build
	forge script script/Deploy.s.sol --rpc-url $(RPC_URL) --broadcast $(if $(LEDGER),--ledger)

# Pick the best deployment manifest and copy to web/ for Zola
prepare-web:
	@best=""; \
	for f in deployments/1_*.json; do \
		[ -f "$$f" ] || continue; \
		block=$$(echo "$$f" | sed 's/.*_//; s/\.json//'); \
		if [ -z "$$best" ] || [ "$$block" -gt "$$best_block" ]; then \
			best="$$f"; best_block="$$block"; \
		fi; \
	done; \
	if [ -z "$$best" ]; then \
		best=$$(ls deployments/*.json 2>/dev/null | head -1); \
	fi; \
	if [ -n "$$best" ]; then \
		chain=$$(basename "$$best" | sed 's/_.*//' ); \
		cp "$$best" web/deployment.json; \
		sed -i "1s/{/{\"_chainId\": $$chain,/" web/deployment.json; \
		echo "Using deployment manifest: $$best (chain $$chain)"; \
	else \
		echo '{}' > web/deployment.json; \
		echo "Warning: no deployment manifest found"; \
	fi

# Generate Fe documentation (docs.json, fe-web.js, index.html)
docs: prepare-web
	cd contracts && fe doc -o ../web/static/api json
	cd contracts && fe doc -o ../web/static/api bundle
	cd contracts && fe doc -o ../web/static/api static
	sed -i 's/Fe Docs/Bountiful Docs/g; s/Fe Documentation/Bountiful Documentation/g' web/static/api/index.html

# Remove all build artifacts
clean:
	rm -rf contracts/out
	rm -rf forge-out
	rm -rf cache
	rm -rf web/static/api

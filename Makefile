SHELL := /bin/sh

.PHONY: tools download verify identify extract inventory analyze report test package clean-work

tools:
	docker build -t mt3000-modem-analysis:2026-07-19 tools/analysis-container

download:
	./scripts/download-firmware.sh

verify:
	./scripts/verify-firmware.sh

identify:
	./scripts/identify-container.sh

extract:
	./scripts/extract-firmware.sh

inventory:
	./scripts/inventory-filesystem.sh
	./scripts/inventory-packages.sh
	./scripts/find-modem-components.sh

analyze:
	./scripts/analyze-frontend.sh
	./scripts/analyze-elf.sh
	./scripts/extract-strings.sh

report:
	./scripts/generate-report.sh

test:
	./tests/run.sh

package:
	./scripts/build-package.sh

clean-work:
	@echo "Remove ignored work directories manually after reviewing their paths."


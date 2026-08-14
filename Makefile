check:
	sh scripts/validate.sh

check-pilot:
	sh scripts/pilot-validate.sh

.PHONY: check check-pilot

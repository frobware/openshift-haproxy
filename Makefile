.PHONY: all
all:
	nix build .\#ocp-haproxy-meta --json \
	  | jq -r '.[].outputs | to_entries[].value' \
	  | cachix push frobware

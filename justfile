# vim: set ft=make :

help:
	@echo "just is a convenient command runner. Try just -l"

setup:
	#!/usr/bin/env bash
	set -euo pipefail
	pushd dockerfiles/node
	./build.sh
	popd
	./bin/yarn add gatsby-cli

deploy:
	#!/usr/bin/env bash
	set -euo pipefail
	pushd front
	../bin/node gatsby build
	../bin/node netlify deploy -p build -s eatnutrients

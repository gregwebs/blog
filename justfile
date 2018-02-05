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
	./bin/yarn add netlify-cli

deploy:
	#!/usr/bin/env bash
	set -euo pipefail
	pushd gatsby-blog
	../bin/node gatsby build
	popd
	./bin/node netlify deploy -p gatsby-blog/public -s blog-greg

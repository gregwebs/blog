+++
title = "Github Actions for trunk based development"
date = 2025-02-11
[taxonomies]
tags = ["github", "ci", "programming"]
+++

## Overview

Goal: On Github make it easy to use trunk based development and releases to deploy an application to staging and production.

A set of supporting Github Actions outlined here are [available to use](https://github.com/gregwebs/.github/tree/main/workflow-templates).


<details>
    <summary>Table of Contents</summary>
    <!-- toc -->
</details>

## Trunk Based Development versus Git Flow on Github

Github default tooling makes it easy to automate working with branches using pull requests, but releases can be more difficult.

This can favor a [Git Flow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow) style of development. However, we can use the flexibility of Github Actions to make [trunk based development](https://trunkbaseddevelopment.com/) work just as well.

In trunk based development work is performed on a long-lived trunk branch (usually "main"). Releases candidates are tagged from main or from short lived release branches made from main.

![Trunk Based Development Diagram](trunk-based.png)
*trunkbaseddevelopment.com*

Git Flow is actually quite similiar, but the development branch is usually called "develop".
Git Flow also specifies one additional step: merging to a long-lived release branch (usually "main") before the release.

![Git Flow Development Diagram](git-flow-diagram.svg)
*Atlassian*


In theory Git Flow creates the additional overhead of maintaining an additional long-lived branches with no benefit compared to trunk based development. In practice with Github the benefit is that the process can be managed entirely with branches and thus Github Pull Requests.


## Overview of trunk based development on Github

There are 2 independent flows: development and release. Development is going to be a standard Pull Request workflow. Lets focus on the release flow:

1) Create a release in Github
  * This pushes deployment artifacts (e.g. push a container to a registry)
  * auto-deploy the release to a staging environment
2) Promote the release to being the "latest" release
  * This will trigger a deployment to production
3) The ability to quickly rollback is available- there is a manual deploy action that can select a (previous) release.

Many minor variations of the above are possible to suit your needs as long as they can be triggered either by release creation/promotion or manual workflow triggers.


## Github Actions using release triggers

As a quick overview of Github actions:
* Github Actions can be re-used as a library with the `uses` clause.
* They can also be invoked directly with workflow_call.
* An environment can be specified: this will apply different configuration values to the workflow


At the top level there is a prerelease action that calls a build or build-deploy action.

```yaml
name: "deploy prerelease"

on:
  release:
    types: [prereleased]

  push:
    branches:
      - 'test-ci/deploy-prerelease/*'

jobs:
  deploy:
    if: "${{\
      startsWith(github.ref, 'refs/tags/release/prod') \
      }}"
    uses: ./.github/workflows/build-deploy.yaml
    with:
      # A prerelease is never deployed to production
      # A production prerelease is auto-deployed to staging for preview
      environment: "${{\
        (startsWith(github.ref, 'refs/tags/release/prod') && 'staging') \
        }}"
    secrets: inherit

  # If the production environment is isolated from the staging environment,
  # then we need to build and push the production artifacts without deploying them.
  # We can do this optimistically once the staging deployment is successful.
  build-prod:
    needs: deploy
    if: "${{ startsWith(github.ref, 'refs/tags/release/prod') }}"
    uses: ./.github/workflows/build.yaml
    with:
      environment: production
      artifacts: true
      notify: true
    secrets: inherit
```

Marking a release as the latest release deploys to production:

```yaml
name: Deploy release

on:
  release:
    types: [released]

  push:
    branches:
      - 'test-ci/deploy-release/*'

# This only calls deploy, assuming that deploy-prerelease already pushed the production artifacts
# If you are not using that flow you can use the build-deploy workflow instead
jobs:
  build:
    uses: ./.github/workflows/deploy.yaml
    with:
      environment: 'production'
    secrets: inherit
```

## Building and deploying

The build-deploy action combines building an deploying. You may want to make it callable.
Similarly, the deploy action can be callable: this allows for a quick rollback.
The build action can be re-used for pull requests.

```yaml
name: Build and Deploy

on:
  workflow_dispatch:
    inputs:
      environment:
        description: environment to push docker image to
        required: true
        type: choice
        options:
          - qa
          - staging
          - production

  workflow_call:
    inputs:
      environment:
        description: environment to push docker image to
        required: true
        type: string
      ref:
        required: false
        type: string

  push:
    branches:
      - 'test-ci/build-deploy/*'

jobs:
  # The build job validates and pushes artifacts
  build:
    uses: ./.github/workflows/build.yaml
    with:
      artifacts: true
      ref: "${{inputs.ref}}"
      environment: "${{inputs.environment}}"
    secrets: inherit

  deploy:
    needs: build
    uses: ./.github/workflows/deploy.yaml
    with:
      ref: "${{inputs.ref}}"
      environment: "${{inputs.environment}}"
    secrets: inherit
```


## Automating release pushing

We can automate pushing a tag and creating a release.
This script is designed for applications and assumes a date-based release versioning.  It will:

* generate the tag with an incremented postfix if there are multiple releases in a day
* push the tag
* generate a url to click on to create a release in Github for the tag

```sh
#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT=${ENVIRONMENT:-prod}

git fetch origin --tags

# Find the next available tag
i=1
tag="release/$ENVIRONMENT/$(date -u "+%Y-%m-%d")/$i"
until [[ -z $(git tag -l "$tag") ]] ; do
    i=$((i + 1))
    tag="release/$ENVIRONMENT/$(date -u "+%Y-%m-%d")/$i"
done

git tag "$tag"
git push origin "$tag"

if repo=$(git remote -v | grep push | awk '{print $2}' | cut -d ':' -f 2) ; then
	echo "Create a release with this url:"
	echo "https://github.com/${repo}/releases/new?tag=${tag}"
fi
```

Github will auto-generate release notes.
There is still a manual button click to make the release and the selection of the previous release to compare against.


## Conclusion

Github already has a release feature that is perfect for trunk based development.
If we add in some additional automation trunk based development can be just as easy to use on Github as Git flow.

## References

* [Github Action workflow templates](https://github.com/gregwebs/.github/tree/main/workflow-templates)
* [Deploying from a Github release to AWS ECS](https://medium.com/@smadan2703/use-github-actions-for-trunk-based-development-to-deploy-aws-ecs-service-13669b06ad8b)
* [Deploying from a Github release with NPM to AWS](https://blog.jannikwempe.com/github-actions-trunk-based-development)
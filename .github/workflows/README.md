## CI/CD

There are 5 main stages that run on GitHub actions:

* Linting
* Test
* Test `main` versions
* Package
* Release

There are some other stages that run for every push on the main branches:

* [Microbenchmark](./microbenchmark.yml)
* [Snapshoty](./snapshoty.yml)

### Scenarios

* Compatibility matrix runs on branches, tags and PRs basis.
* Tests should be triggered on branch, tag and PR basis.
* Commits that are only affecting the docs files should not trigger any test or similar stages that are not required.
* Automated release in the CI gets triggered when a tag release is created.
* **This is not the case yet**, but if Github secrets are required then Pull Requests from forked repositories won't run any build accessing those secrets. If needed, then create a feature branch.

### Compatibility matrix

Ruby agent supports compatibility to different ruby versions and frameworks, those are defined in:

* [frameworks](../../.ci/.framework.yml) for all the PRs.
* [frameworks](../../.ci/.main_framework.yml) for all the PRs using the `main` branches.
* Ruby [versions](../../.ci/.ruby.yml) for all the `*nix` builds.
* [Exclude list](../../.ci/.exclude.yml) for the above entries.

### How to interact with the CI?

#### On a PR basis

Once a PR has been opened then there are two different ways you can trigger builds in the CI:

1. Commit based
1. UI based, any Elasticians can force a build through the GitHub UI

#### Branches

Every time there is a merge to main or any release branches the whole workflow will compile and test every entry in the compatibility matrix for Linux.

### Release process

This process has been fully automated and it gets triggered when a tag release has been created.
The tag release follows the naming convention: `v.<major>.<minor>.<patch>`, where `<major>`, `<minor>` and `<patch>`.

### OpenTelemetry

There is a GitHub workflow in charge to populate what the workflow run in terms of jobs and steps. Those details can be seen in [here](https://ela.st/oblt-ci-cd-stats) (**NOTE**: only available for Elasticians).

## Bump automation

[updatecli](https://www.updatecli.io/) is the tool we use to automatically update the specs
the [APM agents](./updatecli.yml) use.

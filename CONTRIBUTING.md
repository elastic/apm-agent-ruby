# Contributing to the APM Agent

The APM Agent is open source and we love to receive contributions from our community — you!

There are many ways to contribute,
from writing tutorials or blog posts,
improving the documentation,
submitting bug reports and feature requests or writing code.

You can get in touch with us through [Discuss](https://discuss.elastic.co/c/apm),
feedback and ideas are always welcome.

## Code contributions

If you have a bugfix or new feature that you would like to contribute,
please find or open an issue about it first.
Talk about what you would like to do.
It may be that somebody is already working on it,
or that there are particular issues that you should know about before implementing the change.

### Workflow

All feature development and most bug fixes hit the main branch first.
Pull requests should be reviewed by someone with commit access.
Once approved, the author of the pull request,
or reviewer if the author does not have commit access,
should "Squash and merge".

### Testing

To do a full test run, use either `bundle exec rspec` or `rake spec`. Individual specs should also run as expected. The Mongo test needs a Mongo instance running, but will start one itself if Docker is installed.

To test other platform, use the Docker setup and scripts like `spec.sh RUBY_DOCKER_IMAGE FRAMEWORK`.

```sh
$ spec/scripts/spec.sh ruby:2.6 rails-5.2
```

### Releasing

To release a new version:

1. Update `VERSION` in `lib/elastic_apm/version.rb` according to the changes (major, minor, patch).
1. Add a section for the new version to `docs/release-notes/index.md`, including the release date and links to notable PRs.
1. For Majors: Add a new row to the EOL table in `docs/reference/upgrading.md`. The EOL date is the release date plus 18 months.
1. Open a PR with the changes above, with a title in the style of `vX.X.X`, and merge it once green.
1. Tag the merged commit and push the tag to GitHub:
    ```sh
    git tag vX.X.X
    git push upstream vX.X.X
    ```
1. The tag triggers the `release` workflow, which will...
    1. Build the gem and publish it to RubyGems using [trusted publishing](https://guides.rubygems.org/trusted-publishing/) (no API key involved).
    1. Generate build provenance attestation.
    1. Create a GitHub release with auto-generated notes.
    1. Update the `4.x` branch to be at the released commit and push it to GitHub.

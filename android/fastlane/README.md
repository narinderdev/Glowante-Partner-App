fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android dev

```sh
[bundle exec] fastlane android dev
```

Build & upload the dev flavor to Play Console internal testing

### android staging

```sh
[bundle exec] fastlane android staging
```

Build & upload the staging (test) flavor to Play Console internal testing

### android prod

```sh
[bundle exec] fastlane android prod
```

Build & upload the prod flavor to Play Console. Defaults to internal testing; pass track:production to release to production (uploaded as a draft — publish manually in Play Console — unless you also pass release_status:completed).

### android all

```sh
[bundle exec] fastlane android all
```

Build & upload all three flavors, one after another

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).

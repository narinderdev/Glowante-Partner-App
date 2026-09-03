fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios dev

```sh
[bundle exec] fastlane ios dev
```

Build & upload the dev flavor to TestFlight

### ios staging

```sh
[bundle exec] fastlane ios staging
```

Build & upload the staging (test) flavor to TestFlight

### ios prod

```sh
[bundle exec] fastlane ios prod
```

Build & upload the prod flavor to TestFlight

### ios all

```sh
[bundle exec] fastlane ios all
```

Build & upload all three flavors to TestFlight, one after another

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).

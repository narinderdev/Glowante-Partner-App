#!/usr/bin/env bash
# Runs any `flutter` command with the right --flavor and matching
# --dart-define=APP_FLAVOR so the two never drift apart.
#
# Usage:
#   scripts/flutter_flavor.sh <dev|staging|prod> <flutter args...>
#
# Examples:
#   scripts/flutter_flavor.sh dev run -d <device-id>
#   scripts/flutter_flavor.sh staging build apk --release
#   scripts/flutter_flavor.sh prod build ipa --release
set -euo pipefail

FLAVOR="${1:-}"
if [[ -z "$FLAVOR" ]]; then
  echo "Usage: scripts/flutter_flavor.sh <dev|staging|prod> <flutter args...>" >&2
  exit 1
fi
shift

case "$FLAVOR" in
  dev) DART_FLAVOR="dev" ;;
  # Android's flavor is named "staging" (AGP reserves flavor names that
  # start with "test"), but lib/config/app_environment.dart's enum/base
  # URL for this environment is still called "test" — this is the one
  # place that mapping lives.
  staging) DART_FLAVOR="test" ;;
  prod) DART_FLAVOR="prod" ;;
  *)
    echo "Unknown flavor: $FLAVOR (expected dev, staging, or prod)" >&2
    exit 1
    ;;
esac

set -x
exec flutter "$@" --flavor "$FLAVOR" --dart-define=APP_FLAVOR="$DART_FLAVOR"

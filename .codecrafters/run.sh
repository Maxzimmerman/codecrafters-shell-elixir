#!/bin/sh
#
# This script is used to run your program on CodeCrafters
#
# This runs after .codecrafters/compile.sh
#
# Learn more: https://codecrafters.io/program-interface

set -e # Exit on failure

stty -icanon -echo min 1 2>/dev/null || true
exec /tmp/codecrafters-build-shell-elixir "$@"

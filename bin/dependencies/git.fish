#!/usr/bin/env fish

# Sourced by ../dependencies.fish.
hash git
if test $status -ne 0
    xcode-select --install
    or exit $status
    echo "Complete the Command Line Tools installation, then rerun this script."
    exit 1
end

#!/usr/bin/env fish

set -l script_dir (path resolve (path dirname (status filename)))

# Git / Apple Command Line Tools
echo "=== Git / Apple Command Line Tools ==="
source "$script_dir/dependencies/git.fish"; or exit $status

# Shared installation paths and temporary workspace
set -l install_dir "$HOME/.local/bin"
set -gx PATH "$install_dir" $PATH
set -l work_dir (mktemp -d /tmp/fireplace-dependencies.XXXXXXXX)
or exit 1

function cleanup --on-event fish_exit --inherit-variable work_dir
    rm -rf -- "$work_dir"
end

cd "$work_dir"; or exit 1

# CMake
echo "=== CMake ==="
source "$script_dir/dependencies/cmake.fish"; or exit $status

# clang-format
echo "=== clang-format ==="
source "$script_dir/dependencies/clang-format.fish"; or exit $status

echo "Dependencies ready."

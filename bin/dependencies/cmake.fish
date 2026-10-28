#!/usr/bin/env fish

# Sourced by ../dependencies.fish.
if not command -q cmake
    git clone --depth=1 https://github.com/wieczorek1990/install-cmake.git
    or exit 1
    cd install-cmake; or exit 1
    sh bin/install.sh; or exit 1
    "$install_dir/cmake" --version; or exit 1
    cd "$work_dir"; or exit 1
end

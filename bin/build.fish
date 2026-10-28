#!/usr/bin/env fish

set -l project_dir (path resolve (path dirname (status filename))/..)

cmake -S "$project_dir" -B "$project_dir/cmake-build-debug" -DCMAKE_BUILD_TYPE=Debug
or exit $status
cmake --build "$project_dir/cmake-build-debug" --parallel

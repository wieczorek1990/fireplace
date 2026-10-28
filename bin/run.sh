#!/usr/bin/env fish

set -l project_dir (path resolve (path dirname (status filename))/..)
set -l executable "$project_dir/cmake-build-debug/fireplace"

if not test -x "$executable"
    echo "Fireplace has not been built. Run $project_dir/bin/build.sh first." >&2
    exit 1
end

exec "$executable" $argv

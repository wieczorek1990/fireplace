#!/usr/bin/env fish

set -l script_dir (path resolve (path dirname (status filename)))

"$script_dir/build.sh"
or exit $status
exec "$script_dir/run.sh" $argv

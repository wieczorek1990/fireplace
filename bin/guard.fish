#!/usr/bin/env fish

# Read-only source checks and a fresh Release build. Never commits or pushes.
set -l project_dir (path resolve (path dirname (status filename))/..)
cd "$project_dir"; or exit 1

for tool in git cmake clang-format
    if not command -q $tool
        echo "Missing required tool: $tool" >&2
        exit 1
    end
end

set -l failed 0

echo "Checking Git whitespace..."
git diff --check
or set failed 1
git diff --cached --check
or set failed 1

echo "Checking fish syntax..."
for script in bin/*.fish
    fish --no-execute "$script"
    or set failed 1
end

echo "Checking source and script formatting..."
"$project_dir/bin/format.fish" --check
or set failed 1

echo "Building Release in a temporary directory..."
set -l build_dir (mktemp -d /tmp/fireplace-guard.XXXXXXXX)
if test $status -ne 0
    exit 1
end
cmake -S "$project_dir" -B "$build_dir" -DCMAKE_BUILD_TYPE=Release
if test $status -eq 0
    cmake --build "$build_dir" --parallel
    or set failed 1
else
    set failed 1
end
rm -rf -- "$build_dir"

if test $failed -ne 0
    echo "Guard failed. Fix the reported issues before pushing." >&2
    exit 1
end

echo "Guard passed. Manually check the scene and mouse rotation before pushing."

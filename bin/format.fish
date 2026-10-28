#!/usr/bin/env fish

set -l project_dir (path resolve (path dirname (status filename))/..)
set -l mode write
if test (count $argv) -gt 1
    echo "Usage: format.fish [--check]" >&2
    exit 1
end
if test (count $argv) -eq 1
    if test "$argv[1]" != --check
        echo "Usage: format.fish [--check]" >&2
        exit 1
    end
    set mode check
end

for tool in clang-format fish_indent
    if not command -q $tool
        echo "Missing required tool: $tool" >&2
        exit 1
    end
end

# Keep generated files and third-party sources out of the formatter.
set -l sources (path filter -f "$project_dir"/*.{cpp,h,mm})
set -l failed 0
if test "$mode" = check
    clang-format --dry-run --Werror $sources
    or set failed 1
    fish_indent --check "$project_dir"/bin/*.fish
    or set failed 1
else
    clang-format -i $sources
    or set failed 1
    fish_indent --write "$project_dir"/bin/*.fish
    or set failed 1
end
exit $failed

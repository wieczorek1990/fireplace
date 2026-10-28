#!/usr/bin/env fish

# Build clang-format separately from the application and install it locally.
for tool in git cmake
    if not command -q $tool
        echo "Missing required tool: $tool" >&2
        exit 1
    end
end

set -l work_dir (mktemp -d /tmp/fireplace-dependencies.XXXXXXXX)
or exit 1
set -l install_dir "$HOME/.local/bin"
set -l result 0

git clone --depth=1 https://github.com/llvm/llvm-project.git "$work_dir/llvm-project"
and cmake -S "$work_dir/llvm-project/llvm" -B "$work_dir/build" \
    -DLLVM_ENABLE_PROJECTS=clang -DCMAKE_BUILD_TYPE=Release
and cmake --build "$work_dir/build" --target clang-format --parallel
and mkdir -p "$install_dir"
and cp "$work_dir/build/bin/clang-format" "$install_dir/clang-format"
or set result 1

rm -rf -- "$work_dir"
if test $result -eq 0
    echo "Installed $install_dir/clang-format"
end
exit $result

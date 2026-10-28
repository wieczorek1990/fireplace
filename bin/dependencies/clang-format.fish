#!/usr/bin/env fish

# Sourced by ../dependencies.fish.
if not command -q clang-format
    git clone --depth=1 https://github.com/llvm/llvm-project.git
    or exit 1
    cmake -S llvm-project/llvm -B build \
        -DLLVM_ENABLE_PROJECTS=clang -DCMAKE_BUILD_TYPE=Release
    or exit 1
    cmake --build build --target clang-format --parallel; or exit 1
    mkdir -p "$install_dir"; or exit 1
    cp build/bin/clang-format "$install_dir/clang-format"; or exit 1
end

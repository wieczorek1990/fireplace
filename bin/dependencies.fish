#!/usr/bin/env fish
# Dependencies installer.

# CLANG-FORMAT
git clone --depth=1 git@github.com:llvm/llvm-project.git
cd llvm-project/
cmake -S llvm -B build \
    -DLLVM_ENABLE_PROJECTS=clang \
    -DCMAKE_BUILD_TYPE=Release
cmake --build build --target clang-format --parallel
cp ./build/bin/clang-format ~/.local/bin/
cd ..
rm -rf llvm-project/

#!/bin/bash -e

if find . -name '*.sh' -print0 | xargs -n1 -0 shellcheck -x -s bash; then
    echo -e "\033[0;32mShell script linting passed!\033[0m"
else
    echo -e >&2 "\033[0;31mShell script linting failed!\033[0m"
    exit 1
fi

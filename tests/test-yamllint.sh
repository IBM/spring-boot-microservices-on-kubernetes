#!/bin/bash -e

if find . \( -name '*.yml' -o -name '*.yaml' \) -print0 | xargs -n1 -0 yamllint -c .yamllint.yml; then
    echo -e "\033[0;32mYAML linting passed!\033[0m"
else
    echo -e >&2 "\033[0;31mYAML linting failed!\033[0m"
    exit 1
fi

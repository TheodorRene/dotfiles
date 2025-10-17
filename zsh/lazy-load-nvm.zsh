#!/usr/bin/env zsh

# Create wrappers around common nvm consumers.
# nvm, node, yarn and npm will load nvm.sh on their first invocation,
# posing no start up time penalty for the shells that aren't going to use them at all.
# There is only single time penalty for one shell.

typeset -ga __lazyLoadLabels=(nvm node npm npx pnpm yarn pnpx bun bunx)

__load-nvm() {
    [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
    [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion
}

__work() {
    for label in "${__lazyLoadLabels[@]}"; do
        unset -f $label
    done
    unset -v __lazyLoadLabels

    __load-nvm
    unset -f __load-nvm __work
}

for label in "${__lazyLoadLabels[@]}"; do
    eval "$label() { __work; $label \$@; }"
done

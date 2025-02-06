path+=$HOME/.local/bin
path+=$HOME/.dotnet
path+=$HOME/.cargo/bin
path+=$HOME/.local/share/bob/nvim-bin
path+=$HOME/.luarocks/bin
path+=$HOME/.npm-packages/bin
path+=./node_modules/.bin

export ANDROID_HOME=$HOME/Library/Android/sdk
export JAVA_HOME="/Users/thca/.openjdk/jdk-17/Contents/Home"
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/emulator

export PATH="$JAVA_HOME/bin:$PATH"
export PATH="$HOME/.yarn/bin:$HOME/.local/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH:$HOME/.gem/ruby/2.6.0/bin:$HOME/bin"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# flashlight
export PATH="/Users/thca/.flashlight/bin:$PATH"

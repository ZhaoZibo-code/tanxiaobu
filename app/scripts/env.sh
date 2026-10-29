# From app/, source this file from Bash or Zsh. It changes only the current shell.
# Override M00_TOOLS_DIR / OHOS_SDK_HOME when using another verified installation.
export M00_TOOLS_DIR="${M00_TOOLS_DIR:-$HOME/Library/OpenHarmony/Tools}"
export NODE_HOME="$M00_TOOLS_DIR/node-v18.20.8-darwin-arm64"
export JAVA_HOME="$M00_TOOLS_DIR/jdk-17.0.21+9/Contents/Home"
export OHOS_SDK_HOME="${OHOS_SDK_HOME:-$HOME/Library/OpenHarmony/Sdk}"
export DEVECO_STUDIO_HOME="${DEVECO_STUDIO_HOME:-/Applications/DevEco-Studio.app}"
export PATH="$PWD/scripts:$NODE_HOME/bin:$JAVA_HOME/bin:$DEVECO_STUDIO_HOME/Contents/tools/ohpm/bin:$OHOS_SDK_HOME/12/toolchains:$PATH"
# Hvigor's wrapper runs pnpm outside this project; retain its scoped registry.
export npm_config_userconfig="$PWD/.npmrc"

#!/bash/bin

RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
BLUE='\e[34m'

RESET='\e[0m'


info()  { echo -e "${BLUE}[INFO]${RESET} $1"; }
ok()    { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${RESET} $1"; }
error() { echo -e "${RED}[ERROR]${RESET} $1"; }


if ! command -v bubblewrap > /dev/null 2>&1; then
    echo "[INFO] Bubblewrap is not installed on the machine"

    read -r -p "You want to install? (y/N) " answer
    if [[ "$answer" == [yY] ]]; then
        info "Installing 'bubblewrap'"
        npm install -g @bubblewrap/cli
    else
        error "Installation skipped"
        exit 1
    fi
fi

if ! npm ls -g --depth=0 | grep -i bubblewrap; then 
    error "Bubblewrap is not from @meta-quest" 
    exit 1
fi

BW_PATH=~/.bubblewrap
BW_CONFIG_PATH=~/.bubblewrap/config.json

if [ ! -f "$BW_CONFIG_PATH" ]; then
    warn "Bubblewrap config not found: $BW_CONFIG_PATH"

    info "Creating config at '$BW_CONFIG_PATH'"
    mkdir -p "$BW_PATH"
    cat > "$BW_CONFIG_PATH" << 'EOF'
{
  "jdkPath": "",
  "androidSdkPath": ""
}
EOF
fi

get_path() {
    python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2]) or "")' "$BW_CONFIG_PATH" "$1"
}

JDK_PATH=$(get_path jdkPath)
SDK_PATH=$(get_path androidSdkPath)

if [ -z "$JDK_PATH" ] || [ -z "$SDK_PATH" ]; then
    info "jdkPath or androidSdkPath is not set in $BW_CONFIG_PATH"
    cat "$BW_CONFIG_PATH" | python3 -m json.tool

    JDK_DOWNLOAD_PATH=~/.bubblewrap/jdk
    SDK_DOWNLOAD_PATH=~/.bubblewrap/andriod_sdk

    printf '%.0s-' {1..60}; echo
    INFO "Downloading JDK"
    mkdir -p "$JDK_DOWNLOAD_PATH"
    ok "Folder created at "$JDK_DOWNLOAD_PATH""
    info "Downloading and extracting"
    curl -L "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.11%2B9/OpenJDK17U-jdk_x64_linux_hotspot_17.0.11_9.tar.gz" | tar -xz -C "$JDK_DOWNLOAD_PATH"
    ok "JDK downloaded with version 17.0.11+9 "$JDK_DOWNLOAD_PATH""
    printf '%.0s-' {1..60}; echo

    printf '%.0s-' {1..60}; echo
    info "Downloading SDK"
    mkdir -p "$SDK_DOWNLOAD_PATH"
    ok "Folder created at "$JDK_DOWNLOAD_PATH""
    curl -L -o ~/.bubblewrap/cmdline-tools.zip "https://dl.google.com/android/repository/commandlinetools-linux-6609375_latest.zip"
    unzip -q ~/.bubblewrap/cmdline-tools.zip -d "$SDK_DOWNLOAD_PATH"

    
    cat > "$BW_CONFIG_PATH" << EOF
{
  "jdkPath": "/home/mantis/.bubblewrap/jdk/jdk-17.0.11+9",
  "androidSdkPath": "$SDK_DOWNLOAD_PATH"
}
EOF

    JDK_PATH=$(get_path jdkPath) 
    SDK_PATH=$(get_path androidSdkPath)
fi

echo ""
ok "JDK PATH: $JDK_PATH"
ok "SDK PATH: $SDK_PATH"

if ! bubblewrap doctor > /dev/null 2&>1; then
    error "bubblewrap doctor failed. Path are not setup properly"
    exit 1
else
    ok "bubblewrap doctor - Test passed"
fi


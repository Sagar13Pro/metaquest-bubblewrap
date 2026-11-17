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


APK_FOLDER="apk"
APK_FILE="app-release-signed.apk"

read -r -p "[INPUT] Enter folder path: " name
if [ -n "$name" ]; then 
    APK_FOLDER="$name"
fi


if [ -d "$APK_FOLDER" ]; then
    info "Folder '$APK_FOLDER' already exists"
elif ! mkdir -p "$APK_FOLDER"; then
    error "Could not create folder '$APK_FOLDER'"
    exit 1
else    
    ok "Folder created"
fi


PROJECT_URL=https://traditions-ball-opposite-subsection.trycloudflare.com

read -r -p "[INPUT] Project URL ('$PROJECT_URL') or blank for default: " url
PROJECT_URL="${PROJECT_URL%/}"
MANIFEST_URL="$PROJECT_URL/manifest.webmanifest"

info "PROJECT LINK: '$PROJECT_URL'"
info "Checking manifest at '$MANIFEST_URL'"

status=$(curl -s -o /dev/null -w "%{http_code}" "$MANIFEST_URL")

if [ "$status" != "200" ]; then
    error "Manifest not reachable (HTTP $status)"
    exit 1
fi
ok "Manifest is reachable (HTTP $status)"

cd "$APK_FOLDER" || { error "Cannot enter '$APK_FOLDER'"; exit 1; }

info "Generating wrapper for the project"
bubblewrap init --manifest="$MANIFEST_URL" --metaquest

info "Checking whether 'isMetaQuest: true' and 'horizonOSAppMode: immersive'"
grep -n -i "horizon\|metaquest\|packageId\|host" twa-manifest.json 

info "Building now. Output will be 'app-release-signed.apk'" 
bubblewrap build


TWA_MANIFEST="twa-manifest.json"
get_path() {
    python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2]) or '')" $1 $2
}

PACKAGEID=$(get_path $TWA_MANIFEST "packageId" )
SIGNING_KEY=$(get_path $TWA_MANIFEST "signingKey")


ALIAS=$(echo "$SIGNING_KEY" | sed -n "s/.*'alias': *'\([^']*\)'.*/\1/p")

printf '%.0s-' {1..60}; echo
echo 'SHA256'
printf '%.0s-' {1..60}; echo



extract_fingerPrint() { 
    python3 -c  '
        import re,sys 
        m = re.search(r"SHA256:\s*((?:[0-9A-Fa-f]{2}:){31}[0-9A-Fa-f{2}])", sys.stdin.read())
        print(m.group(1) if m else "")
    ' 
}

SHA256=$(keytool -list -v -keystore android.keystore -alias "$ALIAS" | grep SHA256)

FINGERPRINT=$(echo $SHA256 | extract_fingerPrint)

ok "SHA256 = '$FINGERPRINT'"

mkdir -p .well-known
cat > .well-known/assetlinks.json << 'EOF'
[
    {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
        "namespace": "android_app",
        "package_name": "$PACKAGEID",
        "sha256_cert_fingerprints": [
        "$FINGERPRINT"
        ]
    }
    }
]
EOF

ok ".well-known/assetlinks.json is created"
info "Place assetlinks.json at public/.well-known/assetlinks.json in your project"
warn "It must be reachable at: $PROJECT_URL/.well-known/assetlinks.json"

status_assetlinks=$(curl -sL -o /dev/null -w "%{http_code}" "$PROJECTURL/.well-known/assetlinks.json")

if [ "$status_assetlinks" !="200" ]; then 
    error "assetlinks.json not reachable yet (HTTP $status)"
    exit 1
fi


if [ ! -f "$APK_FILE" ]; then
    error "APK not found: $APK_FILE"
    exit 1
fi

printf '%.0s-' {1..60}; echo
echo 'Getting SHA256 HASH for "$APK_FILE"'
printf '%.0s-' {1..60}; echo

APK_HASH=$(sha256sum "$APK_FILE" | cut -d ' ' -f 1)

info "Upload '$APK_FILE' to a public direct-download link for VR Manager"
info "Enter this SHA-256 hash in the VR Device Manager:"
echo "$APK_HASH"
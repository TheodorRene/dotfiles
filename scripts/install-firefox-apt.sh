#!/usr/bin/env bash
set -euo pipefail

echo "Setting up Mozilla's official APT repository..."
sudo install -d -m 0755 /etc/apt/keyrings
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- \
    | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null

echo "Verifying signing key fingerprint..."
gpg -n -q --import --import-options import-show /etc/apt/keyrings/packages.mozilla.org.asc \
    | awk '/pub/{getline; gsub(/^ +| +$/,""); if($0 == "35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3") print "Key OK: "$0; else { print "Key mismatch: "$0; exit 1 }}'

echo "Adding Mozilla APT repository..."
echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
    | sudo tee /etc/apt/sources.list.d/mozilla.list > /dev/null

echo "Pinning Mozilla repo at priority 1000..."
sudo tee /etc/apt/preferences.d/mozilla-firefox > /dev/null <<'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

echo "Removing snap firefox..."
sudo snap remove firefox || true

echo "Removing snap stub apt package..."
sudo apt remove --purge -y firefox || true

echo "Installing firefox from Mozilla repo..."
sudo apt update -qq
sudo apt install -y firefox

echo "Done. Firefox binary: $(which firefox)"
firefox --version

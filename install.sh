#!/bin/bash


# Ideas:
# implement /tmp installation maybe?
# mute output from git clone commands unless output is from stderr? (1>)
# (and implement progress bar or some progress icon like pipx does)

detect_package_manager() {
    if command -v pacman &> /dev/null; then
        printf "pacman"
    elif command -v apt-get &> /dev/null; then
        printf "apt"
    elif command -v dnf &> /dev/null; then
        printf "dnf"
    else
        printf "unknown"
    fi
}

install_packages() {
    local PKG_MANAGER=""$(detect_package_manager)""
    echo $PKG_MANAGER
    #pacman has python-pipx instead of pipx,
    #so setting up one list for all packages might not work

    case "$PKG_MANAGER" in
        "pacman")
            sudo pacman -Sy --needed python-pipx curl git zstd
            ;;
        "apt")
            sudo apt-get update
            sudo apt-get install -y pipx curl git zstd
            ;;
        "dnf")
            sudo dnf install pipx curl git zstd
            ;;
        *)
        echo "Unknown package manager or not yet implemented, sorry"
        exit 1
        ;;
    esac
    pipx ensurepath
    pipx install semgrep
}


install_packages

echo "Installing bearer"
curl -sfL https://raw.githubusercontent.com/Bearer/bearer/main/contrib/install.sh | sh

echo "Cloning rules for semgrep"
mkdir rules
cd rules
git clone https://github.com/semgrep/semgrep-rules
cd ../


echo "Downloading CodeQL"
wget https://github.com/github/codeql-action/releases/latest/download/codeql-bundle-linux64.tar.zst
echo "Extracting archive, please wait..."
tar --zstd -xvf codeql-bundle-linux64.tar.zst 1> /dev/null #to not output stdout
echo "Exctration done!"
rm codeql-bundle-linux64.tar.zst
#probably no need to add to PATH because we can just invoke it manually
#but maybe we need to add SUST_INSTALL (as in current work dir for this script) to path

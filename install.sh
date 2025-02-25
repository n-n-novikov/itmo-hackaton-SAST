#!/bin/bash


# Ideas:
# implement /tmp installation maybe?


run_with_spinner() {
    local command="$1"
    local message="$2"

    spinner() {
        local i sp n
        sp='/-\|'
        n=${#sp}
        printf ' '
        while sleep 0.2; do
            printf "%s\b" "${sp:i++%n:1}"
        done
    }

    echo "$message "
    #start spinner and remove cursor
    spinner &
    local spinner_pid=$!
    tput civis

    eval "$command"
    local command_status=$?

    #kill spinner and restore cursor
    kill $spinner_pid &>/dev/null
    tput cnorm
    echo

    return $command_status

}

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

echo "Choose SUST installation type:"
echo "1: Persistent installation (in current directory) (default)"
echo "2: Temporary installation (in /tmp/sust)"
while true; do
    read -p "Choose 1 or 2: " INSTALL_CHOICE
    if [ "$INSTALL_CHOICE" == "1" ] || [ "$INSTALL_CHOICE" == "2" ]; then
        break
    else
        echo "Invalid choice. Enter only '1' or '2'"
    fi
done

echo $INSTALL_CHOICE
if [ "$INSTALL_CHOICE" == "2" ]; then
    echo "Installing in /tmp/sust/"
    INSTALL_DIR="/tmp/sust/"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
else
    INSTALL_DIR=$(pwd)
fi

run_with_spinner "curl -sfL https://raw.githubusercontent.com/Bearer/bearer/main/contrib/install.sh | sh 1>/dev/null" "Installing bearer"

mkdir rules
cd rules
run_with_spinner "git clone https://github.com/semgrep/semgrep-rules --quiet" "Cloning rules for semgrep"
rm -r ./semgrep-rules/Pipfile* ./semgrep-rules/Makefile ./semgrep-rules/*.md ./semgrep-rules/LICENSE ./semgrep-rules/template.yaml ./semgrep-rules/.* ./semgrep-rules/stats
cd ../

echo "Downloading CodeQL"
wget https://github.com/github/codeql-action/releases/latest/download/codeql-bundle-linux64.tar.zst -q --show-progress

run_with_spinner "tar --zstd -xvf codeql-bundle-linux64.tar.zst 1>/dev/null" "Extracting archive, please wait..."
echo "Extraction done!"
rm codeql-bundle-linux64.tar.zst

if [ "$INSTALL_CHOICE" == "1" ]; then
    echo "Adding SUST_INSTALL_DIR to your .bashrc / .zshrc."
    if [ "$SHELL" == "/usr/bin/zsh" ]; then
        echo "export SUST_INSTALL_DIR=\"$INSTALL_DIR\"" >> ~/.zshrc
        export SUST_INSTALL_DIR="$INSTALL_DIR"
    else
        echo "export SUST_INSTALL_DIR=\"$INSTALL_DIR\"" >> ~/.bashrc
        export SUST_INSTALL_DIR="$INSTALL_DIR"
    fi
else
    export SUST_INSTALL_DIR="$INSTALL_DIR"
    echo -e "Exported SUST_INSTALL_DIR. Open sust.sh from the same shell, or use\n export SUST_INSTALL_DIR=\"$INSTALL_DIR\""
fi

echo "Installation done! You can use sust.sh with the following arguments:"
echo -e "\t-p/--path /path/to/project\t-path to project that will be scanned"
echo -e "\t-m/--mode fast/full\t-analysis mode. fast (default) launches semgrep and bearer, full launches CodeQL too"
echo -e "\t-b/--bearer-rules /path/to/rules/\t-path to bearer rules"
echo -e "\t-s/--semgrep-rules /path/to/rules/\t-path to semgrep rules ($INSTALL_DIR/rules/semgrep-rules/ by default)"
echo -e "\t-h/--help\t-prints help message of sust.sh\n"
echo -e "\nAttention! If you've launched this using bash install.sh, you need to source ~/.bashrc (in case of persistent install), or use \nexport SUST_INSTALL_DIR=\"$INSTALL_DIR\""



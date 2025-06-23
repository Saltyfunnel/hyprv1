#!/bin/bash
set -euo pipefail

# --- Initialization ---

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/install.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Starting Modular Hyprland Installation ==="
echo "Log file: $LOG_FILE"

if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo."
  exit 1
fi

if [ -z "${SUDO_USER:-}" ]; then
  echo "Run this script using sudo, e.g. sudo bash install.sh"
  exit 1
fi

USER_HOME=$(eval echo "~$SUDO_USER")
echo "Installing as user: $SUDO_USER"
echo "User home directory: $USER_HOME"

# --- Helper functions ---

error_exit() {
  echo "Error: $1"
  exit 1
}

check_command() {
  command -v "$1" >/dev/null 2>&1 || error_exit "Required command '$1' not found. Please install it and rerun."
}

# --- Install functions ---

install_base() {
  echo "Updating system and installing base packages..."
  pacman -Syyu --noconfirm
  pacman -S --noconfirm base-devel git
}

install_yay() {
  if ! command -v yay &>/dev/null; then
    echo "Installing yay AUR helper..."
    cd "$USER_HOME"
    sudo -u "$SUDO_USER" bash -c "
      git clone https://aur.archlinux.org/yay.git
      cd yay
      makepkg -si --noconfirm
    "
    echo "yay installed"
  else
    echo "yay already installed"
  fi
}

install_hyprland_official() {
  echo "Installing Hyprland official repo packages..."
  local pkgs=(
    pipewire wireplumber pamixer brightnessctl
    ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans ttf-firacode-nerd
    ttf-iosevka-nerd ttf-iosevkaterm-nerd ttf-jetbrains-mono-nerd ttf-jetbrains-mono
    ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono
    sddm firefox unzip thunar thunar-archive-plugin thunar-volman xarchiver tumbler gvfs kitty nano code fastfetch starship tar
    hyprland xdg-desktop-portal-hyprland polkit-kde-agent dunst qt5-wayland qt6-wayland waybar cliphist
  )
  pacman -S --noconfirm "${pkgs[@]}"
  systemctl enable sddm.service
}

install_nvidia_drivers() {
  if lspci -k | grep -EA3 'VGA|3D|Display' | grep -i nvidia &>/dev/null; then
    echo "NVIDIA card detected. Installing NVIDIA drivers..."
    pacman -S --noconfirm nvidia nvidia-utils nvidia-settings lib32-nvidia-utils opencl-nvidia
  else
    echo "No NVIDIA GPU detected. Skipping NVIDIA drivers."
  fi
}

install_hyprland_aur() {
  echo "Installing Hyprland AUR packages..."
  local aur_pkgs=(wofi swww hyprpicker hyprlock wlogout grimblast hypridle kvantum-theme-catppuccin-git thefuck)
  sudo -u "$SUDO_USER" yay -S --noconfirm "${aur_pkgs[@]}"
}

install_bluetooth() {
  echo "Installing Bluetooth support..."
  pacman -S --noconfirm bluez bluez-utils blueman
  systemctl enable bluetooth.service
  systemctl start bluetooth.service
}

install_browsers() {
  echo "Installing browsers..."
  pacman -S --noconfirm firefox chromium
  sudo -u "$SUDO_USER" yay -S --noconfirm brave-bin
}

install_games() {
  echo "Installing gaming software..."
  pacman -S --noconfirm steam
  sudo -u "$SUDO_USER" yay -S --noconfirm lutris
  pacman -S --noconfirm wine wine-mono wine-gecko winetricks
}

install_media() {
  echo "Installing media players..."
  pacman -S --noconfirm vlc mpv
  sudo -u "$SUDO_USER" yay -S --noconfirm spotify
}

install_devtools() {
  echo "Installing developer tools..."
  pacman -S --noconfirm code git docker nodejs npm htop neofetch tmux unzip
  systemctl enable docker.service
  systemctl start docker.service
}

install_office() {
  echo "Installing office applications..."
  pacman -S --noconfirm libreoffice-fresh evince
  sudo -u "$SUDO_USER" yay -S --noconfirm onlyoffice-bin
}

install_networking() {
  echo "Installing networking tools..."
  pacman -S --noconfirm networkmanager openvpn wireshark-qt
  systemctl enable NetworkManager.service
  systemctl start NetworkManager.service
  usermod -aG wireshark "$SUDO_USER"
}

copy_configs() {
  echo "Copying config files..."
  # Customize these paths to your actual config locations
  local src_base="$USER_HOME/hyprv1"

  mkdir -p "$USER_HOME/.config/hypr"
  cp -r "$src_base/configs/hypr/hyprland.conf" "$USER_HOME/.config/hypr/"
  cp -r "$src_base/configs/hypr/hyprlock.conf" "$USER_HOME/.config/hypr/"
  cp -r "$src_base/configs/hypr/hypridle.conf" "$USER_HOME/.config/hypr/"

  mkdir -p "$USER_HOME/.config/dunst"
  cp -r "$src_base/configs/dunst/"* "$USER_HOME/.config/dunst/"

  mkdir -p "$USER_HOME/.config/waybar"
  cp -r "$src_base/configs/waybar/"* "$USER_HOME/.config/waybar/"

  mkdir -p "$USER_HOME/.config/wofi"
  cp -r "$src_base/configs/wofi/"* "$USER_HOME/.config/wofi/"

  mkdir -p "$USER_HOME/.config/kitty"
  cp -r "$src_base/configs/kitty/"* "$USER_HOME/.config/kitty/"

  mkdir -p "$USER_HOME/.config/scripts"
  cp -r "$src_base/configs/scripts/logout-menu.sh" "$USER_HOME/.config/scripts/logout-menu.sh"
  chmod +x "$USER_HOME/.config/scripts/logout-menu.sh"

  mkdir -p "$USER_HOME/.config/assets/backgrounds"
  cp -r "$src_base/assets/backgrounds/"* "$USER_HOME/.config/assets/backgrounds/"

  mkdir -p "$USER_HOME/.config/starship"
  cp "$src_base/configs/starship/starship.toml" "$USER_HOME/.config/starship.toml"

  mkdir -p "$USER_HOME/.config/fastfetch"
  cp "$src_base/configs/fastfetch/config.conf" "$USER_HOME/.config/fastfetch/config.conf"

  echo "Config files copied."
}

apply_themes() {
  echo "Installing and applying themes..."

  local src_base="$USER_HOME/hyprv1"

  # Extract themes/icons to system dirs
  tar -xf "$src_base/assets/themes/Catppuccin-Mocha.tar.xz" -C /usr/share/themes/
  tar -xf "$src_base/assets/icons/Tela-circle-dracula.tar.xz" -C /usr/share/icons/
  tar -xf "$src_base/assets/themes/Bibata-Modern-Ice.tar.xz" -C /usr/share/icons/

  # Apply GTK, icon, cursor themes for user
  sudo -u "$SUDO_USER" dbus-launch gsettings set org.gnome.desktop.interface gtk-theme 'Catppuccin-Mocha'
  sudo -u "$SUDO_USER" dbus-launch gsettings set org.gnome.desktop.interface icon-theme 'Tela-circle-dracula'
  sudo -u "$SUDO_USER" dbus-launch gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'

  echo "Themes applied."
}

fix_permissions() {
  echo "Fixing ownership of config files..."
  chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.config"
  chown "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.bashrc"
}

# --- UI Functions using whiptail ---

declare -A CATEGORY_OPTIONS=(
  [Base]="install_base install_yay"
  [Hyprland]="install_hyprland_official install_nvidia_drivers install_hyprland_aur copy_configs apply_themes fix_permissions"
  [Bluetooth]="install_bluetooth"
  [Browsers]="install_firefox install_chromium install_brave"
  [Games]="install_steam install_lutris install_wine"
  [Media]="install_vlc install_mpv install_spotify"
  [DevTools]="install_code install_git install_docker install_nodejs install_htop install_neofetch install_tmux install_unzip"
  [Office]="install_libreoffice install_evince install_onlyoffice"
  [Networking]="install_networkmanager install_openvpn install_wireshark"
)

declare -A OPTION_DESCRIPTIONS=(
  [install_base]="Update system & base-devel"
  [install_yay]="Install yay AUR helper"
  [install_hyprland_official]="Install Hyprland official packages"
  [install_nvidia_drivers]="Install NVIDIA drivers if detected"
  [install_hyprland_aur]="Install Hyprland AUR packages"
  [copy_configs]="Copy configuration files"
  [apply_themes]="Install & apply themes"
  [fix_permissions]="Fix permissions on configs"

  [install_bluetooth]="Bluetooth support (BlueZ, Blueman)"
  
  [install_firefox]="Firefox browser"
  [install_chromium]="Chromium browser"
  [install_brave]="Brave browser"
  
  [install_steam]="Steam gaming platform"
  [install_lutris]="Lutris gaming platform"
  [install_wine]="Wine for Windows apps"
  
  [install_vlc]="VLC media player"
  [install_mpv]="MPV media player"
  [install_spotify]="Spotify music player"
  
  [install_code]="Visual Studio Code"
  [install_git]="Git version control"
  [install_docker]="Docker container engine"
  [install_nodejs]="Node.js & npm"
  [install_htop]="htop process viewer"
  [install_neofetch]="neofetch system info"
  [install_tmux]="tmux terminal multiplexer"
  [install_unzip]="unzip utility"
  
  [install_libreoffice]="LibreOffice suite"
  [install_evince]="Evince document viewer"
  [install_onlyoffice]="OnlyOffice suite"
  
  [install_networkmanager]="NetworkManager"
  [install_openvpn]="OpenVPN client"
  [install_wireshark]="Wireshark network analyzer"
)

# Map options to their functions (for direct call)
declare -A OPTION_FUNCTIONS=(
  [install_base]=install_base
  [install_yay]=install_yay
  [install_hyprland_official]=install_hyprland_official
  [install_nvidia_drivers]=install_nvidia_drivers
  [install_hyprland_aur]=install_hyprland_aur
  [copy_configs]=copy_configs
  [apply_themes]=apply_themes
  [fix_permissions]=fix_permissions

  [install_bluetooth]=install_bluetooth
  
  [install_firefox]=install_firefox
  [install_chromium]=install_chromium
  [install_brave]=install_brave
  
  [install_steam]=install_steam
  [install_lutris]=install_lutris
  [install_wine]=install_wine
  
  [install_vlc]=install_vlc
  [install_mpv]=install_mpv
  [install_spotify]=install_spotify
  
  [install_code]=install_code
  [install_git]=install_git
  [install_docker]=install_docker
  [install_nodejs]=install_nodejs
  [install_htop]=install_htop
  [install_neofetch]=install_neofetch
  [install_tmux]=install_tmux
  [install_unzip]=install_unzip
  
  [install_libreoffice]=install_libreoffice
  [install_evince]=install_evince
  [install_onlyoffice]=install_onlyoffice
  
  [install_networkmanager]=install_networkmanager
  [install_openvpn]=install_openvpn
  [install_wireshark]=install_wireshark
)

# Dummy install functions for individual packages not defined above (browsers, games, etc)
install_firefox() { pacman -S --noconfirm firefox; }
install_chromium() { pacman -S --noconfirm chromium; }
install_brave() { sudo -u "$SUDO_USER" yay -S --noconfirm brave-bin; }

install_steam() { pacman -S --noconfirm steam; }
install_lutris() { sudo -u "$SUDO_USER" yay -S --noconfirm lutris; }
install_wine() { pacman -S --noconfirm wine wine-mono wine-gecko winetricks; }

install_vlc() { pacman -S --noconfirm vlc; }
install_mpv() { pacman -S --noconfirm mpv; }
install_spotify() { sudo -u "$SUDO_USER" yay -S --noconfirm spotify; }

install_code() { pacman -S --noconfirm code; }
install_git() { pacman -S --noconfirm git; }
install_docker() {
  pacman -S --noconfirm docker
  systemctl enable docker.service
  systemctl start docker.service
}
install_nodejs() { pacman -S --noconfirm nodejs npm; }
install_htop() { pacman -S --noconfirm htop; }
install_neofetch() { pacman -S --noconfirm neofetch; }
install_tmux() { pacman -S --noconfirm tmux; }
install_unzip() { pacman -S --noconfirm unzip; }

install_libreoffice() { pacman -S --noconfirm libreoffice-fresh; }
install_evince() { pacman -S --noconfirm evince; }
install_onlyoffice() { sudo -u "$SUDO_USER" yay -S --noconfirm onlyoffice-bin; }

install_networkmanager() {
  pacman -S --noconfirm networkmanager
  systemctl enable NetworkManager.service
  systemctl start NetworkManager.service
  usermod -aG wireshark "$SUDO_USER"
}
install_openvpn() { pacman -S --noconfirm openvpn; }
install_wireshark() { pacman -S --noconfirm wireshark-qt; }

# --- Whiptail UI ---

main_menu() {
  local choices=()
  for cat in "${!CATEGORY_OPTIONS[@]}"; do
    choices+=("$cat" "")
  done

  CHOICE=$(whiptail --title "Select Category to Configure" --menu "Use arrow keys to select category:" 20 60 10 "${choices[@]}" 3>&1 1>&2 2>&3) || exit 0

  select_options_for_category "$CHOICE"
}

select_options_for_category() {
  local category="$1"
  local options_string="${CATEGORY_OPTIONS[$category]}"
  IFS=' ' read -r -a options <<< "$options_string"

  local checklist=()
  for opt in "${options[@]}"; do
    checklist+=("$opt" "${OPTION_DESCRIPTIONS[$opt]:-No description}" "OFF")
  done

  SELECTED_OPTIONS=$(whiptail --title "Select options to install in $category" --checklist "Select with SPACE. ENTER to confirm." 20 70 15 "${checklist[@]}" 3>&1 1>&2 2>&3) || main_menu

  # whiptail returns selections as quoted strings: "opt1" "opt2"
  # Strip quotes and spaces
  SELECTED_OPTIONS=$(echo "$SELECTED_OPTIONS" | sed 's/"//g')

  if [ -z "$SELECTED_OPTIONS" ]; then
    echo "No options selected. Returning to main menu."
    main_menu
  fi

  execute_selected_options $SELECTED_OPTIONS

  # Back to main menu after finishing
  main_menu
}

execute_selected_options() {
  for opt in "$@"; do
    echo "Running install for: $opt"
    if [[ -n "${OPTION_FUNCTIONS[$opt]:-}" ]]; then
      "${OPTION_FUNCTIONS[$opt]}"
    else
      echo "No function defined for $opt"
    fi
  done
}

# --- Main ---

check_command whiptail

# If first arg is --unattended, run default base + hyprland + bluetooth silently (example)
if [[ "${1:-}" == "--unattended" ]]; then
  echo "Running unattended installation..."

  install_base
  install_yay
  install_hyprland_official
  install_nvidia_drivers
  install_hyprland_aur
  copy_configs
  apply_themes
  fix_permissions
  install_bluetooth

  echo "Unattended install finished."
  exit 0
fi

# Interactive mode
while true; do
  main_menu
done

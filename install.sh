#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/install.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Starting Simple Hyprland Installation ==="
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

### Update system first
echo "Updating system..."
pacman -Syyu --noconfirm

### Install base-devel and git (needed for yay)
echo "Installing base-devel and git..."
pacman -S --noconfirm base-devel git

### Install yay as $SUDO_USER if not installed
if ! command -v yay &> /dev/null; then
  echo "yay not found, installing yay..."
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

### Packages to install from official repos
OFFICIAL_PKGS=(
  pipewire wireplumber pamixer brightnessctl
  ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans ttf-firacode-nerd
  ttf-iosevka-nerd ttf-iosevkaterm-nerd ttf-jetbrains-mono-nerd ttf-jetbrains-mono
  ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono
  sddm firefox unzip thunar thunar-archive-plugin thunar-volman xarchiver tumbler gvfs kitty nano code fastfetch starship tar
  hyprland xdg-desktop-portal-hyprland polkit-kde-agent dunst qt5-wayland qt6-wayland waybar cliphist
)

echo "Installing official repo packages..."
pacman -S --noconfirm "${OFFICIAL_PKGS[@]}"

### Enable sddm service
systemctl enable sddm.service

### Detect NVIDIA card and install drivers
if lspci -k | grep -EA3 'VGA|3D|Display' | grep -i nvidia > /dev/null; then
  echo "NVIDIA card detected, installing NVIDIA drivers..."
  pacman -S --noconfirm nvidia nvidia-utils nvidia-settings lib32-nvidia-utils opencl-nvidia
else
  echo "No NVIDIA card detected, skipping NVIDIA drivers."
fi

### Packages to install from AUR via yay
AUR_PKGS=(
  wofi swww hyprpicker hyprlock wlogout grimblast hypridle kvantum-theme-catppuccin-git thefuck
)

echo "Installing AUR packages with yay..."
sudo -u "$SUDO_USER" yay -S --noconfirm "${AUR_PKGS[@]}"

### Copy configs and assets

echo "Copying Hyprland config..."
mkdir -p "$USER_HOME/.config/hypr"
cp -r "$USER_HOME/hyprv1/configs/hypr/hyprland.conf" "$USER_HOME/.config/hypr/"

echo "Copying dunst config..."
mkdir -p "$USER_HOME/.config/dunst"
cp -r "$USER_HOME/hyprv1/configs/dunst/"* "$USER_HOME/.config/dunst/"

echo "Copying waybar config..."
mkdir -p "$USER_HOME/.config/waybar"
cp -r "$USER_HOME/hyprv1/configs/waybar/"* "$USER_HOME/.config/waybar/"

echo "Copying wofi config..."
mkdir -p "$USER_HOME/.config/wofi"
cp -r "$USER_HOME/hyprv1/configs/wofi/"* "$USER_HOME/.config/wofi/"

echo "Copying hyprlock config..."
mkdir -p "$USER_HOME/.config/hypr"
cp -r "$USER_HOME/hyprv1/configs/hypr/hyprlock.conf" "$USER_HOME/.config/hypr/"

echo "Copying hypridle config..."
mkdir -p "$USER_HOME/.config/hypr"
cp -r "$USER_HOME/hyprv1/configs/hypr/hypridle.conf" "$USER_HOME/.config/hypr/"

echo "Copying sample wallpapers..."
mkdir -p "$USER_HOME/.config/assets/backgrounds"
cp -r "$USER_HOME/hyprv1/assets/backgrounds/"* "$USER_HOME/.config/assets/backgrounds/"

echo "Copying Kitty config..."
mkdir -p "$USER_HOME/.config/kitty"
cp -r "$USER_HOME/hyprv1/configs/kitty/"* "$USER_HOME/.config/kitty/"

### Set up Starship and Fastfetch
echo "Setting up Starship and Fastfetch..."

mkdir -p "$USER_HOME/.config"
cp "$USER_HOME/hyprv1/configs/starship/starship.toml" "$USER_HOME/.config/starship.toml"

mkdir -p "$USER_HOME/.config/fastfetch"
cp "$USER_HOME/hyprv1/configs/fastfetch/config.conf" "$USER_HOME/.config/fastfetch/config.conf"

BASHRC="$USER_HOME/.bashrc"

#Add TheFuck Starship and Fastfetch into bashrc
if ! grep -q 'eval "$(thefuck' "$BASHRC"; then
  echo 'eval "$(thefuck --alias)"' >> "$BASHRC"
fi

if ! grep -q 'starship init bash' "$BASHRC"; then
  echo 'eval "$(starship init bash)"' >> "$BASHRC"
fi

if ! grep -q 'fastfetch' "$BASHRC"; then
  echo -e '\n# Show system info\nif command -v fastfetch &> /dev/null; then\n  fastfetch\nfi' >> "$BASHRC"
fi

### Fix ownership
chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.config"
chown "$SUDO_USER":"$SUDO_USER" "$BASHRC"

### Extract and install themes and icons

echo "Installing Catppuccin-Mocha GTK theme..."
tar -xf "$USER_HOME/hyprv1/assets/themes/Catppuccin-Mocha.tar.xz" -C /usr/share/themes/

echo "Installing Tela Circle Dracula icon theme..."
tar -xf "$USER_HOME/hyprv1/assets/icons/Tela-circle-dracula.tar.xz" -C /usr/share/icons/

echo "Installing Bibata cursor theme..."
tar -xf "$USER_HOME/hyprv1/assets/themes/Bibata-Modern-Ice.tar.xz" -C /usr/share/icons/

echo "Setting up Kvantum Catppuccin theme..."
# Already installed kvantum-theme-catppuccin-git from AUR above

### Apply GTK, icon, and cursor theme using gsettings

echo "Applying GTK, icon, and cursor themes for user $SUDO_USER..."
sudo -u "$SUDO_USER" dbus-launch gsettings set org.gnome.desktop.interface gtk-theme 'Catppuccin-Mocha'
sudo -u "$SUDO_USER" dbus-launch gsettings set org.gnome.desktop.interface icon-theme 'Tela-circle-dracula'
sudo -u "$SUDO_USER" dbus-launch gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Ice'

echo "Restarting Thunar for theme to apply..."
sudo -u "$SUDO_USER" pkill thunar || true
sleep 2

echo "All done! You can now log in to Hyprland."
echo "========================================"

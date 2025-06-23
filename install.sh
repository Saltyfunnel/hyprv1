#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/install.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Starting Simple Hyprland Installation with Catppuccin Moch Theme ==="
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

### Install official packages (Hyprland, utilities, fonts)
OFFICIAL_PKGS=(
  pipewire wireplumber pamixer brightnessctl
  ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code
  ttf-fira-mono ttf-fira-sans ttf-firacode-nerd ttf-iosevka-nerd
  ttf-iosevkaterm-nerd ttf-jetbrains-mono-nerd ttf-jetbrains-mono
  ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono
  sddm firefox unzip thunar thunar-archive-plugin thunar-volman
  xarchiver tumbler gvfs kitty nano code fastfetch starship tar
  hyprland xdg-desktop-portal-hyprland polkit-kde-agent dunst
  qt5-wayland qt6-wayland waybar cliphist
)

echo "Installing official repo packages..."
pacman -S --noconfirm "${OFFICIAL_PKGS[@]}"

### Enable sddm service
echo "Enabling sddm service..."
systemctl enable sddm.service --now

### Detect NVIDIA card and install drivers
echo "Detecting NVIDIA card..."
if lspci -k | grep -EA3 'VGA|3D|Display' | grep -i nvidia > /dev/null; then
  echo "NVIDIA card detected, installing NVIDIA drivers..."
  pacman -S --noconfirm nvidia nvidia-utils nvidia-settings lib32-nvidia-utils opencl-nvidia
else
  echo "No NVIDIA card detected, skipping NVIDIA drivers."
fi

### Install AUR packages
AUR_PKGS=(
  tofi swww hyprpicker hyprlock wlogout grimblast hypridle
  kvantum-theme-catppuccin-git
)

echo "Installing AUR packages..."
sudo -u "$SUDO_USER" yay -S --noconfirm "${AUR_PKGS[@]}"

### Install Catppuccin Moch Theme
echo "Installing Catppuccin Moch theme..."
yay -S --noconfirm catppuccin-mocha-hyprland

### Configure Hyprland and other programs to use the Catppuccin Moch theme

echo "Configuring Hyprland to use Catppuccin Moch theme..."
mkdir -p "$USER_HOME/.config/hypr"
cp "$USER_HOME/hyprv1/configs/hypr/hyprland.conf" "$USER_HOME/.config/hypr/"

cat >> "$USER_HOME/.config/hypr/hyprland.conf" <<EOL
# Hyprland Config for Catppuccin Moch
exec hyprctl theme CatppuccinMoch
EOL

echo "Configuring Kvantum to use Catppuccin Moch theme..."
mkdir -p "$USER_HOME/.config/Kvantum"
echo "export KVANTUM_THEME=catppuccin-mocha" >> "$USER_HOME/.profile"

echo "Configuring Tofi to use Catppuccin Moch theme..."
mkdir -p "$USER_HOME/.config/tofi"
echo "theme = catppuccin-mocha" > "$USER_HOME/.config/tofi/config"

echo "Configuring Grimblast to use Catppuccin Moch theme..."
mkdir -p "$USER_HOME/.config/grimblast"
echo "theme = catppuccin-mocha" > "$USER_HOME/.config/grimblast/config"

echo "Configuring Hyprlock to use Catppuccin Moch theme..."
mkdir -p "$USER_HOME/.config/hyprlock"
echo "theme = catppuccin-mocha" > "$USER_HOME/.config/hyprlock/config"

echo "Configuring Wlogout to use Catppuccin Moch theme..."
mkdir -p "$USER_HOME/.config/wlogout"
echo "theme = catppuccin-mocha" > "$USER_HOME/.config/wlogout/config"

### Copy the required assets and configs

echo "Copying configuration files for Hyprland, Waybar, etc..."
mkdir -p "$USER_HOME/.config/waybar"
cp -r "$USER_HOME/hyprv1/configs/waybar/"* "$USER_HOME/.config/waybar/"

mkdir -p "$USER_HOME/.config/kitty"
cp -r "$USER_HOME/hyprv1/configs/kitty/"* "$USER_HOME/.config/kitty/"

mkdir -p "$USER_HOME/.config/wofi"
cp -r "$USER_HOME/hyprv1/configs/wofi/"* "$USER_HOME/.config/wofi/"

mkdir -p "$USER_HOME/.config/dunst"
cp -r "$USER_HOME/hyprv1/configs/dunst/"* "$USER_HOME/.config/dunst/"

echo "Copying sample wallpapers..."
mkdir -p "$USER_HOME/.config/assets/backgrounds"
cp -r "$USER_HOME/hyprv1/assets/backgrounds/"* "$USER_HOME/.config/assets/backgrounds/"

### Finalizing setup

echo "Setting up Starship and Fastfetch..."

mkdir -p "$USER_HOME/.config"
cp "$USER_HOME/hyprv1/configs/starship/starship.toml" "$USER_HOME/.config/starship.toml"

mkdir -p "$USER_HOME/.config/fastfetch"
cp "$USER_HOME/hyprv1/configs/fastfetch/config.conf" "$USER_HOME/.config/fastfetch/config.conf"

BASHRC="$USER_HOME/.bashrc"

# Add TheFuck, Starship, and Fastfetch into bashrc
if ! grep -q 'eval "$(thefuck' "$BASHRC"; then
  echo 'eval "$(thefuck --alias)"' >> "$BASHRC"
fi

if ! grep -q 'starship init bash' "$BASHRC"; then
  echo 'eval "$(starship init bash)"' >> "$BASHRC"
fi

if ! grep -q 'fastfetch' "$BASHRC"; then
  echo -e '\n# Show system info\nif command -v fastfetch &> /dev/null; then\n  fastfetch\nfi' >> "$BASHRC"
fi

### Set correct ownership
chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.config"
chown "$SUDO_USER":"$SUDO_USER" "$BASHRC"

echo "All done! You can now reboot and enjoy your new environment."

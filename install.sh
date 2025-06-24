#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/full-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Full Hyprland + Catppuccin SDDM Setup ==="

# Check root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo."
  exit 1
fi

if [ -z "${SUDO_USER:-}" ]; then
  echo "Run this script using sudo, e.g. sudo bash install.sh"
  exit 1
fi

USER_HOME=$(eval echo "~$SUDO_USER")
BASHRC="$USER_HOME/.bashrc"
echo "Installing for user: $SUDO_USER"
echo "User home: $USER_HOME"

### --- System Update ---
echo "Updating system..."
pacman -Syyu --noconfirm

### --- Base Deps ---
echo "Installing base-devel and git..."
pacman -S --noconfirm base-devel git

### --- yay installation ---
if ! command -v yay &> /dev/null; then
  echo "Installing yay..."
  cd "$USER_HOME"
  sudo -u "$SUDO_USER" bash -c "
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
  "
fi

### --- Official Packages ---
OFFICIAL_PKGS=(
  pipewire wireplumber pamixer brightnessctl
  ttf-cascadia-code-nerd ttf-fira-code ttf-jetbrains-mono ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono
  sddm firefox unzip thunar kitty nano code fastfetch starship tar
  hyprland xdg-desktop-portal-hyprland polkit-kde-agent dunst qt5-wayland qt6-wayland waybar cliphist cava
)

echo "Installing official packages..."
pacman -S --noconfirm "${OFFICIAL_PKGS[@]}"

### --- Enable SDDM ---
systemctl enable sddm.service

### --- NVIDIA Drivers if needed ---
if lspci | grep -i nvidia > /dev/null; then
  echo "Installing NVIDIA drivers..."
  pacman -S --noconfirm nvidia nvidia-utils nvidia-settings lib32-nvidia-utils opencl-nvidia
fi

### --- AUR Packages ---
AUR_PKGS=(
  tofi swww hyprpicker hyprlock wlogout grimblast hypridle kvantum-theme-catppuccin-git thefuck
  sddm-theme-catppuccin
)

echo "Installing AUR packages..."
sudo -u "$SUDO_USER" yay -S --noconfirm "${AUR_PKGS[@]}"

### --- Detect Catppuccin SDDM Theme ---
THEME_DIR=$(find /usr/share/sddm/themes -maxdepth 1 -type d -name 'catppuccin*' | head -n 1)
THEME_NAME=$(basename "$THEME_DIR")

if [ ! -d "$THEME_DIR" ]; then
  echo "ERROR: Catppuccin SDDM theme not found."
  exit 1
fi

echo "Detected Catppuccin theme: $THEME_NAME"

### --- Configure SDDM Theme ---
if [ ! -f /etc/sddm.conf ]; then
  echo "Creating default /etc/sddm.conf..."
  sddm --example-config > /etc/sddm.conf
fi

if grep -q "^\[Theme\]" /etc/sddm.conf; then
  sed -i "/^\[Theme\]/,/^\[/ s/^Current=.*/Current=$THEME_NAME/" /etc/sddm.conf || \
  sed -i "/^\[Theme\]/a Current=$THEME_NAME" /etc/sddm.conf
else
  echo -e "\n[Theme]\nCurrent=$THEME_NAME" >> /etc/sddm.conf
fi

### --- Copy Configs ---
CONFIG_SRC="$USER_HOME/hyprv1"

declare -A CONFIGS=(
  [hypr]="$CONFIG_SRC/configs/hypr"
  [dunst]="$CONFIG_SRC/configs/dunst"
  [waybar]="$CONFIG_SRC/configs/waybar"
  [tofi]="$CONFIG_SRC/configs/tofi"
  [kitty]="$CONFIG_SRC/configs/kitty"
)

for key in "${!CONFIGS[@]}"; do
  echo "Copying $key config..."
  mkdir -p "$USER_HOME/.config/$key"
  cp -r "${CONFIGS[$key]}"/* "$USER_HOME/.config/$key/" || true
done

cp "$CONFIG_SRC/configs/hypr/hyprlock.conf" "$USER_HOME/.config/hypr/"
cp "$CONFIG_SRC/configs/hypr/hypridle.conf" "$USER_HOME/.config/hypr/"

echo "Copying assets (wallpapers)..."
mkdir -p "$USER_HOME/.config/assets/backgrounds"
cp -r "$CONFIG_SRC/assets/backgrounds/"* "$USER_HOME/.config/assets/backgrounds/"

echo "Setting wallpaper via swww..."
sudo -u "$SUDO_USER" swww init || true
sudo -u "$SUDO_USER" swww img "$USER_HOME/.config/assets/backgrounds/cat_leaves.jpg" || true

### --- Starship & Fastfetch ---
echo "Setting up Starship and Fastfetch..."
mkdir -p "$USER_HOME/.config"
cp "$CONFIG_SRC/configs/starship/starship.toml" "$USER_HOME/.config/starship.toml"
mkdir -p "$USER_HOME/.config/fastfetch"
cp "$CONFIG_SRC/configs/fastfetch/config.conf" "$USER_HOME/.config/fastfetch/config.conf"

# Bashrc additions
grep -qxF 'eval "$(thefuck --alias)"' "$BASHRC" || echo 'eval "$(thefuck --alias)"' >> "$BASHRC"
grep -qxF 'eval "$(starship init bash)"' "$BASHRC" || echo 'eval "$(starship init bash)"' >> "$BASHRC"
grep -q 'fastfetch' "$BASHRC" || echo -e '\n# Show system info\nif command -v fastfetch &> /dev/null; then\n  fastfetch\nfi' >> "$BASHRC"

### --- Add logout keybind ---
HYPR_CONF="$USER_HOME/.config/hypr/hyprland.conf"
grep -q 'logout-menu.sh' "$HYPR_CONF" || echo 'bind = SUPER+ESC, exec ~/.config/scripts/logout-menu.sh' >> "$HYPR_CONF"

### --- Fix Ownership ---
echo "Fixing config file ownerships..."
chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.config"
chown "$SUDO_USER":"$SUDO_USER" "$BASHRC"

### --- Themes and Icons ---
echo "Installing GTK and icon themes..."
tar -xf "$CONFIG_SRC/assets/themes/Catppuccin-Mocha.tar.xz" -C /usr/share/themes/
tar -xf "$CONFIG_SRC/assets/icons/Tela-circle-dracula.tar.xz" -C /usr/share/icons/

### --- Apply Themes via GSettings ---
echo "Applying GTK + icon theme..."
sudo -u "$SUDO_USER" dbus-launch gsettings set org.gnome.desktop.interface gtk-theme 'Catppuccin-Mocha'
sudo -u "$SUDO_USER" dbus-launch gsettings set org.gnome.desktop.interface icon-theme 'Tela-circle-dracula'

### --- Finish ---
echo "Restarting SDDM..."
systemctl restart sddm

echo "✅ All done! You can now log in to Hyprland."

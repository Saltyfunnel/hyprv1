#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/hyprland-catppuccin-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Starting Hyprland + Catppuccin SDDM Installation ==="
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
echo "Installing for user: $SUDO_USER"
echo "User home directory: $USER_HOME"

# Update system
echo "Updating system..."
pacman -Syyu --noconfirm

# Install yay if missing
if ! command -v yay &> /dev/null; then
  echo "Installing yay..."
  cd "$USER_HOME"
  sudo -u "$SUDO_USER" bash -c "
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
  "
fi

# Install official packages
OFFICIAL_PKGS=(
  pipewire wireplumber pamixer brightnessctl
  ttf-cascadia-code-nerd ttf-fira-code ttf-jetbrains-mono-nerd
  sddm firefox thunar kitty nano code fastfetch starship
  hyprland xdg-desktop-portal-hyprland polkit-kde-agent dunst
  qt5-wayland qt6-wayland waybar cliphist cava
)

echo "Installing official packages..."
pacman -S --noconfirm "${OFFICIAL_PKGS[@]}"

# NVIDIA driver check
if lspci -k | grep -iE 'vga|3d' | grep -iq nvidia; then
  echo "Installing NVIDIA drivers..."
  pacman -S --noconfirm nvidia nvidia-utils lib32-nvidia-utils opencl-nvidia
else
  echo "No NVIDIA GPU detected."
fi

# Install AUR packages
AUR_PKGS=(
  tofi swww hyprpicker hyprlock wlogout grimblast hypridle
  kvantum-theme-catppuccin-git thefuck sddm-theme-catppuccin
)

echo "Installing AUR packages..."
sudo -u "$SUDO_USER" yay -S --noconfirm "${AUR_PKGS[@]}"

# Set Catppuccin Mocha SDDM theme
echo "Configuring SDDM with Catppuccin Mocha theme..."
THEME_DIR="/usr/share/sddm/themes/catppuccin-mocha"

if [ -d "$THEME_DIR" ]; then
  if [ ! -f /etc/sddm.conf ]; then
    echo "Creating default /etc/sddm.conf..."
    sddm --example-config > /etc/sddm.conf
  fi

  if grep -q "^\[Theme\]" /etc/sddm.conf; then
    sed -i "/^\[Theme\]/,/^\[.*\]/ s/^Current=.*/Current=catppuccin-mocha/" /etc/sddm.conf || \
    sed -i "/^\[Theme\]/a Current=catppuccin-mocha" /etc/sddm.conf
  else
    echo -e "[Theme]\nCurrent=catppuccin-mocha" >> /etc/sddm.conf
  fi
else
  echo "ERROR: Catppuccin Mocha theme not found at $THEME_DIR"
fi

# Enable SDDM
systemctl enable sddm.service

# Copy dotfiles/configs
echo "Copying configuration files to $USER_HOME/.config..."
mkdir -p "$USER_HOME/.config"
cp -r "$USER_HOME/hyprv1/configs/"* "$USER_HOME/.config/"
cp -r "$USER_HOME/hyprv1/assets/backgrounds" "$USER_HOME/.config/assets/"

# Set up Starship + Fastfetch
cp "$USER_HOME/hyprv1/configs/starship/starship.toml" "$USER_HOME/.config/starship.toml"
cp "$USER_HOME/hyprv1/configs/fastfetch/config.conf" "$USER_HOME/.config/fastfetch/config.conf"

BASHRC="$USER_HOME/.bashrc"
grep -qxF 'eval "$(thefuck --alias)"' "$BASHRC" || echo 'eval "$(thefuck --alias)"' >> "$BASHRC"
grep -qxF 'eval "$(starship init bash)"' "$BASHRC" || echo 'eval "$(starship init bash)"' >> "$BASHRC"
grep -q 'fastfetch' "$BASHRC" || echo -e '\nif command -v fastfetch &> /dev/null; then\n  fastfetch\nfi' >> "$BASHRC"

# Add logout menu shortcut to Hyprland config
HYPR_CONF="$USER_HOME/.config/hypr/hyprland.conf"
grep -q 'logout-menu.sh' "$HYPR_CONF" || echo 'bind = SUPER+ESC, exec ~/.config/scripts/logout-menu.sh' >> "$HYPR_CONF"

# Fix permissions
chown -R "$SUDO_USER:$SUDO_USER" "$USER_HOME/.config"
chown "$SUDO_USER:$SUDO_USER" "$BASHRC"

# Install and extract GTK and icon themes
echo "Extracting and installing GTK and icon themes..."
tar -xf "$USER_HOME/hyprv1/assets/themes/Catppuccin-Mocha.tar.xz" -C /usr/share/themes/
tar -xf "$USER_HOME/hyprv1/assets/icons/Tela-circle-dracula.tar.xz" -C /usr/share/icons/

# Apply user theming with gsettings
echo "Applying GTK and icon themes..."
sudo -u "$SUDO_USER" dbus-launch gsettings set org.gnome.desktop.interface gtk-theme 'Catppuccin-Mocha'
sudo -u "$SUDO_USER" dbus-launch gsettings set org.gnome.desktop.interface icon-theme 'Tela-circle-dracula'

# Configure Kvantum to use Catppuccin Mocha
KVANTUM_DIR="$USER_HOME/.config/Kvantum"
mkdir -p "$KVANTUM_DIR"
echo '[General]' > "$KVANTUM_DIR/kvantum.kvconfig"
echo 'theme=Catppuccin-Mocha' >> "$KVANTUM_DIR/kvantum.kvconfig"
chown -R "$SUDO_USER:$SUDO_USER" "$KVANTUM_DIR"

# Optionally restart sddm
read -rp "Would you like to restart SDDM now? (y/N): " RESTART_SDDM
if [[ "$RESTART_SDDM" =~ ^[Yy]$ ]]; then
  systemctl restart sddm.service
else
  echo "Skipping SDDM restart. You can reboot manually later."
fi

echo "✅ Hyprland and Catppuccin Mocha setup completed successfully!"
echo "You can now reboot and log in to your themed Hyprland session."

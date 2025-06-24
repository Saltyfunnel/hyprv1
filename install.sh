#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

THEME_NAME="Catppuccin-Mocha" # Adjust this if needed after install

### Ensure root
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

### Update system
pacman -Syu --noconfirm

### Install base-devel and git
pacman -S --noconfirm base-devel git

### Install yay if not present
if ! command -v yay &> /dev/null; then
  echo "yay not found, installing..."
  cd "$USER_HOME"
  sudo -u "$SUDO_USER" bash -c '
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
  '
fi

### Install Hyprland-related official packages
pacman -S --noconfirm \
  pipewire wireplumber pamixer brightnessctl \
  ttf-cascadia-code-nerd ttf-fira-code ttf-jetbrains-mono-nerd \
  sddm firefox unzip thunar thunar-archive-plugin \
  kitty nano code fastfetch starship tar \
  hyprland xdg-desktop-portal-hyprland polkit-kde-agent \
  dunst qt5-wayland qt6-wayland waybar cliphist cava

### Install SDDM Catppuccin theme
sudo -u "$SUDO_USER" yay -S --noconfirm sddm-catppuccin-git

# Verify theme directory exists
if [ ! -d "/usr/share/sddm/themes/$THEME_NAME" ]; then
  echo "ERROR: Catppuccin SDDM theme not found at /usr/share/sddm/themes/$THEME_NAME"
  exit 1
fi

# Create /etc/sddm.conf if missing
if [ ! -f /etc/sddm.conf ]; then
  sddm --example-config > /etc/sddm.conf
fi

# Set Catppuccin theme in sddm.conf
if grep -q "^\[Theme\]" /etc/sddm.conf; then
  if grep -q "^Current=" /etc/sddm.conf; then
    sed -i "s/^Current=.*/Current=$THEME_NAME/" /etc/sddm.conf
  else
    sed -i "/^\[Theme\]/a Current=$THEME_NAME" /etc/sddm.conf
  fi
else
  echo -e "[Theme]\nCurrent=$THEME_NAME" >> /etc/sddm.conf
fi

# Enable SDDM
systemctl enable sddm.service
systemctl restart sddm.service

### Install AUR packages
sudo -u "$SUDO_USER" yay -S --noconfirm tofi swww hyprpicker hyprlock wlogout grimblast hypridle kvantum-theme-catppuccin-git thefuck

### Copy config files (adjust paths accordingly)
mkdir -p "$USER_HOME/.config/hypr"
cp "$USER_HOME/hyprv1/configs/hypr/hyprland.conf" "$USER_HOME/.config/hypr/"
cp "$USER_HOME/hyprv1/configs/hypr/hyprlock.conf" "$USER_HOME/.config/hypr/"
cp "$USER_HOME/hyprv1/configs/hypr/hypridle.conf" "$USER_HOME/.config/hypr/"
mkdir -p "$USER_HOME/.config/dunst"
cp -r "$USER_HOME/hyprv1/configs/dunst/"* "$USER_HOME/.config/dunst/"
mkdir -p "$USER_HOME/.config/waybar"
cp -r "$USER_HOME/hyprv1/configs/waybar/"* "$USER_HOME/.config/waybar/"
mkdir -p "$USER_HOME/.config/tofi"
cp -r "$USER_HOME/hyprv1/configs/tofi/"* "$USER_HOME/.config/tofi/"
mkdir -p "$USER_HOME/.config/assets/backgrounds"
cp -r "$USER_HOME/hyprv1/assets/backgrounds/"* "$USER_HOME/.config/assets/backgrounds/"
mkdir -p "$USER_HOME/.config/kitty"
cp -r "$USER_HOME/hyprv1/configs/kitty/"* "$USER_HOME/.config/kitty/"

mkdir -p "$USER_HOME/.config"
cp "$USER_HOME/hyprv1/configs/starship/starship.toml" "$USER_HOME/.config/starship.toml"
mkdir -p "$USER_HOME/.config/fastfetch"
cp "$USER_HOME/hyprv1/configs/fastfetch/config.conf" "$USER_HOME/.config/fastfetch/config.conf"

### Add to .bashrc
BASHRC="$USER_HOME/.bashrc"
if ! grep -q 'eval "$(thefuck' "$BASHRC"; then
  echo 'eval "$(thefuck --alias)"' >> "$BASHRC"
fi
if ! grep -q 'starship init bash' "$BASHRC"; then
  echo 'eval "$(starship init bash)"' >> "$BASHRC"
fi
if ! grep -q 'fastfetch' "$BASHRC"; then
  echo -e '\n# Show system info\nif command -v fastfetch &> /dev/null; then\n  fastfetch\nfi' >> "$BASHRC"
fi

# Hyprland logout menu keybind
HYPR_CONF="$USER_HOME/.config/hypr/hyprland.conf"
if ! grep -q 'logout-menu.sh' "$HYPR_CONF"; then
  echo 'bind = SUPER+ESC, exec ~/.config/scripts/logout-menu.sh' >> "$HYPR_CONF"
fi

# Fix ownership
chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.config"
chown "$SUDO_USER":"$SUDO_USER" "$BASHRC"

### Themes and icons
mkdir -p /usr/share/themes /usr/share/icons

# GTK theme
tar -xf "$USER_HOME/hyprv1/assets/themes/Catppuccin-Mocha.tar.xz" -C /usr/share/themes/
# Icon theme
tar -xf "$USER_HOME/hyprv1/assets/icons/Tela-circle-dracula.tar.xz" -C /usr/share/icons/

# GTK theme apply
sudo -u "$SUDO_USER" dbus-launch gsettings set org.gnome.desktop.interface gtk-theme "$THEME_NAME"
sudo -u "$SUDO_USER" dbus-launch gsettings set org.gnome.desktop.interface icon-theme "Tela-circle-dracula"

# Permissions fix for session file
chmod 644 /usr/share/wayland-sessions/hyprland.desktop
chown root:root /usr/share/wayland-sessions/hyprland.desktop

# Wallpaper (requires swww and running session)
echo "Ensure swww is set to autostart in Hyprland config to load wallpaper after login."
echo "All done! Reboot and login to Hyprland."
exit 0

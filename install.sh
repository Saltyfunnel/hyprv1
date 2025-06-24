#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Starting Hyprland + Catppuccin + SDDM Setup ==="
echo "Log file: $LOG_FILE"

# Ensure root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo."
  exit 1
fi

if [ -z "${SUDO_USER:-}" ]; then
  echo "Run this script using sudo, e.g. sudo bash install.sh"
  exit 1
fi

USER_HOME=$(eval echo "~$SUDO_USER")

### System update and yay installation
pacman -Syyu --noconfirm
pacman -S --noconfirm base-devel git

if ! command -v yay &>/dev/null; then
  cd "$USER_HOME"
  sudo -u "$SUDO_USER" bash -c "
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
  "
fi

### Install Official Packages
pacman -S --noconfirm pipewire wireplumber pamixer brightnessctl \
  ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono \
  ttf-fira-sans ttf-firacode-nerd ttf-iosevka-nerd ttf-iosevkaterm-nerd \
  ttf-jetbrains-mono-nerd ttf-jetbrains-mono ttf-nerd-fonts-symbols \
  ttf-nerd-fonts-symbols-mono sddm firefox unzip thunar thunar-archive-plugin \
  thunar-volman xarchiver tumbler gvfs kitty nano code fastfetch starship tar \
  hyprland xdg-desktop-portal-hyprland polkit-kde-agent dunst qt5-wayland \
  qt6-wayland waybar cliphist cava

### NVIDIA Drivers
if lspci | grep -i nvidia; then
  pacman -S --noconfirm nvidia nvidia-utils nvidia-settings lib32-nvidia-utils opencl-nvidia
fi

### Install AUR Packages
AUR_PKGS=(tofi swww hyprpicker hyprlock wlogout grimblast hypridle kvantum-theme-catppuccin-git thefuck sddm-theme-catppuccin)
sudo -u "$SUDO_USER" yay -S --noconfirm "${AUR_PKGS[@]}"

### Verify and configure SDDM theme
if [ ! -d /usr/share/sddm/themes/catppuccin ]; then
  echo "ERROR: Catppuccin SDDM theme not installed"
  exit 1
fi

if [ ! -f /etc/sddm.conf ]; then
  sddm --example-config > /etc/sddm.conf
fi

if grep -q "^\[Theme\]" /etc/sddm.conf; then
  sed -i "/^\[Theme\]/,/^\[.*\]/ s/^Current=.*/Current=catppuccin/" /etc/sddm.conf || sed -i "/^\[Theme\]/a Current=catppuccin" /etc/sddm.conf
else
  echo -e "\n[Theme]\nCurrent=catppuccin" >> /etc/sddm.conf
fi

systemctl enable sddm.service

### Copy Configs
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
mkdir -p "$USER_HOME/.config/kitty"
cp -r "$USER_HOME/hyprv1/configs/kitty/"* "$USER_HOME/.config/kitty/"
mkdir -p "$USER_HOME/.config/assets/backgrounds"
cp -r "$USER_HOME/hyprv1/assets/backgrounds/"* "$USER_HOME/.config/assets/backgrounds/"
mkdir -p "$USER_HOME/.config"
cp "$USER_HOME/hyprv1/configs/starship/starship.toml" "$USER_HOME/.config/starship.toml"
mkdir -p "$USER_HOME/.config/fastfetch"
cp "$USER_HOME/hyprv1/configs/fastfetch/config.conf" "$USER_HOME/.config/fastfetch/config.conf"

### Add wallpaper auto-launch to Hyprland config
WALLPAPER=$(ls "$USER_HOME/.config/assets/backgrounds" | head -n 1)
if ! grep -q 'swww img' "$USER_HOME/.config/hypr/hyprland.conf"; then
  echo "exec-once = swww init && sleep 0.5 && swww img ~/.config/assets/backgrounds/$WALLPAPER" >> "$USER_HOME/.config/hypr/hyprland.conf"
fi

### Add logout keybind
if ! grep -q 'logout-menu.sh' "$USER_HOME/.config/hypr/hyprland.conf"; then
  echo 'bind = SUPER+ESC, exec ~/.config/scripts/logout-menu.sh' >> "$USER_HOME/.config/hypr/hyprland.conf"
fi

### Shell Setup
BASHRC="$USER_HOME/.bashrc"
grep -q 'eval "$(thefuck' "$BASHRC" || echo 'eval "$(thefuck --alias)"' >> "$BASHRC"
grep -q 'starship init bash' "$BASHRC" || echo 'eval "$(starship init bash)"' >> "$BASHRC"
grep -q 'fastfetch' "$BASHRC" || echo -e '\n# Show system info\nif command -v fastfetch &> /dev/null; then\n  fastfetch\nfi' >> "$BASHRC"

### Install GTK and icon themes
tar -xf "$USER_HOME/hyprv1/assets/themes/Catppuccin-Mocha.tar.xz" -C /usr/share/themes/
tar -xf "$USER_HOME/hyprv1/assets/icons/Tela-circle-dracula.tar.xz" -C /usr/share/icons/

### Apply GTK theme and icon
sudo -u "$SUDO_USER" dbus-launch gsettings set org.gnome.desktop.interface gtk-theme 'Catppuccin-Mocha'
sudo -u "$SUDO_USER" dbus-launch gsettings set org.gnome.desktop.interface icon-theme 'Tela-circle-dracula'

### Fix permissions
chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.config"
chown "$SUDO_USER":"$SUDO_USER" "$BASHRC"

echo "=== DONE ==="
echo "SDDM is themed, Hyprland is installed, and wallpaper is applied!"
echo "You can now reboot and log in via SDDM to enjoy your setup."

#!/bin/bash

# ==============================
# Full Hyprland Desktop Installer
# ==============================

set -euo pipefail

LOG_FILE="/var/log/hyprland_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting full Hyprland install: $(date)"

# --- Detect user ---
USER_NAME="${SUDO_USER:-$(logname)}"
USER_HOME="/home/$USER_NAME"
HYPRV1_DIR="$USER_HOME/hyprv1"

if [ ! -d "$HYPRV1_DIR" ]; then
  echo "ERROR: Directory $HYPRV1_DIR not found! Clone your configs there before running."
  exit 1
fi

echo "Installing for user: $USER_NAME"

# --- Update system ---
echo "Updating system packages..."
pacman -Syu --noconfirm

# --- Install base packages ---
echo "Installing base-devel, git, curl, and other essentials..."
pacman -S --noconfirm base-devel git curl pipewire wireplumber pamixer brightnessctl

# --- Fonts ---
echo "Installing nerd fonts..."
pacman -S --noconfirm ttf-cascadia-code-nerd ttf-fira-code ttf-jetbrains-mono ttf-iosevka-nerd ttf-nerd-fonts-symbols

# --- Display manager ---
echo "Installing and enabling SDDM..."
pacman -S --noconfirm sddm
systemctl enable sddm.service

# --- Nvidia detection ---
echo "Checking for NVIDIA GPU..."
if lspci -k | grep -EA3 'VGA|3D|Display' | grep -i nvidia >/dev/null; then
  echo "NVIDIA GPU detected - installing drivers..."
  pacman -S --noconfirm nvidia nvidia-utils nvidia-settings lib32-nvidia-utils opencl-nvidia
else
  echo "No NVIDIA GPU detected - skipping NVIDIA drivers"
fi

# --- Install yay if missing ---
if ! command -v yay &>/dev/null; then
  echo "Installing yay AUR helper..."
  cd /opt
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
  cd -
else
  echo "yay already installed"
fi

# --- Core GUI packages ---
echo "Installing Firefox, Thunar, Kitty, Nano, VSCode, fastfetch, starship, tar..."
pacman -S --noconfirm firefox thunar thunar-archive-plugin thunar-volman tumbler gvfs kitty nano code fastfetch starship tar

# --- Utilities from official repos ---
echo "Installing utilities: waybar, cliphist, polkit-kde-agent, dunst, qt5-wayland, qt6-wayland, xdg-desktop-portal-hyprland"
pacman -S --noconfirm waybar cliphist polkit-kde-agent dunst qt5-wayland qt6-wayland xdg-desktop-portal-hyprland

# --- Utilities from AUR ---
echo "Installing utilities from AUR: wofi, swww, hyprpicker, hyprlock, wlogout, grimblast, hypridle, kvantum-theme-catppuccin-git"
yay -S --noconfirm --sudoloop wofi swww hyprpicker hyprlock wlogout grimblast hypridle kvantum-theme-catppuccin-git

# --- Install Hyprland ---
echo "Installing Hyprland..."
pacman -S --noconfirm hyprland

# --- Copy config files ---
echo "Copying config files for user..."
mkdir -p "$USER_HOME/.config/hypr"
cp -r "$HYPRV1_DIR/configs/hypr/hyprland.conf" "$USER_HOME/.config/hypr/"
cp -r "$HYPRV1_DIR/configs/hypr/hyprlock.conf" "$USER_HOME/.config/hypr/"
cp -r "$HYPRV1_DIR/configs/hypr/hypridle.conf" "$USER_HOME/.config/hypr/"

mkdir -p "$USER_HOME/.config/dunst"
cp -r "$HYPRV1_DIR/configs/dunst"/* "$USER_HOME/.config/dunst/"

mkdir -p "$USER_HOME/.config/waybar"
cp -r "$HYPRV1_DIR/configs/waybar"/* "$USER_HOME/.config/waybar/"

mkdir -p "$USER_HOME/.config/wofi"
cp -r "$HYPRV1_DIR/configs/wofi"/* "$USER_HOME/.config/wofi/"

mkdir -p "$USER_HOME/.config/wlogout"
cp -r "$HYPRV1_DIR/configs/wlogout"/* "$USER_HOME/.config/wlogout/"
mkdir -p "$USER_HOME/.config/assets/wlogout"
cp -r "$HYPRV1_DIR/assets/wlogout"/* "$USER_HOME/.config/assets/wlogout/"

mkdir -p "$USER_HOME/.config/kitty"
cp -r "$HYPRV1_DIR/configs/kitty"/* "$USER_HOME/.config/kitty/"

mkdir -p "$USER_HOME/.config/assets/backgrounds"
cp -r "$HYPRV1_DIR/assets/backgrounds"/* "$USER_HOME/.config/assets/backgrounds/"

# Fix permissions
chown -R "$USER_NAME":"$USER_NAME" "$USER_HOME/.config"

# --- Install GTK and icon themes ---
echo "Installing GTK and icon themes..."
tar -xvf "$HYPRV1_DIR/assets/themes/Catppuccin-Mocha.tar.xz" -C /usr/share/themes/
tar -xvf "$HYPRV1_DIR/assets/icons/Tela-circle-dracula.tar.xz" -C /usr/share/icons/

# --- Final instructions ---
echo
echo "============================================"
echo "All done! Your Hyprland environment is set up."
echo "Login as $USER_NAME, then:"
echo "- Run 'nwg-look' to set GTK theme and icons."
echo "- Use 'kvantummanager' to set Kvantum theme."
echo "- Run 'qt6ct' to configure Qt6 app themes."
echo "============================================"
echo

echo "Hyprland install completed at $(date). Log saved to $LOG_FILE"

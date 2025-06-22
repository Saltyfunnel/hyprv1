#!/bin/bash
set -euo pipefail

# --- Logging helpers ---
log() { echo -e "\033[1;32m[INFO]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
die() { echo -e "\033[1;31m[ERROR]\033[0m $*"; exit 1; }

# --- Pre-checks ---
if [[ "$EUID" -ne 0 ]]; then
  die "Please run this script as root (e.g., with sudo)."
fi

if [[ -z "${SUDO_USER:-}" ]]; then
  die "This script must be run via sudo (not as root directly)."
fi

USER_HOME="/home/$SUDO_USER"
CONFIG_REPO="$USER_HOME/hyprv1/configs"

# --- Config repo presence check ---
if [[ ! -d "$CONFIG_REPO" ]]; then
  die "Config repo not found at $CONFIG_REPO. Please clone your hyprv1 repo first."
fi

# --- Install yay ---
log "Installing yay (AUR helper)..."
rm -rf "$USER_HOME/yay"
sudo -u "$SUDO_USER" git clone https://aur.archlinux.org/yay.git "$USER_HOME/yay"
cd "$USER_HOME/yay"
sudo -u "$SUDO_USER" makepkg -si --noconfirm
cd - >/dev/null

# --- Install packages ---
log "Installing base packages..."
sudo -u "$SUDO_USER" yay -S --noconfirm \
    hyprland xdg-desktop-portal-hyprland \
    waybar thunar kitty firefox \
    sddm sddm-git ttf-jetbrains-mono-nerd \
    qt5-wayland qt6-wayland \
    polkit-gnome wl-clipboard gvfs xdg-user-dirs \
    brightnessctl pamixer playerctl grimblast-git \
    ttf-font-awesome papirus-icon-theme \
    nwg-look qt6ct qt5ct \
    gnome-themes-extra materia-gtk-theme

# --- NVIDIA support ---
if lspci | grep -i nvidia &>/dev/null; then
  log "NVIDIA GPU detected. Installing NVIDIA packages..."
  sudo -u "$SUDO_USER" yay -S --noconfirm nvidia-dkms nvidia-utils libva libva-nvidia-driver-git
fi

# --- Create config directories ---
log "Creating config directories..."
CONFIG_DIRS=( hypr waybar kitty thunar qt5ct qt6ct )
for dir in "${CONFIG_DIRS[@]}"; do
  mkdir -p "$USER_HOME/.config/$dir"
done

# --- Copy configs ---
log "Copying configuration files from $CONFIG_REPO..."
cp -rT "$CONFIG_REPO/hypr" "$USER_HOME/.config/hypr"
cp -rT "$CONFIG_REPO/waybar" "$USER_HOME/.config/waybar"
cp -rT "$CONFIG_REPO/kitty" "$USER_HOME/.config/kitty"
cp -rT "$CONFIG_REPO/thunar" "$USER_HOME/.config/thunar"
cp -rT "$CONFIG_REPO/qt5ct" "$USER_HOME/.config/qt5ct"
cp -rT "$CONFIG_REPO/qt6ct" "$USER_HOME/.config/qt6ct"

# --- GTK Theme, Icons, Cursor ---
GTK_THEME="Catppuccin-Mocha-Standard-Blue-Dark"
ICON_THEME="Papirus-Dark"
CURSOR_THEME="Bibata-Modern-Ice"

log "Setting GTK, icon, and cursor themes..."
sudo -u "$SUDO_USER" dbus-launch gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME"
sudo -u "$SUDO_USER" dbus-launch gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME"
sudo -u "$SUDO_USER" dbus-launch gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME"

# --- Extract themes ---
log "Installing themes and cursors..."
mkdir -p "$USER_HOME/.themes" "$USER_HOME/.icons"

THEME_ARCHIVE="$USER_HOME/hyprv1/assets/themes/Catppuccin-Mocha.tar.xz"
CURSOR_ARCHIVE="$USER_HOME/hyprv1/assets/cursors/Bibata-Modern-Ice.tar.xz"

if [[ -f "$THEME_ARCHIVE" ]]; then
  tar -xf "$THEME_ARCHIVE" -C "$USER_HOME/.themes"
else
  warn "Theme archive not found at $THEME_ARCHIVE"
fi

if [[ -f "$CURSOR_ARCHIVE" ]]; then
  tar -xf "$CURSOR_ARCHIVE" -C "$USER_HOME/.icons"
else
  warn "Cursor archive not found at $CURSOR_ARCHIVE"
fi

# --- GTK fallback settings file ---
log "Writing fallback GTK settings..."
mkdir -p "$USER_HOME/.config/gtk-3.0"
cat > "$USER_HOME/.config/gtk-3.0/settings.ini" <<EOF
[Settings]
gtk-theme-name=$GTK_THEME
gtk-icon-theme-name=$ICON_THEME
gtk-cursor-theme-name=$CURSOR_THEME
EOF

# --- Enable and restart SDDM ---
log "Enabling SDDM login manager..."
systemctl enable sddm

read -rp "⚠️  Restarting SDDM will log you out. Press Enter to continue or Ctrl+C to cancel..."
systemctl restart sddm

# --- Fix ownership ---
log "Fixing ownership for $SUDO_USER..."
chown -R "$SUDO_USER:$SUDO_USER" "$USER_HOME"

log "✅ Hyprland setup complete."

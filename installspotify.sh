#!/bin/bash

# Function to install Spotify
install_spotify() {
  echo "Installing Spotify..."
  sudo pacman -Sy --noconfirm spotify
  if [ $? -eq 0 ]; then
    echo "Spotify installed successfully."
  else
    echo "Spotify installation failed. Please check your internet or repos."
    exit 1
  fi
}

# Function to install Spicetify and Catppuccino theme
install_spicetify_catppuccino() {
  if ! command -v yay &> /dev/null; then
    echo "Error: yay is not installed. Please install yay first to proceed with Spicetify."
    exit 1
  fi

  echo "Installing spicetify-cli..."
  yay -S --noconfirm spicetify-cli

  echo "Backing up current Spicetify config..."
  spicetify backup

  echo "Cloning Catppuccino theme..."
  THEME_DIR="$HOME/.config/spicetify/Themes/Catppuccino"
  if [ ! -d "$THEME_DIR" ]; then
    git clone https://github.com/spicetify-themes/Catppuccino.git "$THEME_DIR"
  else
    echo "Catppuccino theme already exists."
  fi

  echo "Configuring Spicetify with Catppuccino theme..."
  spicetify config current_theme Catppuccino
  spicetify config inject_css 1
  spicetify config inject_js 1
  spicetify config replace_colors 1
  spicetify config color_scheme Catppuccino

  echo "Applying Spicetify changes..."
  spicetify apply

  echo "Spicetify installation and theme applied! Restart Spotify to see changes."
}

# Main script starts here

echo "Do you want to install Spotify? (y/n)"
read -r install_spotify_choice
if [[ "$install_spotify_choice" =~ ^[Yy]$ ]]; then
  install_spotify
else
  echo "Skipping Spotify installation."
fi

echo "Do you want to install Spicetify and apply Catppuccino theme? (y/n)"
read -r install_spicetify_choice
if [[ "$install_spicetify_choice" =~ ^[Yy]$ ]]; then
  install_spicetify_catppuccino
else
  echo "Skipping Spicetify installation."
fi

echo "All done!"

#!/bin/bash

CHOICE=$(printf "Logout\nReboot\nShutdown\nSuspend\nCancel" | wofi --dmenu --prompt "Select action:" --style ~/.config/wofi/style.css)

case "$CHOICE" in
  Logout)
    hyprctl dispatch exit
    ;;
  Reboot)
    systemctl reboot
    ;;
  Shutdown)
    systemctl poweroff
    ;;
  Suspend)
    systemctl suspend
    ;;
  Cancel|*)
    ;;
esac

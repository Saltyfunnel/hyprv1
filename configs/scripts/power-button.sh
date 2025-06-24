#!/bin/bash

case "$1" in
  left)
    systemctl poweroff
    ;;
  right)
    systemctl reboot
    ;;
  *)
    notify-send "Power" "Click to Shutdown (left), Reboot (right)"
    ;;
esac

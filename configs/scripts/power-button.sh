#!/bin/bash

case "$1" in
    left)
        systemctl poweroff
        ;;
    right)
        systemctl reboot
        ;;
    *)
        echo "Usage: $0 {left|right}"
        ;;
esac

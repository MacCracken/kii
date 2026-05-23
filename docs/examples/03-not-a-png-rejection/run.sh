#!/bin/sh
# kii error path — feed a non-PNG file and observe the diagnostic.
# Any text file works; we use /etc/hostname which exists on every
# Linux system.
./build/kii /etc/hostname
echo "exit code: $?"

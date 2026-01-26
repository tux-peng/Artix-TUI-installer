# Changelog

## 2026-01-26

New Features
AUR Support Toggle: Added a prompt to enable/disable AUR support.

Enabling this allows for the installation of extra fonts and monitor-control-qt.

Note: The "Additional Fonts" menu is now hidden if AUR support is declined.

Btrfs Snapshots: Added an option to enable automatic Btrfs snapshots (grub-btrfs) when "Btrfs" is selected as the root filesystem.

Includes automatic service enabling for OpenRC, Runit, and Dinit.

Installs dependencies: grub-btrfs and inotify-tools.

Bug Fixes & Improvements
NVMe/MMC Partition Naming: Fixed partition numbering logic for NVMe and MMC drives. The script now correctly appends the p prefix (e.g., nvme0n1p1 instead of nvme0n11).

Variable Injection: Fixed an issue where variables selected in the host environment (Filesystem choice, Snapshot preference) were not being passed correctly into the chroot environment for configuration.

SSH Installation: Refined the SSH installation process to ensure the base openssh package is installed alongside the init-specific package (e.g., openssh-runit).

GRUB Configuration: Added os-prober to the standard GRUB package installation list to ensure dual-boot detection capabilities.

Documentation (readme.md)
BIOS Support: Updated status of Legacy BIOS support from "experimental" to "untested".

Installation: Added a curl command to download the script directly from the main branch, alongside the stable release tag command.

---

## v1.0.0 — Initial Release

* Multi-init Artix installer
* Auto/manual partitioning
* Desktop and display manager selection
* Basic bootloader support

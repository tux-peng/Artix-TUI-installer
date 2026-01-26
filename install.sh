#!/bin/bash

# ==============================================================================
#  SonicDE Artix Installer (Universal Init Edition)
#  Features: Auto-Detects Init, Multi-DE, Custom KDE Apps, Smart Pkg Mgr, Fonts
# ==============================================================================

# -- 0. Root Check --
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root. Try: sudo ./install.sh"
  exit 1
fi

# -- Colors & Variables --
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
MOUNT_POINT="/mnt"
LOG="/tmp/installer.log"

[ -f "$LOG" ] && rm "$LOG"

# -- Helper Functions --
log() { echo -e "${GREEN}[*] $1${NC}" | tee -a "$LOG"; }
err() { echo -e "${RED}[!] $1${NC}" | tee -a "$LOG"; exit 1; }

# -- 1. Auto-Detect Init System --
detect_init() {
    if command -v rc-update &>/dev/null; then
        INIT_SYS="openrc"
    elif command -v runit &>/dev/null; then
        INIT_SYS="runit"
    elif command -v dinitctl &>/dev/null; then
        INIT_SYS="dinit"
    elif command -v s6-rc &>/dev/null; then
        INIT_SYS="s6"
    else
        err "Could not detect init system (OpenRC, Runit, s6, or Dinit)."
    fi
    log "Detected Init System: $INIT_SYS"
}

# -- 2. Disclaimer Warning --
show_disclaimer() {
    if ! command -v dialog &>/dev/null; then
        pacman -Sy --noconfirm dialog &>/dev/null
    fi

    dialog --title "⚠️ EXPERIMENTAL INSTALLER ⚠️" \
           --msgbox "\nDetected Init System: $INIT_SYS\n\n\
WARNING: The AI wrote 80% of this script.\n\n\
TESTING STATUS:\n\
Only SonicDE on OpenRC with SDDM using GRUB & rEFInd have been explicitly tested.\n\n\
Additionally, only Auto-Partitioning and UEFI Systems have been tested.\n\n\
Other combinations (Runit/s6/Dinit, other DEs, Manual Partitioning, BIOS/CSM) are experimental.\n\n\
Press OK to proceed at your own risk." 18 60
}

# -- 3. Pre-Flight Checks --
pre_flight() {
    clear
    log "Checking environment..."
    if ! ping -c 1 google.com &>/dev/null; then
        err "No internet connection. Please connect manually."
    fi

    log "Updating Artix Keyring..."
    pacman -Sy --noconfirm artix-keyring
    pacman -S --noconfirm dialog git || err "Failed to install dependencies."
}

# -- 4. Configure Artix Repos --
setup_artix_repos() {
    local TARGET_ROOT="$1"
    local CONF_PATH="${TARGET_ROOT}/etc/pacman.conf"

    log "Configuring Artix Repositories on ${TARGET_ROOT:-Live System}..."

    if ! grep -q "^\[galaxy\]" "$CONF_PATH"; then
        sed -i '/#\[galaxy\]/s/^#//g' "$CONF_PATH" 2>/dev/null
        sed -i '/\[galaxy\]/{n;s/^#//}' "$CONF_PATH" 2>/dev/null
        if ! grep -q "^\[galaxy\]" "$CONF_PATH"; then
            echo -e "\n[galaxy]\nInclude = /etc/pacman.d/mirrorlist" >> "$CONF_PATH"
        fi
    fi

    if ! grep -q "^\[lib32\]" "$CONF_PATH"; then
        sed -i '/#\[lib32\]/s/^#//g' "$CONF_PATH" 2>/dev/null
        sed -i '/\[lib32\]/{n;s/^#//}' "$CONF_PATH" 2>/dev/null
    fi

    if [ -z "$TARGET_ROOT" ]; then pacman -Sy; fi
}

# -- 5. Menus --
select_menu_options() {
    # Drive
    OPTIONS=()
    while read -r name size model; do
        desc="${size}_${model// /_}"
        OPTIONS+=("$name" "$desc")
    done < <(lsblk -dnp -o NAME,SIZE,MODEL | grep -v 'loop' | grep -v 'sr0')

    if [ ${#OPTIONS[@]} -eq 0 ]; then err "No disks found."; fi
    DISK=$(dialog --stdout --menu "Select Installation Disk" 15 60 5 "${OPTIONS[@]}") || exit 1

    # Partition Method
    METHOD=$(dialog --stdout --menu "Partitioning Method" 12 60 2 \
        "Auto" "Automatic (Wipe Disk)" \
        "Manual" "Manual via cfdisk (Standard)") || exit 1

    # Auto Options (FS & Swap)
    SWAP_SIZE_GB="0"
    if [ "$METHOD" == "Auto" ]; then
        FS_CHOICE=$(dialog --stdout --menu "Select Root Filesystem" 12 60 3 \
            "Btrfs" "Modern, Copy-on-Write (Snapshot support)" \
            "EXT4" "Standard, reliable, widely supported" \
            "F2FS" "Flash-Friendly (Optimized for SSDs/NVMe)") || exit 1

        TOTAL_RAM_MB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        TOTAL_RAM_GB=$(awk -v ram="$TOTAL_RAM_MB" 'BEGIN { printf "%.0f", ram/1024/1024 }')
        if [ "$TOTAL_RAM_GB" -eq 0 ]; then TOTAL_RAM_GB=1; fi

        SWAP_CHOICE=$(dialog --stdout --menu "Swap Partition Size" 12 60 3 \
            "RAM" "Use detected RAM size (${TOTAL_RAM_GB}GB)" \
            "Manual" "Enter a custom size (GB)" \
            "None" "Do not create a swap partition") || exit 1

        case "$SWAP_CHOICE" in
            "RAM") SWAP_SIZE_GB="$TOTAL_RAM_GB" ;;
            "Manual")
                SWAP_SIZE_GB=$(dialog --stdout --inputbox "Enter Swap size in GB (e.g., 4, 8, 16):" 10 40) || exit 1
                if ! [[ "$SWAP_SIZE_GB" =~ ^[0-9]+$ ]]; then err "Invalid swap size entered."; fi
                ;;
            "None") SWAP_SIZE_GB="0" ;;
        esac
    else
        FS_CHOICE="Manual"
    fi

    # Bootloader
    BOOTLOADER=$(dialog --stdout --menu "Select Bootloader" 13 60 3 \
        "GRUB" "Standard, reliable" \
        "rEFInd" "Graphical, auto-detects" \
        "Limine" "Modern, simple config (PROBABLY BROKEN)") || exit 1

    # Desktop Environment Selection
    DE_CHOICE=$(dialog --stdout --menu "Select Desktop Environment" 16 60 6 \
        "SonicDE" "Plasma Desktop (XLibre Fixes) (Meta Package)" \
        "KDE" "Plasma Desktop (Modern, Customizable)" \
        "Moksha" "Focuses on stability and low resource usage" \
        "MATE" "Traditional (Fork of GNOME 2)" \
        "XFCE4" "Lightweight, Stable, Classic" \
        "LXQt" "Extremely Lightweight (Qt-based)") || exit 1

    # Display Manager Selection
    DM_CHOICE=$(dialog --stdout --menu "Select Display Manager" 13 60 3 \
        "SDDM" "Modern, Qt-based (Recommended for KDE/Sonic/LXQt)" \
        "LightDM" "Lightweight, GTK-based (Recommended for XFCE/MATE)" \
        "XDM" "Minimalist, old-school") || exit 1

    # Font Selection
    FONT_CHOICES=$(dialog --stdout --checklist "Select Additional Fonts (Space to select, Enter to confirm)" 18 75 7 \
        "Monterey" "Fonts extracted from the MacOS Monterey CD" off \
        "Apple-SF" "Fonts extracted from Apples developer webpage" off \
        "Cursive" "otf-frb-american-cursive (50+ faces for education)" off \
        "Annotation" "ttf-annotation-mono-variable (Handwriting style)" off \
        "MS-Fonts" "ttf-ms-fonts (Times New Roman, Arial)" off \
        "Adobe-Base" "adobe-base-14-fonts (Helvetica, Courier)" off \
        "Vista" "ttf-vista-fonts (Calibri, Cambria, Consolas)" off) || FONT_CHOICES=""

    # SSH Option
    dialog --defaultno --yesno "Do you want to enable SSH Server (openssh)?" 8 60
    if [ $? -eq 0 ]; then ENABLE_SSH="yes"; else ENABLE_SSH="no"; fi

    # Timezone
    REGIONS=$(find /usr/share/zoneinfo -maxdepth 1 -mindepth 1 -type d -printf "%f\n" | sort)
    REGION_ARGS=(); for r in $REGIONS; do REGION_ARGS+=("$r" "-"); done
    REGION=$(dialog --stdout --menu "Select Region" 15 40 5 "${REGION_ARGS[@]}") || exit 1

    CITIES=$(find "/usr/share/zoneinfo/$REGION" -maxdepth 1 -mindepth 1 -type f -printf "%f\n" | sort)
    CITY_ARGS=(); for c in $CITIES; do CITY_ARGS+=("$c" "-"); done
    CITY=$(dialog --stdout --menu "Select City" 15 40 10 "${CITY_ARGS[@]}") || exit 1
    TIMEZONE="${REGION}/${CITY}"
}

# -- 6. Partitioning --
partition_drive() {
    if [ "$METHOD" == "Auto" ]; then
        dialog --defaultno --yesno "WARNING: ALL DATA ON $DISK WILL BE ERASED. PROCEED?" 10 60 || exit 1
        clear
        log "Wiping $DISK..."
        sgdisk -Z "$DISK"
        sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI" "$DISK"

        if [ "$SWAP_SIZE_GB" -gt 0 ]; then
            log "Creating ${SWAP_SIZE_GB}GB Swap..."
            sgdisk -n 2:0:+${SWAP_SIZE_GB}G -t 2:8200 -c 2:"SWAP" "$DISK"
            sgdisk -n 3:0:0                 -t 3:8300 -c 3:"ROOT" "$DISK"

            if [[ "$DISK" == *"nvme"* ]]; then
                EFI_PART="${DISK}p1"; SWAP_PART="${DISK}p2"; ROOT_PART="${DISK}p3"
            else
                EFI_PART="${DISK}1"; SWAP_PART="${DISK}2"; ROOT_PART="${DISK}3"
            fi
            mkswap "$SWAP_PART" && swapon "$SWAP_PART"
        else
            log "No Swap selected."
            sgdisk -n 2:0:0 -t 2:8300 -c 2:"ROOT" "$DISK"

            if [[ "$DISK" == *"nvme"* ]]; then
                EFI_PART="${DISK}p1"; ROOT_PART="${DISK}p2"
            else
                EFI_PART="${DISK}1"; ROOT_PART="${DISK}2"
            fi
        fi

        mkfs.vfat -F32 "$EFI_PART"

        log "Formatting Root as $FS_CHOICE..."
        case "$FS_CHOICE" in
            "Btrfs") mkfs.btrfs -f "$ROOT_PART" ;;
            "EXT4")  mkfs.ext4 -F "$ROOT_PART" ;;
            "F2FS")
                if ! command -v mkfs.f2fs &>/dev/null; then pacman -S --noconfirm f2fs-tools; fi
                mkfs.f2fs -f "$ROOT_PART"
                ;;
        esac

        ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
        log "Detected Root UUID: $ROOT_UUID"

        if [ "$FS_CHOICE" == "Btrfs" ]; then
            mount "$ROOT_PART" "$MOUNT_POINT"
            btrfs subvolume create "$MOUNT_POINT/@"
            btrfs subvolume create "$MOUNT_POINT/@home"
            btrfs subvolume create "$MOUNT_POINT/@snapshots"
            btrfs subvolume create "$MOUNT_POINT/@var_log"
            umount "$MOUNT_POINT"

            mount -o noatime,compress=zstd,subvol=@ "$ROOT_PART" "$MOUNT_POINT"
            mkdir -p "$MOUNT_POINT"/{home,.snapshots,var/log,boot}
            mount -o noatime,compress=zstd,subvol=@home "$ROOT_PART" "$MOUNT_POINT/home"
            mount -o noatime,compress=zstd,subvol=@snapshots "$ROOT_PART" "$MOUNT_POINT/.snapshots"
            mount -o noatime,compress=zstd,subvol=@var_log "$ROOT_PART" "$MOUNT_POINT/var/log"
        else
            mount "$ROOT_PART" "$MOUNT_POINT"
            mkdir -p "$MOUNT_POINT"/boot
        fi

        mount "$EFI_PART" "$MOUNT_POINT/boot"

    else
        clear
        log "Launching cfdisk..."
        cfdisk "$DISK"
        dialog --msgbox "Partitioning complete.\n\nPlease manually mount partitions to /mnt now.\n(Alt+F2 to open terminal)\n\nIMPORTANT: When done, you must identify your ROOT partition so we can get the UUID." 12 60
        ROOT_PART=$(dialog --stdout --inputbox "Enter Root Partition (e.g. /dev/sda3):" 10 60) || exit 1
        ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
        if [ -z "$ROOT_UUID" ]; then err "Could not determine UUID. Exiting."; fi
        log "Detected Root UUID: $ROOT_UUID"
    fi
}

# -- 7. Base Install (Init-Aware) --
install_base() {
    clear
    log "Installing Artix Base System ($INIT_SYS)..."

    case "$INIT_SYS" in
        "openrc") PACKAGES="openrc elogind-openrc networkmanager-openrc" ;;
        "runit")  PACKAGES="runit elogind-runit networkmanager-runit" ;;
        "dinit")  PACKAGES="dinit elogind-dinit networkmanager-dinit" ;;
        "s6")     PACKAGES="s6-base elogind-s6 networkmanager-s6" ;;
    esac

    FS_TOOLS=""
    if [ "$FS_CHOICE" == "Btrfs" ]; then FS_TOOLS="btrfs-progs"; fi
    if [ "$FS_CHOICE" == "F2FS" ]; then FS_TOOLS="f2fs-tools"; fi

    basestrap "$MOUNT_POINT" base base-devel elogind linux linux-firmware \
                             networkmanager nano git dialog $FS_TOOLS $PACKAGES || err "Basestrap failed."

    fstabgen -U "$MOUNT_POINT" >> "$MOUNT_POINT/etc/fstab"
    if [ ! -f "$MOUNT_POINT/bin/bash" ]; then err "Base install failed. /mnt/bin/bash not found."; fi
}

# -- 8. Configure Target --
configure_system() {
    local TARGET_UUID="$1"
    local SELECTED_FONTS="$2"

    HOSTNAME=$(dialog --stdout --inputbox "Enter Hostname:" 10 40 "artixlinux")
    USERNAME=$(dialog --stdout --inputbox "Enter Username:" 10 40 "user")

    while true; do
        PASS1=$(dialog --insecure --stdout --passwordbox "Enter Password:" 10 40)
        [ -z "$PASS1" ] && continue
        PASS2=$(dialog --insecure --stdout --passwordbox "Confirm Password:" 10 40)
        if [ "$PASS1" == "$PASS2" ]; then PASSWORD="$PASS1"; break; else dialog --msgbox "Passwords do not match." 10 40; fi
    done

    cp /etc/resolv.conf "$MOUNT_POINT/etc/resolv.conf"

    cat <<EOF > "$MOUNT_POINT/setup_internal.sh"
#!/bin/bash
set -e
exec < /dev/tty

# --- Function: Enable Service ---
enable_service() {
    SERVICE="\$1"
    echo "Enabling \$SERVICE for $INIT_SYS..."
    case "$INIT_SYS" in
        "openrc") rc-update add "\$SERVICE" default ;;
        "runit")  ln -s /etc/runit/sv/"\$SERVICE" /etc/runit/runsvdir/default ;;
        "dinit")  dinitctl enable "\$SERVICE" ;;
        "s6")     if command -v s6-rc-bundle-update &>/dev/null; then s6-rc-bundle-update add default "\$SERVICE"; fi ;;
    esac
}
# ------------------------------

echo "Starting Artix Configuration ($INIT_SYS)..."
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "export LANG=en_US.UTF-8" >> /etc/profile
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

enable_service NetworkManager

# Enable SSH
if [ "$ENABLE_SSH" == "yes" ]; then
    echo "Enabling SSH..."
    SSH_PKG="openssh"
    case "$INIT_SYS" in
        "openrc") SSH_PKG="openssh-openrc" ;;
        "runit")  SSH_PKG="openssh-runit" ;;
        "dinit")  SSH_PKG="openssh-dinit" ;;
        "s6")     SSH_PKG="openssh-s6" ;;
    esac
    pacman -S --noconfirm openssh \$SSH_PKG
    enable_service sshd
fi

# Repos
pacman-key --init
pacman-key --populate artix
if ! grep -q "^\[galaxy\]" /etc/pacman.conf; then
    echo -e "\n[galaxy]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
fi
pacman -Sy

# User
echo "root:$PASSWORD" | chpasswd
useradd -m -G wheel -s /bin/bash "$USERNAME" || true
echo "$USERNAME:$PASSWORD" | chpasswd

# Install Desktop
echo "Installing Desktop: $DE_CHOICE"
case "$DE_CHOICE" in
    "SonicDE")
        echo "Installing SonicDE base + Konsole..."
        pacman -S --noconfirm sonicde-meta konsole || echo "Warning: SonicDE-Meta not found."

        # --- SonicDE KDE Applications Selection ---
        KDE_APPS_CHOICE=\$(dialog --stdout --checklist "Select KDE Application Groups to install:" 18 60 8 \\
            "kde-applications" "Full KDE Suite (Heavy)" off \\
            "kde-graphics" "Graphics (Gwenview, Spectacle)" off \\
            "kde-multimedia" "Multimedia (Elisa, Kdenlive)" off \\
            "kde-network" "Network (KGet, Krdc)" off \\
            "kde-office" "Office (Okular)" off \\
            "kde-pim" "PIM (KMail, Kontact)" off \\
            "kde-system" "System Tools (Dolphin, KSystemLog)" off \\
            "kde-utilities" "Utilities (Kate, Ark, Calc)" off)

        if [ -n "\$KDE_APPS_CHOICE" ]; then
            KDE_APPS_LIST=\$(echo \$KDE_APPS_CHOICE | tr -d '"')
            echo "Installing selected KDE groups: \$KDE_APPS_LIST"
            pacman -S --noconfirm \$KDE_APPS_LIST
        fi

        # --- Install monitor-control-qt (AUR) for SonicDE ---
        echo "Installing monitor-control-qt (AUR)..."
        # Ensure yaourtix is installed
        pacman -S --noconfirm yaourtix

        # Allow temp sudo without password
        echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/00_temp_installer

        # Build as user
        su - "$USERNAME" -c "yaourtix -S --noconfirm monitor-control-qt"

        # Cleanup
        rm /etc/sudoers.d/00_temp_installer
        ;;
    "KDE")     pacman -S --noconfirm plasma kde-applications konsole ;;
    "Moksha")  pacman -S --noconfirm moksha-artix terminology ;;
    "MATE")    pacman -S --noconfirm mate mate-extra system-config-printer blueman connman-gtk mate-terminal ;;
    "XFCE4")   pacman -S --noconfirm xfce4 xfce4-goodies xfce4-terminal ;;
    "LXQt")    pacman -S --noconfirm lxqt breeze-icons qterminal ;;
esac

# Install Pkg Manager
case "$DE_CHOICE" in
    "SonicDE"|"KDE"|"LXQt") pacman -S --noconfirm octopi trizen ;;
    *) pacman -S --noconfirm pamac-gtk || pacman -S --noconfirm pamac-all || echo "Warning: Pamac not found." ;;
esac

# Install Fonts (Yaourtix)
TARGET_FONTS='$SELECTED_FONTS'

if [ -n "\$TARGET_FONTS" ]; then
    echo "Installing Selected Fonts..."
    pacman -S --noconfirm yaourtix
    echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/00_temp_installer

    if [[ "\$TARGET_FONTS" == *"Monterey"* ]]; then
        echo "Building Monterey Fonts..."
        su - "$USERNAME" -c "yaourtix -S --noconfirm ttf-monterey-fonts-en"
    fi
    if [[ "\$TARGET_FONTS" == *"Apple-SF"* ]]; then
        echo "Building Apple SF Fonts..."
        su - "$USERNAME" -c "yaourtix -S --noconfirm apple-sf-fonts"
    fi
    if [[ "\$TARGET_FONTS" == *"Cursive"* ]]; then
        echo "Building FRB American Cursive..."
        su - "$USERNAME" -c "yaourtix -S --noconfirm otf-frb-american-cursive"
    fi
    if [[ "\$TARGET_FONTS" == *"Annotation"* ]]; then
        echo "Building Annotation Mono..."
        su - "$USERNAME" -c "yaourtix -S --noconfirm ttf-annotation-mono-variable"
    fi
    if [[ "\$TARGET_FONTS" == *"MS-Fonts"* ]]; then
        echo "Building MS Fonts..."
        su - "$USERNAME" -c "yaourtix -S --noconfirm ttf-ms-fonts"
    fi
    if [[ "\$TARGET_FONTS" == *"Adobe-Base"* ]]; then
        echo "Building Adobe Base 14 Fonts..."
        su - "$USERNAME" -c "yaourtix -S --noconfirm adobe-base-14-fonts"
    fi
    if [[ "\$TARGET_FONTS" == *"Vista"* ]]; then
        echo "Building Vista Fonts..."
        su - "$USERNAME" -c "yaourtix -S --noconfirm ttf-vista-fonts"
    fi

    rm /etc/sudoers.d/00_temp_installer
fi

# Restore Sudo
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Install & Configure DM
echo "Setting up DM: $DM_CHOICE"
DM_PKG=""
case "$DM_CHOICE" in
    "SDDM")    DM_PKG="sddm" ;;
    "LightDM") DM_PKG="lightdm lightdm-gtk-greeter" ;;
    "XDM")     DM_PKG="xdm" ;;
esac

case "$INIT_SYS" in
    "openrc") pacman -S --noconfirm \$DM_PKG \${DM_PKG%% *}-openrc ;;
    "runit")  pacman -S --noconfirm \$DM_PKG \${DM_PKG%% *}-runit ;;
    "dinit")  pacman -S --noconfirm \$DM_PKG \${DM_PKG%% *}-dinit ;;
    "s6")     pacman -S --noconfirm \$DM_PKG \${DM_PKG%% *}-s6 ;;
esac
enable_service \${DM_PKG%% *}

# Bootloader Setup
echo "Setting up Bootloader: $BOOTLOADER"
echo "Target UUID: $TARGET_UUID"

ROOT_FLAGS="rw"
if [ "$FS_CHOICE" == "Btrfs" ]; then
    ROOT_FLAGS="rw rootflags=subvol=@"
fi

case "$BOOTLOADER" in
    "GRUB")
        pacman -S --noconfirm grub efibootmgr
        grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
        grub-mkconfig -o /boot/grub/grub.cfg
        ;;
    "rEFInd")
        pacman -S --noconfirm refind
        refind-install
        echo "\"Boot with standard options\"  \"root=UUID=$TARGET_UUID \$ROOT_FLAGS initrd=/initramfs-linux.img\"" > /boot/refind_linux.conf
        echo "\"Boot to fallback initramfs\"  \"root=UUID=$TARGET_UUID \$ROOT_FLAGS initrd=/initramfs-linux-fallback.img\"" >> /boot/refind_linux.conf
        ;;
    "Limine")
        pacman -S --noconfirm limine
        mkdir -p /boot/EFI/BOOT
        cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/BOOTX64.EFI
        cat <<LIMINE > /boot/limine.conf
timeout: 5
/Artix Linux
    protocol: linux
    kernel_path: boot://2/vmlinuz-linux
    kernel_cmdline: root=UUID=$TARGET_UUID \$ROOT_FLAGS
    module_path: boot://2/initramfs-linux.img
/Artix Linux (Fallback)
    protocol: linux
    kernel_path: boot://2/vmlinuz-linux
    kernel_cmdline: root=UUID=$TARGET_UUID \$ROOT_FLAGS
    module_path: boot://2/initramfs-linux-fallback.img
LIMINE
        ;;
esac

enable_service elogind
echo "Configuration Complete."
EOF

    chmod +x "$MOUNT_POINT/setup_internal.sh"
    clear
    log "Entering Artix Chroot..."
    artix-chroot "$MOUNT_POINT" /setup_internal.sh
    if [ $? -ne 0 ]; then err "Chroot failed! Check errors."; fi
    rm "$MOUNT_POINT/setup_internal.sh"
}

# -- Main Execution --
detect_init
show_disclaimer
pre_flight
setup_artix_repos ""
select_menu_options
partition_drive
install_base
setup_artix_repos "$MOUNT_POINT"
configure_system "$ROOT_UUID" "$FONT_CHOICES"

# -- FINAL SUCCESS MESSAGE --
FINAL_MSG="Artix Installation Complete! Rebooting..."
if [ "$DE_CHOICE" == "SonicDE" ]; then
    FINAL_MSG="Artix Installation Complete!\n\nIMPORTANT: SonicDE requires X11.\nMake sure to choose 'Plasma (X11)' or 'SonicDE (X11)' at the login screen.\n\nRebooting..."
fi

dialog --msgbox "$FINAL_MSG" 14 60
umount -R "$MOUNT_POINT"
reboot

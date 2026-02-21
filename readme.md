# 🚀 SonicDE Artix Installer
**The Universal Init Edition**

An interactive, TUI-based Bash script designed to bridge the gap between a manual "Arch-way" installation and a full GUI installer. This tool automates the heavy lifting of **Artix Linux** while offering granular control over init systems, filesystems, and desktop environments.

---

## ✨ Key Features

* **Init System Autonomy:** Automatically detects and configures services for **OpenRC, Runit, Dinit, and s6**.
* **Intelligent Partitioning:**
    * **Auto-Mode:** Wipes disk and configures UEFI or BIOS layouts using **Btrfs** (with subvolumes/snapshots), **EXT4**, or **F2FS**.
    * **Manual Mode:** Drops the user into a `cfdisk` environment for custom partition schemes.
* **Desktop Environments:** Native support for **SonicDE** (Plasma-based with XLibre fixes), standard **KDE Plasma**, **Moksha**, **MATE**, **XFCE4**, and **LXQt**.
* **AUR & Font Integration:** Built-in support for `aurutils` to handle curated fonts (Apple San Francisco, Microsoft, Adobe, Monterey) and system utilities like `monitor-control-qt`.
* **Bootloader Variety:** Choose between **GRUB**, **rEFInd** (graphical), or **Limine**.

---

## 🛠️ Requirements

* **Artix Linux ISO:** Ensure you use a base ISO corresponding to your preferred init system.
* **Internet Connection:** Active connection required for package synchronization and updates.
* **Root Access:** The script must be executed with `sudo`.

---

## 🚀 Quick Start

1.  **Boot** into the Artix Live environment and ensure you are connected to the internet.
2.  **Download** the script:
    * **Latest (Main):**
        ```bash
        curl -LO [https://artix.tuxpeng.me/install.sh](https://artix.tuxpeng.me/install.sh)
        ```
    * **Stable Tag (Recommended):**
        ```bash
        curl -LO [https://artix.tuxpeng.me/v1.0/install.sh](https://artix.tuxpeng.me/v1.0/install.sh)
        ```
        *(Replace `v1.0` with the desired version tag)*.
3.  **Make it executable:**
    ```bash
    chmod +x install.sh
    ```
4.  **Run the installer:**
    ```bash
    sudo ./install.sh
    ```

---

## ⚠️ Disclaimer & Testing Status

**Use at your own risk.** This script was developed with significant AI assistance (~80% of the logic) and is currently in a testing phase.

| Component | Status |
| :--- | :--- |
| **Primary Path** | **Stable:** SonicDE on **OpenRC** with **SDDM** and **GRUB**. |
| **Filesystems** | **Tested:** EXT4 and Btrfs (with snapshots). |
| **Boot Modes** | **Tested:** Both UEFI and Legacy BIOS support. |
| **Experimental** | Runit, s6, Dinit, Manual Partitioning, and Limine. |

---

## 📦 Post-Installation

If you opted for the **SonicDE** environment:
* SonicDE is optimized for **X11**.
* At the SDDM login screen, ensure you select **Plasma (X11)** or **SonicDE (X11)** from the session menu for the intended experience.

---

## 📂 Btrfs Subvolume Structure

When using the **Auto-Partitioning** method with **Btrfs**, the script creates a flat subvolume layout for easy snapshot management:
* `@` mounted at `/`
* `@home` mounted at `/home`
* `@snapshots` mounted at `/.snapshots`
* `@var_log` mounted at `/var/log`

If enabled, the script also configures `snapper` and `grub-btrfs` for automatic boot-menu snapshots.

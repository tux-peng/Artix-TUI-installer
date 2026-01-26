**SonicDE Artix Installer (Universal Init Edition)**

An interactive, TUI-based Bash script designed to automate the installation of **Artix Linux**. This installer bridges the gap between a manual "Arch-way" install and a full GUI installer, offering deep customization while handling the complexities of non-systemd init systems.

## **✨ Key Features**

* **Init System Autonomy:** Automatically detects and configures services for **OpenRC, Runit, Dinit, and s6**.  
* **Flexible Partitioning:** \* **Auto:** Wipes disk and sets up UEFI partitions with your choice of **Btrfs** (with subvolumes), **EXT4**, or **F2FS**.  
  * **Manual:** Drops you into cfdisk for custom layouts.  
* **Desktop Environments:** Full support for **SonicDE** (Plasma-based with XLibre fixes), standard **KDE Plasma**, **Moksha**, **MATE**, **XFCE4**, and **LXQt**.  
* **AUR Integration:** Built-in support for yaourtix to handle AUR packages like monitor-control-qt and custom fonts.  
* **Curated Fonts:** Optional installation of Apple San Francisco, Microsoft, and MacOS Monterey font sets.  
* **Bootloader Choice:** Choose between **GRUB**, **rEFInd** (graphical), or **Limine**.

## ---

**🛠️ Requirements**

* **Artix Linux Live ISO**  
* **Active Internet Connection** (for package downloading)  
* **UEFI System** (Legacy BIOS support is untested)

## ---

**🚀 Getting Started**

1. **Boot into the Artix Live environment.**  
2. **Download the script:**  
   Bash  
   curl \-O https://raw.githubusercontent.com/tux-peng/Artix-TUI-installer/refs/heads/main/install.sh
   *** OR LAST STABLE TAG***_
   curl -O https://raw.githubusercontent.com/tux-peng/Artix-TUI-installer/v1.0/install.sh

3. **Make it executable:**  
   Bash  
   chmod \+x install.sh

4. **Run as root:**  
   Bash  
   sudo ./install.sh

## ---

**⚠️ Disclaimer & Testing Status**

\[\!WARNING\]

This script is considered **Experimental**. Use it at your own risk.

* **Tested:** SonicDE on **OpenRC** with **SDDM**, **GRUB/rEFInd**, and **Auto-partitioning** on UEFI.  
* **Experimental:** Runit/s6/Dinit, Manual Partitioning, Limine bootloader, and BIOS/CSM systems.  
* **Note:** This script was developed with heavy assistance from AI (approx. 80% of the logic).

## ---

**📦 Post-Installation**

If you installed **SonicDE**, remember:

* SonicDE is optimized for **X11**.  
* Select **Plasma (X11)** or **SonicDE (X11)** at the SDDM login screen for the intended experience.

---

**Would you like me to create a separate CHANGELOG.md template or a CONTRIBUTING.md file to go along with this?**

# Building an Armbian image for Banana Pro with LeMaker LCD support

This directory lets you build your own Armbian image (Debian 13 trixie, minimal) for the LeMaker Banana Pro in which the LeMaker panels work right after the first boot. Nothing has to be installed on the board afterwards.

Compared to the ready-made image from armbian.com:

- the `edt-ft5x06` touch driver is enabled in the kernel (Armbian does not build it by default),
- compiled overlays for all panels (3.5", 5", 7") are already in `/boot/overlay-user/`,
- the selected panel is enabled in `/boot/armbianEnv.txt`,
- the `.dts` overlay sources are in `/usr/local/share/lemaker-lcd/` (for adjustments on the board).

The build is based on the official [Armbian build framework](https://docs.armbian.com/build-framework/getting-started/) and on the same command Armbian uses for its ready-made images:

```bash
./compile.sh BOARD=bananapipro RELEASE=trixie BUILD_DESKTOP=no BUILD_MINIMAL=yes KERNEL_CONFIGURE=no
```

## Contents

| File | Purpose |
|---|---|
| `zbuduj-obraz.sh` | Script that does everything ("build image"): downloads Armbian build, copies the files, starts the build. |
| `userpatches/config-bananapro-lcd.conf` | Build settings (board, Debian 13, minimal, kernel), enables the touch driver and adds the panel to the image name. |
| `userpatches/customize-image.sh` | Run by Armbian inside the image: compiles the overlays and enables the selected panel. |

## Requirements (the computer you build on)

- Linux x86_64 or arm64 (preferably Debian 13),
- at least 8 GB RAM and about 50 GB of free disk space,
- Docker, git and the ARM emulator (QEMU), without which Armbian cannot prepare an armhf image on an x86 computer:

```bash
sudo apt install -y git docker.io docker-buildx qemu-user-binfmt
sudo usermod -aG docker $USER    # then log out and log back in
```

The path to the build directory must not contain spaces (an Armbian requirement). By default the script uses `~/armbian-build`.

## Quick way: the script

```bash
git clone https://github.com/cyryllo/fex_configuration.git
cd fex_configuration/armbian-build
./zbuduj-obraz.sh --ekran 7
```

Instead of `7` give your panel: `5`, `7`, `35` or `brak` ("none": image with the overlays, but none of them enabled).

Other options:

| Option | Meaning |
|---|---|
| `--jadro edge` | Newer kernel (7.3) instead of `current` (6.18). The overlays were checked on `current`. |
| `--katalog /path` | A different directory for Armbian build (no spaces). |
| `--aktualizuj` | Fetches the latest Armbian build (`git pull`) before building. |
| `-- OPTIONS` | Everything after `--` is passed to `compile.sh`, e.g. `-- KERNEL_CONFIGURE=yes`. |

The finished image is in `~/armbian-build/output/images/`, with a name like `Armbian-unofficial_..._Bananapipro_trixie_current_6.18.x_lcd7_minimal.img`. The `_lcd7` part (or `_lcd5`, `_lcd35`, `_lcd-brak`) shows which panel is enabled, so images for different panels do not overwrite each other.

**Time:** the first build takes a while (from about 20 minutes to a few hours, depending on the computer), because the kernel is compiled from scratch. The prebuilt kernel from the Armbian servers cannot be used, because we changed its configuration (touch). Later builds use the cache and are much faster (a couple of minutes).

## Manual way (without the script)

The same steps the script performs:

```bash
# 1. Armbian build framework
git clone --depth 1 https://github.com/armbian/build.git ~/armbian-build

# 2. Our files into userpatches
cd ~/fex_configuration          # wherever you cloned this repository
mkdir -p ~/armbian-build/userpatches/overlay/lemaker-lcd
cp armbian-build/userpatches/config-bananapro-lcd.conf ~/armbian-build/userpatches/
cp armbian-build/userpatches/customize-image.sh        ~/armbian-build/userpatches/
cp overlays/bananapro-lemaker-lcd*.dts ~/armbian-build/userpatches/overlay/lemaker-lcd/
echo 7 > ~/armbian-build/userpatches/overlay/lemaker-lcd/ekran     # 5, 7, 35 or brak

# 3. Build
cd ~/armbian-build
./compile.sh bananapro-lcd LCD_SUFFIX=_lcd7
```

`./compile.sh bananapro-lcd` loads `userpatches/config-bananapro-lcd.conf`. The result is the same as the armbian.com command, plus it sets `BRANCH=current` (otherwise compile.sh asks for the kernel), enables the touch module and, with `LCD_SUFFIX`, adds the panel to the image name.

## How it works

1. **Touch.** `config-bananapro-lcd.conf` contains the function `custom_kernel_config__lemaker_lcd_touch`, which adds `CONFIG_TOUCHSCREEN_EDT_FT5X06=m` to the kernel configuration. This is the official Armbian mechanism (the `custom_kernel_config` hook). The module loads automatically when the panel overlay describes the touch controller.
2. **Overlays.** Armbian mounts `userpatches/overlay/` inside the image as `/tmp/overlay` and runs `customize-image.sh` there. The script compiles every `.dts` file with `dtc -@` (the same as `armbian-add-overlay` does) and stores the result in `/boot/overlay-user/`.
3. **Panel selection.** The script removes the old `user_overlays=` line from `/boot/armbianEnv.txt` and adds a new one, e.g. `user_overlays=bananapro-lemaker-lcd7`.
4. **Image name.** The `user_config__lemaker_lcd_suffix` hook adds `LCD_SUFFIX` to the Armbian `EXTRA_IMAGE_SUFFIXES` list.

## Writing the image to an SD card

The easiest way is [USBImager](https://gitlab.com/bztsrc/usbimager) or balenaEtcher. From the command line (check the card name in `lsblk` twice, `dd` overwrites the given disk without asking):

```bash
lsblk
sudo dd if=~/armbian-build/output/images/IMAGE_NAME.img of=/dev/sdX bs=4M status=progress conv=fsync
```

For a compressed image from Releases:

```bash
xz -dc IMAGE_NAME.img.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

Put the card into the Banana Pro and connect the panel before powering on. Bootloader (U-Boot) messages only appear on HDMI, the picture on the LCD only appears once the kernel starts. This is normal.

## First boot and checks

After the first login (the Armbian wizard asks for a root password and a new user):

```bash
cat /boot/armbianEnv.txt | grep user_overlays    # the selected overlay should be there
lsmod | grep edt                                  # touch module loaded
ls /sys/class/backlight/                          # backlight
dmesg | grep -iE "sun4i|lvds|panel|edt"
```

More diagnostic commands and a troubleshooting table are in the [main README](../README.md).

## Changing the panel on a running system

All overlays are already in the image, so changing one line is enough:

```bash
sudo nano /boot/armbianEnv.txt
```

```
user_overlays=bananapro-lemaker-lcd5
```

Then `sudo reboot`. To disable the panel, remove the overlay name from this line.

## Adjusting an overlay on the board

The sources are in `/usr/local/share/lemaker-lcd/`. After a change (e.g. backlight polarity, touch axes) install the file again:

```bash
sudo nano /usr/local/share/lemaker-lcd/bananapro-lemaker-lcd7.dts
sudo armbian-add-overlay /usr/local/share/lemaker-lcd/bananapro-lemaker-lcd7.dts
sudo reboot
```

Once a fix is confirmed, please bring it back to the repository so it ends up in future images.

## Kernel updates

The image uses the Armbian repository, so `apt upgrade` may install the official kernel **without** the touch module. The display and backlight will keep working, touch will stop. There are two options:

- hold kernel updates: `sudo apt-mark hold linux-image-current-sunxi linux-dtb-current-sunxi`
- or build the module on the board after the update (option A in the [main README](../README.md)).

You can get a newer kernel with touch by building the image again with `--aktualizuj`. The kernel packages alone (`.deb`, to install with `dpkg -i`) are in `~/armbian-build/output/debs/` after the build.

## Build problems

| Symptom | What to do |
|---|---|
| `permission denied` from Docker | Add yourself to the `docker` group (see Requirements) and log in again. |
| `armhf: not supported on this machine/kernel` or `Failed to update binfmts` | The ARM emulator is missing on the computer: `sudo apt install qemu-user-binfmt`, then `ls /proc/sys/fs/binfmt_misc/` should show `qemu-arm`. |
| Not enough disk space | Armbian needs about 50 GB. The cache is in `~/armbian-build/cache/`. |
| `customize-image.sh exited with error` | Details are in `~/armbian-build/output/logs/`. Most often a syntax error in one of the `.dts` files. |
| The script moved my `customize-image.sh` to `.bak` | It does so when `userpatches/` already contained a different script. Add your own commands at the end of ours. |
| The build asks questions in a menu | Make sure you run `./compile.sh bananapro-lcd` (with the config name). |

## Sources

- Armbian build framework, getting started: <https://docs.armbian.com/build-framework/getting-started/>
- User files (userpatches, customize-image.sh): <https://docs.armbian.com/build-framework/user-configurations/>
- Hooks, including `custom_kernel_config`: <https://docs.armbian.com/build-framework/extensions/hooks/>
- Armbian build repository: <https://github.com/armbian/build>

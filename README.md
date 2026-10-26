# LeMaker LCD panels for Banana Pro on current kernels (Armbian, mainline)

Fork of [LeMaker/fex_configuration](https://github.com/LeMaker/fex_configuration). The manufacturer no longer exists, and the original `script.bin` files only worked with the old sunxi 3.4 kernel. Current Linux kernels use Device Tree and simply ignore `script.bin`, which is why the panels stopped working.

This repository contains **Device Tree overlays** that bring the fex settings to current systems. The parameters (display timings, pins, power, backlight, touch) were taken 1:1 from the original LeMaker fex files.

> **Status:** the 7" panel is confirmed working on real hardware (display, kernel 6.18.58). Touch on the 7" and the 5" panel are being tested. The 3.5" overlay is untested (no hardware). Reports of success (or problems) are welcome.

## Supported panels

| Overlay file | Panel | Interface | Resolution | Touch |
|---|---|---|---|---|
| `overlays/bananapro-lemaker-lcd35.dts` | LeMaker 3.5" (BL035-RGB-002) | parallel RGB | 320x240 | FT5x06 (capacitive) |
| `overlays/bananapro-lemaker-lcd5.dts` | LeMaker 5" | parallel RGB | 800x480 | FT5x06 (capacitive) |
| `overlays/bananapro-lemaker-lcd7.dts` | LeMaker 7" | LVDS | 1024x600 | FT5x06 (capacitive) |

All panels connect to the LCD connector on the Banana Pro (the same one as with the old system, with the same adapter board).

**Only one overlay can be enabled at a time.** They all use the same display controller (TCON0), the same pins and the same touch address.

## Requirements

- **Board:** LeMaker Banana Pro (Allwinner A20). In Armbian the same board is called **Banana Pi Pro** (`bananapipro`), and its DTB file is `sun7i-a20-bananapro.dtb`.
- **System:** Armbian with the `current` or `edge` kernel (checked against kernel 6.18).
- **`device-tree-compiler` package** (the `dtc` tool). It is usually already installed on Armbian. If not:

```bash
sudo apt install device-tree-compiler
```

## Ready-made system images

Instead of installing an overlay by hand, you can flash a ready-made Armbian image (Debian 13 trixie) with the overlays and the touch driver already included. Images are available under [Releases](https://github.com/cyryllo/fex_configuration/releases). Newer images are a single image for all panels: the 7" panel is enabled by default, others are selected with `sudo lemaker-lcd 5` (or `35`, `7`, `off`) and a reboot. To build such an image yourself, see [armbian-build/README.md](armbian-build/README.md).

## Installing a panel

1. Copy the repository to the Banana Pro:

```bash
git clone https://github.com/cyryllo/fex_configuration.git
cd fex_configuration
```

2. Install the overlay for your panel (example for the 7"):

```bash
sudo armbian-add-overlay overlays/bananapro-lemaker-lcd7.dts
```

This command compiles the file, copies the result to `/boot/overlay-user/` and adds its name to the `user_overlays=` line in `/boot/armbianEnv.txt`.

3. Reboot:

```bash
sudo reboot
```

The picture should appear on the panel once the kernel starts. The bootloader (U-Boot) logo and messages will still only show on HDMI, this is normal.

## Changing or disabling the panel

Open `/boot/armbianEnv.txt`:

```bash
sudo nano /boot/armbianEnv.txt
```

Find the `user_overlays=` line and leave only one panel overlay on it, for example:

```
user_overlays=bananapro-lemaker-lcd5
```

To disable the panel completely, remove its name from this line. Run `sudo reboot` after the change.

If you switch to a different panel, first remove the old name from `user_overlays=`, and only then add the new one with `armbian-add-overlay`.

## Touch (requires one extra module)

All three panels use the same FocalTech FT5x06 touch controller. It is handled by the `edt-ft5x06` driver, which **Armbian does not build by default**. The display works without it, touch does not. The module only needs to be built once and works with every panel.

The ready-made images from [Releases](https://github.com/cyryllo/fex_configuration/releases) already include this module.

### Option A: build just the module on the board (simpler)

```bash
# Build tools and kernel headers matching the installed kernel
# (they can also be installed via armbian-config)
sudo apt install build-essential linux-headers-current-sunxi

# Driver source matching the kernel version (here: 6.18)
mkdir ~/ft5x06 && cd ~/ft5x06
wget https://raw.githubusercontent.com/torvalds/linux/v6.18/drivers/input/touchscreen/edt-ft5x06.c
echo 'obj-m += edt-ft5x06.o' > Makefile

# Build and install the module
make -C /lib/modules/$(uname -r)/build M=$PWD modules
sudo make -C /lib/modules/$(uname -r)/build M=$PWD modules_install
sudo depmod -a
sudo reboot
```

If you have the `edge` kernel or a version other than 6.18, replace `v6.18` in the URL with your version (the first two numbers of `uname -r`, e.g. `v7.3`) and `current` with `edge` in the headers package name.

**Note:** after a kernel update the module has to be built again (same commands).

### Option B: custom kernel with the Armbian build framework

On a Linux computer (the build runs in a Docker container):

```bash
git clone https://github.com/armbian/build.git
cd build
./compile.sh kernel-config BOARD=bananapipro BRANCH=current
```

In the menu, enable as a module (`M`):
`Device Drivers > Input device support > Touchscreens > EDT FocalTech FT5x06 I2C Touchscreen support`

Then build the kernel:

```bash
./compile.sh kernel BOARD=bananapipro BRANCH=current
```

The resulting `.deb` packages are in `output/debs/`. Install the `linux-image-...` package on the board with `sudo dpkg -i` and reboot. This option is more convenient in the long run, because the module is part of the kernel.

To build a complete image with the overlays and the touch driver, use the script in [armbian-build/](armbian-build/README.md).

## Checking that it works

```bash
# Did the panel and display controller start
dmesg | grep -iE "sun4i|lvds|panel"

# Is there a backlight (a directory such as lcd7-backlight should appear)
ls /sys/class/backlight/

# Set brightness manually (0-255)
echo 120 | sudo tee /sys/class/backlight/*/brightness

# Does the touch controller answer on I2C (look for "38" or "UU")
sudo apt install i2c-tools
i2cdetect -l
sudo i2cdetect -y 3      # the bus number may differ, check i2cdetect -l

# Is touch visible as an input device
cat /proc/bus/input/devices | grep -A4 -i edt
```

## Troubleshooting

| Symptom | What to check / change |
|---|---|
| Black screen, no backlight | Make sure there is only one panel overlay in `/boot/armbianEnv.txt`. Check `dmesg` for `panel` or `pwm` errors. |
| Backlight works in reverse (0 = brightest) | In the overlay file, in the line `pwms = <&pwm 0 50000 0>;` change the last `0` to `1` and install the overlay again. |
| 7": red or blank screen after the kernel starts | Known LVDS polarity issue in some kernels. The Armbian kernel already has the fix, other distributions may not. |
| 5" or 3.5": colour noise, flickering edges | In the `panel-timing` block (5") add `pixelclk-active = <0>;` or `<1>;` and see which works better. |
| 3.5": picture shifted or "floating" | See the comment next to the pin group in the overlay file (DE signal on PD25). |
| Touch does not work | Check that the `edt-ft5x06` module is built (`lsmod \| grep edt`) and that `i2cdetect` sees address `38`. |
| Touch mirrored or with swapped axes | In the `touchscreen@38` node add `touchscreen-inverted-x;`, `touchscreen-inverted-y;` or `touchscreen-swapped-x-y;`. |

After every change to a `.dts` file, install it again with `sudo armbian-add-overlay ...` and reboot.

## How the fex parameters were converted

The fex files stored timings differently from Device Tree:

- `lcd_hbp` and `lcd_vbp` already include the sync pulse width, so: `hback-porch = lcd_hbp - lcd_hspw`, `vback-porch = lcd_vbp - lcd_vspw`.
- `lcd_vt` is stored as a doubled value (old Allwinner convention), so the total number of lines is `lcd_vt / 2`.
- Front porches: `hfront-porch = lcd_ht - lcd_x - lcd_hbp`, `vfront-porch = lcd_vt/2 - lcd_y - lcd_vbp`.

The exact calculations for each panel are described in the comments in the overlay files.

The most important technical differences from the old system:

- **7" LVDS:** the A20 display controller only enables LVDS mode when the panel has `compatible = "panel-lvds"`. That is why the overlay uses exactly this description.
- **3.5":** this panel is already described in the kernel (`lemaker,bl035-rgb-002`), so the overlay does not specify timings.
- **5":** this panel is not in the kernel, so the timings are given in the overlay using the generic `panel-dpi` description.
- **Touch:** the old `ft5x_ts` driver was replaced by the mainline `edt-ft5x06` driver.

## Old files (kernel 3.4)

The `stare jądro sunxi 3.4/` directory ("old sunxi 3.4 kernel", with `bin/` and `fex/` subdirectories) contains the original LeMaker files. They only work with old system images running the sunxi 3.4 kernel: the chosen `.bin` file was renamed to `script.bin` and copied to the first partition of the card. On Armbian with a current kernel they have no effect and are kept as the source of the parameters.

`stare jądro sunxi 3.4/fex/` also contains files for the 10.1" panel and for the Banana Pi (non-"Pro"). There are no overlays for them yet, but they can be prepared the same way.

## Sources

- Original LeMaker repository: <https://github.com/LeMaker/fex_configuration>
- Armbian overlay documentation: <https://docs.armbian.com/User-Guide_Armbian_overlays/>
- Thread about the 7" panel on Banana Pi Pro with mainline (Armbian forum): <https://forum.armbian.com/topic/7233-bananapi-pro-7-touchlcd-with-debian-buster-and-mainline-kernel-5xxxx/>

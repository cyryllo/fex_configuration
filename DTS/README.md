# Ekrany LCD LeMaker dla Banana Pro na nowym jądrze (Armbian, mainline)

Fork repozytorium [LeMaker/fex_configuration](https://github.com/LeMaker/fex_configuration). Producent już nie istnieje, a oryginalne pliki `script.bin` działały tylko ze starym jądrem sunxi 3.4. Nowe jądra Linuksa korzystają z Device Tree i plik `script.bin` jest przez nie po prostu ignorowany, dlatego ekrany przestały działać.

To repozytorium zawiera **nakładki Device Tree (overlays)**, które przenoszą ustawienia z plików fex na nowe systemy. Parametry (timingi obrazu, piny, zasilanie, podświetlenie, dotyk) zostały przepisane 1:1 z oryginalnych plików fex od LeMakera.

> **Status:** nakładki kompilują się i poprawnie nakładają na `sun7i-a20-bananapro.dtb` z aktualnego jądra mainline, ale nie zostały jeszcze potwierdzone na każdym ekranie. Zgłoszenia działania (lub problemów) są mile widziane.

## Obsługiwane ekrany

| Plik nakładki | Ekran | Złącze | Rozdzielczość | Dotyk |
|---|---|---|---|---|
| `overlays/bananapro-lemaker-lcd35.dts` | LeMaker 3.5" (BL035-RGB-002) | równoległe RGB | 320x240 | FT5x06 (pojemnościowy) |
| `overlays/bananapro-lemaker-lcd5.dts` | LeMaker 5" | równoległe RGB | 800x480 | FT5x06 (pojemnościowy) |
| `overlays/bananapro-lemaker-lcd7.dts` | LeMaker 7" | LVDS | 1024x600 | FT5x06 (pojemnościowy) |

Wszystkie ekrany podłącza się do złącza LCD na płytce Banana Pro (tego samego co przy starym systemie, z tą samą przejściówką).

**Naraz można włączyć tylko jedną nakładkę.** Wszystkie używają tego samego kontrolera obrazu (TCON0), tych samych pinów i tego samego adresu dotyku.

## Wymagania

- **Płytka:** LeMaker Banana Pro (Allwinner A20). W Armbian ta sama płytka nazywa się **Banana Pi Pro** (`bananapipro`), a plik DTB to `sun7i-a20-bananapro.dtb`.
- **System:** Armbian z jądrem `current` lub `edge` (sprawdzane na podstawie jądra 6.18).
- **Pakiet `device-tree-compiler`** (narzędzie `dtc`). W Armbian zwykle jest już zainstalowany. Jeśli nie:

```bash
sudo apt install device-tree-compiler
```

## Instalacja ekranu

1. Skopiuj repozytorium na Banana Pro:

```bash
git clone https://github.com/cyryllo/fex_configuration.git
cd fex_configuration
```

2. Wgraj nakładkę dla swojego ekranu (przykład dla 7"):

```bash
sudo armbian-add-overlay overlays/bananapro-lemaker-lcd7.dts
```

Polecenie kompiluje plik, kopiuje wynik do `/boot/overlay-user/` i dopisuje jego nazwę do linii `user_overlays=` w pliku `/boot/armbianEnv.txt`.

3. Uruchom ponownie:

```bash
sudo reboot
```

Obraz powinien pojawić się na ekranie po starcie jądra. Logo i napisy z bootloadera (U-Boot) nadal będą tylko na HDMI, to normalne.

## Zmiana lub wyłączenie ekranu

Otwórz plik `/boot/armbianEnv.txt`:

```bash
sudo nano /boot/armbianEnv.txt
```

Znajdź linię `user_overlays=` i zostaw na niej tylko jedną nakładkę ekranu, np.:

```
user_overlays=bananapro-lemaker-lcd5
```

Żeby całkiem wyłączyć ekran, usuń jego nazwę z tej linii. Po zmianie zrób `sudo reboot`.

Jeśli zmieniasz ekran na inny, najpierw usuń starą nazwę z `user_overlays=`, a dopiero potem dodaj nową przez `armbian-add-overlay`.

## Dotyk (wymaga jednego dodatkowego modułu)

Wszystkie trzy ekrany mają ten sam układ dotyku FocalTech FT5x06. Obsługuje go sterownik `edt-ft5x06`, którego **Armbian domyślnie nie buduje**. Obraz zadziała bez niego, dotyk nie. Moduł buduje się raz i działa z każdym z ekranów.

### Sposób A: zbudowanie samego modułu na płytce (prostszy)

```bash
# Narzędzia i nagłówki jądra pasujące do zainstalowanego jądra
# (można je też zainstalować przez armbian-config)
sudo apt install build-essential linux-headers-current-sunxi

# Źródło sterownika w wersji odpowiadającej jądru (tu: 6.18)
mkdir ~/ft5x06 && cd ~/ft5x06
wget https://raw.githubusercontent.com/torvalds/linux/v6.18/drivers/input/touchscreen/edt-ft5x06.c
echo 'obj-m += edt-ft5x06.o' > Makefile

# Kompilacja i instalacja modułu
make -C /lib/modules/$(uname -r)/build M=$PWD modules
sudo make -C /lib/modules/$(uname -r)/build M=$PWD modules_install
sudo depmod -a
sudo reboot
```

Jeśli masz jądro `edge` albo inną wersję niż 6.18, zamień `v6.18` w adresie na swoją wersję (pierwsze dwie liczby z `uname -r`, np. `v7.3`) i `current` na `edge` w nazwie pakietu z nagłówkami.

**Uwaga:** po aktualizacji jądra moduł trzeba zbudować ponownie (te same polecenia).

### Sposób B: własne jądro z Armbian build framework

Na komputerze z Linuksem (budowanie odbywa się w kontenerze Docker):

```bash
git clone https://github.com/armbian/build.git
cd build
./compile.sh kernel-config BOARD=bananapipro BRANCH=current
```

W menu włącz jako moduł (`M`):
`Device Drivers > Input device support > Touchscreens > EDT FocalTech FT5x06 I2C Touchscreen support`

Potem zbuduj jądro:

```bash
./compile.sh kernel BOARD=bananapipro BRANCH=current
```

Gotowe pakiety `.deb` znajdziesz w `output/debs/`. Zainstaluj na płytce pakiet `linux-image-...` przez `sudo dpkg -i` i zrób reboot. Ten sposób jest wygodniejszy na dłuższą metę, bo moduł jest częścią jądra.

## Sprawdzenie, czy działa

```bash
# Czy panel i kontroler obrazu wystartowały
dmesg | grep -iE "sun4i|lvds|panel"

# Czy jest podświetlenie (powinien pojawić się katalog np. lcd7-backlight)
ls /sys/class/backlight/

# Ręczna zmiana jasności (0-255)
echo 120 | sudo tee /sys/class/backlight/*/brightness

# Czy układ dotyku odpowiada na I2C (szukaj "38" lub "UU")
sudo apt install i2c-tools
i2cdetect -l
sudo i2cdetect -y 3      # numer magistrali może być inny, sprawdź i2cdetect -l

# Czy dotyk jest widoczny jako urządzenie wejściowe
cat /proc/bus/input/devices | grep -A4 -i edt
```

## Rozwiązywanie problemów

| Objaw | Co sprawdzić / zmienić |
|---|---|
| Ekran czarny, brak podświetlenia | Czy w `/boot/armbianEnv.txt` jest tylko jedna nakładka ekranu. Czy `dmesg` pokazuje błędy `panel` lub `pwm`. |
| Podświetlenie działa odwrotnie (0 = najjaśniej) | W pliku nakładki, w linii `pwms = <&pwm 0 50000 0>;` zmień ostatnie `0` na `1` i wgraj nakładkę ponownie. |
| 7": czerwony lub pusty ekran po starcie jądra | Znany problem z polaryzacją LVDS w części jąder. Jądro Armbian ma już poprawkę, na innych dystrybucjach może jej brakować. |
| 5" lub 3.5": kolorowy szum, migoczące krawędzie | W bloku `panel-timing` (5") dopisz `pixelclk-active = <0>;` albo `<1>;` i sprawdź, który działa lepiej. |
| 3.5": obraz przesunięty lub "pływa" | Opis w komentarzu przy grupie pinów w pliku nakładki (sygnał DE na PD25). |
| Dotyk nie działa | Czy zbudowany jest moduł `edt-ft5x06` (`lsmod \| grep edt`). Czy `i2cdetect` widzi adres `38`. |
| Dotyk w lustrzanym odbiciu lub z zamienionymi osiami | W węźle `touchscreen@38` dopisz `touchscreen-inverted-x;`, `touchscreen-inverted-y;` lub `touchscreen-swapped-x-y;`. |

Po każdej zmianie w pliku `.dts` wgraj go ponownie przez `sudo armbian-add-overlay ...` i zrób reboot.

## Jak przeliczono parametry z fex

Pliki fex zapisywały timingi inaczej niż Device Tree:

- `lcd_hbp` i `lcd_vbp` zawierają już szerokość impulsu synchronizacji, więc: `hback-porch = lcd_hbp - lcd_hspw`, `vback-porch = lcd_vbp - lcd_vspw`.
- `lcd_vt` jest zapisany jako podwojona wartość (stara konwencja Allwinnera), więc całkowita liczba linii to `lcd_vt / 2`.
- Przednie marginesy: `hfront-porch = lcd_ht - lcd_x - lcd_hbp`, `vfront-porch = lcd_vt/2 - lcd_y - lcd_vbp`.

Dokładne wyliczenia dla każdego ekranu są opisane w komentarzach w plikach nakładek.

Najważniejsze różnice techniczne względem starego systemu:

- **7" LVDS:** kontroler obrazu A20 włącza tryb LVDS tylko wtedy, gdy panel ma `compatible = "panel-lvds"`. Dlatego nakładka używa właśnie tego opisu.
- **3.5":** ten ekran jest już opisany w jądrze (`lemaker,bl035-rgb-002`), więc nakładka nie podaje timingów.
- **5":** ekranu nie ma w jądrze, timingi są podane w nakładce przez ogólny opis `panel-dpi`.
- **Dotyk:** stary sterownik `ft5x_ts` zastąpił sterownik `edt-ft5x06` z mainline.

## Stare pliki (jądro 3.4)

Katalogi `bin/` i `fex/` zawierają oryginalne pliki od LeMakera. Działają tylko ze starymi obrazami systemu z jądrem sunxi 3.4: wybrany plik `.bin` zmieniało się na `script.bin` i kopiowało na pierwszą partycję karty. Na Armbian z nowym jądrem nie mają żadnego efektu, zostały jako źródło parametrów.

W `fex/` są też pliki dla ekranu 10.1" i dla Banana Pi (bez "Pro"). Nakładek dla nich na razie nie ma, ale można je przygotować w ten sam sposób.

## Źródła

- Oryginalne repozytorium LeMaker: <https://github.com/LeMaker/fex_configuration>
- Dokumentacja nakładek Armbian: <https://docs.armbian.com/User-Guide_Armbian_overlays/>
- Wątek o ekranie 7" na Banana Pi Pro z mainline (forum Armbian): <https://forum.armbian.com/topic/7233-bananapi-pro-7-touchlcd-with-debian-buster-and-mainline-kernel-5xxxx/>


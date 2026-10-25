# Budowanie obrazu Armbian dla Banana Pro z obsługą ekranów LeMaker

Ten katalog pozwala zbudować własny obraz Armbian (Debian 13 trixie, wersja minimal) dla płytki LeMaker Banana Pro, w którym ekrany LeMaker działają od razu po pierwszym starcie. Nie trzeba niczego doinstalowywać na płytce.

Od gotowego obrazu z armbian.com różni się tym, że:

- w jądrze jest włączony sterownik dotyku `edt-ft5x06` (Armbian domyślnie go nie buduje),
- w `/boot/overlay-user/` są już skompilowane nakładki wszystkich ekranów (3.5", 5", 7"),
- wybrany ekran jest włączony w `/boot/armbianEnv.txt`,
- źródła nakładek `.dts` leżą w `/usr/local/share/lemaker-lcd/` (do poprawek na płytce).

Budowanie oparte jest na oficjalnym [Armbian build framework](https://docs.armbian.com/build-framework/getting-started/) i tym samym poleceniu, którego Armbian używa dla gotowych obrazów:

```bash
./compile.sh BOARD=bananapipro RELEASE=trixie BUILD_DESKTOP=no BUILD_MINIMAL=yes KERNEL_CONFIGURE=no
```

## Zawartość

| Plik | Do czego służy |
|---|---|
| `zbuduj-obraz.sh` | Skrypt, który robi wszystko: pobiera Armbian build, kopiuje pliki, uruchamia budowanie. |
| `userpatches/config-bananapro-lcd.conf` | Ustawienia budowania (płytka, Debian 13, minimal, jądro) i włączenie sterownika dotyku. |
| `userpatches/customize-image.sh` | Uruchamiany przez Armbian wewnątrz obrazu: kompiluje nakładki i włącza wybrany ekran. |

## Wymagania (komputer, na którym budujesz)

- Linux x86_64 lub arm64 (najlepiej Debian 13),
- co najmniej 8 GB RAM i około 50 GB wolnego miejsca,
- Docker, git i emulator ARM (QEMU), bez którego Armbian nie przygotuje obrazu armhf na komputerze x86:

```bash
sudo apt install -y git docker.io docker-buildx qemu-user-binfmt
sudo usermod -aG docker $USER    # potem wyloguj się i zaloguj ponownie
```

Ścieżka do katalogu budowania nie może zawierać spacji (wymóg Armbian). Domyślnie skrypt używa `~/armbian-build`.

## Szybki sposób: skrypt

```bash
git clone https://github.com/cyryllo/fex_configuration.git
cd fex_configuration/armbian-build
./zbuduj-obraz.sh --ekran 7
```

Zamiast `7` podaj swój ekran: `5`, `7`, `35` albo `brak` (obraz z nakładkami, ale żadna nie jest włączona).

Pozostałe opcje:

| Opcja | Znaczenie |
|---|---|
| `--jadro edge` | Nowsze jądro (7.3) zamiast `current` (6.18). Nakładki sprawdzano na `current`. |
| `--katalog /sciezka` | Inny katalog na Armbian build (bez spacji). |
| `--aktualizuj` | Przed budowaniem pobiera najnowszą wersję Armbian build (`git pull`). |
| `-- OPCJE` | Wszystko po `--` trafia do `compile.sh`, np. `-- KERNEL_CONFIGURE=yes`. |

Gotowy obraz znajdziesz w `~/armbian-build/output/images/`, plik ma nazwę w rodzaju `Armbian-unofficial_..._Bananapipro_trixie_current_6.18.x_lcd7_minimal.img`. Część `_lcd7` (albo `_lcd5`, `_lcd35`, `_lcd-brak`) mówi, który ekran jest włączony, dzięki temu obrazy dla różnych ekranów się nie nadpisują.

**Czas:** pierwszy build trwa długo (zwykle od 1 do kilku godzin), bo jądro jest kompilowane od zera. Gotowego jądra z serwerów Armbian nie da się użyć, ponieważ zmieniliśmy jego konfigurację (dotyk). Kolejne buildy korzystają z pamięci podręcznej i są dużo szybsze.

## Ręczny sposób (bez skryptu)

To samo, co robi skrypt, krok po kroku:

```bash
# 1. Armbian build framework
git clone --depth 1 https://github.com/armbian/build.git ~/armbian-build

# 2. Nasze pliki do userpatches
cd ~/fex_configuration          # tu, gdzie masz to repozytorium
mkdir -p ~/armbian-build/userpatches/overlay/lemaker-lcd
cp armbian-build/userpatches/config-bananapro-lcd.conf ~/armbian-build/userpatches/
cp armbian-build/userpatches/customize-image.sh        ~/armbian-build/userpatches/
cp overlays/bananapro-lemaker-lcd*.dts ~/armbian-build/userpatches/overlay/lemaker-lcd/
echo 7 > ~/armbian-build/userpatches/overlay/lemaker-lcd/ekran     # 5, 7, 35 albo brak

# 3. Budowanie
cd ~/armbian-build
./compile.sh bananapro-lcd
```

Jeśli pliki `.dts` nie są jeszcze w `overlays/`, skopiuj je z miejsca, w którym leżą w repozytorium.

`./compile.sh bananapro-lcd` wczytuje plik `userpatches/config-bananapro-lcd.conf`. Daje to ten sam efekt co polecenie z armbian.com, a dodatkowo ustawia `BRANCH=current` (bez tego compile.sh pyta o jądro) i włącza moduł dotyku.

## Jak to działa

1. **Dotyk.** W `config-bananapro-lcd.conf` jest funkcja `custom_kernel_config__lemaker_lcd_touch`, która dopisuje `CONFIG_TOUCHSCREEN_EDT_FT5X06=m` do konfiguracji jądra. To oficjalny mechanizm Armbian (hook `custom_kernel_config`). Moduł ładuje się sam, gdy nakładka ekranu opisze układ dotyku.
2. **Nakładki.** Armbian montuje `userpatches/overlay/` w obrazie jako `/tmp/overlay` i uruchamia w nim `customize-image.sh`. Skrypt kompiluje każdy plik `.dts` przez `dtc -@` (to samo robi `armbian-add-overlay`) i zapisuje wynik w `/boot/overlay-user/`.
3. **Wybór ekranu.** Skrypt usuwa z `/boot/armbianEnv.txt` starą linię `user_overlays=` i dopisuje nową, np. `user_overlays=bananapro-lemaker-lcd7`.

## Wgranie obrazu na kartę SD

Najprościej programem [USBImager](https://gitlab.com/bztsrc/usbimager) albo balenaEtcher. Z linii poleceń (sprawdź dwa razy nazwę karty w `lsblk`, `dd` nadpisze wskazany dysk bez pytania):

```bash
lsblk
sudo dd if=~/armbian-build/output/images/NAZWA_OBRAZU.img of=/dev/sdX bs=4M status=progress conv=fsync
```

Włóż kartę do Banana Pro i podłącz ekran przed włączeniem zasilania. Napisy z bootloadera (U-Boot) pojawią się tylko na HDMI, obraz na LCD pojawia się dopiero po starcie jądra. To normalne.

## Pierwszy start i sprawdzenie

Po pierwszym logowaniu (kreator Armbian poprosi o hasło roota i nowego użytkownika):

```bash
cat /boot/armbianEnv.txt | grep user_overlays    # powinna być wybrana nakładka
lsmod | grep edt                                  # moduł dotyku załadowany
ls /sys/class/backlight/                          # podświetlenie
dmesg | grep -iE "sun4i|lvds|panel|edt"
```

Więcej poleceń diagnostycznych i tabela problemów są w [głównym README](../README.md).

## Zmiana ekranu na gotowym systemie

Wszystkie nakładki są już w obrazie, więc wystarczy zmienić jedną linię:

```bash
sudo nano /boot/armbianEnv.txt
```

```
user_overlays=bananapro-lemaker-lcd5
```

Potem `sudo reboot`. Żeby wyłączyć ekran, usuń nazwę nakładki z tej linii.

## Poprawki nakładki na płytce

Źródła są w `/usr/local/share/lemaker-lcd/`. Po zmianie (np. polaryzacji podświetlenia, osi dotyku) wgraj plik ponownie:

```bash
sudo nano /usr/local/share/lemaker-lcd/bananapro-lemaker-lcd7.dts
sudo armbian-add-overlay /usr/local/share/lemaker-lcd/bananapro-lemaker-lcd7.dts
sudo reboot
```

Sprawdzoną poprawkę warto przenieść do repozytorium, żeby trafiła do kolejnych obrazów.

## Aktualizacje jądra

Obraz korzysta z repozytorium Armbian, więc `apt upgrade` może zainstalować oficjalne jądro **bez** modułu dotyku. Obraz i podświetlenie dalej będą działać, dotyk przestanie. Są dwa wyjścia:

- wstrzymać aktualizacje jądra: `sudo apt-mark hold linux-image-current-sunxi linux-dtb-current-sunxi`
- albo po aktualizacji zbudować moduł na płytce (sposób A w [głównym README](../README.md)).

Nowsze jądro z dotykiem uzyskasz, budując obraz ponownie z opcją `--aktualizuj`. Same pakiety jądra (`.deb`) do wgrania przez `dpkg -i` znajdziesz po buildzie w `~/armbian-build/output/debs/`.

## Problemy z budowaniem

| Objaw | Co zrobić |
|---|---|
| `permission denied` przy dockerze | Dodaj się do grupy `docker` (patrz Wymagania) i zaloguj ponownie. |
| `armhf: not supported on this machine/kernel` albo `Failed to update binfmts` | Brak emulatora ARM na komputerze: `sudo apt install qemu-user-binfmt`, potem `ls /proc/sys/fs/binfmt_misc/` powinno pokazać `qemu-arm`. |
| Brak miejsca na dysku | Armbian potrzebuje około 50 GB. Pamięć podręczna leży w `~/armbian-build/cache/`. |
| `customize-image.sh exited with error` | Szczegóły w `~/armbian-build/output/logs/`. Najczęściej błąd składni w którymś `.dts`. |
| Skrypt przeniósł mój `customize-image.sh` do `.bak` | Robi tak, gdy w `userpatches/` był inny skrypt. Swoje polecenia dopisz na końcu naszego. |
| Build pyta o rzeczy w menu | Upewnij się, że uruchamiasz `./compile.sh bananapro-lcd` (z nazwą konfiguracji). |

## Źródła

- Armbian build framework, pierwsze kroki: <https://docs.armbian.com/build-framework/getting-started/>
- Pliki użytkownika (userpatches, customize-image.sh): <https://docs.armbian.com/build-framework/user-configurations/>
- Hooki, w tym `custom_kernel_config`: <https://docs.armbian.com/build-framework/extensions/hooks/>
- Repozytorium Armbian build: <https://github.com/armbian/build>

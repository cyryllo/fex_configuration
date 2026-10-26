#!/bin/bash
# lemaker-lcd: skrypt z repozytorium cyryllo/fex_configuration
#
# CO: wgrywa do obrazu nakladki ekranow LeMaker i wlacza wybrana.
# Armbian uruchamia go w chroot obrazu tuz przed jego zamknieciem.
# Argumenty od Armbian: $1=RELEASE $2=LINUXFAMILY $3=BOARD $4=BUILD_DESKTOP $5=ARCH
# Pliki z userpatches/overlay/ sa widoczne tutaj jako /tmp/overlay/.

set -e

SRC=/tmp/overlay/lemaker-lcd
DTS_DIR=/usr/local/share/lemaker-lcd
DTBO_DIR=/boot/overlay-user
ENV_FILE=/boot/armbianEnv.txt

if [[ ! -d "${SRC}" ]]; then
	echo "lemaker-lcd: brak ${SRC}, pomijam (uruchom build przez zbuduj-obraz.sh)"
	exit 0
fi

# CO: dtc jest zwykle w obrazie (wymaga go pakiet armbian-bsp-cli).
# DLACZEGO sprawdzamy: gdyby kiedys zniknal z zaleznosci, doinstalujemy go.
if ! command -v dtc > /dev/null; then
	apt-get install -y --no-install-recommends device-tree-compiler
fi

# CO: zrodla .dts zostaja na plycie, a skompilowane .dtbo ida do /boot/overlay-user.
# DLACZEGO kompilujemy wszystkie, a nie tylko wybrany: zmiana ekranu na plycie
# sprowadza sie wtedy do edycji linii user_overlays= w armbianEnv.txt.
mkdir -p "${DTS_DIR}" "${DTBO_DIR}"
cp "${SRC}"/*.dts "${DTS_DIR}/"
for dts in "${DTS_DIR}"/*.dts; do
	name=$(basename "${dts}" .dts)
	dtc -@ -q -I dts -O dtb -o "${DTBO_DIR}/${name}.dtbo" "${dts}"
	echo "lemaker-lcd: ${name}.dtbo"
done

# CO: narzedzia do sprawdzenia dotyku i I2C (evtest, i2cdetect).
# DLACZEGO w obrazie: README kaze ich uzyc przy diagnozie, a na swiezym
# systemie bez nich trzeba by najpierw konfigurowac siec.
apt-get update -qq
apt-get install -y --no-install-recommends evtest i2c-tools

# CO: skrypt do przelaczania ekranu na plycie (sudo lemaker-lcd 7|5|35|off).
install -m 0755 "${SRC}/lemaker-lcd" /usr/local/sbin/lemaker-lcd

# CO: usluga, ktora po starcie ponawia podpiecie sterownika dotyku.
# DLACZEGO: pierwsza proba sterownika przy starcie trafia na blad I2C,
# kolejna przechodzi (opis w samym skrypcie).
install -m 0755 "${SRC}/lemaker-touch-retry" /usr/local/sbin/lemaker-touch-retry
install -m 0644 "${SRC}/lemaker-touch-retry.service" /etc/systemd/system/lemaker-touch-retry.service
systemctl enable lemaker-touch-retry.service

# CO: wlacza domyslny ekran (plik "ekran" zapisuje zbuduj-obraz.sh).
# DLACZEGO przez lemaker-lcd: skrypt dopisuje do armbianEnv.txt blok
# z zakomentowanymi liniami dla wszystkich ekranow, wiec uzytkownik
# moze tez zmienic ekran recznie, odkomentowujac jedna linie.
ekran=$(cat "${SRC}/ekran" 2> /dev/null || true)
[[ "${ekran}" == "brak" || -z "${ekran}" ]] && ekran=off
/usr/local/sbin/lemaker-lcd "${ekran}"
rm -f "${ENV_FILE}.bak"

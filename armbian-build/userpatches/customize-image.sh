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

# CO: wlacza wybrany ekran (plik "ekran" zapisuje zbuduj-obraz.sh).
# DLACZEGO usuwamy stara linie: naraz moze dzialac tylko jedna nakladka ekranu.
ekran=$(cat "${SRC}/ekran" 2> /dev/null || true)
if [[ -n "${ekran}" && "${ekran}" != "brak" ]]; then
	sed -i '/^user_overlays=/d' "${ENV_FILE}"
	echo "user_overlays=bananapro-lemaker-lcd${ekran}" >> "${ENV_FILE}"
	echo "lemaker-lcd: wlaczony ekran ${ekran}"
fi

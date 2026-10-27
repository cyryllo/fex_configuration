#!/bin/bash
# Buduje jeden obraz Armbian (Debian 13 trixie) dla Banana Pro
# z nakladkami wszystkich ekranow LeMaker, sterownikiem dotyku edt-ft5x06
# i skryptem lemaker-lcd do przelaczania ekranu na plycie.
#
# Przyklady:
#   ./zbuduj-obraz.sh                      # pulpit XFCE, wlaczony ekran 7"
#   ./zbuduj-obraz.sh --ekran 5            # pulpit XFCE, wlaczony ekran 5"
#   ./zbuduj-obraz.sh --pulpit brak        # bez pulpitu (minimal)
#   ./zbuduj-obraz.sh -- KERNEL_CONFIGURE=yes   # reszta trafia do compile.sh

set -euo pipefail

SKRYPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR=$(dirname "${SKRYPT_DIR}")

EKRAN="7"
PULPIT="xfce"
JADRO="current"
BUILD_DIR="${HOME}/armbian-build"
AKTUALIZUJ="no"
EXTRA=()

pomoc() {
	cat <<- EOF
		Uzycie: $0 [opcje] [-- dodatkowe opcje compile.sh]

		  -e, --ekran N       ekran wlaczony od pierwszego startu: 7 (domyslnie), 5, 35 albo brak
		                      (nakladki wszystkich ekranow i tak trafiaja do obrazu,
		                      na plycie zmienia sie je przez: sudo lemaker-lcd 7|5|35|off)
		  -p, --pulpit NAZWA  xfce (domyslnie) albo brak (obraz minimal bez pulpitu)
		  -j, --jadro NAZWA   current (domyslnie, 6.18) albo edge
		  -k, --katalog DIR   gdzie trzymac armbian/build (domyslnie ${BUILD_DIR})
		  -u, --aktualizuj    przed budowaniem pobierz najnowszy armbian/build (git pull)
		  -h, --pomoc         ta pomoc
	EOF
}

blad() {
	echo "BLAD: $*" >&2
	exit 1
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		-e | --ekran) EKRAN="${2:-}"; shift 2 ;;
		-p | --pulpit) PULPIT="${2:-}"; shift 2 ;;
		-j | --jadro) JADRO="${2:-}"; shift 2 ;;
		-k | --katalog) BUILD_DIR="${2:-}"; shift 2 ;;
		-u | --aktualizuj) AKTUALIZUJ="yes"; shift ;;
		-h | --pomoc) pomoc; exit 0 ;;
		--) shift; EXTRA=("$@"); break ;;
		*) pomoc; blad "nieznana opcja: $1" ;;
	esac
done

case "${EKRAN}" in
	5 | 7 | 35 | brak) ;;
	*) blad "nieznany ekran: ${EKRAN} (7, 5, 35 albo brak)" ;;
esac
case "${JADRO}" in
	current | edge) ;;
	*) blad "jadro musi byc current albo edge" ;;
esac

# CO: ustawienia pulpitu dla compile.sh.
# DLACZEGO XFCE w wariancie minimal: jest oficjalnie wspierany dla trixie/armhf
# i jest lekki, a A20 ma tylko 1 GB RAM. "minimal" = sam pulpit i ekran
# logowania (ok. 500 MB), wiecej programow mozna doinstalowac przez armbian-config.
case "${PULPIT}" in
	xfce) PULPIT_OPCJE=(BUILD_DESKTOP=yes BUILD_MINIMAL=no DESKTOP_ENVIRONMENT=xfce DESKTOP_TIER=minimal) ;;
	brak) PULPIT_OPCJE=(BUILD_DESKTOP=no BUILD_MINIMAL=yes) ;;
	*) blad "pulpit musi byc xfce albo brak" ;;
esac

# CO: sprawdzenie narzedzi na komputerze.
# DLACZEGO tylko git i docker: reszte (kompilatory, dtc) Armbian ma w swoim kontenerze.
command -v git > /dev/null || blad "brak git (sudo apt install git)"
command -v docker > /dev/null || blad "brak dockera (sudo apt install docker.io docker-buildx)"

# CO: sprawdzenie emulatora ARM (qemu-user przez binfmt_misc).
# DLACZEGO na komputerze, a nie w kontenerze: wpisy binfmt naleza do jadra
# komputera, a bez nich Armbian nie uruchomi programow armhf w obrazie
# (blad "armhf: not supported on this machine/kernel").
if [[ "$(uname -m)" != arm* ]] && ! compgen -G "/proc/sys/fs/binfmt_misc/qemu-arm*" > /dev/null; then
	blad "brak emulatora ARM, zainstaluj: sudo apt install qemu-user-binfmt"
fi

# DLACZEGO: dokumentacja Armbian wymaga sciezki bez spacji.
[[ "${BUILD_DIR}" != *" "* ]] || blad "sciezka katalogu budowania nie moze zawierac spacji: ${BUILD_DIR}"

DTS_SRC="${REPO_DIR}/overlays"
compgen -G "${DTS_SRC}/bananapro-lemaker-lcd*.dts" > /dev/null || blad "nie znaleziono plikow bananapro-lemaker-lcd*.dts w ${DTS_SRC}"

# CO: szybka kontrola skladni nakladek przed dlugim budowaniem.
# DLACZEGO opcjonalna: dtc na komputerze nie jest wymagany, w obrazie i tak jest.
if command -v dtc > /dev/null; then
	for f in "${DTS_SRC}"/bananapro-lemaker-lcd*.dts; do
		dtc -@ -q -I dts -O dtb -o /dev/null "${f}" || blad "blad skladni w ${f}"
	done
	echo ">> Nakladki kompiluja sie poprawnie"
fi

# CO: pobranie lub aktualizacja Armbian build framework.
if [[ ! -d "${BUILD_DIR}/.git" ]]; then
	echo ">> Pobieram armbian/build do ${BUILD_DIR}"
	git clone --depth 1 https://github.com/armbian/build.git "${BUILD_DIR}"
elif [[ "${AKTUALIZUJ}" == "yes" ]]; then
	echo ">> Aktualizuje ${BUILD_DIR}"
	git -C "${BUILD_DIR}" pull --ff-only
fi

# CO: kopiowanie naszych plikow do userpatches.
# DLACZEGO kopia zapasowa: customize-image.sh moze juz istniec (np. szablon
# Armbian albo wlasne zmiany), nie chcemy go po cichu nadpisac.
UP="${BUILD_DIR}/userpatches"
mkdir -p "${UP}/overlay/lemaker-lcd"
if [[ -f "${UP}/customize-image.sh" ]] && ! grep -q "lemaker-lcd" "${UP}/customize-image.sh"; then
	kopia="${UP}/customize-image.sh.$(date +%Y%m%d-%H%M%S).bak"
	mv "${UP}/customize-image.sh" "${kopia}"
	echo ">> Istniejacy customize-image.sh przeniesiony do ${kopia}"
fi
cp "${SKRYPT_DIR}/userpatches/config-bananapro-lcd.conf" "${UP}/"
# CO: wlasne latki jadra (ponowienie rozpoznania dotyku w edt-ft5x06).
# DLACZEGO: pierwsza transakcja I2C do ukladu dotyku po starcie zawsze
# konczy sie bledem magistrali, latka ponawia ja raz (zamiast uslugi
# lemaker-touch-retry). Armbian szuka latek w userpatches/kernel/archive/sunxi-<wersja>/.
cp -r "${SKRYPT_DIR}/userpatches/kernel" "${UP}/"
cp "${SKRYPT_DIR}/userpatches/customize-image.sh" "${UP}/"
chmod +x "${UP}/customize-image.sh"
rm -f "${UP}/overlay/lemaker-lcd/"*.dts
cp "${DTS_SRC}"/bananapro-lemaker-lcd*.dts "${UP}/overlay/lemaker-lcd/"
cp "${SKRYPT_DIR}/lemaker-lcd" "${UP}/overlay/lemaker-lcd/"
echo "${EKRAN}" > "${UP}/overlay/lemaker-lcd/ekran"

# CO: wlasciwe budowanie, odpowiednik:
#   ./compile.sh BOARD=bananapipro RELEASE=trixie BUILD_DESKTOP=... KERNEL_CONFIGURE=no
# plus BRANCH i nasze dodatki z config-bananapro-lcd.conf.
echo ">> Buduje: pulpit=${PULPIT}, domyslny ekran=${EKRAN}, jadro=${JADRO}, Debian 13 trixie"
cd "${BUILD_DIR}"
./compile.sh bananapro-lcd BRANCH="${JADRO}" "${PULPIT_OPCJE[@]}" "${EXTRA[@]}"

echo
echo ">> Gotowe. Obrazy:"
ls -1t "${BUILD_DIR}"/output/images/*Bananapipro*trixie*.img 2> /dev/null | head -5 || true

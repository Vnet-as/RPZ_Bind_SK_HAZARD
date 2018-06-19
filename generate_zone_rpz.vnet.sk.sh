#!/bin/bash

# Created by Peter Vilhan vilhan at vnet.eu
# Dependencies: bash pdftohtml awk sed bind9utils wget sha256sum
# Licencia: GNU GPLv3

# Nastav handlery pre cleanup pri error/exit
trap cleanup ERR
trap cleanup EXIT

function cleanup {
	rm -f "${PDF_NAME}"
	rmdir "${TMP_DIR}"
	popd > /dev/null || exit 1
}

# Zmen aktualny priecinok na docasny v /tmp
TMP_DIR=$(mktemp -q -d -p /tmp/ rpz-tmp-XXX)
pushd "$TMP_DIR" > /dev/null || exit 1

# Premenne
PDF_NAME="haz-web-list.pdf"
REDIRECT_DST="rpz.vnet.sk."
SN=$(date +"%Y%m%d%H")

# Stiahnutie dokumentu
LINK=$(curl 'https://www.financnasprava.sk/sk/infoservis/priklady-hazardne-hry' -so -  | grep -iP 'Zoznam zakázaných webových sídiel.*</a>' | sed -n 's/.*href="\([^"]*\).*$/\1/p')

if ! /usr/bin/wget -t 1 -nd -r -l 1 --ignore-case -A pdf -O "${PDF_NAME}" -q "https://www.financnasprava.sk${LINK}"; then
	echo "Nepodarilo sa stiahnut dokument s bloknutymi webmi!" >&2
	exit 1
fi

# Ziskaj checksum
SOURCESUM=$(/usr/bin/sha256sum ${PDF_NAME})

# Parsovanie zoznamu domen
if [ -e "${PDF_NAME}" ]; then
	IFS=$'\n'

	poloha_zvrchu=$(pdftohtml ${PDF_NAME} -stdout -xml | grep 'zakázanú ponuku' | cut -d\" -f2 | tail -1)
	pozicie_stlpca=($(pdftohtml ${PDF_NAME} -stdout -xml | grep 'zakázanú ponuku' | cut -d\" -f4))

	domeny=($(pdftohtml ${PDF_NAME} -stdout -xml | awk -v padding="${poloha_zvrchu}" -v lava1="${pozicie_stlpca[0]}" -v lava2="${pozicie_stlpca[1]}" 'BEGIN { FS = "\"" } {if( $1=="<page number=" && $2>1)padding=0; if ( $4>lava1 && $4<lava2 && $2>padding ) print $11; else if ( $6>400 && $2>padding) print $13;}' | awk -F'[/<>]' '{if (NF==7) print $4; else if (NF==10) print $4; else print $2}'))

	ZONE_HEADER=$(cat <<_EOF_
\$TTL	3600
@	IN	SOA	ns.vnet.sk.	sysadmin.vnet.sk. (
			${SN}		; Serial
			3600			; Refresh
			900			; Retry
			1209600			; Expire
			3600 )			; Negative Cache TTL
rpz.vnet.sk.	IN	NS		ns.vnet.sk.
rpz.vnet.sk.	IN	NS		ns.vnet.cz.
rpz.vnet.sk.	IN	NS		ns.vnet.eu.
rpz.vnet.sk.	IN	A		46.229.237.56
rpz.vnet.sk.	IN	AAAA		::1
rpz.vnet.sk.	IN	TXT		"sha256 ${SOURCESUM}"
_EOF_
)

	for domena in "${domeny[@]}"; do
		domena=$(echo "${domena}" | sed 's/www.//g;s/^[ \t]*//;s/ *$//')
		if [ ${#domena} -gt 2 ]; then
			RECORDS+="${domena}	IN	CNAME	${REDIRECT_DST}\n"
			RECORDS+="*.${domena}	IN	CNAME	${REDIRECT_DST}\n"
		fi
	done

	# Zlep hlavicku s RPZ zaznamami
	FULL_ZONE="${ZONE_HEADER}\n\n${RECORDS}"

	# Skontrolujeme ci je zonefile syntakticky korektny
	if ! /usr/sbin/named-checkzone -q rpz.vnet.sk <(echo -e "${FULL_ZONE}"); then
		echo "Zonovy subor nepresiel verifikaciou!" >&2
		exit 1
	fi

else
	echo "Neexistuje vstupny subor s hazardnymi webmi ${PDF_NAME}" >&2
	exit 1
fi

echo -e "${FULL_ZONE}"

exit 0

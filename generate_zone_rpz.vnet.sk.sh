#!/bin/bash

# Created by Peter Vilhan vilhan at vnet.eu
# Dependencies: bash csvkit sed bind9utils wget sha256sum
# Licencia: GNU GPLv3

# Nastav handlery pre cleanup pri error/exit
trap cleanup ERR
trap cleanup EXIT

function cleanup {
	rm -f "${CSV_NAME}"
	rmdir "${TMP_DIR}"
	popd > /dev/null || exit 1
}

# Zmen aktualny priecinok na docasny v /tmp
TMP_DIR=$(mktemp -q -d -p /tmp/ rpz-tmp-XXX)
pushd "$TMP_DIR" > /dev/null || exit 1

# Premenne
CSV_NAME="haz-web-list.pdf"
REDIRECT_DST="rpz.vnet.sk."
SN=$(date +"%Y%m%d%H")

# Stiahnutie dokumentu
#LINK=$(curl -N -k -so - https://www.urhh.sk/web/guest/zoznam-zakazanych-sidel | sed  s/"> <"/">\n<"/g | grep 'Zoznam zakázaných webových sídiel_.*csv' -m1 | cut -d'"' -f2)
LINK="https://www.urhh.sk"$(curl -N -k -so - https://www.urhh.sk/web/guest/zoznam-zakazanych-sidel | grep "<a href="  |sed "s/<a href/\\n<a href/g" | grep 'Zoznam+zak%C3%A1zan%C3%BDch+webov%C3%BDch+s%C3%ADdiel' | grep '\.csv' | awk 'NR==1 {print; exit}' | cut -d'"' -f2)
#echo ${LINK}

if ! /usr/bin/wget --no-check-certificate -t 1 -nd -r -l 1 --ignore-case -A pdf -O "${CSV_NAME}" -q "${LINK}"; then
	echo "Nepodarilo sa stiahnut dokument s bloknutymi webmi z linku ${LINK}!" >&2
	exit 1
elif [ `file -i ${CSV_NAME} | grep -c 'text/plain'` -eq 0 ];then
	echo "Stiahol sa dokument ineho typu nez text/plain:"`file -i ${CSV_NAME}` >&2
	exit 1
fi

# Ziskaj checksum
SOURCESUM=$(/usr/bin/sha256sum ${CSV_NAME})

# Parsovanie zoznamu domen
if [ -e "${CSV_NAME}" ]; then
	IFS=$'\n'

	domeny=($(csvcut -S -x -q \" -d\, -K 1 -c 2 ${CSV_NAME} | tail -n +4 | sed s/"http[s]*:\/\/"//g  | grep -v '/'))

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
rpz.vnet.sk.	IN	A		217.73.28.12
rpz2.vnet.sk.	IN	CNAME		rpz.vnet.sk.
rpz.vnet.sk.	IN	AAAA		::1
rpz.vnet.sk.	IN	TXT		"sha256 ${SOURCESUM}"

stb-logging.global.flexitv.sk   IN      CNAME   iptvlog.vnet.sk.
admin.flexitv.sk	IN	A	10.17.14.200
domain.name	IN	CNAME	rpz.vnet.sk.
*.domain.name	IN	CNAME	rpz.vnet.sk.
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
	if ! /usr/bin/named-checkzone -q rpz.vnet.sk <(echo -e "${FULL_ZONE}"); then
		echo "Zonovy subor nepresiel verifikaciou!" >&2
		exit 1
	fi

else
	echo "Neexistuje vstupny subor s hazardnymi webmi ${CSV_NAME}" >&2
	exit 1
fi

echo -e "${FULL_ZONE}"

exit 0

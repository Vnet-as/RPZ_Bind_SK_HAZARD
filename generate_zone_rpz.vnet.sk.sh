#!/bin/bash
# Created by Peter Vilhan vilhan at vnet.eu
# Dependencies: bash pdftohtml awk sed bind9utils wget sha256sum
# Licencia: GNU GPLv3

sn=`date +%Y%m%d%H`
FILE="rpz.vnet.sk.conf.tmp"
DIR_PROD="/srv/salt/files/bind/"
FILE_PROD="rpz.vnet.sk.conf"
REDIRECT_DST="rpz.vnet.sk."

#stiahnutie dokumentu
LINK=`curl 'https://www.financnasprava.sk/sk/infoservis/priklady-hazardne-hry' -so -  | grep -iP 'Zoznam zakázaných webových sídiel.*</a>' | sed -n 's/.*href="\([^"]*\).*$/\1/p'`

/usr/bin/wget -t 1 -nd -r -l 1 --ignore-case -A pdf -q https://www.financnasprava.sk$LINK

if [ $? -gt 0 ];then

	echo "Nepodarilo sa stiahnut dokument s bloknutymi webmi!"
	exit 1

fi

SOURCESUM=`/usr/bin/sha256sum *.pdf`

mv *.pdf dat.pdf

#sparsovanie zoznamu domen
if [ -e dat.pdf ];then

IFS='
'

	poloha_zvrchu=`pdftohtml dat.pdf -stdout -xml | grep 'zakázanú ponuku' | cut -d\" -f2 | tail -1`
	pozicie_stlpca=(`pdftohtml dat.pdf -stdout -xml | grep 'zakázanú ponuku' | cut -d\" -f4`)

	domeny=(`pdftohtml dat.pdf -stdout -xml | awk -v padding="${poloha_zvrchu}" -v lava1="${pozicie_stlpca[0]}" -v lava2="${pozicie_stlpca[1]}" 'BEGIN { FS = "\"" } {if( $1=="<page number=" && $2>1)padding=0; if ( $4>lava1 && $4<lava2 && $2>padding ) print $11; else if ( $6>400 && $2>padding) print $13;}' | awk -F'[/<>]' '{if (NF==7) print $4; else if (NF==10) print $4; else print $2}'`)


	echo "\$TTL	3600" > $FILE
	echo "@	IN	SOA	ns.vnet.sk. sysadmin.vnet.sk. (" >> $FILE
	echo "			${sn}	; Serial" >> $FILE
	echo "			3600		; Refresh" >> $FILE
	echo "			900		; Retry" >> $FILE
	echo "			1209600		; Expire" >> $FILE
	echo "			3600 )	; Negative Cache TTL"  >> $FILE
	echo "rpz.vnet.sk.      IN      NS              ns.vnet.sk." >> $FILE
	echo "rpz.vnet.sk.      IN      NS              ns.vnet.cz." >> $FILE
	echo "rpz.vnet.sk.      IN      NS              ns.vnet.eu." >> $FILE
	echo "rpz.vnet.sk.      IN      A              46.229.237.56" >> $FILE
	echo "rpz.vnet.sk.      IN      AAAA              ::1" >> $FILE
	echo "rpz.vnet.sk.      IN      TXT		\"sha256 ${SOURCESUM}\"" >> $FILE

	for domena in " ${domeny[@]}";do
		domena=`echo ${domena} |sed 's/www.//g;s/^[ \t]*//;s/ *$//'`
		if [ ${#domena} -gt 2 ];then
			echo "${domena}	IN	CNAME	${REDIRECT_DST}" >> $FILE
			echo "*.${domena}	IN	CNAME	${REDIRECT_DST}" >> $FILE
		fi
	done

	#odstranime docasne data
	rm dat.pdf

	#skontrolujeme ci je zonefile syntakticky korektny
	/usr/sbin/named-checkzone -q rpz.vnet.sk $FILE

	if [ $? -gt 0 ];then

        	echo "Zonovy subor nepresiel verifikaciou!"
		cat $FILE
		rm $FILE
	        exit 1
	else
		#prepiseme finalny zonovaci subor monitorovany saltom
		mv $FILE $DIR_PROD$FILE_PROD
	fi


else

	echo "Neexistuje subor dat.pdf"
	exit 1
fi

exit 0

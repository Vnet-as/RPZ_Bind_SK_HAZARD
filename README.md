Tento skript je urceny pre generovanie zakazanych zon podla nariadeni financneho riaditelstva

Treba ho spustat napr kazdu hodku cez cron a sposobi stiahnutie pdf s blokovanymi webmy a vytvorenie zonoveho suboru pre bind. 

Dalsia disrtribucia zonoveho suboru je u nas cez salt, takze si to upravte podla potreby.
Tj treba si upravit sablonu zony podla svojich potrieb aby sa to smerovali na vhodne web servery a premennu DIR_PROD nech sa to uklada na vhodne miesto.
Nasledne si zabezpecit reconfig BINDu a reload zon DNS.

Zavislosti:

pdftohtml
awk
sed
bind9utils
sha256sum

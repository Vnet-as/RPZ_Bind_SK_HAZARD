# RPZ generator pre bind

Tento skript je urceny pre generovanie zakazanych zon podla nariadeni financneho riaditelstva.

Treba ho spustat napr kazdu hodinu cez cron. Skript sposobi stiahnutie pdf s blokovanymi webmy a vytvorenie zonoveho suboru pre `bind`.

Dalsia distribucia zonoveho suboru moze byt cez `rsync`, nastroj manazmentu konfiguracie (`ansible`, `saltstack`) alebo vlastny `shell` skript.

V skripte si treba upravit sablonu zony podla svojich potrieb aby zony smerovali na vhodne web servery. Nasledne si zabezpecit reconfig BINDu a reload zon DNS.

Zavislosti:

* pdftohtml
* awk
* sed
* bind9utils
* sha256sum

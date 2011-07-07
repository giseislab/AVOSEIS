#AVOSEIS=${AVOSEIS}
#AVOSEISMAKE=${AVOSEIS}/include/avoseismake
#AVOSEISWEB=${AVOSEISWEB}
#BACKUPS=${AVOSEIS}/BACKUPS
#PERLMOD=${AVOSEIS}/data/perl

include $(AVOSEISMAKE)

DIRS= adm lib bin data

update:	man scripts schemas pf_localmods html perlmods
.PHONY:	update html	

backups:
	mkdir -p ${BACKUPS}/
	tar -cf ${BACKUPS}/bin.tar ${AVOSEIS}/bin/
	tar -cf ${BACKUPS}/pf.tar ${AVOSEIS}/data/pf/
	tar -cf ${BACKUPS}/man.tar ${AVOSEIS}/man/
	tar -cf ${BACKUPS}/pf_localmods.tar ${AVOSEIS}/data/pf_localmods/

man:
	mkdir -p ${AVOSEIS}/man/man1
	mkdir -p ${AVOSEIS}/man/man3p
	mkdir -p ${AVOSEIS}/man/man5

perlmods:
	mkdir -p ${PERLMOD}/Avoseis
	cp ${PERLMOD}/SwarmAlarm.pm ${PERLMOD}/Avoseis/
	pod2man ${PERLMOD}/Avoseis/SwarmAlarm.pm ${AVOSEIS}/man/man3p/SwarmAlarm.3p

pf_localmods:
	rsync -r data/pf_localmods/generic/* ${AVOSEIS}/data/pf_localmods/
	rsync -r data/pf_localmods/${HOST}/* ${AVOSEIS}/data/pf_localmods/

schemas:
	rsync -r data/schemas/* ${AVOSEIS}/data/schemas

html:
	cp -r html/* ${INTERNALWEBPRODUCTS}/html

scripts:
	rsync bin/misc_scripts/* ${AVOSEIS}/bin

PERLMOD=${AVOSEIS}/data/perl

include $(AVOSEISMAKE)

DIRS= adm lib bin data

# First install only (make coldstart first)
firsttime:
	mkdir -p ${AVOSEIS}/man/man1
	mkdir -p ${AVOSEIS}/man/man3p
	mkdir -p ${AVOSEIS}/man/man5
	mkdir -p ${PERLMOD}/Avoseis

# Every time
scripts:
	rsync bin/misc_scripts/* ${AVOSEIS}/bin

schemas:
	rsync -r data/schemas/* ${AVOSEIS}/data/schemas

perlmods:
	mv ${PERLMOD}/SwarmAlarm.pm ${PERLMOD}/Avoseis/
	pod2man ${PERLMOD}/Avoseis/SwarmAlarm.pm ${AVOSEIS}/man/man3p/SwarmAlarm.3p

pf_localmods:
	rsync -r data/pf_localmods/generic/* ${AVOSEIS}/data/pf_localmods/

# Real-time servers only, everytime
host:
	rsync -r data/pf_localmods/${HOST}/* ${AVOSEIS}/data/pf_localmods/

html:
	cp -r html/* ${INTERNALWEBPRODUCTS}/html



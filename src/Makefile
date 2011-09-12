PERLMOD=${AVOSEIS}/data/perl

include $(AVOSEISMAKE)

DIRS= adm lib bin data

# Note make rules for clean, Include, install (and all) already in $AVOSEISMAKE

update:	#clean Include install schemas perlmods pf_localmods
	make clean
	make Include
	make install
	make schemas
	make perlmods
	make pf_localmods

schemas:
	rsync -r data/schemas/* ${AVOSEIS}/data/schemas

perlmods:
	mv ${PERLMOD}/SwarmAlarm.pm ${PERLMOD}/Avoseis/
	pod2man ${PERLMOD}/Avoseis/SwarmAlarm.pm ${AVOSEIS}/man/man3p/SwarmAlarm.3p

pf_localmods:
	rsync -r data/pf_localmods/generic/* ${AVOSEIS}/data/pf_localmods/

# Real-time servers only
host:
	rsync -r data/pf_localmods/${HOST}/* ${AVOSEIS}/data/pf_localmods/

html:
	chmod -R a+w $INTERNALWEBPRODUCTS
	cp -r html/* ${INTERNALWEBPRODUCTS}/html
	chmod -R a-w $INTERNALWEBPRODUCTS



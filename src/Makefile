#PWD:=$(shell pwd)
SWARMTRACKER=${PWD}/data/perl/Avoseis-SwarmTracker
PERLUTILS=${PWD}/data/perl/Avoseis-Utils
ALARMMANAGER=${PWD}/data/perl/Avoseis-AlarmManager

include $(AVOSEISMAKE)

DIRS= adm lib bin data

# Note make rules for clean, Include, install (and all) already in $AVOSEISMAKE

#update:	clean Include install perlmods schemas pf_localmods
update:	clean Include install schemas pf_localmods

perlmods:	
	cd ${SWARMTRACKER}
	perl ${SWARMTRACKER}/Makefile.PL
	make -f ${SWARMTRACKER}/Makefile
	make -f ${SWARMTRACKER}/Makefile install
	cd ${UTILS}
	perl ${UTILS}/Makefile.PL
	make -f ${UTILS}/Makefile
	make -f ${UTILS}/Makefile install
	cd ${ALARMMANAGER}
	perl ${ALARMMANAGER}/Makefile.PL
	make -f ${ALARMMANAGER}/Makefile
	make -f ${ALARMMANAGER}/Makefile install

schemas:
	rsync -r data/schemas/* ${AVOSEIS}/data/schemas

pf_localmods:
	rsync -r data/pf_localmods/generic/* ${AVOSEIS}/data/pf_localmods/

# Real-time servers only
host:
	rsync -r data/pf_localmods/${HOST}/* ${AVOSEIS}/data/pf_localmods/

html:
	chmod -R a+w ${INTERNALWEBPRODUCTS}
	cp -r html/* ${INTERNALWEBPRODUCTS}/html
	chmod -R a-w ${INTERNALWEBPRODUCTS}


cwd:
	echo ${PWD}

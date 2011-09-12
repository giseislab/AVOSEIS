PWD := $(shell pwd)
PERLMOD=$(PWD)/data/perl/Avoseis-SwarmAlarm

include $(AVOSEISMAKE)

DIRS= adm lib bin data

# Note make rules for clean, Include, install (and all) already in $AVOSEISMAKE

update:	clean Include install perlmods schemas pf_localmods

perlmods:	
	cd ${PERLMOD}
	perl ${PERLMOD}/Makefile.PL
	make -f ${PERLMOD}/Makefile
	make -f ${PERLMOD}/Makefile install

schemas:
	rsync -r data/schemas/* ${AVOSEIS}/data/schemas

pf_localmods:
	rsync -r data/pf_localmods/generic/* ${AVOSEIS}/data/pf_localmods/

# Real-time servers only
host:
	rsync -r data/pf_localmods/${HOST}/* ${AVOSEIS}/data/pf_localmods/

html:
	chmod -R a+w $INTERNALWEBPRODUCTS
	cp -r html/* ${INTERNALWEBPRODUCTS}/html
	chmod -R a-w $INTERNALWEBPRODUCTS


cwd:
	echo $(PWD)

install: coldstart

coldstart: .FORCED
ifdef ANTELOPE
	AVOSEIS=/opt/avoseis/`getid id`; export AVOSEIS; \
	AVOSEISMAKE=/opt/avoseis/`getid id`/include/avoseismake; export AVOSEISMAKE; \
	( cd ../setup; make install ) ; \
	( cd ../../lib/makerules; make install ) ; \
	( cd ../..; make Include ) ; \
	mkdir /opt/avoseis/`getid id`/man ; \
	( cd ../..; make install )
else
	@echo ""
	@echo "The ANTELOPE environment variable is not set." 
	@echo "Please run setup.csh or setup.sh according to the"
	@echo "setup.csh(1) man-page for BRTT Antelope software."
	@echo ""
	@exit 1
endif

.FORCED:

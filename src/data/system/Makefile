DATADIR=system
DATA= envrc \
      aliasrc \
      tcsh_properties \
      tcshrc_default \
      windowbars

CLEAN= tcshrc_default envrc

include $(AVOSEISMAKE)

all :: tcshrc_default envrc

tcshrc_default: tcshrc_default.id
	getid < tcshrc_default.id > tcshrc_default

envrc: envrc.id
	getid < envrc.id > envrc

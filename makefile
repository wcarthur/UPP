SHELL=/bin/sh

#
# Bring in configuration determined for UPP
#include ./configure.upp

#
# dependent build order of source -
# unipost relies on NCEP_modules and lib builds
# copygb  relies on NCEP_modules and lib builds
# ndate   relies on lib builds
SUBDIRS = src/lib src/unipost src/copygb src/ndate src/cnvgrib

#
# TARGETs

all: $(SUBDIRS)
	@for dir in $(SUBDIRS); do \
      ( cd $$dir; echo "Making $@ in `pwd`" ; \
        $(MAKE) $@ ); \
   done

clean: $(SUBDIRS)
	@for dir in $(SUBDIRS); do \
      ( cd $$dir; echo "Making $@ in `pwd`" ; \
        $(MAKE) $@) ; \
   done

.IGNORE:
.PHONY: clean

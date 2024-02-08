# Makefile for the irker relaying daemon

VERS := $(shell sed -n 's/version = "\(.\+\)"/\1/p' irkerd)
SYSTEMDSYSTEMUNITDIR := $(shell pkg-config --variable=systemdsystemunitdir systemd)

# `prefix`, `mandir` & `DESTDIR` can and should be set on the command
# line to control installation locations
prefix ?= /usr
mandir ?= /share/man
target = $(DESTDIR)$(prefix)

docs: irkerd.html irkerd.8 irkerhook.html irkerhook.1 irk.html irk.1

irkerd.8: irkerd.xml
	xmlto man irkerd.xml
irkerd.html: irkerd.xml
	xmlto html-nochunks irkerd.xml

irkerhook.1: irkerhook.xml
	xmlto man irkerhook.xml
irkerhook.html: irkerhook.xml
	xmlto html-nochunks irkerhook.xml

irk.1: irk.xml
	xmlto man irk.xml
irk.html: irk.xml
	xmlto html-nochunks irk.xml

install.html: install.adoc
	asciidoc -o install.html install.adoc
security.html: security.adoc
	asciidoc -o security.html security.adoc
hacking.html: hacking.adoc
	asciidoc -o hacking.html hacking.adoc

install: irk.1 irkerd.8 irkerhook.1 uninstall
	install -m 755 -o 0 -g 0 -d "$(target)/bin"
	install -m 755 -o 0 -g 0 irkerd "$(target)/bin/irkerd"
ifneq ($(strip $(SYSTEMDSYSTEMUNITDIR)),)
	install -m 755 -o 0 -g 0 -d "$(DESTDIR)$(SYSTEMDSYSTEMUNITDIR)"
	install -m 644 -o 0 -g 0 irkerd.service "$(DESTDIR)$(SYSTEMDSYSTEMUNITDIR)"
endif
	install -m 755 -o 0 -g 0 -d "$(target)$(mandir)/man8"
	install -m 755 -o 0 -g 0 irkerd.8 "$(target)$(mandir)/man8/irkerd.8"
	install -m 755 -o 0 -g 0 -d "$(target)$(mandir)/man1"
	install -m 755 -o 0 -g 0 irkerhook.1 "$(target)$(mandir)/man1/irkerhook.1"
	install -m 755 -o 0 -g 0 irk.1 "$(target)$(mandir)/man1/irk.1"

uninstall:
	rm -f "$(target)/bin/irkerd"
ifneq ($(strip $(SYSTEMDSYSTEMUNITDIR)),)
	rm -f "$(DESTDIR)$(SYSTEMDSYSTEMUNITDIR)/irkerd.service"
endif
	rm -f "$(target)$(mandir)/man8/irkerd.8"
	rm -f "$(target)$(mandir)/man1/irkerhook.1"
	rm -f "$(target)$(mandir)/man1/irk.1"

clean:
	rm -f irkerd.8 irkerhook.1 irk.1 irker-*.tar.gz *~ *.html

pylint:
	@pylint --score=n irkerd irkerhook.py

loc:
	@echo "LOC:"; wc -l irkerd irkerhook.py
	@echo -n "LLOC: "; grep -vE '(^ *#|^ *$$)' irkerd irkerhook.py | wc -l

DOCS = \
	README \
	COPYING \
	NEWS \
	install.adoc \
	security.adoc \
	hacking.adoc \
	irkerhook.xml \
	irkerd.xml \
	irk.xml \

SOURCES = \
	$(DOCS) \
	irkerd \
	irkerhook.py \
	filter-example.py \
	filter-test.py \
	irk \
	Makefile

EXTRA_DIST = \
	org.catb.irkerd.plist \
	irkerd.service \
	irker-logo.png

version:
	@echo $(VERS)

irker-$(VERS).tar.gz: $(SOURCES) irkerd.8 irkerhook.1 irk.1
	mkdir irker-$(VERS)
	cp -pR $(SOURCES) $(EXTRA_DIST) irker-$(VERS)/
	@COPYFILE_DISABLE=1 tar -cvzf irker-$(VERS).tar.gz irker-$(VERS)
	rm -fr irker-$(VERS)

irker-$(VERS).md5:
	@md5sum irker-$(VERS).tar.gz >irker-$(VERS).md5

dist: irker-$(VERS).tar.gz irker-$(VERS).md5

WEBDOCS = irkerd.html irk.html irkerhook.html install.html security.html hacking.html

NEWSVERSION=$(shell sed -n <NEWS '/^[0-9]/s/:.*//p' | head -1)

release: irker-$(VERS).tar.gz irker-$(VERS).md5 $(WEBDOCS)
	@[ $(VERS) = $(NEWSVERSION) ] || { echo "Version mismatch!"; exit 1; }
	shipper version=$(VERS) | sh -e -x

refresh: $(WEBDOCS)
	@[ $(VERS) = $(NEWSVERSION) ] || { echo "Version mismatch!"; exit 1; }
	shipper -N -w version=$(VERS) | sh -e -x

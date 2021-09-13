SHELL = /bin/bash

all: downloads pop-fonts

downloads: pkg maint source sourcemax

pkg:
	wget -qO $@ https://popcon.debian.org/by_inst

maint:
	wget -qO $@ https://popcon.debian.org/maint/by_inst

source:
	wget -qO $@ https://popcon.debian.org/source/by_inst

sourcemax:
	wget -qO $@ https://popcon.debian.org/sourcemax/by_inst

pop-fonts: pkg
	grep 'fonts' pkg | sort -nk3 | awk '$$3>=1000 {print $$2}' | sort | grep -E '^fonts|^xfonts' >$@

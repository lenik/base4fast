SHELL = /bin/bash

pop-fonts:
	grep 'fonts' pkg | sort -nk3 | awk '$$3>=1000 {print $$2}' | sort | grep -E '^fonts|^xfonts' >$@


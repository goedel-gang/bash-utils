# make them phonies because Git checkouts will mess up timestamps
.PHONY: all appari.sh apparix.zsh

all: appari.sh apparix.zsh

appari.sh: ~/.apparix/appari.sh
	cp $< $@

apparix.zsh: ~/.zsh/apparix.zsh
	cp $< $@

all: appari.sh apparix.zsh

appari.sh: ~/.apparix/appari.sh
	cp $< $@

apparix.zsh: ~/.zsh/apparix.zsh
	cp $< $@

ALL = demo/prompt.bash

.PHONY: .FORCE

all: $(ALL)

demo/prompt.bash: ~/.bash/prompt.bash .FORCE
	cp $< $@

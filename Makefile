ALL = demo/prompt.bash

# make them phonies because Git checkouts will mess up timestamps
.PHONY: all $(ALL)

all: $(ALL)

demo/prompt.bash: ~/.bash/prompt.bash
	cp $< $@

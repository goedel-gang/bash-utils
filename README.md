# bash-utils

    ██ ███    ███ ██████   ██████  ██████  ████████  █████  ███    ██ ████████ ██ 
    ██ ████  ████ ██   ██ ██    ██ ██   ██    ██    ██   ██ ████   ██    ██    ██ 
    ██ ██ ████ ██ ██████  ██    ██ ██████     ██    ███████ ██ ██  ██    ██    ██ 
    ██ ██  ██  ██ ██      ██    ██ ██   ██    ██    ██   ██ ██  ██ ██    ██       
    ██ ██      ██ ██       ██████  ██   ██    ██    ██   ██ ██   ████    ██    ██ 

This would look better if Github would just use a monospace font with normal
vertical spacing. Oh well.

This fork of apparix is not compatible with older Bashes, as it relies on you
having sourced `bash-completion` (https://github.com/scop/bash-completion),
which needs Bash 4.1+. Fret not, the `master` branch is still more or less
compatible, and gets updates every now and then (when I feel like it).

## Apparix

Directory bookmarking system. It used to be implemented in C, shipped with bash
wrapper functions and completion code. This is now legacy, and should be
retrieved from older commits (see the master branch).

The new pure shell implementation is in `appari.sh`.

Apparix completion is currently still quite weak particularly to newlines and
commas in directory names, as is its completion as it delegates to `_filedir`
from `bash-completion`.

However, in storing directories and bookmarks, it now uses a nice little
serialisation system. The only consequence is that because of the way the
bookmark escaping works, you are asked not to use the string
`__GOEDEL_PLACEHOLDER__` in any of your bookmarks or directories. If you really
need to, you can set the environment variable `$GOEDEL_PLACEHOLDER` to some
other suitable, Perl regex safe string before sourcing Apparix.

There is also a reference prompt that can talk to apparix, if you've got it set
up, in `prompt.bash`. A minimal demo `bashrc` to call both is provided. You can
try it out by running `demo/demo_bash`.

Similarly, I have included a `prompt.zsh`, `zshrc` and `demo/demo_zsh`. See
below screenshot for what they should hopefully look like (in this screenshot I
used tab completion. It's a little hard to see, but it's definitely there, in
between the `h` and the `ello\ world` (which is to say, I didn't have to type
any backslashes)).

![screenshot](https://github.com/goedel-gang/bash-utils/blob/twenty-first-century/prompt_screenshot.png)

## Zapparix

Zapparix is a thin layer on top of Zsh's hashed directories. It provides an
Apparix-like experience, with persistent bookmarks that you create using `bm`.
However, because they are hashed by Zsh, they are much more closely integrated
with the shell.

You automatically get expansion on bookmarks *anywhere* that the
shell expands filenames, and of course you get completion the way you configured
it for the rest of Zsh. Also, the Zsh prompt expansion `%~` understands hashed
directories, so more than likely your prompt already knows about your bookmarks,
with no more configuration needed.

Also, this means that you can use bookmarks together with shell globs
(`cp ~bm/**.{png,jpg} .`).

Even though I say so myself, Zapparix provides some pretty nicely formatted
output.

### commands

| command | effect |
|---|---|
| `bm <mark>` | bookmark the cwd with the name `<mark>` |
| `bm` | show all bookmarks |
| `unbm <mark>` | remove the bookmark `<mark>` |
| `unbm` | remove any bookmarks to the current directory |

Note that hashed directories are accessed by prefixing the hash ("bookmark
name") with a tilde `~`. So a sample session might look like this (this is a
two-line zsh prompt):

     ~
    ❯ cd Documents

     ~/Documents
    ❯ bm doc
    2a3
    > hash -d doc=/home/izaak/Documents

     ~doc
    ❯ cd

     ~
    ❯ cd ~doc

     ~doc
    ❯ pwd
    /home/izaak/Documents

     ~doc
    ❯

Here is a screenshot with colours, and a sample bookmark listing

![screenshot](https://github.com/goedel-gang/bash-utils/blob/twenty-first-century/zapparix_screenshot.png)

There is a similar demo shell in `zdemo/demo_zsh`, which is about three lines of
config setting up a prompt and sourcing zapparix.

See the source of `apparix.zsh` for maybe some more information.

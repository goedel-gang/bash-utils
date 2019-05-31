# shellcheck disable=SC2016 shell=bash
# vim: ts=4 sw=0 sts=-1 et

#   ___  __  __  ____    ___   ____  _____   _     _   _  _____  _
#  |_ _||  \/  ||  _ \  / _ \ |  _ \|_   _| / \   | \ | ||_   _|| |
#   | | | |\/| || |_) || | | || |_) | | |  / _ \  |  \| |  | |  | |
#   | | | |  | ||  __/ | |_| ||  _ <  | | / ___ \ | |\  |  | |  |_|
#  |___||_|  |_||_|     \___/ |_| \_\ |_|/_/   \_\|_| \_|  |_|  (_)
#
# This fork of apparix is not compatible with older Bashes, as it relies on you
# having sourced bash-completion (https://github.com/scop/bash-completion),
# which needs Bash 4.1.


# ignore errors about:
# - unexpanded substitutions in single quotes, because sometimes you need to
#   delay command substitution

# Vim modeline to try and keep the indentation in check.

#                                       .__         .__
# _____   ______  ______ _____  _______ |__|  ______|  |__
# \__  \  \____ \ \____ \\__  \ \_  __ \|  | /  ___/|  |  \
#  / __ \_|  |_> >|  |_> >/ __ \_|  | \/|  | \___ \ |   Y  \
# (____  /|   __/ |   __/(____  /|__|   |__|/____  >|___|  /
#      \/ |__|    |__|        \/                 \/      \/
# FIGMENTIZE: apparish

#  bookmarks for the command line with comprehensive tab completion on target
#                                   content
#                             works for bash and zsh
#
#  Quick Guide:
#  -  save this file in $HOME/.bourne-apparish
#  -  issue 'source $HOME/.bourne-apparish'
#  -  go to a directory and issue 'bm foo'
#  -  you can now go to that directory by issuing 'to foo'
#  -  try tab completion and command substitution, see the examples below.
#
#  Apparish is a pure shell implementation of an older system, apparix, written
#  partly in C.  For both systems the bookmarking commands are implemented as
#  shell functions.  The names of these functions are the same between the two
#  implementations and the function definitions are very similar.  The apparix
#  shell functions invoke a C executable. Apparish uses another shell funtion to
#  mimic this C program and apparish provides two additional functions, and
#  apparix-list. The pivotal commands however are 'bm' (bookmark) and 'to' (go
#  to mark). You can change from apparix to apparish and vice versa, as they use
#  the same resource files.
#
#  To un-create a bookmark (or portal), simply delete its line in $APPARIXRC.
#  This approach is better as programmatically deleting things can be
#  complicated and dangerous, and this means the authors of Apparix are not
#  liable for anything you destroy.
#  For your convenience, Apparix tries to define the alias `via` (VI Apparixrc)
#  which, despite appearances, opens apparixrc in your $EDITOR.
#
#  ---
#     bm <tag>                create bookmark <tag> for current directory
#  ---
#     to <tag>                jump to the directory marked <tag>
#     to <tag> <TAB>          tab-complete on subdirectories of <tag>
#     to <tag> s<TAB>         tab-complete on subdirectories of <tag> starting
#                             with s
#     to <tag> foo/<TAB>      tab-complete in subdirectory foo of <tag>
#     to <tag> foo/bar<TAB>   et cetera et cetera
#
#  --- the commands below allow tab-completion identical to 'to' above.
#     als <tag>               list contents of <tag> directory
#     ald <tag>               list subdirectories of <tag> directory
#     amd <tag> NAME          issue mkdir in <tag> directory
#     amd <tag> PATH/<TAB>    amd allows tab completion
#     ae <tag> FILE           edit FILE in <tag> directory
#     ae <tag> FI<TAB>        complete on FI in <tag> directory
#     a <tag> s<TAB>          echo the location of the <tag> directory or
#                             content.
#                             This is useful in command substitution, e.g.
#                             'cp somefile ($a tag src)'
#
#  --- apparix uses by default the most recent <tag> if identical tags exist.
#                It can e.g. be useful to use 'now' as an often-changing tag.
#     apparix-list <tag>      list all destinations marked <tag>
#     whence <tag>            Enter menu to select destination
#
#  --- the functionality below mimics bash CDPATH.
#     portal                  add all subdirectory names as mark
#     portal-expand           refresh the portal subdirectory cache
#
#  If you use 'ae', make sure $EDITOR is set to the name of an available editor.
#  I find it useful to have this alias:
#
#     alias a=apparish
#
#  as I use it in command substitution, e.g.
#
#     echo cp myfile $(a bm)
#     cp myfile $(a bm)
#
#  This is a big decision from a Huffman point of view.  If you want to remove
#  it, go to all the places in the lines below where the name Huffman is
#  mentioned and remove the relevant part.
#
#  Apparish (this file) implements apparix functionality in shell code,
#  compatible with apparix resource files. You can either use old apparix
#  (compiling and installing the application apparix) in conjunction with
#  sourcing .bourne-apparix, or you can simply source this file without needing
#  to install apparix.  This file implements nearly all apparix functionality
#  in shell code. It uses a apparish in place of apparix.
#
#                       BASH and ZSH functions
#
#  Apparish should work for modern bourne-style shells, not including the
#  bourne shell.  Name this file for example .bourne-apparish in your $HOME
#  directory, and put the line 'source $HOME/.bourne-apparish' (without quotes)
#  in the file $HOME/.bashrc or $HOME/.bash_login if you use bash, in the file
#  $HOME/.zshrc if you use zsh.

 #
#  Thanks to Sitaram Chamarty for all the important parts of the bash completion
#  code, and thanks to Izaak van Dongen for figuring out the zsh completion
#  code, subsequently improving and standardising the bash completion code, and
#  suggesting the name apparish.
 #

APPARIXHOME="${APPARIXHOME:=$HOME}"
# ensure directory exists
command mkdir -p "$APPARIXHOME"
APPARIXRC="${APPARIXRC:=$APPARIXHOME/.apparixrc}"
APPARIXEXPAND="${APPARIXEXPAND:=$APPARIXHOME/.apparixexpand}"
APPARIXLOG="${APPARIXLOG:=$APPARIXHOME/.apparixlog}"

GOEDEL_PLACEHOLDER="${GOEDEL_PLACEHOLDER:=__GOEDEL_PLACEHOLDER__}"

# ensure these files exist
command touch "$APPARIXRC"
command touch "$APPARIXEXPAND"
command touch "$APPARIXLOG"

# Huffman (remove a in the next line)
APPARIX_FILE_FUNCTIONS=( a ae av aget toot apparish apparish_newlinesafe )
APPARIX_DIR_FUNCTIONS=( to als ald amd todo rme )

# Serialise stdin so that it can be stored safely in a CSV file. This
# involves escaping commas and newlines. It should be pretty straightforwardly
# extensible to also escape other types of character.
# It's currently a bit hacky in terms of using multiple seds and awks to bash
# things into the right format. Replacing newlines turns out to be quite
# complicated, and I do this with awk. It turns out it's pretty hard to respect
# trailing newlines when you're using line-based text processing utilities, so I
# add a trailing hash character and then strip it at the end.
# https://stackoverflow.com/questions/1251999/how-can-i-replace-a-newline-n-using-sed
function apparix_serialise() {
    ( command cat; command echo -n '#' ) | command sed 's/%/%%/g
                 s/,/%c/g' | \
        command awk 'BEGIN { ORS="%n" } { print $0 }' | \
        command sed 's/#%n$//'
}

# https://stackoverflow.com/questions/723157/how-to-insert-a-newline-in-front-of-a-pattern
# Makes use of the dummy placeholder _GOEDEL_PLACEHOLDER_, so please don't put
# that in any of your directories or tags, or if you do, think of a better
# placeholder.
# https://unix.stackexchange.com/questions/17732/where-has-the-trailing-newline-char-gone-from-my-command-substitution
# This adds a trailing character "#" to preserve any trailing newlines you had.
# Remove it with the parameter expansion ${var%#}
function apparix_deserialise() {
    # use perl rather than sed, because sed doesn't reliable handle trailing
    # newlines, or particularly the lack thereof across distributions.
    # BSD sed just bluntly adds a newline at the end.
    # https://stackoverflow.com/questions/13325138/why-does-sed-add-a-new-line-in-osx
    command perl -pe 's/%%/'"$GOEDEL_PLACEHOLDER"'/g;
                      s/%c/,/g;
                      s/%n/\'$'\n''/g;
                      s/'"$GOEDEL_PLACEHOLDER"'/%/g'
    echo -n '#'
}

# vim-like: totally silence the given command, with less of the tedium. doesn't
# affect return status, so can be used inside if statements.
# black magic: "$@" expands to each argument as a separate word.
# gotcha: this won't expand any aliases you have. This is probably preferred
# functionality anyway, though (at least for me)
function silent() {
    "$@" > /dev/null 2> /dev/null
}

# Huffman (remove this paragraph, or just alias "a" yourself)
if ! silent command -v a; then
    alias a='apparish'
else
    >&2 echo "Apparish: not aliasing a"
fi

if ! silent command -v via; then
    alias via='vi "$APPARIXRC"'
else
    >&2 echo "Apparish: not aliasing via"
fi

# Apparix now automatically initialises
function apparix-init() {
    >&2 echo "There is no longer any need to call apparix-init"
}

# Generate paths from bookmarks and suffix paths, but append a # sign. This
# guards trailing newlines in command substitution, but isn't very nice to look
# at or use manually.
# This is wrapped by apparish, which strips the # sign. This makes apparish more
# usable in a command line. Apparish also lists bookmarks when given no
# arguments.
# It assumes that the mark it is given is in serialised form, which is what the
# completion should give you. Serialised form is only really a bother if you
# like to put whitespace and commas in your marks.
function apparish_newlinesafe() {
    if [[ 0 == "$#" ]]; then
        >&2 echo "Apparix: need arguments"
        return 1
    else
        # local mark="$(printf "%s" "$1" | apparix_deserialise)"
        # mark="${mark%#}"
        local mark="$1"
        local list="$(command grep -F -- "j,$mark," "$APPARIXRC" "$APPARIXEXPAND")"
        if [[ -z "$list" ]]; then
            >&2 echo "Mark '$mark' not found"
            return 1
        fi
        local target="$(<<< "$list" command tail -n 1 | command cut -f3 -d,)"
        local target="$(printf "%s" "$target" | apparix_deserialise)"
        target="${target%#}"
        if [[ 2 == "$#" ]]; then
            printf "%s/%s#" "$target" "$2"
        elif [[ 1 == "$#" ]]; then
            printf "%s#" "$target"
        else
            # do not fail gracefully, to prevent hard to find errors
            >&2 echo "Apparix: too many arguments. Usage: [command] TAG PATH"
            return 1
        fi
    fi
}

function apparish() {
    if [[ 0 == "$#" ]]; then
        # don't do any deserialisation, because that will mostly just serve to
        # confuse column, by reintroducing tabs and newlines
        echo "Bookmarks"
        grep '^j' -- "$APPARIXRC" | command cut -d, -f2,3 | \
            command column -t -s , | \
            sed 's/^/    /'
        echo "Portals"
        grep '^e' -- "$APPARIXRC" | command cut -d, -f2 | \
            command column -t -s , | \
            sed 's/^/    /'
        echo "Expanded bookmarks"
        command cut -d, -f2,3 "$APPARIXEXPAND" | command column -t -s , | \
            sed 's/^/    /'
        return
    fi
    local result
    if result="$(apparish_newlinesafe "$@")"; then
        echo "${result%#}"
    else
        return 1
    fi
}

function apparix-list() {
    if [[ 0 == "$#" ]]; then
        >&2 echo "Need mark"
        return 1
    fi
    local mark="$1"
    command grep -F -- ",$mark," "$APPARIXRC" "$APPARIXEXPAND" | cut -f3 -d,
}

# create a bookmark in PWD. The bookmark is treated as unsafe, and is passed
# through apparix_serialise to make it safe. This means that if you give an
# argument with a newline in, the bookmark that gets created will instead have a
# %n.
function bm() {
    local mark list target
    if [[ 0 == "$#" ]]; then
        >&2 echo Need mark
        return 1
    fi
    mark="$(printf "%s" "$1" | apparix_serialise)"
    list="$(apparix-list "$mark")"
    target="$(printf "%s" "$PWD" | apparix_serialise)"
    echo "j,$mark,$target" | tee -a -- "$APPARIXLOG" >> "$APPARIXRC"
    if [[ -n "$list" ]]; then
        listsize="$(wc -l <<< "$list")"
        listtail="$(tail -n 2 <<< "$list")"
        ellipsis=""
        if (( listsize > 2 )); then ellipsis="\n(...)"; fi
        if (( listsize > 0 )); then
            echo -e "Bookmark $mark exists" \
                    "($listsize total):$ellipsis\n$listtail"
        fi
        echo "$target (added)"
    fi
}

function to() {
    local loc
    if [[ "$1" == '-' ]]; then
        loc="-"
    else
        loc="$(apparish_newlinesafe "$@")"
        loc="${loc%#}"
    fi
    if [[ "$?" == 0 ]]; then
        cd -- "$loc" || return 1
    fi
}

function portal() {
    local target
    target="$(printf "%s" "$PWD" | apparix_serialise)"
    echo "e,$target" >> "$APPARIXRC"
    portal-expand
}

function portal-expand() {
    local parentdir
    rm -f -- "$APPARIXEXPAND"
    true > "$APPARIXEXPAND"
    command grep '^e,' -- "$APPARIXRC" | cut -f 2 -d , | \
        while IFS='' read -r parentdir; do
            parentdir="$(printf "%s" "$parentdir" | apparix_deserialise)"
            parentdir="${parentdir%#}"
            # run in an explicit bash subshell to be able to locally set the
            # right options
            export -f apparix_serialise
            parentdir="$parentdir" APPARIXEXPAND="$APPARIXEXPAND" bash <<EOF
            cd -- "\$parentdir" || exit 1
            shopt -s nullglob
            shopt -u dotglob
            shopt -u failglob
            GLOBIGNORE="./:../"
            for _subdir in */ .*/; do
                subdir="\${_subdir%/}"
                parentdir="\$(printf "%s" "\$parentdir" | apparix_serialise)"
                parentdir="\${parentdir%#}"
                subdir="\$(printf "%s" "\$subdir" | apparix_serialise)"
                subdir="\${subdir%#}"
                echo "j,\$subdir,\$parentdir/\$subdir" >> "\$APPARIXEXPAND"
            done
EOF
        done || true
}

function whence() {
    local target
    if [[ 0 == "$#" ]]; then
        >&2 echo "Need mark"
        return 1
    fi
    local mark="$1"
    select target in $(apparix-list "$mark"); do
        target="$(printf "%s" "$target" | apparix_deserialise)"
        target="${target%#}"
        cd -- "$target" || return 1
        break
    done
}

function toot() {
    local file
    file="$(apparish_newlinesafe "$@")"
    file="${file%#}"
    if [[ "$?" == 0 ]]; then
        "${EDITOR:-vim}" "$file"
    fi
}

# relies on Bashy expansion, so won't work if you have RC_EXPAND_PARAM in zsh
function todo() {
    toot "$@"/TODO
}

function rme() {
    toot "$@"/README
}

# apparix listing of directories of mark
function ald() {
    local loc
    if loc="$(apparish_newlinesafe "$@")"; then
        loc="${loc%#}"
        ls -d "$loc"/*
    else
        return 1
    fi
}

# apparix ls of mark
function als() {
    local loc
    if loc="$(apparish_newlinesafe "$@")"; then
        loc="${loc%#}"
        ls "$loc"
    else
        return 1
    fi
}

# apparix search if current directory is a bookmark or portal
function amibm() {
    target="$(printf "%s" "$PWD" | apparix_serialise)"
    (
    command grep "^j" "$APPARIXRC" | command cut -d, -f2,3 | \
        sed 's#$#//#' | \
        command grep -F -- ",$target//" | \
        command cut -f1 -d,
    command grep "^e" "$APPARIXRC" | command cut -d, -f2 | \
        sed 's#$#//#' | \
        command grep -Fx -- "$target//" | \
        command sed "s/.*/[p]/"
    command cut -d, -f2,3 "$APPARIXEXPAND" | \
        sed 's#$#//#' | \
        command grep -F -- ",$target//" | \
        command sed "s/.*/>[p]/"
    ) | command paste -s -d ' ' - || true
    # always return successfully, even if grep doesn't find anything
}

# apparix search bookmark
function bmgrep() {
    pat="${1?Need a pattern to search}"
    command grep -i -- "$pat" "$APPARIXRC" | cut -f 2,3 -d ',' | \
        column -t -s,
}

# apparix get; get something from a mark
function aget() {
    local loc
    if loc="$(apparish_newlinesafe "$@")"; then
        loc="${loc%#}"
        cp "$loc" .
    else
        return 1
    fi
}

# apparix mkdir in mark
function amd() {
    local loc
    if loc="$(apparish_newlinesafe "$@")"; then
        loc="${loc%#}"
        mkdir -p -- "$loc"
    else
        return 1
    fi
}

# apparix edit of file in mark or subdirectory of mark
function av() {
    local loc
    if loc="$(apparish_newlinesafe "$@")"; then
        loc="${loc%#}"
        view -- "$loc"
    else
        return 1
    fi
}

# apparix edit of file in mark or subdirectory of mark
function ae() {
    local loc
    if loc="$(apparish_newlinesafe "$@")"; then
        loc="${loc%#}"
        "${EDITOR:-vim}" "$loc"
    else
        return 1
    fi
}

function apparish_ls() {
    cat <<EOH
  bm MARK                 Bookmark current directory as mark
  to MARK [SUBDIR]        Jump to mark or a subdirectory of mark
  ald MARK [SUBDIR]       List subdirectories of mark directory or subdir
  als MARK [SUBDIR]       List mark directory or subdir
  amd MARK [SUBDIR]       Make directory in mark
  ae MARK [SUBDIR/]FILE   Edit file in mark
  av MARK [SUBDIR/]FILE   View file in mark
  amibm                   See if the current directory is a bookmark
  bmgrep PATTERN          List all marks and targets where target matches
                          PATTERN
  todo MARK [SUBDIR]      Edit TODO file in mark directory
  rme MARK [SUBDIR]       Edit README file
  whence MARK             Menu-based selection for mark with multiple targets
  portal                  Add current directory as portal (subdirectories are
                          mark names)
  portal-expand           Re-expand all portals
  apparix-list MARK       List all targets for bookmark mark
EOH
}

if [[ -n "$BASH_VERSION" ]]; then
    # assert that bash version is at least $1.$2.$3
    version_assert() {
        for i in {1..3}; do
            if ((BASH_VERSINFO[$((i - 1))] > ${!i})); then
                return 0
            elif ((BASH_VERSINFO[$((i - 1))] < ${!i})); then
                echo "Your bash is older than $1.$2.$3" >&2
                return 1
            fi
        done
        return 0
    }

    # https://stackoverflow.com/questions/3685970/check-if-a-bash-array-...
    # contains-a-value
    function elemOf() {
        local e match="$1"
        shift
        for e; do [[ "$e" == "$match" ]] && return 0; done
        return 1
    }

    # a file, used by _apparix_comp
    # uses _filedir, so archeological bash is unsupported
    function _apparix_comp_file() {
        local caller="$1"
        # this is used by _filedir
        # shellcheck disable=SC2034
        local cur="$2"
        if elemOf "$caller" "${APPARIX_DIR_FUNCTIONS[@]}"; then
            _filedir -d
        elif elemOf "$caller" "${APPARIX_FILE_FUNCTIONS[@]}"; then
            _filedir
        else
            >&2 echo "Unknown caller: Izaak has probably messed something up"
            return 1
        fi
    }

    # generate completions for a bookmark. It's case insensitive. This completes
    # to a bookmark in serialised form.
    function _apparix_compgen_bm() {
        # first try and find the mark as a prefix
        local target
        target="$1"
        COMPREPLY=()
        while IFS= read -r line; do
            COMPREPLY+=("$(printf "%q" "$line")")
        done< <(
            grep "^j" -- "$APPARIXRC" "$APPARIXEXPAND" | \
                command cut -f2 -d, | command sort | command sed 's/^/,/' | \
                command grep -Fi -- ",$target" | \
                command sed 's/^,//'
            if [[ -n "$1" ]]; then
                command grep "^j" -- "$APPARIXRC" "$APPARIXEXPAND" | \
                    command cut -f2 -d, | command sort | command sed 's/^/,/' | \
                    command grep -Fi -- "$target" | \
                    command grep -Fiv -- ",$target" | \
                    command sed 's/^,//'
            fi
        )
    }

    # complete an apparix tag followed by a file inside that tag's
    # directory
    function _apparix_comp() {
        local tag="${COMP_WORDS[1]}"
        COMPREPLY=()
        if [[ "$COMP_CWORD" == 1 ]]; then
            _apparix_compgen_bm "$tag"
        else
            local cur_file app_dir
            cur_file="${COMP_WORDS[2]}"
            app_dir="$(apparish_newlinesafe "$tag" 2>/dev/null)"
            app_dir="${app_dir%#}"
            if [[ -d "$app_dir" ]]; then
                # can't run in subshell as _apparix_comp_file modifies COMREPLY.
                # Just hope that nothing goes wrong, basically
                silent pushd -- "$app_dir"
                _apparix_comp_file "$1" "$cur_file"
                silent popd
            else
                COMPREPLY=()
            fi
        fi
        return 0
    }

    # register completions
    # nospace prevents bash putting a space after partially completed paths
    # nosort prevents bash from messing up the bespoke order in which bookmarks
    # are completed
    if version_assert 4 4 0; then
        complete -o nospace -o nosort -F _apparix_comp \
            "${APPARIX_FILE_FUNCTIONS[@]}" "${APPARIX_DIR_FUNCTIONS[@]}"
    else
        >&2 echo "(Apparish: Can't disable alphabetic sorting of completions)"
        complete -o nospace -F _apparix_comp \
            "${APPARIX_FILE_FUNCTIONS[@]}" "${APPARIX_DIR_FUNCTIONS[@]}"
    fi

elif [[ -n "$ZSH_VERSION" ]]; then
    # Use zsh's completion system, as this seems a lot more robust, rather
    # than using bashcompinit to reuse the bash code but really this wasn't
    # a hassle to write
    autoload -Uz compinit
    compinit

    # these functions are totally safe because the serialisation system
    # guarantees no newlines in apparixrc.
    function _apparix_file() {
        IFS=$'\n'
        _arguments \
            '1:mark:($(cut -d, -f2 "$APPARIXRC" "$APPARIXEXPAND"))' \
            '2:file:_path_files -W "$(apparish "$words[2]" 2>/dev/null)"'
    }

    function _apparix_directory() {
        IFS=$'\n'
        _arguments \
            '1:mark:($(cut -d, -f2 "$APPARIXRC" "$APPARIXEXPAND"))' \
            '2:file:_path_files -/W "$(apparish "$words[2]" 2>/dev/null)"'
    }

    compdef _apparix_file "${APPARIX_FILE_FUNCTIONS[@]}"
    compdef _apparix_directory "${APPARIX_DIR_FUNCTIONS[@]}"
else
    >&2 echo "Apparish: I don't know how to generate completions"
fi

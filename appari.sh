# shellcheck disable=SC2155,SC2181,SC2016 shell=bash
# vim: ft=sh ts=4 sw=0 sts=-1 et

# ignore errors about:
# - testing $?, because that's useful when you have branches
# - declaring and assigning at the same time because I know what I'm doing
#   (fingers crossed)
# - unexpanded substitutions in single quotes for similar reasons

# Vim modeline to try and keep the indentation in check.

# FIGMENTIZE: apparish
#                                       .__         .__
# _____   ______  ______ _____  _______ |__|  ______|  |__
# \__  \  \____ \ \____ \\__  \ \_  __ \|  | /  ___/|  |  \
#  / __ \_|  |_> >|  |_> >/ __ \_|  | \/|  | \___ \ |   Y  \
# (____  /|   __/ |   __/(____  /|__|   |__|/____  >|___|  /
#      \/ |__|    |__|        \/                 \/      \/

#  bookmarks for the command line with comprehensive tab completion on target
#                                   content
#                             works for bash and zsh
#
#  Quick Guide:
#  -  save this file in $HOME/.bourne-apparish
#  -  issue 'source $HOME/.bourne-apparish'
#  -  issue 'apparix-init'
#  -  go to a directory and issue 'bm foo'
#  -  you can now go to that directory by issuing 'to foo'
#  -  try tab completion and command substitution, see the examples below.
#
#  Apparish is a pure shell implementation of an older system, apparix, written
#  partly in C.  For both systems the bookmarking commands are implemented as
#  shell functions.  The names of these functions are the same between the two
#  implementations and the function definitions are very similar.  The apparix
#  shell functions invoke a C executable. Apparish uses another shell funtion
#  to mimic this C program and apparish provides two additional funcctions,
#  apparix-init and apparix-list. The pivotal commands however are 'bm'
#  (bookmark) and 'to' (go to mark). You can change from apparix to apparish
#  and vice versa, as they use the same resource files.
#
#     apparix-init            initialise apparix (needed only once)
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

# This fork of apparix is not compatible with older Bashes, and relies on you
# having sourced bash-completion

# TODO: allow commas and newlines in directory names
# particular corollary is that amibm and probably some other break quite badly
# in a PWD with a newline, because grep doesn't expect newlines
# TODO: maybe write these as scripts with shebangs, and keep shell functions to
# very hollow wrapper, to prevent the constant checks for bash/zsh and make it
# easier to extend to other shells.

# TODO: replace echo with printf

APPARIXHOME="${APPARIXHOME:=$HOME}"
APPARIXRC="${APPARIXRC:=$APPARIXHOME/.apparixrc}"
APPARIXEXPAND="${APPARIXEXPAND:=$APPARIXHOME/.apparixexpand}"
APPARIXLOG="${APPARIXLOG:=$APPARIXHOME/.apparixlog}"

APPARIX_FILE_FUNCTIONS=( a ae av aget toot apparish ) # Huffman (remove a)
APPARIX_DIR_FUNCTIONS=( to als ald amd todo rme )

# these are some helper functions. With my system they are mostly redundant
# copies of functions I already have defined, but I aim to make this file
# stand-alone.

# sanitise $1 so that it becomes suitable for use with your basic grep
function grepsanitise() {
    sed 's/[].*^$]\|\[/\\&/g' <<< "$1"
}

# similar for find -name
# TODO look up the actual posix dealio
function findsanitise() {
    sed 's/[]*]\|\[/\\&/g' <<< "$1"
}

# vim-like: totally silence the given command, with less of the tedium. doesn't
# affect return status, so can be used inside if statements.
# black magic: "$@" expands to each argument as a separate word.
# gotcha: this won't expand any aliases you have. This is probably preferred
# functionality anyway, though (at least for me)
silent() {
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

function apparix-init() {
    already=""
    if [[ -e "$APPARIXRC" && -e "$APPARIXEXPAND" ]]; then
        already=" already"
    fi
    true >> "$APPARIXRC"
    true >> "$APPARIXEXPAND"
    echo "Apparish is up and running$already"
}

function apparish() {
    if [[ 0 == "$#" ]]; then
        cat -- "$APPARIXRC" "$APPARIXEXPAND" | tr ', ' '\t_' | column -t
        return
    fi
    local mark="$1"
    local list="$(grep -F ",$mark," "$APPARIXRC" "$APPARIXEXPAND")"
    if [[ -z "$list" ]]; then
        >&2 echo "Mark '$mark' not found"
        return 1
    fi
    local target="$( (tail -n 1 | cut -f 3 -d ',') <<< "$list")"
    if [[ 2 == "$#" ]]; then
        echo "$target/$2"
    else
        echo "$target"
    fi
}

function apparix-list() {
    if [[ 0 == "$#" ]]; then
        >&2 echo "Need mark"
        return 1
    fi
    local mark="$1"
    grep -F ",$mark," -- "$APPARIXRC" "$APPARIXEXPAND" | cut -f 3 -d ','
}

function bm() {
    if [[ 0 == "$#" ]]; then
        >&2 echo Need mark
        return 1
    fi
    local mark="$1"
    local list="$(apparix-list "$mark")"
    echo "j,$mark,$PWD" | tee -a -- "$APPARIXLOG" >> "$APPARIXRC"
    if [[ -n "$list" ]]; then
        listsize="$(wc -l <<< "$list")"
        listtail="$(tail -n 2 <<< "$list")"
        ellipsis=""
        if (( listsize > 2 )); then ellipsis="\n(...)"; fi
        if (( listsize > 0 )); then
            echo -e "Bookmark $mark exists" \
                    "($listsize total):$ellipsis\n$listtail"
        fi
        echo "$PWD (added)"
    fi
}

function to() {
    if [[ 2 == "$#" ]]; then
        loc="$(apparish "$1" "$2")"
    elif [[ 1 == "$#" ]]; then
        if [[ "$1" == '-' ]]; then
            loc="-"
        else
            loc="$(apparish "$1")"
        fi
    else
        >&2 echo "Usage: to MARK [SUBDIR1/[SUBDIR2/[etc]]]"
        return 1
    fi
    if [[ "$?" == 0 ]]; then
        cd -- "$loc" || return 1
    fi
}

function portal() {
    echo "e,$PWD" >> "$APPARIXRC"
    portal-expand
}

function portal-expand() {
    local parentdir
    rm -f -- "$APPARIXEXPAND"
    true > "$APPARIXEXPAND"
    grep '^e,' -- "$APPARIXRC" | cut -f 2 -d , | \
        while read -r parentdir; do
            # run in an explicit bash subshell to be able to locally set the
            # right options
            parentdir="$parentdir" APPARIXEXPAND="$APPARIXEXPAND" bash <<EOF
            cd -- "\$parentdir" || return 1
            shopt -s nullglob
            shopt -u dotglob
            shopt -u failglob
            GLOBIGNORE="./:../"
            for _subdir in */ .*/; do
                subdir="\${_subdir%/}"
                echo "j,\$subdir,\$parentdir/\$subdir" >> "\$APPARIXEXPAND"
            done
EOF
        done
}

function whence() {
    if [[ 0 == "$#" ]]; then
        >&2 echo "Need mark"
        return 1
    fi
    local mark="$1"
    select target in $(apparix-list "$mark"); do
        cd -- "$target" || return 1
        break
    done
}

function toot() {
    if [[ 3 == "$#" ]]; then
        file="$(apparish "$1" "$2")/$3"
    elif [[ 2 == "$#" ]]; then
        file="$(apparish "$1")/$2"
    else
        >&2 echo "toot tag dir file OR toot tag file"
        return 1
    fi
    if [[ "$?" == 0 ]]; then
        "${EDITOR:-vim}" "$file"
    fi
}

function todo() {
    toot "$@" TODO
}

function rme() {
    toot "$@" README
}

# apparix listing of directories of mark
function ald() {
    if [[ 2 == "$#" ]]; then
        loc="$(apparish "$1" "$2")"
    elif [[ 1 == "$#" ]]; then
        loc="$(apparish "$1")"
    fi
    if [[ "$?" == 0 ]]; then
        ls -d "$loc"/*
    fi
}

# apparix ls of mark
function als() {
    if [[ 2 == "$#" ]]; then
        loc="$(apparish "$1" "$2")"
    elif [[ 1 == "$#" ]]; then
        loc="$(apparish "$1")"
    fi
    if [[ "$?" == 0 ]]; then
        ls "$loc"
    fi
}

# apparix search bookmark
# TODO: does this still work
function amibm() {
    grep -- ",$(grepsanitise "$PWD")$" "$APPARIXRC" | \
        cut -f 2 -d ',' | paste -s -d ' ' -
}

# apparix search bookmark
function bmgrep() {
    pat="${1?Need a pattern to search}"
    grep -- "$pat" "$APPARIXRC" | cut -f 2,3 -d ',' | tr ',' '\t' | column -t
}

# apparix get; get something from a mark
function aget() {
    if [[ 2 == "$#" ]]; then
        loc="$(apparish "$1" "$2")"
    elif [[ 1 == "$#" ]]; then
        loc="$(apparish "$1")"
    fi
    if [[ "$?" == 0 ]]; then
        cp "$loc" .
    fi
}

# apparix mkdir in mark
function amd() {
    if [[ 2 == "$#" ]]; then
        loc="$(apparish "$1" "$2")"
    elif [[ 1 == "$#" ]]; then
        loc="$(apparish "$1")"
    fi
    if [[ "$?" == 0 ]]; then
        mkdir -p -- "$loc"
    fi
}

# apparix edit of file in mark or subdirectory of mark
function av() {
    if [[ 2 == "$#" ]]; then
        loc="$(apparish "$1" "$2")"
    elif [[ 1 == "$#" ]]; then
        loc="$(apparish "$1")"
    fi
    if [[ "$?" == 0 ]]; then
        view -- "$loc"
    fi
}

# apparix edit of file in mark or subdirectory of mark
function ae() {
    if [[ 2 == "$#" ]]; then
        loc="$(apparish "$1" "$2")"
    elif [[ 1 == "$#" ]]; then
        loc="$(apparish "$1")"
    fi
    if [[ "$?" == 0 ]]; then
        "${EDITOR:-vim}" "$loc"
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
  apparix-init            Use one time after installing apparix
EOH
}

if [[ -n "$BASH_VERSION" ]]; then
    # bash specific helper functions

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

    # define a function to read lines from a file into an array
    # https://github.com/koalaman/shellcheck/wiki/SC2207
    if silent version_assert 4 0 0; then
        function read_array() {
            mapfile -t goedel_array < "$1"
        }
    elif silent version_assert 3 0 0; then
        function read_array() {
            goedel_array=()
            while IFS='' read -r line; do
                goedel_array+=("$line");
            done < "$1"
        }
    else
        >&2 echo "really, bash 2 isn't cool enough to run apparix"
        function read_array() {
            local IFS=$'\n'
            # this is a bad fallback implementation on purpose
            # shellcheck disable=SC2207
            goedel_array=( $(cat -- "$1") )
        }
    fi

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

    # generate completions for a bookmark
    # this is currently case sensitive. Good? Bad? Who knows!
    function _apparix_compgen_bm() {
        cut -f2 -d, -- "$APPARIXRC" "$APPARIXEXPAND" | sort |\
            \grep -i -- "^$(grepsanitise "$1")"
        if [[ -n "$1" ]]; then
            cut -f2 -d, -- "$APPARIXRC" "$APPARIXEXPAND" | sort |\
                \grep -i -- "^..*$(grepsanitise "$1")"
        fi
    }

    # complete an apparix tag followed by a file inside that tag's
    # directory
    function _apparix_comp() {
        local tag="${COMP_WORDS[1]}"
        COMPREPLY=()
        if [[ "$COMP_CWORD" == 1 ]]; then
            read_array <(_apparix_compgen_bm "$tag" | \
                xargs -d $'\n' printf "%q\n")
            COMPREPLY=( "${goedel_array[@]}" )
        else
            local cur_file="${COMP_WORDS[2]}"
            local app_dir="$(apparish "$tag" 2>/dev/null)"
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

    function _apparix_file() {
        _arguments \
          '1:mark:_values "\n" $(cut -d, -f2 "$APPARIXRC" "$APPARIXEXPAND")' \
          '2:file:_path_files -W "$(apparish "$words[2]" 2>/dev/null)"'
    }

    function _apparix_directory() {
        _arguments \
          '1:mark:_values "\n" $(cut -d, -f2 "$APPARIXRC" "$APPARIXEXPAND")' \
          '2:file:_path_files -/W "$(apparish "$words[2]" 2>/dev/null)"'
    }

    compdef _apparix_file "${APPARIX_FILE_FUNCTIONS[@]}"
    compdef _apparix_directory "${APPARIX_DIR_FUNCTIONS[@]}"

else
    >&2 echo "Apparish: I don't know how to generate completions"
fi

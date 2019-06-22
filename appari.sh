# shellcheck disable=SC2016,SC2155,SC1003,SC2120,SC2119 shell=bash
# vim: ts=4 sw=0 sts=-1 et ft=bash

# ignore errors about:
# - unexpanded substitutions in single quotes, because sometimes you need to
#   delay command substitution
# - simultaneous declaration and assignment, because I know what I'm doing
#   (fingers crossed)
# - quoting patterns, because I know better than shellcheck
# - not passing arguments to functions, because that's dumb

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
#  shell functions invoke a C executable. Apparish uses another shell function to
#  mimic this C program and apparish provides two additional functions, and
#  apparix-list. The pivotal commands however are 'bm' (bookmark) and 'to' (go
#  to mark). You can change from apparix to apparish and vice versa, as they use
#  the same resource files.
#
#  For finer-grained control of bookmark removal, Apparix tries to define the
#  alias `via` for your convenience. This opens your $APPARIXRC in your editor
#  of choice (vim by default, obviously), enabling you to delete the offending
#  line(s).
#
#  ---
#     bm TAG                  create bookmark TAG for current directory
#     unbm                    remove the bookmark to CWD
#     unbm TAG                remove any bookmarks named `tag`
#  ---
#     to TAG                  jump to the directory marked TAG
#     to TAG <TAB>            tab-complete on subdirectories of TAG
#     to TAG s<TAB>           tab-complete on subdirectories of TAG starting
#                             with s
#     to TAG foo/<TAB>        tab-complete in subdirectory foo of TAG
#     to TAG foo/bar<TAB>     et cetera et cetera
#
#  --- the commands below allow tab-completion identical to 'to' above.
#     als TAG                 list contents of TAG directory
#     ald TAG                 list subdirectories of TAG directory
#     amd TAG NAME            issue mkdir in TAG directory
#     amd TAG PATH/<TAB>      amd allows tab completion
#     arun TAG PATH COM [...] Run the command COM on the result of getting
#                             PATH from TAG. This is safe on trailing newlines
#                             and such. If you don't want to specify a PATH,
#                             pass an empty argument: ''
#     ae TAG FILE             edit FILE in TAG directory
#     ae TAG FI<TAB>          complete on FI in TAG directory
#     a TAG s<TAB>            echo the location of the TAG directory or
#                             content.
#                             This is useful in command substitution, e.g.
#                             'cp somefile ($a tag src)' - although arun should
#                             be a theoretically safer alternative, if possible.
#
#  --- apparix uses by default the most recent TAG if identical tags exist.
#                It can e.g. be useful to use 'now' as an often-changing tag.
#     apparix-list TAG        list all destinations marked TAG
#     whence TAG              Enter menu to select destination
#
#  --- the functionality below mimics bash CDPATH.
#     portal                  add all subdirectory names as mark
#     portal-expand           refresh the portal subdirectory cache
#     unportal                remove the portal in CWD
#     unportal DIR            remove the portal in DIR
#
#  If you use 'ae', make sure $EDITOR is set to the name of an available editor,
#  or you will be dumped into vim.
#
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
# ensure APPARIXHOME exists
command mkdir -p "$APPARIXHOME"
APPARIXRC="${APPARIXRC:=$APPARIXHOME/.apparixrc}"
APPARIXEXPAND="${APPARIXEXPAND:=$APPARIXHOME/.apparixexpand}"
APPARIXLOG="${APPARIXLOG:=$APPARIXHOME/.apparixlog}"

APPARIX_PLACEHOLDER="${APPARIX_PLACEHOLDER:=__APPARIX_PLACEHOLDER__}"

# ensure set up and log files exist
command touch "$APPARIXRC"
command touch "$APPARIXEXPAND"
command touch "$APPARIXLOG"

# Huffman (remove a in the next line)
APPARIX_FILE_FUNCTIONS=( a ae av aget arun apparish apparish_newlinesafe )
APPARIX_DIR_FUNCTIONS=( to als ald amd todo rme unbm )

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
    # gotcha with the curly braces: you have to put a terminating semicolon for
    # them to be parsed correctly.
    { command cat; command echo -n '#'; } | \
        command sed 's/%/%%/g
                     s/,/%c/g' | \
        command awk 'BEGIN { ORS="%n" } { print $0 }' | \
        command sed 's/#%n$//'
}

# https://stackoverflow.com/questions/723157/how-to-insert-a-newline-in-front-of-a-pattern
# Makes use of the dummy placeholder __APPARIX_PLACEHOLDER__, so please don't
# put that in any of your directories or tags, or if you do, think of a better
# placeholder.
# https://unix.stackexchange.com/questions/17732/where-has-the-trailing-newline-char-gone-from-my-command-substitution
# This adds a trailing character "#" to preserve any trailing newlines you had.
# Remove it with the parameter expansion ${var%#}
function apparix_deserialise() {
    # use perl rather than sed, because sed doesn't reliable handle trailing
    # newlines, or particularly the lack thereof across distributions.
    # BSD sed just bluntly adds a newline at the end.
    # https://stackoverflow.com/questions/13325138/why-does-sed-add-a-new-line-in-osx
    command perl -pe 's/%%/'"$APPARIX_PLACEHOLDER"'/g;
                      s/%c/,/g;
                      s/%n/\'$'\n''/g;
                      s/'"$APPARIX_PLACEHOLDER"'/%/g'
    echo -n '#'
}

# Huffman (remove this paragraph, or just alias "a" yourself)
if ! >/dev/null 2>&1 command -v a; then
    alias a='apparish'
else
    >&2 echo "Apparish: not aliasing a"
fi

if ! >/dev/null 2>&1 command -v via; then
    alias via='"${EDITOR:-vim}" "$APPARIXRC"'
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
    # We need to do this so that zsh acts like bash when doing the parameter
    # expansion "${...%#}".
    [ -n "$ZSH_VERSION" ] && emulate -L bash
    if [ "$#" = 0 ]; then
        >&2 echo "Apparix: need arguments"
        return 1
    else
        local mark="$1"
        local list="$(command grep -F -- "j,$mark," "$APPARIXRC" "$APPARIXEXPAND")"
        if [ -z "$list" ]; then
            >&2 echo "Mark '$mark' not found"
            return 1
        fi
        local target="$(<<< "$list" command tail -n 1 | command cut -f3 -d,)"
        local target="$(printf "%s" "$target" | apparix_deserialise)"
        target="${target%#}"
        if [ "$#" = 2 ]; then
            printf "%s/%s#" "$target" "$2"
        elif [ "$#" = 1 ]; then
            printf "%s#" "$target"
        else
            # do not fail gracefully, to prevent hard to find errors
            >&2 echo "Apparix: too many arguments. Usage: [command] TAG PATH"
            return 1
        fi
    fi
}

# the human-friendly wrapper around apparish_newlinesafe (which means that it
# sacrifices some correctness). Also implements a listing of bookmarks.
function apparish() {
    [ -n "$ZSH_VERSION" ] && emulate -L bash
    if [ "$#" = 0 ]; then
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

# list all instances of bookmarks with some name
function apparix-list() {
    if [ "$#" = 0 ]; then
        >&2 echo "Need mark"
        return 1
    fi
    local mark="$1"
    command grep -F -- ",$mark," "$APPARIXRC" "$APPARIXEXPAND" | \
        command cut -f3 -d,
}

# create one or more bookmarks in CWD. The bookmark is treated as unsafe, and is
# passed through apparix_serialise to make it safe. This means that if you give
# an argument with a newline in, the bookmark that gets created will instead
# have a %n.
function bm() {
    local mark list target
    if [ "$#" = 0 ]; then
        apparish && return 0
    fi
    for arg; do
        if [ -z "$arg" ]; then
            >&2 echo "Bookmarks cannot be empty"
            return 1
        fi
        mark="$(printf "%s" "$arg" | apparix_serialise)"
        list="$(apparix-list "$mark")"
        target="$(printf "%s" "$PWD" | apparix_serialise)"
        echo "j,$mark,$target" | tee -a -- "$APPARIXLOG" >> "$APPARIXRC"
        if [ -n "$list" ]; then
            listsize="$(wc -l <<< "$list")"
            listtail="$(tail -n 2 <<< "$list")"
            ellipsis=""
            if [ "$listsize" -gt 2 ]; then ellipsis="\n(...)"; fi
            if [ "$listsize" -gt 0 ]; then
                echo -e "Bookmark $mark exists" \
                        "($listsize total):$ellipsis\n$listtail"
            fi
            echo "$target (added)"
        fi
    done
}

# indicate differences between $APPARIXRC" and "$APPARIXRC.new", or "$1" and
# "$1.new" if given
function apparix_change() {
    { ! diff "${1:-$APPARIXRC}" "${1:-$APPARIXRC}.new"; } || \
        { >&2 echo "no change"; return 1; }
}

# Remove a bookmark. Given no argument, tries to remove the bookmark in CWD.
# Otherwise, tries to remove the bookmark by name.
function unbm() {
    [ -n "$ZSH_VERSION" ] && emulate -L bash
    local nochange mark target
    if [ -n "$1" ]; then
        mark="$1"
        # This is safe because there are guaranteed to be exactly two commas in each
        # line.
        command grep -v -F "j,$mark," "$APPARIXRC" > "$APPARIXRC.new"
    else
        target="$(printf "%s" "$PWD" | apparix_serialise)"
        # append two slashes to the end in order to match them with a literal
        # grep. Only do this for bookmarks so portal don't get removed.
        command sed 's#^j,.*$#&//#' "$APPARIXRC" | \
            command grep -v -F ",$target//" | \
            command sed 's#//$##' > "$APPARIXRC.new"
    fi
    apparix_change || nochange=true
    command mv "$APPARIXRC.new" "$APPARIXRC"
    [ -n "$nochange" ] && return 1
}

# Remove a portal. Given an argument, it tries to remove the portal in the
# directory by that name. Given no argument, it tries to remove the portal in
# the current directory.
function unportal() {
    [ -n "$ZSH_VERSION" ] && emulate -L bash
    local target nochange
    if [ -n "$1" ]; then
        target="$(realpath "$1")"
    else
        target="$PWD"
    fi
    target="$(printf "%s" "$target" | apparix_serialise)"
    command grep -v -Fx "e,$target" "$APPARIXRC" > "$APPARIXRC.new"
    apparix_change || nochange=true
    command mv "$APPARIXRC.new" "$APPARIXRC"
    portal-expand
    [ -n "$nochange" ] && return 1
}

# Run some command on a subdirectory or subfile of a bookmark.
# The mark and subdirectory come first, followed by the command. Make the
# subdirectory an empty string if you don't want to specify it.
function arun() {
    [ -n "$ZSH_VERSION" ] && emulate -L bash
    local loc
    mark="$1"
    shift
    subdir="$1"
    shift
    if loc="$(apparish_newlinesafe "$mark" "$subdir")"; then
        loc="${loc%#}"
        if [ ! -e "$loc" ]; then
            >&2 echo "warning: '$loc' does not exist"
        fi
        "$@" "$loc"
    else
        return 1
    fi
}

# cd to a mark
function to() {
    arun "$1" "$2" cd
}

function portal() {
    local target
    target="$(printf "%s" "$PWD" | apparix_serialise)"
    echo "e,$target" >> "$APPARIXRC"
    portal-expand
}

function portal-expand() {
    [ -n "$ZSH_VERSION" ] && emulate -L bash
    local parentdir nochange
    true > "$APPARIXEXPAND.new"
    command grep '^e,' -- "$APPARIXRC" | cut -f 2 -d , | \
        while IFS='' read -r parentdir; do
            parentdir="$(printf "%s" "$parentdir" | apparix_deserialise)"
            parentdir="${parentdir%#}"
            # run in an explicit bash subshell to be able to locally set the
            # right options
            export -f apparix_serialise
            parentdir="$parentdir" APPARIXEXPAND="$APPARIXEXPAND" bash -c '
                cd -- "$parentdir" ||
                    { >&2 echo "could not cd to $parentdir"; exit 1; }
                parentdir_ser="$(printf "%s" "$parentdir" | apparix_serialise)"
                parentdir_ser="${parentdir_ser%#}"
                shopt -s nullglob
                shopt -u dotglob
                shopt -u failglob
                GLOBIGNORE="./:../"
                for _subdir in */ .*/; do
                    # can'\''t feasibly use realpath due to the trailing
                    # newlines problem.
                    subdir="${_subdir%/}"
                    subdir="$(printf "%s" "$subdir" | apparix_serialise)"
                    subdir="${subdir%#}"
                    echo "j,$subdir,$parentdir_ser/$subdir" >> "$APPARIXEXPAND.new"
                done'
        done || true
    apparix_change "$APPARIXEXPAND" || nochange=true
    command mv "$APPARIXEXPAND.new" "$APPARIXEXPAND"
    [ -n "$nochange" ] && return 1
}

# Like to, but for when you have conflicting bookmark entries
function whence() {
    [ -n "$ZSH_VERSION" ] && emulate -L bash
    local target
    if [ "$#" = 0 ]; then
        >&2 echo "Need mark"
        return 1
    fi
    local mark="$1"
    select target in $(apparix-list "$mark"); do
        target="$(printf "%s" "$target" | apparix_deserialise)"
        target="${target%#}"
        cd -- "$target" ||
            { >&2 echo "Could not cd to $1"; return 1; }
        break
    done
}

# apparix search if current directory is a bookmark or portal
function amibm() {
    [ -n "$ZSH_VERSION" ] && emulate -L bash
    target="$(printf "%s" "$PWD" | apparix_serialise)"
    {
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
    } | command paste -s -d ' ' - || true
    # always return successfully, even if grep doesn't find anything
}

# apparix search bookmark
function bmgrep() {
    [ -n "$ZSH_VERSION" ] && emulate -L bash
    pat="${1?Need a pattern to search}"
    command grep -i -- "$pat" "$APPARIXRC" | cut -f 2,3 -d ',' | \
        column -t -s,
}

# edit a TODO file
function todo() {
    # make sure to use Bashy expansion for "$@"/TODO
    [ -n "$ZSH_VERSION" ] && emulate -L bash
    ae "$1" "$2"/TODO
}

# edit a README file
function rme() {
    [ -n "$ZSH_VERSION" ] && emulate -L bash
    ae "$1" "$2"/README
}

# apparix listing of directories of mark
function ald() {
    arun "$1" "$2" ls -d
}

# apparix ls of mark
function als() {
    arun "$1" "$2" ls
}

# We need to define this intermediate function so that we move the argument
# order around
function apparix_aget_cp() {
    cp "$1" .
}

# apparix get; get something from a mark
function aget() {
    arun "$1" "$2" apparix_aget_cp
}

# apparix mkdir in mark
function amd() {
    arun "$1" "$2" mkdir -p --
}

# apparix edit of file in mark or subdirectory of mark
function av() {
    arun "$1" "$2" view --
}

# apparix edit of file in mark or subdirectory of mark
function ae() {
    arun "$1" "$2" "${EDITOR:-vim}"
}

# Display usage text
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

if [ -n "$BASH_VERSION" ]; then
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

    # complete sensibly on filenames and directories
    # https://stackoverflow.com/questions/12933362/getting-compgen-to-include...
    # -slashes-on-directories-when-looking-for-files
    function _all_files_compgen() {
        local cur="$1"

        # The outcommented code splits directories and files but then treats
        # them the same. Previously, it used to add a slash for directories, but
        # this makes completing actually harder; Manually adding a slash is a
        # good way of instigating the next level of completion. Anyway, I've
        # kept this around in case people want to change this behaviour. I use
        # comm because old greps have an issue where -v does not treat an empty
        # file with -f correctly.
        # $ comm -3 <(compgen -f -- "$cur" | sort) \
        #           <(compgen -d -- "$cur" | sort) # | sed -e 's/$/ /'
        # Directories (add -S / for slash separator):
        # $ compgen -d -- "$cur"

        compgen -f -- "$cur"
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
    function old_apparix_comp() {
        local caller="$1"
        local cur_file="$2"

        if elemOf "$caller" "${APPARIX_DIR_FUNCTIONS[@]}"; then
            if [ -n "$APPARIX_USE_OLD_COMPLETION" ]; then
                # # Directories (add -S / for slash separator):
                compgen -d -- "$cur_file"
            else
                apparix_compfile "$cur_file" d
            fi
        elif elemOf "$caller" "${APPARIX_FILE_FUNCTIONS[@]}"; then
            # complete on filenames. this is a little harder to do nicely.
            if [ -n "$APPARIX_USE_OLD_COMPLETION" ]; then
                _all_files_compgen "$cur_file"
            else
                apparix_compfile "$cur_file" f
            fi
        else
            >&2 echo "Unknown caller: Izaak has probably messed something up"
            return 1
        fi
    }

    # the existence of this function is a counterexample to Gödel's little known
    # incompletion theorem: there's no such thing as good completion on files in
    # Bash
    function apparix_compfile() {
        local part_esc="$1"
        case "$2" in
            f)
                local find_files=true;;
            d) ;;
            *) >&2 echo "Specify file type"; return 1;;
        esac
        local part_unesc="$(bash -c "printf '%s' $part_esc")"
        local part_dir="$(dirname "$part_unesc")"
        COMPREPLY=()
        # can't pipe to while because that's a subshell and we need to modify
        # COMREPLY.
        while IFS='' read -r -d '' result; do
            # this is a bit of a weird hack because printf "%q\n" with no
            # arguments prints ''. It should be robust, because any actual
            # single quotes will have been escaped by printf.
            if [ "$result" != "''" ]; then
                COMPREPLY+=("$result")
            fi
        # use an explicit bash subshell to set some glob flags.
        done < <(part_dir="$part_dir" part_unesc="$part_unesc" \
                 find_files="$find_files" bash -c '
            shopt -s nullglob
            shopt -s extglob
            shopt -u dotglob
            shopt -u failglob
            GLOBIGNORE="./:../"
            if [ "$part_dir" = "." ]; then
                find_name_prefix="./"
            fi
            # here we delay the %q escaping because I want to strip trailing /s
            if [ -d "$part_unesc" ]; then
                if [[ "$part_unesc" != +(/) ]]; then
                    part_unesc="${part_unesc%%+(/)}"
                fi
                if [ "$find_files" = "true" ]; then
                    printf "%q\0" "$part_unesc"/* "$part_unesc"/*/
                else
                    printf "%q\0" "$part_unesc"/*/
                fi
            else
                if [ "$find_files" = "true" ]; then
                    printf "%q\0" "$part_unesc"*/ "$part_unesc"*
                else
                    printf "%q\0" "$part_unesc"*/
                fi
            fi'
        )
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
            if [ -n "$1" ]; then
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
        if [ "$COMP_CWORD" = 1 ]; then
            _apparix_compgen_bm "$tag"
        else
            local cur_file app_dir
            cur_file="${COMP_WORDS[2]}"
            app_dir="$(apparish_newlinesafe "$tag" 2>/dev/null)"
            app_dir="${app_dir%#}"
            if [ -d "$app_dir" ]; then
                # can't run in subshell as old_apparix_comp modifies COMREPLY.
                # Just hope that nothing goes wrong, basically
                >/dev/null 2>&1 pushd -- "$app_dir" ||
                    { >&2 echo "bad directory: $app_dir"; exit; }
                old_apparix_comp "$1" "$cur_file"
                >/dev/null 2>&1 popd ||
                    { >&2 echo "could not popd"; exit; }
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

elif [ -n "$ZSH_VERSION" ]; then
    # Use zsh's completion system, as this seems a lot more robust, rather
    # than using bashcompinit to reuse the bash code but really this wasn't
    # a hassle to write
    autoload -Uz compinit
    compinit

    # these functions are totally safe because the serialisation system
    # guarantees no newlines in apparixrc.
    function _apparix_file() {
        local IFS=$'\n'
        _arguments \
            '1:mark:($(cut -d, -f2 "$APPARIXRC" "$APPARIXEXPAND"))' \
            '2:file:_path_files -W "$(apparish "$words[2]" 2>/dev/null)"'
    }

    function _apparix_directory() {
        local IFS=$'\n'
        _arguments \
            '1:mark:($(cut -d, -f2 "$APPARIXRC" "$APPARIXEXPAND"))' \
            '2:file:_path_files -/W "$(apparish "$words[2]" 2>/dev/null)"'
    }

    compdef _apparix_file "${APPARIX_FILE_FUNCTIONS[@]}"
    compdef _apparix_directory "${APPARIX_DIR_FUNCTIONS[@]}"
else
    >&2 echo "Apparish: I don't know how to generate completions"
fi

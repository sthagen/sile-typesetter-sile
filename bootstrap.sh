#!/usr/bin/env sh
set -e

incomplete_source () {
    printf '%s\n' \
        "$1. Please either:" \
        "* $2," \
        "* or use the source packages instead of a repo archive" \
        "* or use a full Git clone." >&2
    exit 1
}

# We need a local copy of the libtexpdf library to compile. If this was
# downloaded as a src distribution package this will exist already, but if not
# and we are part of a git repository that the user has not fully initialized,
# go ahead and do the step of fetching the submodule so the compile process can
# run.
if [ ! -f "libtexpdf/configure.ac" ]; then
    if [ -e ".git" ]; then
        git submodule update --init --recursive --remote
    else
        incomplete_source "No libtexpdf sources found" \
            "download and extract a copy yourself"
    fi
fi

# This enables easy building from Github's snapshot archives
if [ ! -e ".git" ]; then
    if [ ! -f ".tarball-version" ]; then
    incomplete_source "No version information found" \
        "identify the correct version with \`echo \$version > .tarball-version\`"
    fi
else
    # Just a head start to save a ./configure cycle
    ./build-aux/git-version-gen .tarball-version > .version
fi

# Autoreconf uses a perl script to inline includes from Makefile.am into
# Makefile.in before ./configure is ever run even once ... which typically
# means AX_AUTOMAKE_MACROS forfeit access to substitutions or conditional logic
# because they enter the picture after those steps. We're intentionally using
# the expanded value of @INC_AMINCLUDE@ directly so the include will be
# inlined. To bootstrap, we must pre-seed an empty file to avoid a 'file not
# found' error on first run. Subsequently running ./configure will generate the
# content based on configure flags and also get re-inlined into Makefile.in.
touch aminclude.am

autoreconf --install

build-aux/decore-automake.sh

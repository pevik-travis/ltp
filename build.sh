#!/bin/sh
# Copyright (c) 2017 Petr Vorel <pvorel@suse.cz>
# Script for travis builds.
#
# TODO: Implement comparison of installed files. List of installed files can
# be used only for local builds as Travis currently doesn't support sharing
# file between jobs, see
# https://github.com/travis-ci/travis-ci/issues/6054

set -e

LTP_PREFIX="${LTP_PREFIX:-$HOME/ltp-install}"

CONFIGURE_OPTS_IN_TREE="--with-open-posix-testsuite --with-realtime-testsuite --prefix=$LTP_PREFIX"

# TODO: open posix testsuite is currently broken in out-tree-build. Enable it once it's fixed.
CONFIGURE_OPTS_OUT_TREE="--with-realtime-testsuite"

MAKE_OPTS="-j$(getconf _NPROCESSORS_ONLN)"

build_32()
{
	echo "===== 32-bit in-tree build into $LTP_PREFIX ====="
	build_in_tree CFLAGS="-m32" CXXFLAGS="-m32" LDFLAGS="-m32"
}

build_native()
{
	echo "===== native in-tree build into $LTP_PREFIX ====="
	build_in_tree
}

build_cross()
{
	local host="${CROSS_COMPILE%-}"
	[ -n "$host" ] || host="${CC%-gcc}"
	[ -n "$host" ] || \
		{ echo "Missing CROSS_COMPILE and CC variables. You need to set at least one" >&2; exit 1; }

	echo "===== cross-compile ${host} in-tree build into $LTP_PREFIX ====="
	build_in_tree "--host=$host" CROSS_COMPILE="${host}-"
}

build_out_tree()
{
	local tree="$PWD"
	local build="$tree/../ltp-build"
	local make_opts="$MAKE_OPTS -C $build -f $tree/Makefile top_srcdir=$tree top_builddir=$build"

	echo "===== native out-of-tree build into $LTP_PREFIX ====="
	mkdir -p $build

	echo "=== autotools ==="
	make autotools

	cd $build
	if ! $tree/configure $CONFIGURE_OPTS; then
		echo "== ERROR: configure failed, config.log =="
		cat config.log
		exit 1
	fi

	echo "== include/config.h =="
	cat include/config.h

	make $make_opts
	make $make_opts DESTDIR="$LTP_PREFIX" SKIP_IDCHECK=1 install
}

build_in_tree()
{
	echo "=== autotools ==="
	make autotools

	echo "=== configure ==="
	if ! ./configure $CONFIGURE_OPTS_IN_TREE $@; then
		echo "== ERROR: configure failed, config.log =="
		cat config.log
		exit 1
	fi

	echo "== include/config.h =="
	cat include/config.h

	echo "=== build ==="
	make $MAKE_OPTS

	echo "=== install ==="
	make $MAKE_OPTS install
}

usage()
{
	cat << EOF
Usage:
$0 [ BUILD_TYPE ]
$0 -h|--help|help

Options:
-h|--help|help  Print this help

BUILD TYPES:
32      32-bit in-tree build
cross   cross-compile in-tree build (requires to set CROSS_COMPILE or CC variable)
native  native in-tree build
out     out-of-tree build

Default build is native in-tree build.

LTP is installed into '$LTP_PREFIX'.
The destination can be changed by setting LTP_PREFIX environment variable.
EOF
}

case "$1" in
	-h|--help|help) usage; exit 0;;
	32) build="build_32";;
	cross) build="build_cross";;
	out) build="build_out_tree";;
	*) build="build_native";;
esac

cd `dirname $0`
$build

# Makefile for setting up SlugOS/OE builds
# based on pieces from MokoMakefile
#
# Copyright (c) 2007  Rod Whitby <rod@whitby.id.au>
# Copyright (c) 2009  Cliff Brake <cbrake@bec-systems.com>
# Copyright (c) 2011  Khem Raj <raj.khem@gmail.com>
#
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# version 2 as published by the Free Software Foundation.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA  02110-1301, USA

# comment out GIT_REV to use the HEAD of a branch
# note, the existence of _REV means we ignore _BRANCH

DEFAULT_DISTRO = slugos
# the following is required because ti-dsplink can't have a
# '.' in the build path
DEFAULT_DISTRO_BUILD_DIR = slugos
DEFAULT_MACHINE = nslu2be

BITBAKE = source ./setup-env && bitbake

all: setup slugos-image

check-eglibc-setup:
	. ./setup-env && \
	(if grep uclibc setup-env; then \
		echo "switching to eglibc ..."; \
		make setup-eglibc; \
	fi)

check-uclibc-setup:
	. ./setup-env && \
	(if ! grep uclibc setup-env; then \
		echo "switching to uclibc ..."; \
		make setup-uclibc; \
	fi)

setup:  setup-env setup-bblayers setup-site setup-auto
	[ -e downloads ] || mkdir downloads
	@[ -e bitbake/bin/bitbake ] || echo "NOTE: must initialize git submodules: make setup-slugos"

setup-slugos: setup
	git submodule init bitbake
	git submodule init openembedded-core
	git submodule init meta-openembedded
	git submodule init meta-slugos
	git submodule init meta-nslu2
	git submodule update

setup-env: 
	echo 'export BBFETCH2=True' > setup-env
	echo 'export OEDIR="'`pwd`'"' >> setup-env
	echo 'export PYTHONPATH="$${OEDIR}/bitbake/lib"' >> setup-env
	echo 'export PATH="$${OEDIR}/openembedded-core/scripts:$${OEDIR}/bitbake/bin:$${PATH}"' >> setup-env
	echo 'export MACHINE=${DEFAULT_MACHINE}' >> setup-env
	echo 'export BB_ENV_EXTRAWHITE="MACHINE DISTRO TCLIBC TCMODE OEDIR OE_GIT_BRANCH BBPATH TOPDIR http_proxy ftp_proxy"' >> setup-env
setup-bblayers: conf/bblayers.conf
conf/bblayers.conf:
	echo '# LAYER_CONF_VERSION is increased each time build/conf/bblayers.conf' > conf/bblayers.conf
	echo '# changes incompatibly' >> conf/bblayers.conf
	echo 'LCONF_VERSION = "1"' >> conf/bblayers.conf
	echo 'TOPDIR := "$${@os.path.dirname(os.path.dirname(d.getVar("FILE", True)))}"' >> conf/bblayers.conf
	echo 'BBPATH = "$${TOPDIR}"' >> conf/bblayers.conf
	echo 'BBFILES = ""' >> conf/bblayers.conf
	echo '# Add your overlay location to BBLAYERS' >> conf/bblayers.conf
	echo '# Make sure to have a conf/layers.conf in there' >> conf/bblayers.conf
	echo 'BBLAYERS = " \' >> conf/bblayers.conf
	echo '  $${TOPDIR}/meta-slugos \' >> conf/bblayers.conf
	echo '  $${TOPDIR}/meta-nslu2 \' >> conf/bblayers.conf
	echo '  $${TOPDIR}/meta-openembedded/meta-oe \' >> conf/bblayers.conf
	echo '  $${TOPDIR}/meta-openembedded/meta-efl \' >> conf/bblayers.conf
	echo '  $${TOPDIR}/meta-openembedded/meta-gpe \' >> conf/bblayers.conf
	echo '  $${TOPDIR}/meta-openembedded/meta-gnome \' >> conf/bblayers.conf
	echo '  $${TOPDIR}/openembedded-core/meta \' >> conf/bblayers.conf
	echo '"' >> conf/bblayers.conf

setup-site: conf/site.conf
conf/site.conf:
	echo '# Where to store sources' > conf/site.conf
	echo 'DL_DIR = "$${OEDIR}/downloads"' >> conf/site.conf
	echo '# Where to save shared state' >> conf/site.conf
	echo 'SSTATE_DIR = "$${OEDIR}/build/sstate-cache"' >> conf/site.conf
	echo '# Which files do we want to parse:' >> conf/site.conf
	echo 'BBFILES ?= "$${OEDIR}/openembedded-core/meta/recipes-*/*/*.bb"' >> conf/site.conf
	echo 'TMPDIR = "$${OEDIR}/build/tmp-slugos"' >> conf/site.conf
	echo '# Go through the Firewall' >> conf/site.conf
	echo '#HTTP_PROXY        = "http://${PROXYHOST}:${PROXYPORT}/"' >> conf/site.conf

setup-auto: conf/auto.conf
conf/auto.conf:
	echo 'MACHINE ?= "${MACHINE}"'> conf/auto.conf

setup-default-machine:
	. ./setup-env && ([ -e $${TOPDIR}/conf/auto.conf ] || make setup-machine-${DEFAULT_MACHINE} )

.PHONY: setup-machine-%
setup-machine-%:
	sed -i -e 's/^export MACHINE.*/export MACHINE=\"$*\"/' setup-env

.PHONY: setup-machine-%
setup-distro-%:
	. ./setup-env && sed -i -e 's/export TOPDIR.*/export TOPDIR=\"$${OEDIR}\/build\/$*\"/' setup-env

.PHONY: setup-uclibc
setup-uclibc:
	sed -i -e 's/^TCLIBC.*//' setup-env && \:
	echo 'export TCLIBC="uclibc"' >> setup-env

.PHONY: setup-eglibc
setup-eglibc:
	sed -i -e 's/^export TCLIBC.*//' setup-env

.PHONY: print-setup
print-setup:
	. ./setup-env && echo $${TOPDIR} && cat $${TOPDIR}/conf/auto.conf && cat $${TOPDIR}/conf/local.conf

.PHONY: update
update:
	git pull
	git submodule foreach --recursive git submodule update

.PHONY: bitbake-%
bitbake-%: setup-env
	${BITBAKE} $*

.PHONY: %-image
%-image: setup-env
	${BITBAKE} $*-image

.PHONY: devshell-%
devshell-%: setup-env
	${BITBAKE} $* -c devshell

# run the following target if you want to clean the OE tmp directory where things are built
.PHONY: clean
clean: setup-env
	. ./setup-env && pushd $${TOPDIR} && rm -rf tmp && popd

# run the following target if you want to completely reset your build and download
# new OE/bitbake sources
.PHONY: clobber
clobber: clean
	rm -rf bitbake
	rm -rf openembedded-core
	rm -rf meta-openembedded
	rm -rf meta-slugos
	rm -rf meta-nslu2
	rm setup-env

PWD := $(shell pwd)
MACHINE := $(shell source ./setup-env && echo $${MACHINE})
DEPLOY := ${PWD}/build/${DEFAULT_DISTRO_BUILD_DIR}/tmp/deploy/glibc/images/${MACHINE}

nslu2-install-boot:
	echo MACHINE = ${MACHINE}
	rm -rf /media/boot/*
	cp ${DEPLOY}/uImage-${MACHINE}.bin /media/boot/zImage

nslu-install-%-rootfs:
	rm -rf /media/*
	cd /media/; tar xvzf ${DEPLOY}/$*-${MACHINE}.tar.gz
	sync


%target GNUmakefile
#
# InspIRCd -- Internet Relay Chat Daemon
#
#   Copyright (C) 2018 Puck Meerburg <puck@puckipedia.com>
#   Copyright (C) 2012-2022 Sadie Powell <sadie@witchery.services>
#   Copyright (C) 2012, 2015-2016 Attila Molnar <attilamolnar@hush.com>
#   Copyright (C) 2012 Robby <robby@chatbelgie.be>
#   Copyright (C) 2012 Christoph Egger <christoph@debian.org>
#   Copyright (C) 2012 ChrisTX <xpipe@hotmail.de>
#   Copyright (C) 2010 Dennis Friis <peavey@inspircd.org>
#   Copyright (C) 2009-2010 Daniel De Graaf <danieldg@inspircd.org>
#   Copyright (C) 2007 Robin Burchell <robin+git@viroteck.net>
#   Copyright (C) 2005-2007 Craig Edwards <brain@inspircd.org>
#   Copyright (C) 2005 Craig McLure <craig@frostycoolslug.com>
#
# This file is part of InspIRCd.  InspIRCd is free software: you can
# redistribute it and/or modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation, version 2.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#


#
#               InspIRCd Main Makefile
#
# This file is automagically generated by configure, from
# make/template/main.mk. Any changes made to the generated
#     files will go away whenever it is regenerated!
#
# Please do not edit unless you know what you're doing.
#


CXX = @CXX@ -std=c++17
COMPILER = @COMPILER_NAME@
SYSTEM = @SYSTEM_NAME@
SOURCEPATH = @SOURCE_DIR@
BUILDPATH ?= $(SOURCEPATH)/build/@COMPILER_NAME@-@COMPILER_VERSION@
SOCKETENGINE = @SOCKETENGINE@
CORECXXFLAGS = -fPIC -fvisibility=hidden -fvisibility-inlines-hidden -pipe -I"$(SOURCEPATH)/include" -isystem "$(SOURCEPATH)/vendor" -Wall -Wextra -Wfatal-errors -Woverloaded-virtual -Wpedantic -Wno-format-nonliteral -Wno-unused-parameter -DFMT_SHARED
LDLIBS = @COMPILER_EXTRA_LDLIBS@
CORELDFLAGS = -fPIE -L.
PICLDFLAGS  = -fPIC -shared

DESTDIR := $(if $(DESTDIR),$(DESTDIR),"@DESTDIR|@")
BINPATH = "$(DESTDIR)@BINARY_DIR@"
CONPATH = "$(DESTDIR)@CONFIG_DIR@"
DATPATH = "$(DESTDIR)@DATA_DIR@"
EXAPATH = "$(DESTDIR)@EXAMPLE_DIR@"
LOGPATH = "$(DESTDIR)@LOG_DIR@"
MANPATH = "$(DESTDIR)@MANUAL_DIR@"
MODPATH = "$(DESTDIR)@MODULE_DIR@"
RUNPATH = "$(DESTDIR)@RUNTIME_DIR@"
SCRPATH = "$(DESTDIR)@SCRIPT_DIR@"

INSTALL      ?= install
INSTMODE_DIR ?= 0755
INSTMODE_BIN ?= 0755
INSTMODE_TXT ?= 0644
INSTMODE_PRV ?= 0640

# Use the native shared library file extension for modules.
ifeq ($(SYSTEM), darwin)
  DLLEXT = "dylib"
else
  DLLEXT = "so"
endif

# Only set the ownership of installed files when --disable-ownership
# was not passed to configure.
DISABLE_OWNERSHIP=@DISABLE_OWNERSHIP@
ifeq ($(DISABLE_OWNERSHIP), 1)
  INSTFLAGS =
else
  INSTFLAGS = -g @GID@ -o @UID@
endif

# Force the use of libc++ on macOS as on some systems it is not the
# default and this breaks modern C++ support.
ifeq ($(COMPILER), AppleClang)
  CXX += -stdlib=libc++
endif

# Enable Clang-specific compiler warnings.
ifeq ($(COMPILER), $(filter $(COMPILER), AppleClang IntelClang Clang))
  CORECXXFLAGS += -Wshadow-all -Wshorten-64-to-32
endif

# Enable GCC-specific compiler warnings.
ifeq ($(COMPILER), GCC)
  CORECXXFLAGS += -Wshadow
endif

# The libc++ and libstdc++ <thread> implementation still requires
# manually linking against pthreads on all systems other than macOS
# and Haiku where pthreads are linked by default as part of libSystem
# and libroot respectively.
ifneq ($(SYSTEM), $(filter $(SYSTEM), darwin haiku))
  LDLIBS += -pthread
endif

# On these systems we need libdl for loading modules.
ifeq ($(SYSTEM), $(filter $(SYSTEM), gnu linux))
	LDLIBS += -ldl
endif

# On these systems we need librt for clock_gettime.
ifeq ($(SYSTEM), $(filter $(SYSTEM), gnu linux solaris))
	LDLIBS += -lrt
endif

# On Haiku we need _BSD_SOURCE for common BSD extensions and
# libnetwork for creating sockets.
ifeq ($(SYSTEM), haiku)
  CORECXXFLAGS += -D_BSD_SOURCE
  LDLIBS += -lnetwork
endif

# On Solaris and derivatives we need libsocket for creating sockets.
ifeq ($(SYSTEM), solaris)
  LDLIBS += -lsocket
endif

# On macOS this option is named different and on Haiku the linker
# only supports dynamic libraries so this is implied.
ifneq ($(SYSTEM), $(filter $(SYSTEM), darwin haiku))
  CORELDFLAGS += -rdynamic
  PICLDFLAGS  += -rdynamic
endif

# On macOS we need to give the linker these flags so the libraries it
# generates act like they do on other UNIX-like systems.
ifeq ($(SYSTEM), darwin)
  CORELDFLAGS += -bind_at_load -dynamic
  PICLDFLAGS  += -twolevel_namespace -undefined dynamic_lookup
endif

ifndef INSPIRCD_DEBUG
  INSPIRCD_DEBUG=0
endif

DBGOK=0
ifeq ($(INSPIRCD_DEBUG), 0)
  CORECXXFLAGS += -fno-rtti -O2
ifeq ($(COMPILER), GCC)
    CORECXXFLAGS += -g1
endif
  HEADER = std-header
  DBGOK=1
endif
ifeq ($(INSPIRCD_DEBUG), 1)
  CORECXXFLAGS += -O0 -g3 -Werror -DINSPIRCD_ENABLE_RTTI
  HEADER = debug-header
  DBGOK=1
endif
ifeq ($(INSPIRCD_DEBUG), 2)
  CORECXXFLAGS += -fno-rtti -O2 -g3
  HEADER = debug-header
  DBGOK=1
endif
ifeq ($(INSPIRCD_DEBUG), 3)
  CORECXXFLAGS += -fno-rtti -O0 -g0 -Werror
  HEADER = std-header
  DBGOK=1
endif

MAKEFLAGS += --no-print-directory

ifndef INSPIRCD_VERBOSE
  MAKEFLAGS += --silent
endif

# Append any flags set in the environment after the base flags so
# that they can be overridden if necessary.
CORECXXFLAGS += $(CPPFLAGS) $(CXXFLAGS)
CORELDFLAGS += $(LDFLAGS)
PICLDFLAGS += $(LDFLAGS)

export BUILDPATH
export CORECXXFLAGS
export CORELDFLAGS
export CXX
export INSPIRCD_VERBOSE
export LDLIBS
export PICLDFLAGS
export SOCKETENGINE
export SOURCEPATH

# Default target
TARGET = all

ifdef INSPIRCD_TARGET
    HEADER = mod-header
    TARGET = $(INSPIRCD_TARGET)
endif

ifeq ($(DBGOK), 0)
  HEADER = unknown-debug-level
endif

all: finishmessage

target: $(HEADER)
	$(MAKEENV) perl make/calcdep.pl
	cd "$(BUILDPATH)"; $(MAKEENV) $(MAKE) -f real.mk $(TARGET)

debug:
	@${MAKE} INSPIRCD_DEBUG=1 all

debug-header:
	@echo "*************************************"
	@echo "*    BUILDING WITH DEBUG SYMBOLS    *"
	@echo "*                                   *"
	@echo "*   This will take a *long* time.   *"
	@echo "*  Please be aware that this build  *"
	@echo "*  will consume a very large amount *"
	@echo "*  of disk space (~350MB), and may  *"
	@echo "*  run slower. Use the debug build  *"
	@echo "*  for module development or if you *"
	@echo "*    are experiencing problems.     *"
	@echo "*                                   *"
	@echo "*************************************"

mod-header:
	@echo 'Building specific targets:'

std-header:
	@echo "*************************************"
	@echo "*       BUILDING INSPIRCD           *"
	@echo "*                                   *"
	@echo "*   This will take a *long* time.   *"
	@echo "*     Why not read our docs at      *"
	@echo "*     https://docs.inspircd.org     *"
	@echo "*  while you wait for Make to run?  *"
	@echo "*************************************"

finishmessage: target
	@echo ""
	@echo "*************************************"
	@echo "*        BUILD COMPLETE!            *"
	@echo "*                                   *"
	@echo "*   To install InspIRCd, type:      *"
	@echo "*        'make install'             *"
	@echo "*************************************"

install: target
	@-$(INSTALL) -d $(INSTFLAGS) -m $(INSTMODE_DIR) $(BINPATH)
	@-$(INSTALL) -d $(INSTFLAGS) -m $(INSTMODE_DIR) $(CONPATH)
	@-$(INSTALL) -d $(INSTFLAGS) -m $(INSTMODE_DIR) $(DATPATH)
	@-$(INSTALL) -d $(INSTFLAGS) -m $(INSTMODE_DIR) $(EXAPATH)/codepages
	@-$(INSTALL) -d $(INSTFLAGS) -m $(INSTMODE_DIR) $(EXAPATH)/providers
	@-$(INSTALL) -d $(INSTFLAGS) -m $(INSTMODE_DIR) $(EXAPATH)/services
	@-$(INSTALL) -d $(INSTFLAGS) -m $(INSTMODE_DIR) $(EXAPATH)/sql/log_sql
	@-$(INSTALL) -d $(INSTFLAGS) -m $(INSTMODE_DIR) $(EXAPATH)/sql/sqloper
	@-$(INSTALL) -d $(INSTFLAGS) -m $(INSTMODE_DIR) $(LOGPATH)
	@-$(INSTALL) -d $(INSTFLAGS) -m $(INSTMODE_DIR) $(MANPATH)
	@-$(INSTALL) -d $(INSTFLAGS) -m $(INSTMODE_DIR) $(MODPATH)
	@-$(INSTALL) -d $(INSTFLAGS) -m $(INSTMODE_DIR) $(RUNPATH)
	@-$(INSTALL) -d $(INSTFLAGS) -m $(INSTMODE_DIR) $(SCRPATH)
	-$(INSTALL) $(INSTFLAGS) -m $(INSTMODE_BIN) "$(BUILDPATH)/bin/inspircd" $(BINPATH)
	-$(INSTALL) $(INSTFLAGS) -m $(INSTMODE_BIN) "$(BUILDPATH)/modules/"*.$(DLLEXT) $(MODPATH)
	-$(INSTALL) $(INSTFLAGS) -m $(INSTMODE_BIN) @CONFIGURE_DIRECTORY@/inspircd $(SCRPATH) 2>/dev/null
	-$(INSTALL) $(INSTFLAGS) -m $(INSTMODE_TXT) @CONFIGURE_DIRECTORY@/apparmor $(SCRPATH) 2>/dev/null
	-$(INSTALL) $(INSTFLAGS) -m $(INSTMODE_TXT) @CONFIGURE_DIRECTORY@/logrotate $(SCRPATH) 2>/dev/null
ifeq ($(SYSTEM), darwin)
	-$(INSTALL) $(INSTFLAGS) -m $(INSTMODE_BIN) @CONFIGURE_DIRECTORY@/org.inspircd.plist $(SCRPATH) 2>/dev/null
endif
ifeq ($(SYSTEM), linux)
	-$(INSTALL) $(INSTFLAGS) -m $(INSTMODE_TXT) @CONFIGURE_DIRECTORY@/inspircd.service $(SCRPATH) 2>/dev/null
endif
	-$(INSTALL) $(INSTFLAGS) -m $(INSTMODE_TXT) @CONFIGURE_DIRECTORY@/inspircd.1 $(MANPATH) 2>/dev/null
	-$(INSTALL) $(INSTFLAGS) -m $(INSTMODE_TXT) @CONFIGURE_DIRECTORY@/inspircd-testssl.1 $(MANPATH) 2>/dev/null
	-$(INSTALL) $(INSTFLAGS) -m $(INSTMODE_BIN) tools/testssl $(BINPATH)/inspircd-testssl 2>/dev/null
	-$(INSTALL) $(INSTFLAGS) -m $(INSTMODE_TXT) docs/conf/*.example $(EXAPATH)
	-$(INSTALL) $(INSTFLAGS) -m $(INSTMODE_TXT) docs/conf/codepages/*.example $(EXAPATH)/codepages
	-$(INSTALL) $(INSTFLAGS) -m $(INSTMODE_TXT) docs/conf/providers/*.example $(EXAPATH)/providers
	-$(INSTALL) $(INSTFLAGS) -m $(INSTMODE_TXT) docs/conf/services/*.example $(EXAPATH)/services
	-$(INSTALL) $(INSTFLAGS) -m $(INSTMODE_TXT) docs/sql/log_sql/*.sql $(EXAPATH)/sql/log_sql
	-$(INSTALL) $(INSTFLAGS) -m $(INSTMODE_TXT) docs/sql/sqloper/*.sql $(EXAPATH)/sql/sqloper
	-$(INSTALL) $(INSTFLAGS) -m $(INSTMODE_TXT) @CONFIGURE_DIRECTORY@/help.txt $(CONPATH)
	@echo ""
	@echo "*************************************"
	@echo "*        INSTALL COMPLETE!          *"
	@echo "*************************************"
	@echo 'Paths:'
	@echo '  Configuration:' $(CONPATH)
	@echo '  Binaries:' $(BINPATH)
	@echo '  Modules:' $(MODPATH)
	@echo '  Data:' $(DATPATH)
	@echo 'To start the ircd, run:' $(SCRPATH)/inspircd start
	@echo 'Remember to create your config file:' $(CONPATH)/inspircd.conf
	@echo 'Examples are available at:' $(EXAPATH)

GNUmakefile: make/template/main.mk src/version.sh configure @CONFIGURE_CACHE_FILE@
	./configure --update

clean:
	@echo Cleaning...
	-rm -f "$(BUILDPATH)/bin/inspircd" "$(BUILDPATH)/include" "$(BUILDPATH)/real.mk"
	-rm -rf "$(BUILDPATH)/obj" "$(BUILDPATH)/modules"
	@-rmdir "$(BUILDPATH)/bin" 2>/dev/null
	@-rmdir "$(BUILDPATH)" 2>/dev/null
	@echo Completed.

deinstall:
	-rm -f $(BINPATH)/inspircd
	-rm -f $(BINPATH)/inspircd-testssl
	-rm -f $(CONPATH)/help.txt
	-rm -f $(EXAPATH)/*.example
	-rm -f $(EXAPATH)/codepages/*.example
	-rm -f $(EXAPATH)/providers/*.example
	-rm -f $(EXAPATH)/services/*.example
	-rm -f $(EXAPATH)/sql/*.sql
	-rm -f $(MANPATH)/inspircd-testssl.1
	-rm -f $(MANPATH)/inspircd.1
	-rm -f $(MODPATH)/core_*.$(DLLEXT)
	-rm -f $(MODPATH)/m_*.$(DLLEXT)
	-rm -f $(SCRPATH)/apparmor
	-rm -f $(SCRPATH)/inspircd
	-rm -f $(SCRPATH)/inspircd.service
	-rm -f $(SCRPATH)/logrotate
	-rm -f $(SCRPATH)/org.inspircd.plist
	-[ -d $(BINPATH) ] && find $(BINPATH) -type d -empty -delete
	-[ -d $(CONPATH) ] && find $(CONPATH) -type d -empty -delete
	-[ -d $(DATPATH) ] && find $(DATPATH) -type d -empty -delete
	-[ -d $(EXAPATH) ] && find $(EXAPATH) -type d -empty -delete
	-[ -d $(LOGPATH) ] && find $(LOGPATH) -type d -empty -delete
	-[ -d $(MANPATH) ] && find $(MANPATH) -type d -empty -delete
	-[ -d $(MODPATH) ] && find $(MODPATH) -type d -empty -delete
	-[ -d $(RUNPATH) ] && find $(RUNPATH) -type d -empty -delete
	-[ -d $(SCRPATH) ] && find $(SCRPATH) -type d -empty -delete

configureclean:
	-rm -f GNUmakefile
	-rm -f include/config.h
	-rm -rf @CONFIGURE_DIRECTORY@

distclean: clean configureclean
	-rm -rf "$(SOURCEPATH)/run"
	-find "$(SOURCEPATH)/src/modules" -type l -delete

help:
	@echo 'InspIRCd Makefile'
	@echo ''
	@echo 'Use: ${MAKE} [flags] [targets]'
	@echo ''
	@echo 'Flags:'
	@echo ' INSPIRCD_VERBOSE=1  Show the full command being executed instead of "BUILD: dns.cpp"'
	@echo ' INSPIRCD_DEBUG=1    Enable debug build, for module development or crash tracing'
	@echo ' INSPIRCD_DEBUG=2    Enable debug build with optimizations, for detailed backtraces'
	@echo ' INSPIRCD_DEBUG=3    Enable fast build with no optimisations or symbols (only for CI)'
	@echo ' DESTDIR=            Specify a destination root directory (for tarball creation)'
	@echo ' -j <N>              Run a parallel build using N jobs'
	@echo ''
	@echo 'Targets:'
	@echo ' all       Complete build of InspIRCd, without installing (default)'
	@echo ' install   Build and install InspIRCd to the directory chosen in ./configure'
	@echo ' debug     Compile a debug build. Equivalent to "make D=1 all"'
	@echo ''
	@echo ' INSPIRCD_TARGET=target  Builds a user-specified target, such as "inspircd" or "core_dns"'
	@echo '                         Multiple targets may be separated by a space'
	@echo ''
	@echo ' clean     Cleans object files produced by the compile'
	@echo ' distclean Cleans all generated files (build, configure, run, etc)'
	@echo ' deinstall Removes the files created by "make install"'
	@echo

.NOTPARALLEL:

.PHONY: all target debug debug-header mod-header mod-footer std-header finishmessage install clean deinstall configureclean help

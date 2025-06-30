.PHONY: all deps clean

PERL        := perl
LOCAL_LIB   := $(CURDIR)/local
PERL5LIB    := $(LOCAL_LIB)/lib/perl5
CPANM       := $(LOCAL_LIB)/bin/cpanm
PP          := $(LOCAL_LIB)/bin/pp
APP_PL      := gerrit.pl
APP_EXE     := build/gerrit

export PERL5LIB
export PERL_LOCAL_LIB_ROOT=$(LOCAL_LIB)
export PERL_MB_OPT=--install_base $(LOCAL_LIB)
export PERL_MM_OPT=INSTALL_BASE=$(LOCAL_LIB)
export PATH := $(LOCAL_LIB)/bin:$(PATH)

all: $(APP_EXE)

$(CPANM):
	$(PERL) -Mlocal::lib=$(LOCAL_LIB) -MCPAN -e 'CPAN::Shell->install("App::cpanminus")'

deps: $(CPANM)
	$(CPANM) --local-lib=$(LOCAL_LIB) --installdeps .
	$(CPANM) --local-lib=$(LOCAL_LIB) PAR::Packer

$(APP_EXE): deps $(APP_PL)
	mkdir -p build
	$(PP) -x -o $(APP_EXE) $(APP_PL)

clean:
	rm -rf build local


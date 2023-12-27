NPROC=4
YACC=u yacc
LEX=u lex
SOURCES=grap_draw.cc grap_pic.cc grap_parse.cc grap_tokenizer.cc
TARGETS=${SOURCES:%.cc=%.o} grap_lex.o grap.o
CXX=clang++
CXXFLAGS=-O2 -Wall -std=c++0x
PREFIX=/usr/local
DEFS=-DHAVE_CONFIG_H -DHAVE_SNPRINTF -DHAVE_UNISTD_H

all:V: grap grap.1

clean:V:
    rm -f $TARGETS
    rm -f grap

install:V: all
	install grap $PREFIX/bin
	install grap.1 $PREFIX/share/man/man1/grap.1
	mkdir -p $PREFIX/etc/grap
	cp grap.defines grap.tex.defines $PREFIX/etc/grap/

%.o: %.cc config.h y.tab.h
	$CXX $CXXFLAGS $DEFS -c $stem.cc

grap_lex.cc: grap_lex.ll
	$LEX -o $target $prereq

y.tab.c y.tab.h: grap.yy
	$YACC -d $prereq

grap.cc: y.tab.c
	cp $prereq $target

config.h:
	sh ./buildconfig.sh > $target

grap: $TARGETS
	$CXX -o $target $prereq

grap.1: grap.doc
	mandoc -T man $prereq > $target

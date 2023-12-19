NPROC=4
YACC=u yacc
LEX=u lex
TARGET=grap_draw.o grap_pic.o grap_parse.o
SOURCES=grap_draw.cc grap_pic.cc grap_parse.cc grap_tokenizer.cc
CXX=clang++
CXXFLAGS=-O2 -Wall -Wno-deprecated-declarations -std=c++0x
PREFIX=/usr/local
DEFS=-DHAVE_CONFIG_H -DHAVE_SNPRINTF -DHAVE_UNISTD_H

all:V: grap

install:V: grap
	install grap $PREFIX/bin
	install grap.doc $PREFIX/share/man/man1/grap.1
	mkdir -p $PREFIX/etc/grap
	cp grap.defines grap.tex.defines $PREFIX/etc/grap/

%.o: %.cc config.h
	$CXX $CXXFLAGS $DEFS -c $stem.cc

grap_lex.cc: grap_lex.ll
	$LEX -o $target $prereq

y.tab.c: grap.yy
	$YACC $prereq

grap.cc: y.tab.c
	cp $prereq $target

config.h:
	sh ./buildconfig.sh > $target

grap: ${SOURCES:%.cc=%.o} grap_lex.o grap.o
	$CXX -o $target $prereq

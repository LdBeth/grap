#!/bin/dash
PREFIX=/usr/local
echo "#define DEFINES \"${PREFIX}/etc/grap/grap.defines\""
echo '#define PACKAGE_VERSION "1.46"'
echo "#define OS_VERSION \"$(uname -mrs)\""
echo '#define PACKAGE_BUGREPORT "ldbeth@sdf.org"'

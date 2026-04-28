# -*- Makefile -*-
# Copyright 2010-2011, Georgia Institute of Technology, USA.
# See COPYING for license.
CC = gcc -flto -fwhole-program
CFLAGS = -g -std=c99 -Wall -O3 -march=native
LDLIBS = -lm -lrt

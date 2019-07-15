
# Project:	FPGA-DNA-Sequence-Search

# Created by Oliver Knodel on 12.07.10.


# MIT License

# Copyright (c) 2019 Oliver Knodel

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE. 
 

OBJS   := main.o ethernet.o formatdb.o gettime.o
LIBS   := -lconfig -lpthread
CFLAGS := -Wall -O3

# Targets
.PHONY: all
all: main

# Top-Level Linkage
main: $(OBJS)
	g++ $(CFLAGS) -o$@ $+ $(LIBS)

# Additional Dependencies
main.o: header/align.h  header/ethernet.h  header/formatdb.h  header/gettime.h
ethernet.o: header/gettime.h
formatdb.o: header/gettime.h header/align.h
formatdb.o: CFLAGS += -D_LARGEFILE64_SOURCE

%.o: %.c
	gcc $(CFLAGS) -c -o$@ $<
%.o: %.cpp
	g++ $(CFLAGS) -c -o$@ $<

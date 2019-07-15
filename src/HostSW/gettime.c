/*
    gettime.c
    Project:	FPGA-DNA-Sequence-Search

 	Created by Oliver Knodel on 12.07.10.
 
	Description:
    Wrapper for gettimeofday-function


 	MIT License
 
	Copyright (c) 2019 Oliver Knodel

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE. 
 */

#include <time.h>
#include <sys/time.h>
#include <stdio.h>
#include <sys/types.h>
#include <unistd.h>

struct timeval starttime, endtime, helptime;
struct timezone tz;
double runtime;
int durchlauf;
int tag = 24*60*60;
FILE *datei;

void openfile() {
	datei = fopen("time.txt", "w");
	durchlauf = 10;
}

void writefile() {
	fprintf(datei, "%d %f\n", durchlauf, runtime);
	durchlauf = durchlauf + 5;
}

void closefile() {
	fclose(datei);
}

void setstart(){
	gettimeofday(&starttime, NULL);
}

double setend() {
	gettimeofday(&endtime, NULL);
	if (starttime.tv_usec >  endtime.tv_usec) {
		runtime = ((endtime.tv_sec - starttime.tv_sec) + (starttime.tv_usec - endtime.tv_usec));
	} else {
		runtime = ((endtime.tv_sec - starttime.tv_sec) + (endtime.tv_usec - starttime.tv_usec));
	}
	runtime = runtime * 1e-6;//second
	return runtime;
}

double printtime() {
	printf("time: %f s\n", runtime);
	return runtime;
}

double gettime(double time0) {
	gettimeofday(&starttime,&tz);
 	starttime.tv_sec %=  tag;
	return ((double)starttime.tv_sec+(double)starttime.tv_usec * 1e-6 - time0);
}

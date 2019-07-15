/*
    formatdb.c
    Project:	FPGA-DNA-Sequence-Search

 	Created by Oliver Knodel on 12.07.10.

	Description:
    Initialization of independent transmitter and receiver interfaces
    for parallel send and receive.
 

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
**Project : FPGA -
	DNA - Sequence - Search **Created by Oliver Knodel on 12.07.10. * Copyright 2010 Technische Universitaet Dresden.All rights reserved.**Description : *Transforms the original ASCI - characters to binary Symbols ******************************************************************************* /

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include "header/align.h"
#include "header/gettime.h"

#define LABEL 200

																																															 /*
 * Transforms nucleotide-database in a binary database
 * and creates index with positions from the different
 * sequences in the databas
 *
 *pos.->		1		2		3		4
 * A -> 00		0x00	0x00	0x00	0x00
 * G -> 01		0x40	0x10	0x04	0x01
 * T -> 10		0x80	0x20	0x08	0x02
 * C -> 11		0xC0	0x30	0x0C	0x03
 */

																																															 char nucA[4] = {0x00, 0x00, 0x00, 0x00};
char nucG[4] = {0x40, 0x10, 0x04, 0x01};
char nucT[4] = {0x80, 0x20, 0x08, 0x02};
char nucC[4] = {0xC0, 0x30, 0x0C, 0x03};


/*
 * Transformation for the database
 */
int transformdb(char *databasename, char *bindbname, char *infodbname) {
	double seqlength = 0, dblength = 0;
	double dbsequences = 0;
	double dbcharcount = 0;

	unsigned int i = 0;
	char line[150];
	char dbchar, binchar;
	double time0, time1;
	long int bppos;

	FILE *db, *bindb, *infodb;

	printf("\n--- Starting Database Transformation for %s ---\n", databasename);

	db = fopen64(databasename, "rb");
	if (db == NULL) {
		fprintf(stderr, "\nError: can not open File %s\n", databasename);
		return -1;
	}

	bindb = fopen64(bindbname, "wb");
	if (bindb == NULL) {
		fprintf(stderr, "\nError: can not create File %s\n", bindbname);
		return -1;
	}

	infodb = fopen(infodbname, "wb");
	if (infodb == NULL) {
		fprintf(stderr, "\nError: can not create File %s\n", infodbname);
		return -1;
	}

	time0 = gettime(0);

	fprintf(infodb, "# %10.0f\n", 0.0);
	bppos = ftell(infodb);

	i = 0;
	binchar = 0x00;
	while (((dbchar = getc(db)) != EOF)) {
	  if(dbchar < 'A') {
		if (dbchar == '>') {
			if(i != 0){ //Always end of sequence in last char
				fwrite(&binchar, sizeof(binchar), 1, bindb);
				i = 0;
				dbcharcount++;
			}
			fprintf(infodb, "# %10.0f\n\n", dbcharcount); //number of chars
			dbcharcount = 0;
			fgets(line, 150, db);
			dblength = dblength + seqlength;
			fprintf(infodb, "# %10.0f\n", dblength); //position
			fprintf(infodb, "%s", line);
			dbsequences++;
			seqlength = 0;
		}
	  }
	  else {
	    binchar |= PACK_BASE(dbchar) << (2*(3-i));
	    seqlength++;

	    if(i == 3) {
	      fwrite(&binchar, sizeof(binchar), 1, bindb);
	      i = 0;
	      binchar = 0x00;
	      dbcharcount++;
	    }
	    else  i++;
	  }
	}
	dblength = dblength + seqlength;

	fprintf(infodb, "# %10.0f\n\n", dbcharcount);
	fseek(infodb, 0, SEEK_SET);
	fprintf(infodb, "# %10.0f\n\n", dbsequences);
	fseek(infodb, bppos, SEEK_SET);
	fprintf(infodb, "# %10.0f\n", dblength);


	time1 = gettime(time0);


	printf("Characters: %.0f\n", dblength);
	printf("Sequences: %.0f\n", dbsequences);
	printf("Time: %f seconds\n\n", time1);
	printf("create files: %s and %s \n", bindbname, infodbname);

	printf("\n-> finished transformation for %s\n\n", databasename);

	fclose(db);
	fclose(bindb);
	fclose(infodb);

	return 0;
}


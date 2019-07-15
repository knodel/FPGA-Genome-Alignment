/*
    main.cpp
    Project:	FPGA-DNA-Sequence-Search

 	Created by Oliver Knodel on 12.07.10.
 
	Description:
    This program transfers short reads of Nucleotides to a FPGA and streams in
    a second step the database to the FPGA. The result is a file with positions
    of reads in the database.


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

#include <stdlib.h>
#include <stdint.h>
#include <iostream>
#include <stdio.h>
#include <math.h>
#include <time.h>
#include <cstring>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/mman.h>
#include <unistd.h>
#include <fcntl.h>
#include <pthread.h>
#include <getopt.h>
#include <pthread.h>

extern "C" {
# include "header/align.h"
# include "header/ethernet.h"
# include "header/gettime.h"
# include "header/formatdb.h"
}

using namespace std;

#define BUF_SIZE 	 1514
#define DATA_SIZE 	 1498
#define REAL_DB_DATA 1496
#define CTR_BUF_SIZE 60
#define MAXUNITS_V5  100
#define MAXUNITS_V6  600
#define LABEL		 200


/* Functions */
int sendingReads(int mismatch, int double_units);
int sendingDB();
int saveResults();
int printResults();
int readingOptions(int argc, char** argv);
int transformread();
int readConfiguration();
int overflow_response();

void print_help();

/* Threads */
void *rcvError(void *threadid);
void *stream(void *threadid);

/* send next*/
pthread_mutex_t next_mutex;
pthread_cond_t next_signal;

int sleeping = 0;

/* wait */
pthread_mutex_t wait_mutex;
pthread_cond_t wait_signal;

/* wait */
pthread_mutex_t end_mutex;
pthread_cond_t end_signal;

/* Files */
FILE *infodb, *readfile, *resultfile, *mapfile, *unmapfile;
int bindb;
char *dbmap, *readmap, *results, *indexlabel;
unsigned int reads, maxunits;

/* Buffer*/
char* send_buffer;
char* rec_buffer;
char*line;

int8_t* readbestmatch;
int8_t* readbestmismatch;
uint16_t* readposcount;

/* Control- and status information */
unsigned int packets;
unsigned int id = 1;
int stream_error = 0;
int stream_end = 0;
int send_next_stream = 0;
int stream_wait = 0;
uint16_t sendNext;

double positions = 0;
double mapped = 0;
double seqchars = 0;
double maxreads = 0;
double overflows = 0;
unsigned int dbmapposition = 0;

enum CONTROL {
	ctr_first_data 			= 0x10,	/* First Data Packet */
	ctr_data 				= 0x11,	/* Normal Data Packet */
	ctr_last_data 			= 0x12,	/* Last Data Packet */

	ctr_send_next 			= 0x13,	/* FPGA -> Host: send next Data Packet */
	ctr_send_DB 			= 0x14,	/* FPGA -> Host: send DB */
	ctr_get_data 			= 0x15,	/* Host -> FPGA: send Data */
	ctr_finished_search 	= 0x16, /* FPGA -> HOST: last DB character */
	ctr_finished_sending 	= 0x17, /* FPGA -> HOST: finished sending of results */
	ctr_next_segment		= 0x18, /* Host -> FPGA: begin iteration for next segment of reads */
	ctr_finished_iteration	= 0x19, /* HOST -> FPGA: finished work -> next state waiting */

	ctr_getid 				= 0x20,	/* Host -> FPGA: get ID */
	info_v5 				= 0x21,	/* FPGA -> Host: ID = Vertex-5 */
	info_v6 				= 0x22,	/* FPGA -> Host: ID = Vertex-6 */
	error					= 0x24, /* FPGA -> Host: packet lost */
	ctr_reset				= 0x19, /* Host -> FPGA: reset */

	ctr_overflow			= 0x30, /* FPGA -> Host: overflow */
	ctr_overflow_ready		= 0x31  /* Host -> FPGA: continue searching */
} ctr;

/* Initialization vectors for the CFGLUT5 primitives used for the
 * sequence aligner. After configuration, the LUT will generate:
 *
 *  Input:  a two-base subsequence ("bb", "bb") -> (A3, A2, A1, A0)
 *  Output: count of mismatches (m1, m0) -> (O6, O5)
 */
uint32_t const  LUT5_CFG[5][5] = {
  {             // Matched Input
    0xEEE0111E, // 0:0
    0xDDD0222D, // 0:1
    0xBBB0444B, // 0:2
    0x77708887, // 0:3
    0x0000FFF0  // 0:x
  },
  {
    0xEE0E11E1, // 1:0
    0xDD0D22D2, // 1:1
    0xBB0B44B4, // 1:2
    0x77078878, // 1:3
    0x0000FF0F  // 1:x
  },
  {
    0xE0EE1E11, // 2:0
    0xD0DD2D22, // 2:1
    0xB0BB4B44, // 2:2
    0x70778788, // 2:3
    0x0000F0FF  // 2:x
  },
  {
    0x0EEEE111, // 3:0
    0x0DDDD222, // 3:1
    0x0BBBB444, // 3:2
    0x07777888, // 3:3
    0x00000FFF  // 3:x
  },
  {
    0x0000EEEE, // x:0
    0x0000DDDD, // x:1
    0x0000BBBB, // x:2
    0x00007777, // x:3
    0x00000000  // x:x
  }
};

/* main options */

struct globalArgs_t {
	char *databasename;			/* FASTA database */
	char *bindbname;			/* binary database */
	char *infodbname;			/* infofile for database */
	char *readname;				/* query */
	char *output;				/* -o option */
	char *unmapoutput;			/* -o option */
	char *mapoutput;			/* -o option */

	unsigned int mismatch;		/* -m option */
	unsigned int transform_only;/* -t option */
	unsigned int transform;		/* when no bindb available */
	unsigned int status;		/* -i option */
	unsigned int sam;			/* -s option */
	unsigned int map;			/* -u option */
	unsigned int fpga;			/* Virtex 5 or 6*/
	unsigned int positions;		/* -p option */
} global_opt;

struct function_time {
	double send;
	double create;
	double rcv;
	double search;
	double save;
	double txBandwidth;
	double rxBandwidth;
	double streams;
	double all;
} func_time;

static struct option main_lopts[] = {
	{ "query",		required_argument, NULL, 'q' },
	{ "database",	required_argument, NULL, 'd' },
	{ "bindb",		required_argument, NULL, 'b' },
	{ "transform",	no_argument		 , NULL, 't' },
	{ "mismatch",	required_argument, NULL, 'm' },
	{ "output",		required_argument, NULL, 'o' },
	{ "sam",		no_argument		 , NULL, 's' },
	{ "map",		no_argument		 , NULL, 'u' },
	{ "status",		no_argument		 , NULL, 'i' },
	{ "positions",	no_argument		 , NULL, 'p' },
	{ 0, 0, 0, 0 }
};

static char main_sopts[] = "q:d:b:tm:o:suip";


/********************************************************************************
 * Main Function - Transforms in the first step the database and the reads in
 * a binary format. In the second step the reads were transmitted to the parallel
 * units of the FPGA. Then begins the real search in the database with the
 * predefined mismatch-values. The database is streamed over all parallel units
 * with a simple flow-control. In the End the FPGA transmits the results back
 * to the Host.
 *
 * fpga-align [options]
 * Options:
 * --query		-q <filename>   query input file
 * --database	-d <filename>  	database input file in fasta format
 * --bindb		-b <filename>	database input files in binary fasta format
 * --transform	-t				only transforms the database from fasta to
 * 								binary fasta (default: no)
 * --mismatch	-m [int]		maximum number of mismatches per read (default: 0)
 * --output		-o <filename>	output file
 * --status		-o 				print status information and performance data
 * 								(default: no)
 * --help		-h				print this usage message
 ********************************************************************************/
 int main(int argc, char** argv) {

	char ctr, *ptr;
	double dbchars, sequences;
	double time0, time1, latency;
	struct stat sb;
	uint16_t device_units;
	unsigned int i = 0, j = 0;

	func_time.all = 0;
	func_time.create = 0;
	func_time.rcv = 0;
	func_time.save = 0;
	func_time.search = 0;
	func_time.send = 0;
	func_time.rxBandwidth = 0;
	func_time.txBandwidth = 0;
	func_time.streams = 0;

	/*------------------------------------------------------
		 				prepare threads
	 ------------------------------------------------------*/
	void *status;
	pthread_t thread[2];
	pthread_attr_t attr;
	int rc;

	/* Initialize and set thread detached attribute */
	pthread_attr_init(&attr);
	pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_JOINABLE);

	/*------------------------------------------------------
	 					allocating memory
	 ------------------------------------------------------*/

	send_buffer 	= (char*) malloc(BUF_SIZE * sizeof(char));
	rec_buffer 		= (char*) malloc(BUF_SIZE * sizeof(char));
	line 			= (char*) malloc(LABEL * sizeof(char));
	readbestmatch	= (int8_t*) malloc(MAXUNITS_V6 * sizeof(int8_t));
	readbestmismatch= (int8_t*) malloc(MAXUNITS_V6 * sizeof(int8_t));
	readposcount	= (uint16_t*) malloc(MAXUNITS_V6 * sizeof(uint16_t));

	for(j = 0; j < MAXUNITS_V6; j++){
		readbestmatch[j] 	= 8;
		readbestmismatch[j] = 8;
		readposcount[j] 	= 0;
	}

 	/*------------------------------------------------------
 						reading options
 	------------------------------------------------------*/

	if (readingOptions(argc, argv) == -1) {
		return -1;
	}

	/*------------------------------------------------------
						 transform db
	------------------------------------------------------*/
	if (global_opt.transform == 1) {
		if(transformdb(global_opt.databasename, global_opt.bindbname, global_opt.infodbname) == -1){
			return -1;
		}
	}
	if (global_opt.transform_only == 1){
		cout << "transformation of database completed" << endl;
		return 0;
	}

	/*------------------------------------------------------
				open connection and searching device
	------------------------------------------------------*/
	cout << "--- open connection ---" << endl;

	initializeEthernetConnection(send_buffer);
	sendControl(ctr_reset, send_buffer, id);


	time0 = gettime(0);
	device_units = searchDevice(send_buffer, rec_buffer, id);
	time1 = gettime(time0);
	latency = (time1 / 2 ) * 1000000; /* µ seconds */
	printf("Latency: %8.2f µ seconds\n\n", latency);
	id++;

	if (device_units == 0){
		return -1;
	} else {
		maxunits = device_units;
	}

	results		= (char*) malloc(maxunits * 4000 * 4 * sizeof(char));	// 1,024 results max
	readmap 	= (char*) malloc(maxunits * 32 * 32 * sizeof(char));
	indexlabel	= (char*) malloc(maxunits * LABEL * sizeof(char));		// 200 character label per read

	/*------------------------------------------------------
			opening files and reading information
	------------------------------------------------------*/

	cout << endl << "--- opening files and getting information ---" << endl;

	infodb = fopen(global_opt.infodbname, "rb");
	if (infodb == NULL) {
		fprintf(stderr, "\nError: can not open File %s\n", global_opt.infodbname);
		return -1;
	}

	/* reading from info-File and calculating number of Packets */
	fgets(line, 20, infodb);
	sscanf(line, "# %lf\n", &sequences);
	printf("sequences: %.0f\n", sequences);

	bindb = open64(global_opt.bindbname, O_RDONLY);
	if (bindb == -1) {
		fprintf(stderr, "\nError: can not open File %s\n", global_opt.bindbname);
		return -1;
	}

	if(fstat(bindb, &sb) == -1) {
		fprintf(stderr, "\nError: fstat database.fastbin\n");
		return -1;
	}

	dbmap = (char*) mmap(0, sb.st_size, PROT_READ, MAP_SHARED, bindb, 0);
	if(dbmap == MAP_FAILED) {
		fprintf(stderr, "\nError: mapping db\n");
		return -1;
	}

	close(bindb);

	/* files for results */
	resultfile = fopen(global_opt.output, "wb");
	if (resultfile == NULL) {
		fprintf(stderr, "\nError: can not create File %s\n", global_opt.output);
		return -1;
	}

	fprintf(resultfile, "@HD VN:1.3 SO:unsorted\n");

	if(global_opt.map == 1){
		mapfile = fopen(global_opt.mapoutput, "wb");
		if (mapfile == NULL) {
			fprintf(stderr, "\nError: can not create File %s\n", global_opt.mapoutput);
			return -1;
		}

		unmapfile = fopen(global_opt.unmapoutput, "wb");
		if (unmapfile == NULL) {
			fprintf(stderr, "\nError: can not create File %s\n", global_opt.unmapoutput);
			return -1;
		}

		fprintf(mapfile, "# readname \t number of mapping positions \t minimal number of mismatches\n");
		fprintf(unmapfile, "# readname \t necessary mismatches\n");
	}

	/*------------------------------------------------------
					read transformation
	------------------------------------------------------*/

	readfile = fopen(global_opt.readname, "rb");
	if (readfile == NULL) {
		fprintf(stderr, "\nError: can not open File %s\n", global_opt.readname);
		return -1;
	}

	reads = transformread();
	maxreads = reads;

	cout << endl << "--- transfer data ---" << endl << endl;

	fgets(line, 20, infodb);
	sscanf(line, "# %lf\n", &dbchars);
	printf("characters: %.0f\n", dbchars);
	fgets(line, 20, infodb);//empty


	while(reads != 0) {

		/*------------------------------------------------------
									transfer reads
		------------------------------------------------------*/
		sendingReads(global_opt.mismatch, 0);

		for(i = 0; i < sequences; i++){

			fgets(line, 20, infodb);//position

			fgets(line, LABEL, infodb);//name
			ptr = strchr(line, '\n');
			if (ptr != NULL) {
				*ptr = ' ';
			}

			fscanf(infodb, "# %lf\n", &seqchars);//characters
			fprintf(resultfile, "@SQ SN:%s LN:%.0f\n", line, seqchars*4);

			packets = seqchars / REAL_DB_DATA;

			/*------------------------------------------------------
							transfer database
			------------------------------------------------------*/
			ctr = receive(CTR_BUF_SIZE, rec_buffer);
			while(ctr != ctr_send_DB){
				ctr = receive(CTR_BUF_SIZE, rec_buffer);
			}

			memcpy(&sendNext, rec_buffer+1, 2);//number of Bytes in FPGA-Text-FIFO


			rc = pthread_create(&thread[0], &attr, rcvError, (void *) 0);
			if (rc){
				printf("ERROR; return code from pthread_create() is %d\n", rc);
			}

			rc = pthread_create(&thread[1], &attr, stream, (void *) 0);
			if (rc){
				printf("ERROR; return code from pthread_create() is %d\n", rc);
			}


			rc = pthread_join(thread[0], &status);
			rc = pthread_join(thread[1], &status);

			/*------------------------------------------------------
							load results
			------------------------------------------------------*/

			if (saveResults() == -1){
				fprintf(stderr, "\nError: saving results\n");
				return -1;
			}
			//cout << "saved" << endl;

			if (printResults() == -1){
				fprintf(stderr, "\nError: printing results\n");
				return -1;
			}

			//cout << "printed" << endl;

			if (i != (sequences-1)) {
				sendControl(ctr_next_segment, send_buffer, id);
				id++;
			}

			dbmapposition = dbmapposition + (unsigned int) seqchars;
		}

		dbmapposition = 0;

		//calculating mapped reads and print list of mapped and unmapped
		for(j = 0; j < reads; j++){
			if (readbestmatch[j] < (int8_t) 8) {
				mapped = mapped + 1;
				if(global_opt.map == 1){
					fprintf(mapfile, "%s", indexlabel + (j * LABEL));
					fprintf(mapfile, " %u %u\n", readposcount[j], readbestmatch[j]);
				}
			} else {
				if(global_opt.map == 1){
					fprintf(unmapfile, "%s", indexlabel + (j * LABEL));
					fprintf(unmapfile, " %u\n", readbestmismatch[j]);
				}
			}
			readbestmatch[j] = 8;
			readbestmismatch[j] = 8;
			readposcount[j] = 0;
		}

		if (reads < maxunits) {
			reads = 0;
		} else {
			reads = transformread();

		}

		maxreads = maxreads + reads;

		sendControl(ctr_finished_iteration, send_buffer, id);
		id = 1;
		sleep(0.5);
	}


	/*------------------------------------------------------------------------------------------------------------*/

	cout << endl << "--- finished search ---" << endl;

	cout << "created files: " << global_opt.output << ", " << global_opt.mapoutput << " and " << global_opt.unmapoutput << endl;

	cout << "found " << positions << " positions in " << sequences << " sequences" << endl;
	cout << "mapped " << mapped << " (" << (100 / maxreads) * mapped << " %) of " << maxreads << " reads" << endl;
	cout << "overflows: " << overflows << endl;


	if (global_opt.status == 1){
		cout << endl << "--- statistics ---" << endl;

		func_time.all = func_time.create + func_time.rcv + func_time.save + func_time.search + func_time.send;
		cout << "creating reads: " 		<< "\t" 	<< (100 / func_time.all) * func_time.create << endl;
		cout << "receive: " 			<< "\t\t" 	<< (100 / func_time.all) * func_time.rcv << endl;
		cout << "save results: " 		<< "\t\t" 	<< (100 / func_time.all) * func_time.save << endl;
		cout << "searching: " 			<< "\t\t" 	<< (100 / func_time.all) * func_time.search << endl;
		cout << "sending reads: " 		<< "\t\t" 	<< (100 / func_time.all) * func_time.send << endl;
		cout << "time: " 				<< "\t\t\t" << func_time.all << endl;

		cout << "average TX bandwidth:" << "\t" 	<< func_time.txBandwidth / func_time.streams  << " MBit/s" << endl;
		cout << "average RX bandwidth:" << "\t" 	<< func_time.rxBandwidth / func_time.streams  << " MBit/s" << endl;
	}

	/*------------------------------------------------------
						cleaning up
	------------------------------------------------------*/

	fclose(readfile);
	fclose(resultfile);
	fclose(infodb);

	if(global_opt.map == 1){
		fclose(mapfile);
		fclose(unmapfile);
	}

	free(send_buffer);
	free(rec_buffer);
	free(results);
	free(readmap);
	free(readbestmatch);
	free(readbestmismatch);
	free(readposcount);
	munmap(dbmap, sb.st_size);

	return 0;
}

/******************************************************************************
 * Database streaming Thread
 ******************************************************************************/
void *stream(void *threadid) {

	double fullsend0, fullsend1, bandwidth;
	unsigned int i, j, p, fpgaPackets, packetsize, nextBytes;

	p = 0;
	i = 0;
	fullsend0 = gettime(0);
	send_next_stream = 1;

	double time0 = gettime(0);

	//cout << "begin stream" << endl;

	while(p <= packets){

		pthread_mutex_lock(&next_mutex);
		if(send_next_stream == 1){

			send_next_stream = 0;
			pthread_mutex_unlock(&next_mutex);


			nextBytes = (unsigned int) sendNext;
			fpgaPackets = (nextBytes / REAL_DB_DATA)-4;//FFFF -> 43 Pakete
			if (fpgaPackets > 43) {
				fpgaPackets = 2;
			} else if (fpgaPackets == 0) {
				fpgaPackets = 0;
			}

			if(stream_wait == 1){
				overflow_response();
			}

			//cout << "send " << fpgaPackets << " packets" << endl;

			for (j = 0; (j < fpgaPackets) && (p <= packets); j++) {

				//stops at the end of a sequence
				if(p == packets) {
					packetsize = seqchars - (REAL_DB_DATA * p);
				} else {
					packetsize = DATA_SIZE;
				}

				memcpy(send_buffer+17, dbmap + dbmapposition + (REAL_DB_DATA * p), packetsize);
				p++;

				if (j == 0 and i == 0) {
					sendData(packetsize, ctr_first_data, send_buffer, id);
					id++;
				} else if (p == packets + 1) {
					sendData(packetsize, ctr_data, send_buffer, id);
					id++;
					break;
				} else {
					sendData(packetsize, ctr_data, send_buffer, id);
					id++;
				}
				if (stream_error == 1) {
					pthread_exit((void*) 1);
				}

				if(stream_wait == 1){
					overflow_response();
				}
			}
			if (stream_error == 1) {
				pthread_exit((void*) 1);
			}
			i++;

			if(stream_wait == 1){
				overflow_response();
			}

		} else {
			sleeping = 1;
			while(sleeping == 1){
				pthread_cond_wait(&next_signal, &next_mutex);
				if(sleeping == 1) {
					overflow_response();
				}
			}
			pthread_mutex_unlock(&next_mutex);

		}
	}

	func_time.search = func_time.search + gettime(time0);

	sendControl(ctr_last_data, send_buffer, id);
	id++;

	fullsend1 = gettime(fullsend0);

	if(stream_wait == 1){
		overflow_response();
	}

	if(stream_end != 1) {
		pthread_cond_wait(&end_signal, &end_mutex);
	}
	stream_end = 0;

	if(stream_wait == 1){
		overflow_response();
	}

	/*------------------------------------------------------
					calculating bandwidth
	 ------------------------------------------------------*/

	bandwidth = ((p * (REAL_DB_DATA * 8)) / fullsend1) / 1024 / 1024;

	if (global_opt.status == 1){
		printf("Bandwidth: %8.2f MBit/s \n", bandwidth);
		printf("processed %.0f reads \n", maxreads);
	}

	func_time.txBandwidth = func_time.txBandwidth + bandwidth;
	func_time.streams++;

	pthread_exit((void*) 0);
}

/******************************************************************************
 * Thread waiting for error
 ******************************************************************************/
void *rcvError(void *threadid) {
	char ctr;
	unsigned int lastPacket;
	stream_error = 0;

	do {
		ctr = receive(CTR_BUF_SIZE, rec_buffer);
		if (ctr == error) {
			lastPacket = rec_buffer[1] & 255;
			printf("\nError: message number %u lost\n", lastPacket);
			stream_error = 1;
			pthread_exit((void*) 1);

		} else if(ctr == ctr_send_next) {
			memcpy(&sendNext, rec_buffer+1, 2);
			pthread_mutex_lock(&next_mutex);
			send_next_stream = 1;
			if (sleeping == 1){
				sleeping = 0;
				pthread_cond_signal(&next_signal);
			}
			pthread_mutex_unlock(&next_mutex);

		} else if (ctr == ctr_overflow) {
			stream_wait = 1;
			if (global_opt.status == 1){
				printf("unit overflow\n");
			}

			pthread_mutex_lock(&next_mutex);
			if (sleeping == 1){
				pthread_mutex_unlock(&next_mutex);
				pthread_cond_signal(&next_signal);
			}else {
				if(stream_end != 1) {
					pthread_cond_signal(&end_signal);
					stream_end = 1;
				}
				pthread_mutex_unlock(&next_mutex);

			}
			pthread_cond_wait(&wait_signal, &wait_mutex);

		} else if (ctr == ctr_finished_search) {
			if (stream_end != 1){
				stream_end = 1;
				pthread_cond_signal(&end_signal);
				pthread_exit((void*) 0);
			}
		} else {
			printf("\nError: Received invalid message\n");
			pthread_exit((void*) 1);
		}
	} while(1);

}

int overflow_response(){

	sendControl(ctr_overflow_ready, send_buffer, id);
	id++;

	overflows++;

	if (saveResults() == -1){
		fprintf(stderr, "\nError: saving results\n");
		pthread_exit((void*) 1);
	}
	if (printResults() == -1){
		fprintf(stderr, "\nError: printing results\n");
		pthread_exit((void*) 1);
	}
	sendControl(ctr_overflow_ready, send_buffer, id);
	id++;
	pthread_cond_signal(&wait_signal);
	sleep(0.1);
	stream_wait = 0;

	return 0;
}

/******************************************************************************
 * Sends the reads to the fpga
 ******************************************************************************/
int sendingReads(int mismatch, int double_units){
	 unsigned int j, i;

	 unsigned int units = reads - 1; /* The FPGA counts starting with "0" */

	 double time0 = gettime(0);

	 /* unit information */
	 memcpy(send_buffer+16, &units, 2);

	 if (double_units == 1){
		 send_buffer[19] = 0x10;		//double read length
	 } else {
		 send_buffer[19] = 0x00;
	 }

	 if (global_opt.positions == 1){
	 	send_buffer[18] = 0x10;			//send positions
	 } else {
	 	send_buffer[18] = 0x00;
	 }

	 i = 0;
	 j = 0;

	 for(j = 0; j < reads; j++) {
		 if(j < 10) {
			 /* control information */
			 send_buffer[20 + (i * 136)] = mismatch;	/* max mismatches */
			 if (global_opt.positions == 1){
				 send_buffer[21 + (i * 136)] = 0x00;
			 } else {
				 send_buffer[21 + (i * 136)] = 0x08;	/* no positions */
			 }
			 send_buffer[22 + (i * 136)] = 0x08;		/* searching for this unit is active */
			 send_buffer[23 + (i * 136)] = 0x00;

			 memcpy(send_buffer + 24 + (i * 136), readmap + (j * 132), 132);
		 } else {
			 /* control information */
			 send_buffer[16 + (i * 136)] = mismatch;	/* max mismatches */
			 if (global_opt.positions == 1){
			 	send_buffer[21 + (i * 136)] = 0x00;
			 } else {
			 	send_buffer[21 + (i * 136)] = 0x08;		/* no positions */
			 }
			 send_buffer[18 + (i * 136)] = 0x08;		/* searching for this unit is active */
			 send_buffer[19 + (i * 136)] = 0x00;

			 memcpy(send_buffer + 20 + (i * 136), readmap + (j * 132), 132);
		 }

		 i++;
		 if ((j == 9) || ((j == (reads - 1)) && (reads <= 10))) {
			 sendData((136 * i) + 4, ctr_first_data, send_buffer, id);//max 10 reads per packet
			 id++;
			 i = 0;
		 } else if((i == 10) || (j == (reads - 1))) {
			 sendData((136 * i), ctr_data, send_buffer, id);
			 id++;
			 i = 0;
		 }
	 }
	 for(i = 16; i < 51; i++) {
		 send_buffer[i] = 0x00;
	 }
	 sendData(35, ctr_data, send_buffer, id);
	 id++;

	 func_time.send = func_time.send + gettime(time0);

	 return 0;
 }

/******************************************************************************
 * Save results of one run in memory
 ******************************************************************************/
int saveResults() {
	char ctr;
	unsigned int i = 0, p = 0;
	double bandwidth;
	int packetcount = 0, maxpacket = (maxunits * 4000 * 4 * sizeof(char))/BUF_SIZE;

	double rcvtime, time0 = gettime(0);

	sendControl(ctr_get_data, send_buffer, id);
	id++;

	do {
		ctr = receive(BUF_SIZE, rec_buffer);
	} while(ctr != ctr_data);

	if (ctr == ctr_data) {
		p++;
		memcpy(results, rec_buffer + 2, DATA_SIZE);
		packetcount++;
	} else {
		cout << "Error: no results" << endl;
		return -1;
	}

	ctr = receive(BUF_SIZE, rec_buffer);

	while (ctr == ctr_data) {
		memcpy(results + DATA_SIZE + (i * (DATA_SIZE+1)), rec_buffer + 1, DATA_SIZE+1);
		packetcount++;
		i++;

		ctr = receive(BUF_SIZE, rec_buffer);

		if(packetcount == maxpacket){
			return 0;
		}
	}

	if (ctr != ctr_finished_sending) {
		cout << "error, finishing iteration" << endl;
		return -1;
	}

	rcvtime = gettime(time0);
	bandwidth = ((p * (REAL_DB_DATA * 8)) / rcvtime) / 1024 / 1024;
	func_time.rxBandwidth = func_time.rxBandwidth + bandwidth;

	func_time.rcv = func_time.rcv + rcvtime;

	return 0;
}

/******************************************************************************
 * Writes results of one run to output file
 ******************************************************************************/
int printResults(){
  struct result_t {
    uint16_t  location_cnt;
    uint8_t   mismatches_min;
    uint8_t   padding;
    uint32_t  positions[0];
  };

  double time0 = gettime(0);

  unsigned  k = 0;

  for(unsigned  i = 0; i < reads; i++) {

	  struct result_t const *const  res = (struct result_t*)(results + k*4);
	  k++;

	  if(res->location_cnt != 0) {
		  readposcount[i] = readposcount[i] + res->location_cnt;
		  if(global_opt.positions == 1) {
			  for(unsigned  j = 0; j < res->location_cnt; j++) {
				  fprintf(resultfile, "%s", indexlabel + (i * LABEL));
				  if(global_opt.sam == 0){
					  fprintf(resultfile, "\t%u \n", res->positions[j]-1);
				  } else {
					  fprintf(resultfile, "\t0 \t%s \t0 \t%u \t* \t* \t* \t* \t* \t* \t*\n", line, res->positions[j]-1);
				  }
			  }
			  k += res->location_cnt;
		  }
		  positions = positions + res->location_cnt;
		  if(res->mismatches_min < readbestmatch[i]){
			  readbestmatch[i] = (int8_t) res->mismatches_min;
		  }
	  } else {
		  if(readbestmismatch[i] > res->mismatches_min){
			  readbestmismatch[i] = (int8_t) res->mismatches_min;
		  }
	  }
  }

  func_time.save = func_time.save + gettime(time0);
  return 0;
}

/******************************************************************************
 * Transforms read for the LUT-RAM
 ******************************************************************************/
int transformread() {
  unsigned const  MAX_NUCS = 64;
  char* ptr;
  double time0 = gettime(0);

  // Generating table with LUT-information in order
  unsigned  reads = 0;
  while(reads < maxunits) {
    switch(getc(readfile)) {
    case EOF:
      return  reads;
    case '>': {
      // Save Read Label and remove \n
      fgets(indexlabel + (reads * LABEL), LABEL, readfile);
      ptr = strchr((indexlabel + (reads * LABEL)), '\n');
      *ptr = ' ';
      // Scan Sequence
      uint32_t  table[MAX_NUCS/2];
      unsigned  len = 0;
      unsigned  mis = 'A';
      while(len < MAX_NUCS/2) {
	int  c1 = getc(readfile);
        if(c1 < 'A') {
          table[len++] = 0;
	  mis = c1;
          break;
        }
	c1 = (c1 & 8)? 4 : PACK_BASE(c1);

        int  c2 = getc(readfile);
        if(c2 < 'A') {
          table[len++] = LUT5_CFG[c1][4];
	  mis = c2;
          break;
        }
	c2 = (c2 & 8)? 4 : PACK_BASE(c2);
        table[len++] = LUT5_CFG[c1][c2];
      }
      while(mis >= 'A')  mis = getc(readfile); // Consume extra bases
      // check for read-specific mismatch count
      if((mis != '/') || (fscanf(readfile, "%u", &mis) != 1))  mis = global_opt.mismatch;

      // TODO:
      //   Encode read-specific mismatch count -> currently ignored.
      //   This value should probably be stated in the results for this read.

      // Generating table with parallel Bits
      // table_block[0..32], table_block[32] = 0
      uint32_t *const  table_block = (uint32_t*)(readmap + (reads * 132));

      uint32_t  msk = 1;
      table_block[32] = 0;
      for(signed  i = 32; --i >= 0;) {
	uint32_t  entry = 0;
	for(signed  k = len; --k >= 0;) {
	  uint32_t const  b = table[k] & msk;
	  entry |= (k-i > 0)? b >> (k-i) : b << (i-k);
	}
	table_block[i] = entry;   // TODO: htonl()
	msk <<= 1;
      }

      reads++;
    }
    default:
      break;
    }
  }
  func_time.create = func_time.create + gettime(time0);

  return  reads;
}

/******************************************************************************
 * Reads the options from the command line and sets the
 * global options or returns error messages
 ******************************************************************************/
int readingOptions(int argc, char** argv) {

	int opt;
	char *output;

	/* Initialize global options */
	global_opt.databasename = NULL;
	global_opt.bindbname = NULL;
	global_opt.readname = NULL;
	global_opt.mismatch = 0;
	global_opt.transform_only = 0;
	global_opt.transform = 0;
	global_opt.output = NULL;
	global_opt.unmapoutput = NULL;
	global_opt.mapoutput = NULL;
	global_opt.sam = 0;
	global_opt.map = 0;
	global_opt.status = 0;
	global_opt.positions = 1;

	while ((opt=getopt_long(argc, argv, main_sopts, main_lopts, NULL)) != -1) {
		switch(opt) {
			case 'q':
	 			global_opt.readname = optarg;
	 	        break;

	 	    case 'd':
	 	    	global_opt.databasename = optarg;
	 	        global_opt.transform = 1;
	 	        break;

	 		case 'b':
	 			global_opt.bindbname = optarg;
	 			break;

			case 't':
	 			global_opt.transform_only = 1;
	 			break;

	 		case 'm':
	 			global_opt.mismatch = atoi(optarg);
	 			break;

	 		case 'o':
	 			output = optarg;
				break;

	 		case 'i':
	 			global_opt.status = 1;
	 			break;

	 		case 's':
	 			 global_opt.sam = 1;
	 			 break;

	 		case 'u':
	 			 global_opt.map = 1;
	 			 break;

	 		case 'p':
	 			global_opt.positions = 1;
	 			break;

			default:
	 			print_help();
	 			return -1;
	 	}
	}

	if((global_opt.databasename == NULL) and (global_opt.bindbname == NULL)){
		printf("No input files specified\n");
	 	print_help();
	 	return -1;
	}

	char *suffix, *oldsuffix;

	/* sets the name for the binary database if database name is given*/
	if (global_opt.transform == 1) {
		global_opt.bindbname = (char*) malloc(strlen(global_opt.databasename)+8);
		memcpy(global_opt.bindbname, global_opt.databasename, strlen(global_opt.databasename));
		suffix = strchr(global_opt.bindbname, '.');
		if (suffix == NULL) {
			strcpy(suffix, ".bindb");
		} else {
			while (suffix != NULL){
				oldsuffix = suffix;
				suffix = strchr(suffix+1, '.');
			}
			strcpy(oldsuffix, ".bindb");
		}
	}


	global_opt.infodbname= (char*) malloc(strlen(global_opt.bindbname)+8);
	memcpy(global_opt.infodbname, global_opt.bindbname, strlen(global_opt.bindbname));

	suffix = strchr(global_opt.infodbname, '.');
	if (suffix == NULL) {
		strcpy(suffix, ".bindb");
	} else {
		while (suffix != NULL){
			oldsuffix = suffix;
			suffix = strchr(oldsuffix+1, '.');
		}
		strcpy(oldsuffix, ".dbinfo");
	}


	if((global_opt.transform_only == 1) and (global_opt.transform == 0)){
		printf("FASTA Database required\n");
		print_help();
		return -1;
	}

	if (global_opt.transform_only != 1) {
		if(output == NULL){
			printf("No output file specified\n");
			print_help();
			return -1;
		} else {
			global_opt.output = (char*) malloc(strlen(output)+4);
			memcpy(global_opt.output, output, strlen(output));

			if(global_opt.sam == 0){
				strcat(global_opt.output, ".pam");
			} else {
				strcat(global_opt.output, ".sam");
			}

			global_opt.mapoutput = (char*) malloc(strlen(output)+4);
			memcpy(global_opt.mapoutput, output, strlen(output));
			strcat(global_opt.mapoutput, ".map");

			global_opt.unmapoutput = (char*) malloc(strlen(output)+6);
			memcpy(global_opt.unmapoutput, output, strlen(output));
			strcat(global_opt.unmapoutput, ".unmap");
		}
	}

	return 0;
 }

/******************************************************************************
 * Help-screen for global options
 ******************************************************************************/
void print_help(){

 	printf("\nFPGA-Alignment\n");
 	printf("Usage:\n");
 	printf("\tfpga-align [options] \n\n");
 	printf("Options:\n");
 	printf("\t--query \t-q <filename> \tquery input file\n");
 	printf("\t--database \t-d <filename> \tdatabase in fasta format\n");
 	printf("\t--bindb \t-b <filename> \tdatabase in binary fasta format\n");
 	printf("\t--transform \t-t \t\tonly transform database (default: no)\n");
 	printf("\t--mismatch \t-m [int] number of mismatches (default: 0)\n");
 	printf("\t--output \t-o <filename> \tbase name for output files\n");
 	printf("\t--sam \t\t-s \t \tsave output in SAM-format (default: no)\n");
 	printf("\t--unmap \t-u \t \tcreate map and unmap files (default: no)\n");
 	printf("\t--status \t-i	\tprint performance info (default: no)\n");
 	printf("\t--help \t\t-h \t\tprint this usage message\n");
 }

/*
    ethernet.c
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

#include <sys/socket.h>
#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <asm/types.h>

#include <math.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <signal.h>

#include <linux/if_packet.h>
#include <linux/if_ether.h>
#include <linux/if_arp.h>
#include <libconfig.h>
#include <errno.h>


#include "header/gettime.h"

#define CTR_BUF_SIZE 60

/* MAC and interface*/
 char host_mac[6] = {0x00, 0x19, 0x99, 0x12, 0x3d, 0x08};
 char client_mac[6] = {0x00, 0x0a, 0x35, 0x02, 0x2a, 0x42};
const char* ifname = "eth1";

/* Socketdescriptor */
int send_socket = 0;
int recv_socket = 0;
struct sockaddr_ll sa;
struct sockaddr_ll ra;
struct ifreq ifinfo;

/* Packet */
//unsigned  rec_length;
unsigned  send_length;
socklen_t rec_length = 0;

/*****************************************************************************
* Initialization of the Ethernet connection with header,
* containing host/client MAC and send/receive socket for
* a specified interface
******************************************************************************/
void initializeEthernetConnection(char* send_buffer){

	rec_length = sizeof(ra);
	int ifindex;

	config_t cfg, *cf;
	const config_setting_t *mac;
	int count = 0, i;


	//Read config-file
	cf = &cfg;
	config_init(cf);


	if (!config_read_file(cf, "mac.config")) {
		fprintf(stderr, "%s:%d - %s\n",
		#ifdef config_error_file
			config_error_file(cf),
		#else
		    "",
		#endif
		    config_error_line(cf),
		    config_error_text(cf));
		    config_destroy(cf);
		    exit(1);
		}

		 /*
		 config_lookup_int(cf, "ETH", &iface);

		 if(iface == 0) {
			 interface = "eth0";
		 } else{
			 interface = "eth1";
		 }
		*/

	mac = config_lookup(cf, "FPGA");
	count = config_setting_length(mac);
	if(count == 6) {
		for (i = 0; i < count; i++) {
			client_mac[i] = config_setting_get_int_elem(mac, i);
		}
	}

	mac = config_lookup(cf, "HOST");
	count = config_setting_length(mac);
	if(count == 6) {
		for (i = 0; i < count; i++) {
			host_mac[i] = config_setting_get_int_elem(mac, i);
		}
	}

	config_destroy(cf);

	/*------------------------------------------------------
				initialize ethernet connection
	------------------------------------------------------*/

	/* check rights */
	if (getuid() && geteuid()) {
		fprintf(stderr, "Error: No su rights!\n");
		exit(1);
	}

	/*------------------------------------------------------
						Transmitter
	------------------------------------------------------*/

	if ((ifindex = if_nametoindex(ifname)) == 0) {
		fprintf(stderr, "Error: Could not read address of interface '%s' for receiver!\n", ifname);
		exit(1);
	}

	/*prepare send header*/
	memcpy(send_buffer, client_mac, 6);
	memcpy(send_buffer+6, host_mac, 6);
	send_buffer[12] = 0x08; // X.75 -> X.75 allows network-generated reset and
	send_buffer[13] = 0x01; // clearing causes to be passed in either direction

	send_socket = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL));

	if (send_socket == -1) {
		fprintf(stderr, "Error: Could not open socket for receiver!");
	    exit(1);
	}

	memset(&sa, 0, sizeof (sa));
	sa.sll_family    = AF_PACKET;
	sa.sll_ifindex   = ifindex;
	sa.sll_protocol  = htons(ETH_P_ALL);

	/*------------------------------------------------------
						Receiver
	------------------------------------------------------*/

	recv_socket = socket(AF_PACKET, SOCK_DGRAM, htons(ETH_P_ALL));

	if (recv_socket == -1) {
		fprintf(stderr, "Error: Could not open socket for receiver!");
	  	exit(1);
	}

	struct ifreq ifr;
	bzero(&ifr, sizeof(struct ifreq));
	strncpy(ifr.ifr_name, ifname, sizeof(ifname));

	if (ioctl(recv_socket, SIOCGIFHWADDR, &ifr) == -1) {
		fprintf(stderr, "Error: Could not read local MAC address for receiver!\n");
	    exit(1);
	}

	memset(&ra, 0, sizeof(ra));
	ra.sll_family    = AF_PACKET;
	ra.sll_ifindex   = ifindex;
	ra.sll_protocol  = htons(0x0801);
	memcpy(ra.sll_addr, client_mac, 6);

	if (bind(recv_socket, (struct sockaddr *)&ra, sizeof(ra)) == -1) {
		fprintf(stderr, "Error: Could not bind socket for receiver!\n");
		exit(EXIT_FAILURE);
	}
}

/******************************************************************************
 * Send Data with length "length"
 ******************************************************************************/
void sendData(int length, char ctr, char* send_buffer, unsigned int id) {

	int sd;

	send_buffer[15] = (char) id;
	send_buffer[14] = ctr;

	sd = sendto(send_socket, send_buffer, length+16, MSG_DONTWAIT, (struct sockaddr *)&sa, sizeof (sa));
	if (sd <= 0) {
		fprintf(stderr, "\nError: sending Data\n");
	}
	if (errno == EAGAIN) {
		fprintf(stderr, "\nError: Buffer\n");
	}
}

/******************************************************************************
 * Send Data with length "length"
 ******************************************************************************/
void sendControl(char ctr,  char* send_buffer, unsigned int id) {

	int sd, i;

	send_buffer[15] = (char) id;
	send_buffer[14] = ctr;
	for (i = 16; i < CTR_BUF_SIZE; i++) {
		send_buffer[i] = 0x00;
	}

	sd = sendto(send_socket, send_buffer, CTR_BUF_SIZE, 0, (struct sockaddr *)&sa, sizeof (sa));
	if (sd == -1) {
		fprintf(stderr, "\nError: sending Control\n");
	}
}

/******************************************************************************
 * Receive Data
 ******************************************************************************/
char receive(int buf_size, char* rec_buffer) {

	int sd;

		sd = (int) recvfrom(recv_socket, (void*)rec_buffer, buf_size, 0, (struct sockaddr *)&ra, &rec_length);
		if(sd == -1) {
			printf("\nError: receiving\n");
			return 0x14;
		} else {
			return rec_buffer[0];
		}

}

/******************************************************************************
 * search possible devices and number of units
 ******************************************************************************/
uint16_t searchDevice(char* send_buffer, char* rec_buffer, unsigned int id) {
	uint16_t units;

	sendControl(0x20, send_buffer, id);
	char ctr = receive(CTR_BUF_SIZE, rec_buffer);
	memcpy(&units, rec_buffer+1, 2);
	units = units * 2;

	switch (ctr) {
		case 0x21:
			printf("found Virtex-5 with %u units\n", units);
			return units;
		case 0x22:
			printf("found Virtex-6 with %u units\n", units);
			return units;
		default:
			fprintf(stderr, "no Device: %d\n", ctr);
			return 0;
	}

}

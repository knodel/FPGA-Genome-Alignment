/*
 * ethernet.h
 *
 *  Created on: Aug 4, 2010
 *      Author: root
 */

#ifndef ETHERNET_H_
#define ETHERNET_H_

void initializeEthernetConnection(char* send_buffer);

void sendData(int length, char ctr,  char* send_buffer, unsigned int id);

void sendControl(char ctr,  char* send_buffer, unsigned int id);

char receive(int buf_size, char* rec_buffer);

uint16_t searchDevice(char* send_buffer, char* rec_buffer, unsigned int id);

double testMaxBandwidth(char* send_buffer, char* rec_buffer);

double testStreamBandwidth(char* send_buffer, char* rec_buffer);


#endif /* ETHERNET_H_ */

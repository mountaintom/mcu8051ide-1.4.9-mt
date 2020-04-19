/**
 * Very very simple demonstration code written in C language
 * @file demo_c_0.c
 */

// This file defines registers available in AT89x51 MCUs
// See /usr/share/sdcc/include/mcs51/ for alternatives
#include <at89x51.h>

unsigned long some_variable=0;	///< Documentation for this variable comes here
int i;				///< General purpose interator

/**
 * These lines are a doxygen documentation for this function
 * See doxygen manual for more details (http://www.stack.nl/~dimitri/doxygen/manual.html)
 * Note: Try to click on the 1st line of the function declaration and then press Ctrl+E
 * <b style="color: #FF0000">Some bold text</b>
 * @param somevalue Some agrument
 */
void someFunction(unsigned char somevalue)
{
	// P1 and P3 are variables defined in "at89x51.h"
	P1=somevalue;
	P3=somevalue^0xFF;
}

/** Main loop */
int main()
{
	// Infinite loop
	while(1) {
		for(i=0; i<255; i++) {
			someFunction(i+2);
			some_variable++;
		}
		some_variable-=22;
	}

	// Report success
	return 0;
}

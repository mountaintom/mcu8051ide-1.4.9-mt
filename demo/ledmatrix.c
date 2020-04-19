/**
 * Demonstration code for <b>MCU 8051 IDE</b>
 *
 * Virtual HW and C language
 * Requires MCU AT89C51 or similar ( [Project] -> [Edit project] -> [Select MCU] )
 * @file demo_c_0.c
 */

// Create virtual LED matrix and load configuration file "ledmatrix.vhc"
// [Virtual HW] -> [LED Matrix]

// To compile the code press F11 (This code is precompiled)
// To start simulator press F2
// To simulate the program press F6 (animate) or F7 (step) or F8 (step over) or F9 (run)

// To save some time you can use program hibernation function
// [Simulator] -> [Resume hibernated program] and select "ledmatrix.m5hib"


#include <at89x51.h>

static const char image[] = {
	0xb1, 0x9d, 0xbd, 0xb1,
	0xb7, 0xb7, 0x11, 0xff
};

int main()
{
	int i;
	while(1) {
		for(i=0; i<8; i++) {
			P1 = 0xff;
			P0 = image[i];
			P1 = (1 << i) ^ 255;
		}
	}
}

// Note: Sometimes people wonder how it is possible to
// write a program for MCU in C language. So please
// study this code or SDCC manual or another documents.
// And please do not ask me silly questions ... :)
// By the way my email is <martin.osmera@gmail.com>

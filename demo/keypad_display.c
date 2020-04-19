/**
 * Demonstration code for MCU 8051 IDE
 *
 * Create virtual multiplexed LED display
 * [Main menu] -> [Virtual HW] -> [Open]
 * and open file keypad_display.vhw .
 * Then press F2 and F9 to start simulation.
 *
 * Notes:
 *	F9 - stop simulation
 *	F2 - shut down simulator
 *
 * @file keypad_display.c
 */

#include <8051.h>
#define USE_INLINE_ASM 1

static const char keypad[] = {
  0xEF, 0xDF, 0xBF, 0x7F
};
static const char display_0[] = {
  0xf9, 0x64, 0x70, 0x48
};
static const char display_1[] = {
  0x59, 0x52, 0x42, 0x40
};
static const char display_2[] = {
  0xf8, 0x40, 0x50, 0xc6
};
static const char display_3[] = {
  0x79, 0xc0, 0x49, 0xc0
};

char state;
int row;

int main()
{
  while(1) {
    for(row=0; row<4; row++) {
      P1=keypad[row];

      #if USE_INLINE_ASM
        // Inline assembler
        _asm
          mov	_state, P1
        _endasm;
      #else
        state=P1;
      #endif

      state&=0x0f;
      state^=0x0f;

      if(state & 1) {
        state=0;
      } else if(state & 2) {
        state=1;
      } else if(state & 4) {
        state=2;
      } else if(state & 8) {
        state=3;
      } else {
        continue;
      }

      switch(row) {
        case 0:
          P3=display_0[state];
          break;
        case 1:
          P3=display_1[state];
          break;
        case 2:
          P3=display_2[state];
          break;
        case 3:
          P3=display_3[state];
          break;
      }
    }
  }
}

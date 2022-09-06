/*******************************************************************************
* Copyright (C) 2016 Mike Ferrara (mikef@mrf.sonoma.ca.us), All rights reserved.
*
*
* Filename:     ks8769m.c
*
* Description: SP6T control of Keysight 8769M switch with 5V latching coils
* 
*
*******************************************************************************/
//#define TRACE_PRINT 1

#include "OSandPlatform.h"

#define GLOBAL_KS8769M
#include "ks8769m.h"

#define KS8769M_DELAY 200

#define pulseCoil(coil) gpio_set(coil);delayms(KS8769M_DELAY);gpio_clear(coil)

void deselectAll8769(void) {
  pulseCoil(S1U);
  pulseCoil(S2U);
  pulseCoil(S3U);
  pulseCoil(S4U);
  pulseCoil(S5U);
}


void set8769(sp8tSel_t sel) {
  deselectAll8769();
  switch (sel) {
  case J1:
    pulseCoil(S1D);
    break;
  case J2:
    pulseCoil(S2D);
    break;
  case J3:
    pulseCoil(S3D);
    break;
  case J4:
    pulseCoil(S4D);
    break;
  case J5:
    pulseCoil(S5D);
    break;
  case J6:
    deselectAll8769();
    break;
  default:
    ;
  }
}
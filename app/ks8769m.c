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

#define KS8769M_DELAY 100

#define pulseCoil(coil) gpio_set(coil);delayms(KS8769M_DELAY);gpio_clear(coil)

void deselectAll8769(void) {
  gpio_set(S1U); delayms(60);
  gpio_set(S2U); delayms(60);
  gpio_set(S3U); delayms(60);
  gpio_set(S4U); delayms(60);
  gpio_set(S5U); delayms(60);
  gpio_clear(GPIOC,GPIO0|GPIO2|GPIO4|GPIO6);
  gpio_clear(GPIOA,GPIO4);

  gpio_clear(LED1);
  gpio_clear(LED2);
  gpio_clear(LED3);
  
  /*  pulseCoil(S1U);
  pulseCoil(S2U);
  pulseCoil(S3U);
  pulseCoil(S4U);
  pulseCoil(S5U);*/
}

void set8769(sp8tSel_t sel) {
  deselectAll8769();
  switch (sel) {
  case J1:
    pulseCoil(S1D);
    gpio_set(LED1);
    gpio_clear(LED2);
    gpio_clear(LED3);
    break;
  case J2:
    pulseCoil(S2D);
    gpio_clear(LED1);
    gpio_set(LED2);
    gpio_clear(LED3);
    break;
  case J3:
    pulseCoil(S3D);
    gpio_set(LED1);
    gpio_set(LED2);
    gpio_clear(LED3);
    break;
  case J4:
    pulseCoil(S4D);
    gpio_clear(LED1);
    gpio_clear(LED2);
    gpio_set(LED3);
    break;
  case J5:
    pulseCoil(S5D);
    gpio_set(LED1);
    gpio_clear(LED2);
    gpio_set(LED3);
    break;
  case J6:
    deselectAll8769();
    break;
  default:
    ;
  }
}

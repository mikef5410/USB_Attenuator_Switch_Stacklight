/*******************************************************************************
*           Copyright (C) 2015 Michael R. Ferrara, All rights reserved.
*
*                       Santa Rosa, CA 95404
*                       Tel:(707)536-1330
*
* Filename:     stacklight.c
*
* Description: STACKLIGHT "driver"
*
*******************************************************************************/
//#define TRACE_PRINT 1

#define GLOBAL_STACKLIGHT
#include "stacklight.h"

#include "OSandPlatform.h"
#include <limits.h>

// 30ms is enough to switch the stacklightuator
#define STACKLIGHT_DLY 30

#define STACKRED S2U
#define STACKYEL S4U
#define STACKGRN S3D

static uint32_t on_time = 100;
static uint32_t off_time = 900;
static uint32_t color=0;
static uint32_t count=0;
static uint32_t taskRun=1;

void stackRed(int on) {

  hvOn(1);//Charge up the output cap
  
  if (on) {
    gpio_clear(STACKYEL);
    gpio_clear(STACKGRN);
    gpio_set(STACKRED);
  } else {
    gpio_clear(STACKRED);
    hvOn(0);
  }

}

void stackYel(int on) {

  hvOn(1);//Charge up the output cap
  
  if (on) {
    gpio_clear(STACKRED);
    gpio_clear(STACKGRN);
    gpio_set(STACKYEL);
  } else {
    gpio_clear(STACKYEL);
    hvOn(0);
  }

}


void stackGrn(int on) {

  hvOn(1);//Charge up the output cap
  
  if (on) {
    gpio_clear(STACKRED);
    gpio_clear(STACKYEL);
    gpio_set(STACKGRN);
  } else {
    gpio_clear(STACKGRN);
    hvOn(0);
  }

}

// Color or 0 for off, on time (ms), off time (ms), count (0 for infinite)
uint32_t stackNotify(uint32_t col, uint32_t on, uint32_t off, uint32_t cnt)
{
  if (col) {
    if (on==0) { //Solid on
      taskRun=0;
      switch(col) {
      case R: stackRed(1); break;
      case Y: stackYel(1); break;
      case G: stackGrn(1); break;
      }
    } else {
      on_time=on;
      off_time = (off) ? off : on*2;
      color=col;
      count=cnt;
    }
  } else { //Turn off
    color=0;
    taskRun=1;
  }

  return(0);
}
    
portTASK_FUNCTION(vStackTask, pvParameters)
{
  uint32_t hv = 0;
  uint32_t lastColor=0;
  (void)pvParameters;
  uint32_t cnt = 0;
  
  while (taskRun) {
    if (color && !hv) {
      hvOn(1);
      hv=1;
    }
    if (color && count) {
      if (cnt==0) {
        cnt=count;
      } else {
        cnt--;
        if (cnt == 0) color=0;
      }
    }
    switch(color) {
    case R:
      gpio_set(STACKRED);
      delayms(on_time);
      gpio_clear(STACKRED);
      delayms(off_time);
      break;
    case Y:
      gpio_set(STACKYEL);
      delayms(on_time);
      gpio_clear(STACKYEL);
      delayms(off_time);
      break;
    case G:
      gpio_set(STACKGRN);
      delayms(on_time);
      gpio_clear(STACKGRN);
      delayms(off_time);
      break;
    case 0:
      if (lastColor) {
        gpio_clear(STACKRED);
        gpio_clear(STACKYEL);
        gpio_clear(STACKGRN);
        hvOn(0);
        hv=0;
        cnt=0;
      }
      //FALLTHRU
    default:
      taskYIELD();
    }
    lastColor=color;
  }
}

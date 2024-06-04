/*******************************************************************************
*           Copyright (C) 2015 Michael R. Ferrara, All rights reserved.
*
*                       Santa Rosa, CA 95404
*                       Tel:(707)536-1330
*
* Filename:     bsp.c
*
* Description: BSP "driver"
*
*******************************************************************************/
//#define TRACE_PRINT 1

#define GLOBAL_BSP
#include "bsp.h"
#include "OSandPlatform.h"

static const clock_scale_t clock32F411 = {
  //96 MHz, 16MHz crystal
  .pllm = 16, //1MHz reference
  .plln = 192, // 192MHz VCO
  .pllp = 2, // 96 MHz core clock
  .pllq = 4, // 48 MHz USB clock
  .hpre = RCC_CFGR_HPRE_DIV_NONE, // 96MHz AHB
  .ppre1 = RCC_CFGR_PPRE_DIV_2,  
  .ppre2 = RCC_CFGR_PPRE_DIV_2,
  .flash_config = FLASH_ACR_ICE | FLASH_ACR_DCE |
  FLASH_ACR_LATENCY_3WS,
  .apb1_frequency = 48000000,
  .apb2_frequency = 48000000,
};

void greenOn(int on)
{
  if (on) {
    gpio_set(GREENLED);
  } else {
    gpio_clear(GREENLED);
  }
  return;
}


void redOn(int on)
{
  if (on) {
    gpio_set(REDLED);
  } else {
    gpio_clear(REDLED);
  }
  return;
}

void vhvTimerExpired(xTimerHandle pxTimer)
{
  /* Optionally do something if the pxTimer parameter is NULL. */
  //configASSERT( pxTimer );

  /* Which timer expired? */
  //lArrayIndex = ( long ) pvTimerGetTimerID( pxTimer );
  
  /* Do not use a block time if calling a timer API function from a timer callback
     function, as doing so could cause a deadlock! */
  xTimerStop( pxTimer, 0 );
  if (! stacklightForceHV ) {
    hvOn(0);
  }
}

  
void hvOn(int on)
{
  if (on) {
    if (! hvState ) {
      gpio_set(HVEnable);
      delayms(60); //Power-up time is about 40ms
      hvState=1;
    }
    xTimerReset(xTimers[0],5);
  }  else {
    gpio_clear(HVEnable);
    hvState=0;
  }
}


void setupClocks(void)
{

  rcc_clock_setup_hse_3v3(&clock32F411);
  SystemCoreClock = 96000000;
  return;
}

void setupGPIOs(void)
{
  rcc_periph_clock_enable(RCC_GPIOA);
  rcc_periph_clock_enable(RCC_GPIOB);
  rcc_periph_clock_enable(RCC_GPIOC);
  rcc_periph_clock_enable(RCC_GPIOD);

  // Setup USBOTG Clocking and pins
  rcc_periph_clock_enable(RCC_OTGFS);
  gpio_mode_setup(GPIOA, GPIO_MODE_AF, GPIO_PUPD_NONE,
                  GPIO9 | GPIO11 | GPIO12);
  gpio_set_af(GPIOA, GPIO_AF10, GPIO9 | GPIO11 | GPIO12);
  

  //Red LED
  gpio_mode_setup(GPIOA, GPIO_MODE_OUTPUT, GPIO_PUPD_NONE, GPIO0);
  gpio_set_output_options(GPIOA, GPIO_OTYPE_PP, GPIO_OSPEED_2MHZ, GPIO0);
  gpio_clear(GPIOA,GPIO0);
  
  //Grn LED
  gpio_mode_setup(GPIOB, GPIO_MODE_OUTPUT, GPIO_PUPD_NONE, GPIO0);
  gpio_set_output_options(GPIOB, GPIO_OTYPE_PP, GPIO_OSPEED_2MHZ, GPIO0);
  gpio_clear(GPIOB,GPIO0);
  
  //Control IOs
  gpio_mode_setup(GPIOC, GPIO_MODE_OUTPUT, GPIO_PUPD_NONE, GPIO0|GPIO1|
                  GPIO2|GPIO3|GPIO4|GPIO5|GPIO6|GPIO7|GPIO8|
                  GPIO9|GPIO10|GPIO11|GPIO12);
  gpio_set_output_options(GPIOC, GPIO_OTYPE_PP, GPIO_OSPEED_2MHZ, GPIO0|GPIO1|
                  GPIO2|GPIO3|GPIO4|GPIO5|GPIO6|GPIO7|GPIO8|
                  GPIO9|GPIO10|GPIO11|GPIO12);
  gpio_clear(GPIOC, GPIO0|GPIO1|
                  GPIO2|GPIO3|GPIO4|GPIO5|GPIO6|GPIO7|GPIO8|
                  GPIO9|GPIO10|GPIO11|GPIO12);

  gpio_mode_setup(GPIOA, GPIO_MODE_OUTPUT, GPIO_PUPD_NONE, GPIO4|GPIO5|GPIO8|GPIO9|GPIO10);
  gpio_set_output_options(GPIOA, GPIO_OTYPE_PP, GPIO_OSPEED_2MHZ, GPIO4|GPIO5|GPIO8|GPIO9|GPIO10);
  gpio_clear(GPIOA, GPIO4|GPIO5|GPIO8|GPIO9|GPIO10 );
  gpio_set(GPIOA,GPIO10|GPIO9|GPIO8);
  delayms(100);
  gpio_clear(GPIOA,GPIO10|GPIO9|GPIO8);
  
  
  //HV Enable
  gpio_mode_setup(GPIOD, GPIO_MODE_OUTPUT, GPIO_PUPD_NONE, GPIO2);
  gpio_set_output_options(GPIOD, GPIO_OTYPE_PP, GPIO_OSPEED_2MHZ, GPIO2);
  gpio_clear(GPIOD, GPIO2);

  eeprom9366_init();
  return;
}

void setupNVIC(void)
{
  const uint32_t interrupt_priority_group4 = (0x3 << 8); // 15 priority interrupts, no sub-priorities
  scb_set_priority_grouping(interrupt_priority_group4);
  for (int irqNum=0; irqNum<=NVIC_IRQ_COUNT ; irqNum++) {
    nvic_set_priority(irqNum, 0x6f);
  }
  nvic_set_priority(-4,0); //MMU Fault
  nvic_set_priority(-5,0); //Bus Fault
  nvic_set_priority(-6,0); //Usage Fault
  nvic_set_priority(-11,0); //SVCall
  nvic_set_priority(-14,0); //PendSV
  nvic_set_priority(-15,0); //SysTick

  return;
}

void setupTimers(void)
{
  xTimers[0] = xTimerCreate("HVTimer", (HVTimeout/portTICK_RATE_MS),
                            pdFALSE, (void *) 0, vhvTimerExpired );
}
  

void Delay(volatile uint32_t nCount)
{
  while (nCount--) {
    __asm__("nop");
  }
}

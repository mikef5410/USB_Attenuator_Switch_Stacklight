/* shamelessly stolen from the libopencm3-examples and modified ...
 * This file is part of the libopencm3 project.
 *
 * Copyright (C) 2010 Gareth McMullin <gareth@blacksphere.co.nz>
 *
 * This library is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this library.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "OSandPlatform.h"

#include <libopencm3/stm32/f4/nvic.h>
#include <libopencm3/usb/cdc.h>

#include "instr_task.h"
#include "usbcmdio.h"

#define MAGIC (0xAA)
static char serialNumber[24]="0";
static char manufacturer[64]="MF";
static char product[64]="USB Switch/Attenuator/Stacklight";
static uint16_t vendorID = 0x4161;
static uint16_t productID = 0x00ff;

xQueueHandle UARTinQ;


usbd_device *CDCACM_dev;
static xSemaphoreHandle usbInterrupted = NULL;

static struct usb_device_descriptor dev = {
  .bLength = USB_DT_DEVICE_SIZE,
  .bDescriptorType = USB_DT_DEVICE,
  .bcdUSB = 0x0200,
  .bDeviceClass = USB_CLASS_CDC,
  .bDeviceSubClass = 0,
  .bDeviceProtocol = 0,
  .bMaxPacketSize0 = 64,
  .idVendor = 0x4161,
  .idProduct = 0x0001,
  .bcdDevice = 0x0200,
  .iManufacturer = 1,
  .iProduct = 2,
  .iSerialNumber = 3,
  .bNumConfigurations = 1,
};

/*
 * This notification endpoint isn't implemented. According to CDC spec it's
 * optional, but its absence causes a NULL pointer dereference in the
 * Linux cdc_acm driver.
 */
static const struct usb_endpoint_descriptor comm_endp[] = {{
    .bLength = USB_DT_ENDPOINT_SIZE,
    .bDescriptorType = USB_DT_ENDPOINT,
    .bEndpointAddress = 0x83,
    .bmAttributes = USB_ENDPOINT_ATTR_INTERRUPT,
    .wMaxPacketSize = 16,
    .bInterval = 255,
  } };

static const struct usb_endpoint_descriptor data_endp[] = {{
    .bLength = USB_DT_ENDPOINT_SIZE,
    .bDescriptorType = USB_DT_ENDPOINT,
    .bEndpointAddress = 0x02,
    .bmAttributes = USB_ENDPOINT_ATTR_BULK,
    .wMaxPacketSize = 64,
    .bInterval = 1,
  }, {
    .bLength = USB_DT_ENDPOINT_SIZE,
    .bDescriptorType = USB_DT_ENDPOINT,
    .bEndpointAddress = 0x82,
    .bmAttributes = USB_ENDPOINT_ATTR_BULK,
    .wMaxPacketSize = 64,
    .bInterval = 1,
  } };

// Bulk data pipes for control I/O
static const struct usb_endpoint_descriptor bulkctrl_endp[] = {{
    .bLength = USB_DT_ENDPOINT_SIZE,
    .bDescriptorType = USB_DT_ENDPOINT,
    .bEndpointAddress = 0x01,
    .bmAttributes = USB_ENDPOINT_ATTR_BULK,
    .wMaxPacketSize = 64,
    .bInterval = 1,
  }, {
    .bLength = USB_DT_ENDPOINT_SIZE,
    .bDescriptorType = USB_DT_ENDPOINT,
    .bEndpointAddress = 0x81,
    .bmAttributes = USB_ENDPOINT_ATTR_BULK,
    .wMaxPacketSize = 64,
    .bInterval = 1,
  } };

static const struct {
  struct usb_cdc_header_descriptor header;
  struct usb_cdc_call_management_descriptor call_mgmt;
  struct usb_cdc_acm_descriptor acm;
  struct usb_cdc_union_descriptor cdc_union;
} __attribute__((packed)) cdcacm_functional_descriptors = {
  .header = {
    .bFunctionLength = sizeof(struct usb_cdc_header_descriptor),
    .bDescriptorType = CS_INTERFACE,
    .bDescriptorSubtype = USB_CDC_TYPE_HEADER,
    .bcdCDC = 0x0110,
  },
  .call_mgmt = {
    .bFunctionLength = sizeof(struct usb_cdc_call_management_descriptor),
    .bDescriptorType = CS_INTERFACE,
    .bDescriptorSubtype = USB_CDC_TYPE_CALL_MANAGEMENT,
    .bmCapabilities = 0,
    .bDataInterface = 1,
  },
  .acm = {
    .bFunctionLength = sizeof(struct usb_cdc_acm_descriptor),
    .bDescriptorType = CS_INTERFACE,
    .bDescriptorSubtype = USB_CDC_TYPE_ACM,
    .bmCapabilities = 0,
  },
  .cdc_union = {
    .bFunctionLength = sizeof(struct usb_cdc_union_descriptor),
    .bDescriptorType = CS_INTERFACE,
    .bDescriptorSubtype = USB_CDC_TYPE_UNION,
    .bControlInterface = 0,
    .bSubordinateInterface0 = 1,
  }
};

static const struct usb_interface_descriptor comm_iface[] = {{
    .bLength = USB_DT_INTERFACE_SIZE,
    .bDescriptorType = USB_DT_INTERFACE,
    .bInterfaceNumber = 0,
    .bAlternateSetting = 0,
    .bNumEndpoints = 1,
    .bInterfaceClass = USB_CLASS_CDC,
    .bInterfaceSubClass = USB_CDC_SUBCLASS_ACM,
    .bInterfaceProtocol = USB_CDC_PROTOCOL_AT,
    .iInterface = 0,

    .endpoint = comm_endp,

    .extra = &cdcacm_functional_descriptors,
    .extralen = sizeof(cdcacm_functional_descriptors)
  } };

static const struct usb_interface_descriptor data_iface[] = {{
    .bLength = USB_DT_INTERFACE_SIZE,
    .bDescriptorType = USB_DT_INTERFACE,
    .bInterfaceNumber = 1,
    .bAlternateSetting = 0,
    .bNumEndpoints = 2,
    .bInterfaceClass = USB_CLASS_DATA,
    .bInterfaceSubClass = 0,
    .bInterfaceProtocol = 0,
    .iInterface = 0,

    .endpoint = data_endp,
  } };

//My bulk control interface
static const struct usb_interface_descriptor bulkctrl_iface[] = {{
    .bLength = USB_DT_INTERFACE_SIZE,
    .bDescriptorType = USB_DT_INTERFACE,
    .bInterfaceNumber = 2,
    .bAlternateSetting = 0,
    .bNumEndpoints = 2,
    .bInterfaceClass = 0xff,   //vendor-specific
    .bInterfaceSubClass = 0xff, //vendor-specific
    .bInterfaceProtocol = 0xff, //vendor-specific
    .iInterface = 0,

    .endpoint = bulkctrl_endp,
  } };

static const struct usb_interface ifaces[] = {{
    .num_altsetting = 1,
    .altsetting = comm_iface,
  }, {
    .num_altsetting = 1,
    .altsetting = data_iface,
  }, { //My bulk control interface
    .num_altsetting = 1,
    .altsetting = bulkctrl_iface,
  }
};

static const struct usb_config_descriptor config = {
  .bLength = USB_DT_CONFIGURATION_SIZE,
  .bDescriptorType = USB_DT_CONFIGURATION,
  .wTotalLength = 0,
  .bNumInterfaces = 3,
  .bConfigurationValue = 1,
  .iConfiguration = 0,
  .bmAttributes = 0x80,
  .bMaxPower = 0x64, //200mA

  .interface = ifaces,
};

static const char * usb_strings[] = {
  manufacturer,
  product,
  serialNumber,
};

/* Buffer to be used for control requests. */
uint8_t usbd_control_buffer[128];

static int cdcacm_control_request(usbd_device *usbd_dev,
                                  struct usb_setup_data *req,
                                  uint8_t **buf, uint16_t *len,
                                  usbd_control_complete_callback *complete)
{
  (void)complete;
  (void)buf;
  (void)usbd_dev;

  switch (req->bRequest) {
  case USB_CDC_REQ_SET_CONTROL_LINE_STATE: {
    /*
     * This Linux cdc_acm driver requires this to be implemented
     * even though it's optional in the CDC spec, and we don't
     * advertise it in the ACM functional descriptor.
     */
    return 1;
  }
  case USB_CDC_REQ_SET_LINE_CODING:
    if (*len < sizeof(struct usb_cdc_line_coding)) {
      return 0;
    }

    return 1;
  }
  return 0;
}

static void cdcacm_data_rx_cb(usbd_device *usbd_dev, uint8_t ep)
{
  (void)ep;

  portBASE_TYPE rval;
  portBASE_TYPE pxHigherPriTaskWoken;
  
  char buf[64];

  int len = usbd_ep_read_packet(usbd_dev, 0x02, buf, 64);

        
  if (len) {
    for (int j = 0; j<len; j++) {
      rval=xQueueSendFromISR(UARTinQ,&(buf[j]),&pxHigherPriTaskWoken);
      (void)rval;
      //if (rval != pdTRUE) { queue was full; }
    }
  }
}

static void bulkctrl_data_rx_cb(usbd_device *usbd_dev, uint8_t ep)
{
  (void)ep;

  portBASE_TYPE rval;
  portBASE_TYPE pxHigherPriTaskWoken;
  
  char buf[65];
  buf[0]=(uint8_t)FLOW_USB;

  int len = usbd_ep_read_packet(usbd_dev, 0x01, buf+1, 64);
  if (len) {
    redOn(1);
    rval=xQueueSendFromISR(CTRLinQ,&buf,&pxHigherPriTaskWoken);
    redOn(0);
    (void)pxHigherPriTaskWoken;
    (void)rval;
    //if (rval != pdTRUE) { queue was full; }
  }
}

static void cdcacm_set_config(usbd_device *usbd_dev, uint16_t wValue)
{
  (void)wValue;

  //CDCACM data endpoints 0x2,0x82
  usbd_ep_setup(usbd_dev, 0x02, USB_ENDPOINT_ATTR_BULK, 64,
                cdcacm_data_rx_cb);
  usbd_ep_setup(usbd_dev, 0x82, USB_ENDPOINT_ATTR_BULK, 64, NULL);
  //CDCACM interrupt endpoint 0x83
  usbd_ep_setup(usbd_dev, 0x83, USB_ENDPOINT_ATTR_INTERRUPT, 16, NULL);

  //Bulk control endpoints 0x1,0x81
  usbd_ep_setup(usbd_dev, 0x01, USB_ENDPOINT_ATTR_BULK, 64,
                bulkctrl_data_rx_cb);
  usbd_ep_setup(usbd_dev, 0x81, USB_ENDPOINT_ATTR_BULK, 64, NULL);

  usbd_register_control_callback(
                                 usbd_dev,
                                 USB_REQ_TYPE_CLASS | USB_REQ_TYPE_INTERFACE,
                                 USB_REQ_TYPE_TYPE | USB_REQ_TYPE_RECIPIENT,
                                 cdcacm_control_request);
  USBConfigured=1;

}

void otg_fs_isr(void) __attribute__ ((interrupt ));
void otg_fs_isr(void)
{
  portBASE_TYPE HPTw = pdFALSE;

  nvic_disable_irq(NVIC_OTG_FS_IRQ);
  xSemaphoreGiveFromISR(usbInterrupted, &HPTw);
  portEND_SWITCHING_ISR( HPTw );
}

extern const struct _usbd_driver stm32f411_usb_driver;

void copyFromEE(char *dest, uint16_t addr, uint8_t len)
{
  uint8_t j=0;
  uint16_t a=addr;

  for (j=0; j<len; j++) {
    dest[j] = eeprom9366_read(a);
    a++;
  }
  dest[j]=0;
  return;
}

//Get USB identifiers from EEPROM if the first byte of eeprom matches MAGIC
void readEEprom(void)
{
  uint8_t dataValid;
  uint16_t strPtr;
  uint8_t strLen;
  
  dataValid = eeprom9366_read(0);
  if (dataValid != MAGIC) {
    return;
  }
  //First VendorID, little endian
  strLen = eeprom9366_read(1);
  strPtr = strLen;
  strLen = eeprom9366_read(2);
  strPtr += strLen * 256;
  if (strPtr) {
    dev.idVendor=strPtr;
    vendorID=strPtr;
  }

  //Next ProductID, little endian
  strLen = eeprom9366_read(3);
  strPtr = strLen;
  strLen = eeprom9366_read(4);
  strPtr += strLen * 256;
  if (strPtr) {
    dev.idProduct=strPtr;
    productID=strPtr;
  }
  
  // String 1: Manufacturer
  strLen = eeprom9366_read(5);
  strPtr = strLen;
  strLen = eeprom9366_read(6);
  strPtr += strLen * 256;
  strLen = eeprom9366_read(7);
  if (strPtr && strLen) {
    copyFromEE(manufacturer, strPtr, strLen);
  }

  // String 2: Product
  strLen = eeprom9366_read(8);
  strPtr = strLen;
  strLen = eeprom9366_read(9);
  strPtr += strLen * 256;
  strLen = eeprom9366_read(0xA);
  if (strPtr && strLen) {
    copyFromEE(product, strPtr, strLen);
  }

  // String 3: Serial Number
  strLen = eeprom9366_read(0xB);
  strPtr = strLen;
  strLen = eeprom9366_read(0xC);
  strPtr += strLen * 256;
  strLen = eeprom9366_read(0xD);
  if (strPtr && strLen) {
    copyFromEE(serialNumber, strPtr, strLen);
  }
  
}

uint8_t shortProdID(void)
{
  return((uint8_t)(productID % 256));
}

portTASK_FUNCTION(vUSBCDCACMTask, pvParameters)
{
  usbd_device *usbd_dev;
  char id[24];
  
  (void)(pvParameters);//unused params

  UARTinQ = xQueueCreate( 256, sizeof(char));
  CTRLinQ = xQueueCreate( 2, sizeof(cmd_packet_t));

  //Default enumeration descriptors ...
  desig_get_unique_id_as_string(id,24); //Copy device SN to USB reported SN
  //strncpy(serialNumber,id,24);
  strncpy(serialNumber,id + strlen(id)- 8,24);

  dev.idVendor=vendorID;
  dev.idProduct=productID;

  //If enumeration info is in EEPROM, use it, instead.
  readEEprom();
  
  vSemaphoreCreateBinary(usbInterrupted);
  //Take the semaphore nonblocking to ensure in the correct state
  xSemaphoreTake(usbInterrupted,0);

  nvic_disable_irq(NVIC_OTG_FS_IRQ);
  usbd_dev = usbd_init(&stm32f411_usb_driver, &dev, &config,
                       usb_strings, 3,
                       usbd_control_buffer, sizeof(usbd_control_buffer));

  CDCACM_dev=usbd_dev;
  usbd_register_set_config_callback(usbd_dev, cdcacm_set_config);
  nvic_set_priority(NVIC_OTG_FS_IRQ,0xdf);

  //Now handle normal USB traffic with interrupts.
  nvic_enable_irq(NVIC_OTG_FS_IRQ);
  while (1) {
    if (pdPASS == xSemaphoreTake(usbInterrupted,portMAX_DELAY)) {
      taskENTER_CRITICAL();
      usbd_poll(usbd_dev);
      taskEXIT_CRITICAL();
      nvic_enable_irq(NVIC_OTG_FS_IRQ);
    }
  }
}

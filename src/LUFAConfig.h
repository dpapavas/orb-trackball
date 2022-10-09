#ifndef _LUFA_CONFIG_H_
#define _LUFA_CONFIG_H_

#define USE_FLASH_DESCRIPTORS
#define FIXED_CONTROL_ENDPOINT_SIZE 8
#define FIXED_NUM_CONFIGURATIONS 1
#define USB_DEVICE_ONLY
#define USE_STATIC_OPTIONS (USB_DEVICE_OPT_FULLSPEED \
                            | USB_OPT_REG_ENABLED \
                            | USB_OPT_AUTO_PLL)

#endif

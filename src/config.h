#ifndef _CONFIG_H_
#define _CONFIG_H_

/* Uncomment this to enable a serial console. */

/* #define ENABLE_CDC */

/* USB device identifiers */

#define MANUFACTURER L"Dimitris Papavasiliou"
#define PRODUCT L"The Orb"
#define VENDOR_ID 0x03eb
#define PRODUCT_ID 0x2041

/* The sensor resolution, in CPI. Should be a multiple of 50. */

#define RESOLUTION 16000

/* The polling interval in ms. */

#define POLLING_INTERVAL 2

/* GPIO pin numbers, where each of the five buttons and the common
 * ground are attached. */

#define BUTTON_GROUND PIND6
#define BUTTON_A PIND4
#define BUTTON_B PIND5
#define BUTTON_C PIND2
#define BUTTON_D PIND3
#define BUTTON_E PIND1

/* Mouse button assignments */

#define BUTTONS BUTTON_C, BUTTON_B, BUTTON_A, BUTTON_E

/* Switch debounce interval, in number of polling intervals. */

#define DEBOUNCE_INTERVAL 5

/* If defined, this button will act as a toggle that makes the ball
 * act as a wheel, or rather as two wheels, vertical and
 * horizontal. */

#define SCROLL_BUTTON BUTTON_D

/* Scroll wheel speed coefficients. */

#define WHEEL_SENSITIVITY_X 0.35
#define WHEEL_SENSITIVITY_Y 0.35

/* Pointer speed coefficient and rotation in degrees. */

#define POINTER_SENSITIVITY 0.012
#define POINTER_ROTATION -22

#endif

#include <stdio.h>
#include <stdbool.h>
#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr/power.h>
#include <avr/sleep.h>
#include <util/delay.h>

#include "config.h"
#include "srom.h"

#define T_STDWN 0.5
#define T_WAKEUP 50e3
#define T_SRAD 160
#define T_SWWR 180
#define T_SRWR 20
#define T_SRAD_MOTBR 35
#define T_BEXIT 0.5
#define T_NCS_SCLK 0.12
#define T_SCLK_NCS_READ 0.12
#define T_SCLK_NCS_WRITE 35

#define DDRSPI DDRB
#define PORTSPI PORTB
#define PINSS PINB0
#define PINSCL PINB1
#define PINMOSI PINB2
#define PINMISO PINB3

/* Undefine the USB product id, previously defined in config.h.  We
 * don't need it here. */

#undef PRODUCT_ID

#define PRODUCT_ID 0x0
#define MOTION 0x2
#define RESOLUTION_L 0x0e
#define RESOLUTION_H 0x0f
#define CONFIG2 0x10
#define ANGLE_TUNE 0x11
#define SROM_ENABLE 0x13
#define SROM_ID 0x2a
#define POWER_UP_RESET 0x3a
#define SHUTDOWN 0x3b
#define INVERSE_PRODUCT_ID 0x3f
#define MOTION_BURST 0x50
#define SROM_LOAD_BURST 0x62

void initialize_usb(void);
void wait_for_host(void);
void update_axes(int16_t delta_x, int16_t delta_y, bool scroll);
void do_usb_tasks(void);

static uint8_t transceive(uint8_t c)
{
    SPDR = c;

    while (!(SPSR & (1 << SPIF)));

    return SPDR;
}

static void assert_ncs(void)
{
    PORTSPI &= ~(1 << PINSS);
}

static void deassert_ncs(void)
{
    PORTSPI |= (1 << PINSS);
}

static uint8_t read(uint8_t addr)
{
    assert_ncs();
    _delay_us(T_NCS_SCLK);

    transceive(addr);
    _delay_us(T_SRAD);
    uint8_t x = transceive(0);

    _delay_us(T_SCLK_NCS_READ);
    deassert_ncs();
    _delay_us(T_SRWR - T_SCLK_NCS_READ);

    return x;
}

static void write(uint8_t addr, uint8_t data)
{
    assert_ncs();
    _delay_us(T_NCS_SCLK);

    transceive(addr | 0x80);
    transceive(data);

    _delay_us(T_SCLK_NCS_WRITE);
    deassert_ncs();
    _delay_us(T_SWWR - T_SCLK_NCS_WRITE);
}

static void reset(void)
{
    /* Shut down. */

    deassert_ncs();
    _delay_us(T_SRWR);

    write(SHUTDOWN, 0xb6);
    _delay_us(T_STDWN);

    /* Wake up. */

    deassert_ncs();
    _delay_us(T_SRWR);

    write(POWER_UP_RESET, 0x5a);
    _delay_us(T_WAKEUP);

    /* Read all motion registers. */

    for (int i = 2; i < 7; i++) {
        read(i);
    }

    /* Download SROM. */

    write(CONFIG2, 0);
    write(SROM_ENABLE, 0x1d);
    _delay_ms(10);
    write(SROM_ENABLE, 0x18);

    assert_ncs();
    _delay_us(T_NCS_SCLK);

    transceive(SROM_LOAD_BURST | 0x80);

    for (unsigned int i = 0;
         i < sizeof(srom_data) / sizeof(srom_data[0]);
         i++) {
        _delay_us(15);
        transceive(pgm_read_byte(srom_data + i));
    }

    _delay_us(15);
    deassert_ncs();

    _delay_us(200 - 15);
#ifdef ENABLE_CDC
    const uint8_t i =
#endif
        read(SROM_ID);

    write(CONFIG2, 0);

#ifdef ENABLE_CDC
    printf("ID: %x, %x, %x\n", read(PRODUCT_ID), read(INVERSE_PRODUCT_ID), i);
#endif
}

int main(void)
{
    clock_prescale_set(clock_div_1);

    /* Keep NRESET high. */

    DDRD &= ~(1 << PIND0);
    PORTD |= (1 << PIND0);

    /* Initialize the SPI port. */

    DDRSPI |= (1 << PINMOSI) | (1 << PINSS) | (1 << PINSCL);
    PORTSPI |= (1 << PINSS);
    SPCR = (1 << SPE) | (1 << MSTR) | (1 << SPI2X) | (1 << CPOL) | (1 << CPHA);

    /* Set up the buttons. */

    PORTD &= ~(1 << BUTTON_GROUND);
    DDRD |= (1 << BUTTON_GROUND);
    for (int i = 1; i <= 6 ; i++) {
        if (i == BUTTON_GROUND) {
            continue;
        }

        DDRD &= ~(1 << i);
        PORTD |= (1 << i);
    }

    /* Reset and configure the sensor. */

    reset();

    {
        uint16_t r = RESOLUTION / 50;

        write(RESOLUTION_L, (uint8_t)(r & 0xff));
        write(RESOLUTION_H, (uint8_t)(r >> 8 & 0xff));
    }

    write(ANGLE_TUNE, POINTER_ROTATION);

    initialize_usb();
    wait_for_host();

#ifdef ENABLE_CDC
    puts("Hello world.");
    printf("Resolution: %u\n", ((uint16_t)read(RESOLUTION_H) << 8
                                | read(RESOLUTION_L)));
#endif

    write(MOTION_BURST, 0);

    while(true) {
#ifdef ENABLE_CDC
#define N 12
#else
#define N 6
#endif
        uint8_t v[N];

        assert_ncs();
        _delay_us(T_NCS_SCLK);

        transceive(MOTION_BURST);
        _delay_us(T_SRAD_MOTBR);

        v[0] = transceive(0);

        int delta_x, delta_y;

        if ((v[0] & 0x80) > 0) {
            for (int i = 1; i < N; i++) {
                v[i] = transceive(0);
            }

            delta_x = *(int16_t *)(v + 2);
            delta_y = *(int16_t *)(v + 4);
        } else {
            delta_x = 0;
            delta_y = 0;
        }

        deassert_ncs();
        /* _delay_us(T_BEXIT); */
#undef N

#ifdef SCROLL_BUTTON
        const bool scroll = ((PIND & (1 << SCROLL_BUTTON)) == 0);
#else
        const bool scroll = false;
#endif

        update_axes(delta_x, delta_y, scroll);
        do_usb_tasks();

#ifdef ENABLE_CDC
        printf(
            "M: %d, O: %d, X: % 5d, Y: % 5d, SQ: % 4d, R: % 3d-% 3d, SH: %5u\n",
            (v[0] & 0x80) > 0, (v[0] & 0x8) > 0,
            delta_x, delta_y, v[6],
            v[8], v[9], *(uint16_t *)(v + 10));
#endif
    }

    return 0;
}

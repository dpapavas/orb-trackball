#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <math.h>

#include "config.h"

static double axes[4];

void update_axes(int16_t delta_x, int16_t delta_y, bool scroll)
{
    axes[scroll * 2 + 0] += delta_x;
    axes[scroll * 2 + 1] += delta_y;
}

bool get_axes(int16_t *p)
{
    /* Scale the sensed pointer coordinates, before passing them
     * on. (Also flip one of the axes since, this being a trackball,
     * the sensor is mounted upside-down.) */

    {
        const double x = POINTER_SENSITIVITY * axes[0];
        const double y = POINTER_SENSITIVITY * -axes[1];

        double ix, iy;
        const double fx = modf(x, &ix);
        const double fy = modf(y, &iy);

        p[0] = (int16_t)ix;
        p[1] = (int16_t)iy;

        /* Scale any fractional remainders back and accummulate
         * them. */

        axes[0] = fx / POINTER_SENSITIVITY;
        axes[1] = -fy / POINTER_SENSITIVITY;
    }

    /* Same thing for the wheel. */

    {
        const double x = WHEEL_SENSITIVITY_X * axes[2];
        const double y = WHEEL_SENSITIVITY_Y * axes[3];

        double ix, iy;
        const double fx = modf(x, &ix);
        const double fy = modf(y, &iy);

        p[2] = (int16_t)ix;
        p[3] = (int16_t)iy;

        axes[2] = fx / WHEEL_SENSITIVITY_X;
        axes[3] = fy / WHEEL_SENSITIVITY_Y;
    }

    for (int i = 0; i < 4; i++) {
        if (p[i]) {
            return true;
        }
    }

    return false;
}

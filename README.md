<!-- -*- coding: utf-8 -*- -->

# The Orb trackball

![The Orb trackball](./doc/orb_trackball.png?raw=true)

The Orb is a parametric trackball design, which uses BTUs as bearings to support
the ball for smooth, accurate, low-maintenance operation.  The design has the
form of a Scheme program, meant to be executed using the
[Gamma](https://github.com/dpapavas/gamma) computational geometry compiler, in
order to produce model files, that can then be used for fabrication.  This
allows substantial configurability, since parameters of the program can be
changed in order to alter the design, for instance to change the trackball
diameter, or adapt the design to different BTU part.

The Orb was created as a relatively complex application, that could be used to
drive the design of Gamma during the initial stages of development, but it works
pretty well and can be used in practice as a pointing device.  For a frew more
photos, see the [doc/](./doc) directory and see below for building instructions,
if you're interested in making one.

## Building an Orb

These instructions will be rather brief, as I do not expect many people to be
interested in making an Orb.  If you find that you are though and are unclear
about something, please open an issue on the Github project page, requesting
better documentation, making sure to mention the details you're unclear about.

The default configuration is made for a 55mm trackball (such as the one used in
the Kensington Expert Mouse) and the Ahcell D-6H BTU.  The PCB is mounted with
M3 screws, using threaded inserts with an M5-0.5x12 outer thread. If you decide
to use the same parts, you can use the pre-built STLs in [things/](./things/) and
skip the next section.

### Making design changes

To adapt the design for different parts (or make other customizations), you'll
first have to install Gamma. See its [project
page](https://github.com/dpapavas/gamma), for further instructions.  Once that
is accomplished, you're ready to compile the design.  The compilation process
creates lots of files, as it caches all intermediate non-trivial computations,
so it's best to carry it out in a separate directory, to keep things tidy.  (The
commands below assume you're starting out at the top-level directory of the Orb
sources.)

```bash
$ mkdir build
$ cd build
```

The design source (located in the [scheme/](./scheme/) directory) defines a set
of outputs, each of which can be compiled and written to a file in one of the
supported output formats.  To see the available outputs, you can use the
`-Woutputs` option, which enables warnings about unused outputs.  This will list
all of them, since we haven't selected any.

```bash
gamma -Woutputs ../scheme/trackball.scm
```

You can examine the sources to see what all of these outputs are about.  To
compile designs with the default configuration, we'll only need the `chassis` ,
`boot` and `cap` outputs, and we'll only need to concern ourselves with the
first for the time being.  We'll first build a draft design (`-Ddraft`), since
compilation in full resolution can take quite long and we just want to change a
few parameters and get an idea of the result.

```bash
gamma -Ddraft -o chassis.stl ../scheme/trackball.scm
```

The first compilation will typically take a while.  In draft mode, it should be
several minutes.  If you're worried that Gamma has frozen, you can use the
`--dump-operations=-` option, to convince yourself otherwise.  It takes so long,
because all calculations need to be carried out from scratch, but this will
typically only happen once.  Intermediate results are saved (which explains the
slew of `.o` or `.zo` files which now exist in your build directory) and future
recompilations will only recalculate the parts that have changed.  This helps
keep compilation times at relatively interactive levels most of the time.

To change the design to accept a different size ball, say a pool ball with a
diameter of 57.15mm, you only need to change the definition `ball-radius`
(setting it to `5715/200` [^1]) and recompile as before.  (You may note that
this compilation again takes some time.  That is because the change is quite
fundamental and requires changes and thus recalculation of most of the
geometry.)

Adapting the design to a different BTU part is also relatively straightforward.
For instance, if you want to use the `11MI-05-13` part (made by various
manufacturers) you need only to change `btu-radius` to `13/2` and
`btu-thread-length` to `15`.

After inspecting the draft result for any obvious defects, it's time to compile
the final part.  We work as before, but remove the `-Ddraft` option.

```bash
gamma -o chassis.stl ../scheme/trackball.scm
```

The part looks okay, but we can be more thorough.  The `interference` output takes
the intersection of the main chassis part with all mounted peripherals (PCB
board, BTUs, ball, etc.).  The result should ideally be empty, otherwise there
will be interference during assembly, but in practice, very small intersection
can be okay, depending on manufacturing tolerances and intended postprocessing of
the part.

We can also use the `-Dvertical=...` and `-Dhorizontal=...` options, to inspect
cross-sections of the part, for instance to make sure that wall thicknesses are
acceptable at critical points.  (See the comments in the sources for more
details.)

To get an idea of the assembled device, we just have to select the `assembly`
output and define some options to specify what to include in the assembly.

```bash
gamma -Dplace-ball -Dplace-board -Dplace-bearings -Dplace-caps -Dplace-boot -o assembly.stl ../scheme/trackball.scm
```

Finally, to make the bottom cover and keycaps, use the `boot` and `cap` outputs.

```bash
gamma -o boot.stl -o cap.stl ../scheme/trackball.scm
```

All this is not meant to give the idea that the design is infinitely flexible;
there are limits to the changes that can be carried out through simple
reparameterization.  These limits generally depend on the design, which can be
made to be more or less "generic", but small changes are usually okay.  After a
point though, changes in one part of the design may necessitate changes in other
parameters to ensure a defect-free result and still larger alterations can well
require changes to the design itself.

For some more tips on using Gamma, see the documentation for the [examples in
its project page](https://github.com/dpapavas/gamma/tree/master/examples).

## Fabrication

Once the parts have been compiled, they can be fabricated using a 3D printer, a
prototype fabrication service, or any other means at your disposal.  Note that,
depending on the manufacturing tolerance of the chosen method, you may need to
make minor changes to some design parameters to ensure perfect fit.
Alternatively, you can also postprocess the part instead.

The main chassis part and keycaps should be made in plastic (for instance using
TPU 3D printing filament) while the boot is meant to be flexible (TPU filament
or any rubber-like material should work fine).

## The controller board

The controller PCB was designed with [KiCad 6.0.7](https://kicad.org/)
and all relevant files are contained in the [kicad/](./kicad)
directory.

There are numerous fabrication services, where you can simply upload the KiCad
PCB file ([kicad/keyboard_mcu.kicad_pcb](./kicad/keyboard_mcu.kicad_pcb)) and
have a small number of PCBs fabricated and sent to you at a small price.  One
example, that is simple to use as it doesn't present you with a bewildering
array of choices, is [OSH Park](https://oshpark.com/).  Other services might
require so-called Gerber files, an industry standard which
[KiCad](https://kicad.org/) can generate.

The controller is designed around the Pixart PMW3389DM-T3QU optical sensor and
supports up to 5 buttons (or potentially 6, if some sort of matrix circuit is
used).  It should be adaptable to the PMW3360DM‐T2QU part, which is pin
compatible and uses the same lens, but note that some components will have to be
changed (for instance the current limiting resistor for the sensor LED).

### BOM

Apart from the PCBs, you'll also need the following parts:

| Component(s) | Part description | Part # |
| ------------ | ---------------- | ------ |
| C1, C14, C15, C18 (4 pcs, 10uF) | 10uF, 10%, X7R, 0603 | GRM188Z71A106KA73D |
| C2, C3 (2 pcs, 22p) | 15PF, 1%, C0G (NP0), 0603 | GRM1885C1H150FA01D |
| C4, C6, C7, C8, C10, C11, C12, C20 (8 pcs, 100nF) | 0.1uF, 10%, X7R, 0603 | EMK107B7104KA-T |
| C5, C9, C16, C17, C19 (5 pcs, 1uF) | 1uF, 10%, X7R, 0603 | EMK107B7105KA-T |
| C13 (1 pcs, 4.7uF 10V) | 4.7uF, 10V, 10%, X5R, 0603 | LMK107BJ475KA-T |
| J1 (1 pcs, USB_B_Micro) | USB Micro Type B connector | Wurth 629105150521 |
| J2, J3 (2 pcs, Conn) | 2.0mm pin header | Harwin M22-2530305 |
|  | 2.0mm female housing | Harwin M22-3010300 |
|  | 2.0mm crimp contact | Harwin M22-3040042 |
| R1, R2 (2 pcs, 22) | 22Ω, 1%, 0603 | CRCW060322R0FKEA |
| R3, R6 (2 pcs, 10K) | 10kΩ, 1%, 0603 | CRCW060310K0FKEA |
| R4 (1 pcs, 1k) | 1kΩ, 1%, 0603 | RCA06031K00FKEA |
| R5 (1 pcs, 13) | 13Ω, 1%, 0603 | CRCW060313R0FKEA |
| SW1 (1 pcs, SW_Push) | Tactile Switch SPST-NO | TL3305AF160QG |
| U1 (1 pcs ATmega32U4-AU) | AVR microcontroller | ATMEGA32U4-AU |
| U2 (1 pcs, LD39015M33R) | 150mA voltage regulator, 3.3V, SOT-23-5 | LD39015M33R |
| U3 (1 pcs, PMW3389-T3QU) | Optical sensor chip | PMW3389-T3QU |
| | Optical sensor lens | LM19‐LSI |
| U4 (1 pcs, TLV70019_SOT23-5) | 200mA voltage regulator, 1.9V, SOT-23-5 | TLV70019DDCR |
| Y1 (1 pcs, Crystal_GND24) | Four pin crystal, GND on pins 2 and 4 | ABM3B-8.000MHZ-10-1-U-T |

I've tried to select components with high availability, but you can treat the
part numbers given for the two-terminal chip resistor and capacitors as
suggestions.  Any part with the specifications listed in the part description
should do equally well.

In addition to the above, you'll need 5 Kailh CPG1350 CHOC low profile switches.
You can find these in many variations, but I would recommend low actuation force
parts, such as the "Red Rro" linear, or "Blue" clicky versions.  Apart from
ergonomic considerations, since the force of actuation is transmitted radially
to the chassis, it will tend to shift it around on the desk if it is too high.

Finally, I would advise not crimping your own wires unless you have the proper
equipment, prior experience and know you can do a good job.  The procedure can
be rather tedious and getting a proper result can be hard to impossible,
depending on the tools used.  You can get pre-crimped wires instead, but if you
do decide to crimp your own, get *plenty* of crimp terminals.

## Assembly

Assembly is simple in theory, but it can get tricky due to the confined work
space.  Start by inserting the threaded inserts.  The default design takes
inserts for M3 screws, with M5-0.5x12 outer thread, but it can be adapted to
other parts, if necessary (through the `board-insert-thread` and `boss-radius`
parameters).  See
[here](https://github.com/dpapavas/lagrange-keyboard/blob/master/BUILD.md#installing-the-threaded-inserts)
for installation instructions.

Continue by creating a common ground bus for the switches.  One way, is to make
it out of a single solid core wire with exposed loops at the proper intervals,
that can be soldered onto one terminal of each switch.  See
[here](https://github.com/dpapavas/lagrange-keyboard/blob/master/BUILD.md#rows)
for a potential technique.  The wire should have some slack, so that you can
pull the loops one at a time, far enough out of the switch hole, in order to
solder it to the switch, but not too much slack, or else the wire might
interfere with other parts.

Continue with the crimped and terminated wires for the switches.  These should
initially be of ample length, so that they can be threaded through the wiring
guides (the loops around the lens mating surface), around the lens and through
the switch holes (one pair through each hole, plus one common ground wire
connected to the ground bus), with the terminals at the place where the mating
headers on the board will end up.  Again, leave some slack, so that you can mate
the headers during assembly, but not too much, then cut the wires to length and
solder them, one at a time, to the switches and ground bus.

Carefully remove the Kapton tape protecting the optics of the sensor chip making
sure to hold the PCB with the chip face down, to avoid getting any dust on the
exposed optics, then quickly insert the lens (practice a bit before removing the
tape, to get the hang of the process).  Insert the PCB-lens assembly far enough
into the chassis to attach the headers, then insert it fully, making sure that
no wiring has been caught between the PCB or lens and the mating sites on the
chassis and fasten it using M3x12 button head screws.  Finally insert the boot
and you're done.

Unless the boot is manufactured using a high grip material, it is very much
recommended to coat the bottom with some silicone, or similar material, to
ensure sufficient traction and keep the device from sliding around.

## Firmware

Before building the firmware, have a look at the `./src/config.h` header and
make any necessary configuration changes.  You're probably going to have to set
the button pins, unless you happened to used the same pinout as I, but you can
also change the device-to-OS button mapping, optical resolution, sensitivities,
etc.

To build the firmware, you'll need the AVR GCC toolchain, which you can most
likely install through your system's package system.  Then building can be done
simply by:

```bash
$ cd src
$ make
```

Assuming nothing has gone wrong, connect the device to your computer and press
the reset switch.  You can then install the firmware with:

```bash
$ make install
```

## License

The Scheme code in [scheme/](./scheme), producing the Orb's designs, is
distributed under the [GNU Affero General Public License Version
3](./LICENSE.AGPL).

The firmware sources in [src/](./src), except for the portion in the
[src/LUFA/](./src/LUFA/) directory, as well as the controller PCB design
residing in [kicad/](./kicad/), is distributed under the [GNU General
Public License Version 3](./LICENSE.GPL).

For the sources in the [src/LUFA/](./src/LUFA/) see the [license
notice](./src/LUFA/License.txt) therein.

[^1]: You could also set it to `28.575` and it would work fine, but rational
      numbers should probably be preferred.  Gamma works with exact arithmetic
      on rational numbers (for the most part), so using floating point-input can
      result in needlessly "large" numbers.  For instance `28.575` is really
      `28.575000762939453125` in double precision floating point, with a
      rational representation of `8043147459506995/281474976710656`, instead of
      the much simpler `5715/200`.  (There's technically also some loss of
      precision, but this is generally down at the atomic scale, so we can
      probably ignore it).

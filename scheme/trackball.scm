;; -*- mode:scheme; coding: utf-8 -*-

;; Copyright 2020 Dimitris Papavasiliou

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU Affero General Public License for more details.

;; You should have received a copy of the GNU Affero General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;; -----

;; This program produces "The Orb", an optical trackball device.  It must be
;; processed using Gamma (https://github.com/dpapavas/gamma), the computational
;; geometry compiler, in order to produce geometry, which can then be
;; fabricated, for instance with a 3D printer.

;; Since Gamma is not documented at the time of this writing, I have tried to
;; document this code extensively enough to hopefully allow the adventurous to
;; get an idea of how Gamma in general and this construction in particular
;; works.  The construction carried out with the code below, essentially
;; contains the basic design techniques I've been able to find and incorporate
;; into Gamma so far, so it should not be inconceivable, that one might use what
;; follows as a tutorial of sorts.  Be warned though, that some experience with
;; Scheme or other LISPs, will be required.

;; Assuming you have successfully installed Gamma, you can process this file
;; with:

;; $ gamma trackball.scm

;; With the above invocation, nothing will happen, because no outputs have been
;; enabled.  Available outputs, are specified with the `output` or
;; `define-output` forms, but instead of searching the code, a list can be had
;; with the `-Woutputs` option (which enables warnings about unused outputs and
;; effectively produces the desired list):

;; $ gamma -Woutputs trackball.scm

;; Each listed output can be saved to a file with the -o/--output option.  For
;; instance, to build the `chassis` output (the main part of the trackball) and
;; save it in STL format:

;; $ gamma -o chassis.stl trackball.scm

;; While this invocation gets the job done, it litters the source directory with
;; all sorts of files, by-products of the build process.  One way to avoid this,
;; is to make a separate build directory, and only run Gamma from within it:

;; $ mkdir build
;; $ cd build
;; $ gamma -o chassis.stl ../trackball.scm

;; Now, in order to clean all cached intermediate evaluations, previously built
;; outputs etc., we can simply clear the build directory.  This is handy, so all
;; invocations below will assume such a setup.

;; Other output formats are also available, including OFF and WRL.  Another
;; option, is to output the geometry straight to Geomview, on platforms where
;; this is available.  One convenient way to use it, is to start Geomview with
;; something like:

;; $ geomview -nopanels -Mc output -wpos 800,600 -wins 0

;; This will start Geomview without showing any windows, waiting for incoming
;; geometry.  Then any output can be built and inspected by invoking Gamma with:

;; $ gamma -o:cap --dump-operations=- ../trackball.scm

;; Note the colon before the output name (here `cap` for the keycap part) and
;; the absence of a suffix.  This requests "debug" output (for now implemented
;; via Geomview) to the default Geomview pipe (named `output`, which matches the
;; argument to the `-Mc` option to Geomview above).  You can rotate and move the
;; part, or change the way it's displayed with the proper key bindings; consult
;; Geomview's manual.  (Alternatively, if you prefer a GUI, remove the
;; `-nopanels` switch above.)  When you're done simply close the window and
;; Geomview will stay running in the background, waiting for the next build.

;; We also added the `--dump-operations=-` option in our previous invocation.
;; This prints operations as they are evaluated during the course of the
;; construction to the standard output, allowing some insight into its progress
;; and inner workings.

;; The imports below, are mostly boilerplate, but note the final import
;; (`sensor`).  This is a separate program, packaged as a library, that builds
;; a model of the sensor chip and lens assembly.  We place it on our crude model
;; of the PCB board and use it to design and validate the parts of the chassis
;; that mate with the PCB, but since it is a relatively complex build and not
;; really related to the trackball device itself, we place it in a separate
;; file.  To get an idea of its usefulness try the following build:

;; $ gamma -Ddraft -o:assembly -Dplace-board -Dvertical=98 ../trackball.scm

(import (scheme inexact) (srfi 1)
        (gamma inexact) (gamma transformation) (gamma polygons)
        (gamma polyhedra) (gamma volumes) (gamma selection)
        (gamma operations) (gamma write)

        (rename (sensor) (assembly sensor-assembly)))

;; The `define-option` form works like define, except it doesn't do anything if
;; the variable already exists.  It can be used in combination with the `-D`
;; command line switch, which predefines variables, to implement build options.

;; For instance, the invocations presented above, will produce detailed builds
;; since `draft?` will be set to `#false` by the call to `define-option` below.
;; This produces nice results, but it can take a while to build.  Having to wait
;; several minutes during iterative exploration of the design can be cumbersome,
;; so we can set `draft?` to `#true` by providing the `-Ddraft` command line
;; option.  In this form, the option sets the variable `draft?` to `#true`
;; before running the code, so that `define-option` below finds it already set
;; and leaves it alone.  (The addition of the question mark happens in the
;; Scheme back-end only, in an attempt to follow Scheme convention.)

;; Other than that, `draft?` is a normal predicate variable, which happens to be
;; used in key places in the code, to adjust parameters so as to limit detail
;; when it is set.  This is a useful technique, in that it allows quick and
;; dirty builds during design, but it has its limitations. Care must be
;; exercised, to make sure that the draft geometry is representative of the
;; production build and in some cases, tweaks will have to be done in full
;; detail.

(define-option draft? #false)           ; Produce quick low-resolution output?

;; These options specify what parts to include when producing the `assembly`
;; output.

(define-option place-ball? #false)      ; Place various peripheral parts on the
(define-option place-board? #false)     ; build?  This can be useful to get a
(define-option place-bearings? #false)  ; better idea of the final assembly, or
(define-option place-caps? #false)      ; to check fit and tolerances.
(define-option place-switches? #false)
(define-option place-boot? #false)

;; These options produce horizontal (at the given height) or vertical (at the
;; given angle) sections in the `assembly` output, which can be useful to
;; inspect and adjust internal parts of the geometry.  For instance, the
;; geometry of one of the bearing mounts, with BTUs installed, can be inspected
;; with:

;; $ gamma -Ddraft -Dplace-bearings -Dvertical=120 -o:assembly ../trackball.scm

(define-option vertical #false)
(define-option horizontal #false)

;; Parameters for the various deformation operations, used to build the chassis.

(define fair-parameter 1)
(define remesh-target (if draft? 3 1))
(define remesh-iterations (if draft? 1 2))
(define deflate-parameters (if draft? (list 2 3/2) (list 2 3/2)))
(define smooth-parameter 5)

;; The main parameters that define the chassis.

(define ball-radius 55/2)               ; Trackball radius
(define ball-offset 23/2)               ; Mounted ball height
(define ball-gap 1/2)                   ; Gap between ball and chassis

(define button-layout                   ; A list of angular offsets, at which to
  (list 98 142 218 262 338 22))         ; place buttons.
(define button-offset 10)               ; Radial offset of the buttons
(define button-taper 1)                 ; A button shape parameter
(define button-hole-size 14)            ; The switch hole side length
(define button-case-size                ; The outer button side length
  (+ button-hole-size 4))
(define button-hole-depth               ; Parameters for the switch hole cutout
  (list 3 11/2))

(define chamfer-length 3/4)             ; Global chamfer length
(define center-offset 3)                ; Chassis center region height offset
(define boss-radius 15/4)               ; Screw boss radius
(define wall-width 12/5)                ; Chassis wall thickness
(define lens-cutout-gap 2/10)           ; Gap between lens and locating cutout
(define lens-z-offset -5/10)            ; Vertical offset applied to the lens
                                        ; cutout.  Adjust this to set the
                                        ; desired lens to ball distance.

;; Parameters that define the shape of the keycap.

(define cap-size 18)                    ; Short side length
(define cap-corner-radius 2)            ; Corner rounding radius
(define cap-top-radius 28)              ; Top surface radius
(define cap-height (list 7/2 8))        ; Heights (main part and skirt)
(define cap-width 6/5)                  ; Thickness

;; Design parameters for the BTU. These are for an Ahcell D-6H.
;; See: https://www.ahcell.com/Product/4063521954.html

(define btu-radius 12/2)
(define btu-height 9)
(define btu-thread-radius 6/2)
(define btu-thread-length 12)
(define btu-mount-elevation 45)
(define btu-nut-height 48/10)
(define btu-nut-radius 57/10)

;; Design parameters for the PCB.

(define board-radius 48/2)
(define board-cutout-height 5/2)
(define board-cutout-gap 3/4)
(define board-width 16/10)

;; Design parameters for the sensor lens (LM19‐LSI).  See the datasheet for
;; details.

(define lens-radius 705/100)
(define lens-width 19)
(define lens-height 2135/100)

;; Measurements and parameters derived from the above; not meant to be adjusted.

(define vertical-section                ; Cut the part vertically at the
  (when vertical (list vertical 0)))    ; specified angle and offset.

(define horizontal-section              ; Same, but take a horizontal section.
  (when horizontal (list
                    (if (positive? horizontal) 180 0)
                    (abs horizontal))))

(define chassis-height
  (- ball-offset
     (* ball-radius (- (cos° btu-mount-elevation) 1))
     (* (+ btu-height
           (/ btu-radius (tan° (- 90 btu-mount-elevation))))
        (cos° btu-mount-elevation))))

(define chassis-radius
  (+ (* (+ ball-radius btu-height) (sin° btu-mount-elevation))
     (* -1 btu-radius (cos° btu-mount-elevation))))

(define btu-mount-depth (- btu-nut-height btu-thread-length))

(define board-height (+ board-width (- ball-offset 74/10 lens-z-offset)))
(set-curve-tolerance! (if draft? 1/15 1/50))

(define board-cutout-radius (+ board-radius board-cutout-gap))
(define board-rotation (- (first button-layout) 90))

;; Functions named place-*, such as these, accept a part and return a list of
;; copies of it, transformed to their mounted positions and orientations.  They
;; can then conveniently be used, both to mount the parts themselves, as well as
;; any geometry or selectors that we wish to place relative to them.

(define (place-bearing part)
  (list-for ((φ (list 0 120 240)))
    (transform
     part
     (translation 0 0 (- (+ btu-height ball-radius)))
     (rotation btu-mount-elevation 1)
     (translation 0 0 (+ ball-radius ball-offset))
     (rotation φ 2))))

(define (place-button part)
  (list-for ((φ button-layout))
    (transform
     part
     (rotation 90 1)
     (translation (+ chassis-radius button-offset)
                  0
                  (+ (/ button-case-size 2) 0))
     (rotation φ 2))))

(define (place-board part)
  (transform part
             (rotation 180 1)
             (translation 0 0 board-height)
             (rotation board-rotation 2)))

(define (place-boss part . rest)
  (list-for ((i (iota 3)))
    (when~> part
            #true (transform _
                             (translation 1366/100 1502/100 0)
                             (rotation (* i 120) 2))

            (or (zero? (length rest))
                (not (first rest))) (place-board _))))

(define (place-lens part)
  (transform part
             (translation 0 0 (- ball-offset 24/10 lens-z-offset -1/100))
             (rotation board-rotation 2)))

(define (place-guide part)
  (let ((z (- (+ board-width 1/2))))
    (apply list
           (append
            (list-for ((s (list -1 1)))
              (~> part
                  flush-west
                  (translate _ (/ lens-width 2) (+ (* s 5) 295/1000) z)
                  place-board))

            (list-for ((s (list -1 1))
                       (t (list -1 1)))
              (~> part
                  (flush _ (- s) 0 0)
                  (transform
                   _
                   (translation (+ (* s (/ lens-height 2)) 295/1000) (* t 5) z)
                   (rotation 90 2))
                  place-board))))))

(define (place-port part)
  (~> part
      (rotate _ -90 0)
      (translate _ 0 0 (- board-height board-width 235/200))
      (translate _ 0 board-cutout-radius 0)
      (rotate _ board-rotation 2)))

;; This octahedron serves to apply chamfering to any geometry; one simply needs
;; to take the `minkowski-sum` of it with the geometry that needs to be
;; chamfered.  It's a simple approach, but not ideal: for one `minkowski-sum`
;; can be very slow for complex geometry and when that is not a problem the
;; chamfering is all-or-nothing and it also augments the dimensions of the part
;; by `chamfer-length` on each side, so that one needs to take that into
;; account, when designing the part.

(define chamfer-kernel
  (let ((c (* 2 chamfer-length)))
    (octahedron c c chamfer-length)))

;; These functions, build parts that are not meant for production, such as the
;; BTUs and the board, modeled only with the necessary detail, so that they can
;; be placed along with the main parts and guide their design (e.g. inspect
;; tolerances, check for interferences, etc.)

(define usb-connector
  (union
   (linear-extrusion
    (apply hull (list-for ((s (list -1 1)))
                  (translate (circle 13/4) (* 9/4 s) 0))) 0 15)
   (flush-top (cuboid 69/10 19/10 6))))

(define nut (translate (prism 6 btu-nut-radius btu-nut-height)
                       0 0 (/ btu-nut-height 2)))

(define flanged-nut
  (~> (prism 6 btu-nut-radius 6)
      (translation-λ 0 0 3)
      (union _ (extrusion (circle 12/2)
                          (translation 0 0 0)
                          (transformation-append
                           (scaling 7/6 7/6 1)
                           (translation 0 0 1))
                          (transformation-append
                           (scaling 5/7 5/7 1)
                           (translation 0 0 3))))
      (difference _ (cylinder 6/2 50))))

(define btu
  (let ((r (/ 6.35 2))
        (h_1 3/2))
    (union
     (translate (sphere r) 0 0 (- btu-height r))
     (translate (cylinder btu-radius (- h_1 btu-height))
                0 0 (/ (- h_1 btu-height) -2))
     (translate (cylinder btu-thread-radius (- btu-thread-length))
                0 0 (- (/ btu-thread-length 2) btu-height)))))

(define ball
  (transformation-apply
   (translation 0 0 (+ ball-radius ball-offset))
   (sphere ball-radius)))

(define switch
  (union
   (extrusion (rectangle 15 15)
              (translation 0 0 0)
              (translation 0 0 8/10)
              (transformation-append
               (translation 0 0 8/10)
               (scaling 14/15 14/15 1))
              (transformation-append
               (translation 0 0 19/5)
               (scaling 11/15 11/15 1)))

   (flush-top (cuboid 138/10 138/10 22/10))
   (translate (apply union
                     (flush-top (cylinder 32/20 265/100))
                     (append
                      (list-for ((s (list -1 1)))
                        (~> (cylinder 18/20 265/100)
                            flush-top
                            (translate _ (* s 55/10) 0 0)))
                      (list-for ((place (list (translation-λ 0 59/10 0)
                                              (translation-λ 5 38/10 0))))
                        (~> (cuboid 3/2 1/2 3)
                            flush-top
                            place))))
              0 0 -22/10)))

(define board
  (let ((header
         (translate (hull
                     (translate (cuboid 6 102/10 1) 3 -102/20 1/2)
                     (extrusion (rectangle 6 87/10)
                                (translation 3 -87/20 2)))
                    -1 102/10 0)))
    (~> (cylinder board-radius board-width)
        flush-top
        (apply difference
               _

               ;; Sensor cutout

               (translate (cuboid 86/10 1726/100 50) 0 -19/100 0)

               ;; Mount holes

               (place-boss (cylinder 27/20 50) #true))

        (union _
               ;; Sensor

               (translate sensor-assembly -535/100 566/100 0)

               ;; USB port

               (translate (union
                           (flush (cuboid 8 54/10 266/100) 0 -1 -1)
                           (flush (cuboid 745/100 66/10 235/100) 0 -1 -1))
                          0 35/2 0)

               ;; Reset switch

               (translate (union
                           (flush-bottom (cuboid 9/2 9/2 36/10))
                           (flush-bottom (cylinder 5/4 38/10)))
                          0 -12 0)

               ;; Headers

               (transform header
                          (rotation 180 1)
                          (translation -1104/100
                                       -1491/100
                                       (- board-width)))
               (transform header
                          (rotation 180 1)
                          (rotation 180 2)
                          (translation -1504/100
                                       1493/100
                                       (- board-width))))

        (translate _ 0 0 board-width))))

;; The basic portion of the chassis, to which will be added the structures on
;; which the BTUs and button switches are mounted.  Note the extrusion, which
;; produces a solid of revolution.  In general, the extrusion operation accepts
;; a polygon, which is to be extruded, and an arbitrary number of (arbitrary)
;; transformations.  The polygon is transformed by each transform in order,
;; forming a segment in the extrusion for each transformation after the first.
;; (An extrusion with only one transform is valid and can be useful.  It creates
;; a 3D mesh version of the polygon which can be of use, e.g. in forming hulls
;; with other geometry.)

(define base
  (let ((r (+ board-cutout-radius wall-width)))
    (apply
     extrusion
     (simple-polygon
      (point 0 0)
      (point (- r chamfer-length) 0)
      (point r chamfer-length)
      (point (+ chassis-radius (* (- btu-mount-depth)
                                  (sin° btu-mount-elevation)))
             (- chassis-height (* (- btu-mount-depth)
                                  (cos° btu-mount-elevation))))
      (point chassis-radius chassis-height)

      ;; The following slight extension leads to a better fairing
      ;; result.

      (point (- chassis-radius (* 1/2 (sin° btu-mount-elevation)))
             (- chassis-height (* 1/2 (cos° btu-mount-elevation))))

      (point (* chassis-radius 3/4) (+ button-case-size center-offset))
      (point 0 (+ button-case-size center-offset)))

     (list-for ((φ (if draft? (iota 73 0 5) (iota 121 0 3))))
       (transformation-append
        (rotation φ 2)
        (rotation 90 0))))))

;; The coarse chassis mesh, consisting of the base above, plus main structures
;; for buttons and BTUs.

(define coarse
  (let* ((l (- button-case-size (* 2 chamfer-length)))
         (xforms (list
                  (translation 0 0 (- chamfer-length))
                  (translation 0 0 (- (+ chamfer-length
                                         (first button-hole-depth))))
                  (transformation-append
                   (scaling (/ (+ l center-offset) l) button-taper 1)
                   (translation (/ center-offset -2)
                                0
                                (* -5/4 chassis-radius))))))
    (apply
     union

     base

     (append
      ;; Buttons: We create each separately as a mostly rectangular extrusion
      ;; extending radially away from the center, but we hull (part of) them in
      ;; twos to create three button groups.

      (~> (drop xforms 1)
          (apply extrusion (apply rectangle (make-list 2 l)) _)
          (minkowski-sum _ chamfer-kernel)

          place-button
          (tile _ 2)
          (map (partial apply hull) _))

      (~> (take xforms 2)
          (apply extrusion (apply rectangle (make-list 2 l)) _)
          (minkowski-sum _ chamfer-kernel)
          place-button)

      ;; Bearing mounts: The main part is essentially a cylinder on which the
      ;; BTU is fastened via a nut (although one side is hexagonal to match the
      ;; nut for style points).  This is then hulled with a portion cut out from
      ;; the base directly below it, forming a neck joining it to the base.

      (list-for ((st (map list
                          (place-bearing
                           (hull
                            (flush-top (cylinder btu-radius 2))
                            (translate (prism 6 btu-nut-radius 0)
                                       0 0 btu-mount-depth)))
                          (place-bearing
                           (translate
                            (cuboid 5 (* 2 btu-radius) (* -3/4 btu-mount-depth))
                            btu-radius 0 (/ btu-mount-depth 2))))))
        (hull (first st) (intersection base (second st))))))))

;; The chassis part above is only a crude base mesh, that can be used to form
;; the final part (and which can be viewed with the `-o:unfaired` command line
;; option).  The basic idea is this: the basic mesh defines the general outline
;; of the desired shape of the final part, crucially including those regions,
;; which are functionally critical, such as the mating surfaces on which the
;; BTUs and fastening nuts will be mounted, the mating surfaces of the button
;; switches and a flat base, that can be placed on the desk.

;; The whole mesh except for these surfaces is then selected, remeshed and
;; faired, leading to a, hopefully, pleasantly shaped final part with the
;; functionally critical parts having remained fixed.  The shape of the
;; resulting final part can be controlled in various ways: one obvious approach
;; is to change the configuration of the base mesh (see for instance the
;; `center-offset` parameter that leads to a taller bulge in the center of the
;; chassis, that more fully envelops the tracking ball). Another obvious
;; approach is to adjust the `fair-parameter`.

;; There are also more subtle ways.  The final result of the fairing operation,
;; is determined, not only by the shape of the coarse mesh, but also by its
;; triangulation, which effectively specifies the domain over which the fairing
;; operation is evaluated, as well as the selected vertices, which specify the
;; boundary conditions, so to speak.  In other words, the fairing operation (and
;; many other deforming operations), works by moving the selected vertices so as
;; to assume a "fairer" shape, subject to the constraints represented by the
;; unselected parts of the mesh.  A finer, or more uniformly triangulated mesh
;; will achieve different results, as will keeping more or less of the mesh
;; unselected and therefore fixed.  (This is also the reason for the remesh
;; operation, which produces a relatively uniform retriangulation of our input
;; mesh, at an arbitrary resolution.  The uniformity of the triangulation allows
;; for more predictable fairing results, while the remeshing density can be
;; used to control the smoothness and detail of the faired surface.)

;; Note below that, although when constructing the outer shell, we don't remesh
;; certain parts, such as mating surfaces, so as to preserve their exact shape,
;; for the "inner shell", used to produce the cutout for the PCB cavity, we
;; remesh (almost) everything, so as to get more uniform contraction (deflation
;; + smoothing) later.  Also note that the selection of the portion of the mesh
;; to be remeshed and faired, can be inspected visually, by coloring the faces
;; or vertices in question, via `color-selection`.

(define (fair-remeshed part volume remesh-whole?)
  (when~> part

          remesh-whole?
          (remesh _
                  (faces-partially-in
                   (complement
                    (bounding-halfspace 0 0 1 (- chamfer-length))))
                  remesh-target remesh-iterations)

          (not remesh-whole?)
          (remesh _ (faces-partially-in volume) remesh-target remesh-iterations)

          (not remesh-whole?)
          (~> _
              (color-selection _ (faces-partially-in volume) 1)
              (output "unfaired" _))

          #true
          (fair _ (contract-selection (vertices-in volume) 1) fair-parameter)


          (not remesh-whole?)
          (~> _
              (color-selection _ (vertices-in volume) 1)
              (output "faired" _))))

;; Selection of the vertices to be faired is achieved via bounding volumes.
;; These represent basic volumes, such as spheres, cylinders and boxes, which
;; can be transformed and combined via boolean operations, much like normal
;; polyhedra.  Vertices or faces bounded by these volumes can be selected via
;; e.g. `vertices-in` or `faces-partially-in`.  We place bounding volumes
;; precisely, by utilizing the same placement functions we used to build the
;; mesh (and essentially mirroring the build operation to a large extent).
;; Finally we take the complement, since we want to fair all vertices but the
;; ones we selected.  The resulting selection can be further tweaked with
;; functions such as `expand-selection` and `contract-selection`.

(define (fair-chassis remesh-whole?)
  (difference
   (fair-remeshed
    coarse
    (complement
     (apply union
            (bounding-halfspace 0 0 1 (- chamfer-length))
            (append
             (place-bearing (union
                             (bounding-cylinder btu-radius 0)
                             (translate (bounding-cylinder btu-nut-radius 0)
                                        0 0 btu-mount-depth)))
             (place-button (flush-top
                            (bounding-box button-case-size
                                          button-case-size
                                          (first button-hole-depth)))))))
    remesh-whole?)

   ;; Cut out the part of the faired result that would interfere with the
   ;; trackball (done here because it is convenient).

   (translate (sphere (+ ball-radius ball-gap))
              0 0 (+ ball-radius ball-offset))))

;; We'll need to remove parts of the faired chassis, to form the areas on which
;; hardware, such as the PCB assembly and BTUs can be mounted.  To that end, we
;; define some cutout shapes, which can be subtracted from the chassis.

(define (lens-cutout-shape ε)
  (~> (list-for ((s (list -1 1))
                 (t (list -1 1)))
        (let ((δ (- lens-radius ε)))
          (translate (circle lens-radius) (* s (- (/ lens-width 2) δ))
                     (* t (- (/ lens-height 2) δ)))))
      (apply hull _)
      (translate _ 0 295/1000)))

(define lens-cutout
  (union
   (linear-extrusion (lens-cutout-shape lens-cutout-gap) 0 -50)

   (hull
    (extrusion (union (circle 2) (translate (rectangle 4 4) 0 2))
               (translation 0 0 0))
    (extrusion (let* ((ρ (+ 2 (/ 5 (tan° 68.5))))
                      (ρρ (+ ρ ρ)))
                 (union (circle ρ) (translate (rectangle ρρ ρρ) 0 ρ)))
               (translation 0 0 5)))))

;; This forms a more-or-less standard DIN female thread cutout, that can accept
;; a threaded insert for the mounting fasteners.  It also illustrates the
;; generality of the `extrusion` operations, as the part is formed by a single
;; helical extrusion of the thread profile, onto which the shank is added in the
;; form of a pointed cylinder, formed by another extrusion.

(define (thread-cutout D P L)
  (let* ((H (* 1/2 (sqrt 3) P))
         (r (- (/ D 2) (* 7/8 H))))

    (~> (difference
         (simple-polygon
          (point (* -1/2 P) 0)
          (point (* 1/2 P) 0)
          (point 0 H))

         ;; Shave off a bit (H/16) of the thread; the standard allows
         ;; it (not that it matters) and it ensures a valid resulting
         ;; mesh.

         (rectangle P (/ H 8)))

        (apply extrusion
               _
               (list-for ((s (iota (- (ceiling (/ L P)) 1)))
                          (t (iota 30 0 1/30)))
                 (transformation-append
                  (translation 0 0 (/ P 2))
                  (rotation -90 1)
                  (rotation (* 360 t) 0)
                  (translation 0 r 0)
                  (translation (* P (+ s t)) 0 0))))

        (union _ (extrusion (regular-polygon 30 (+ r (/ H 8)))
                            (scaling 4/3 4/3 1)
                            (translation 0 0 (/ r 3))
                            (translation 0 0 L)
                            (transformation-append
                             (translation 0 0 (+ L (/ P 2) (* r 9/10 7/10)))
                             (scaling 1/100 1/100 1))))

        (clip _ (plane 0 0 -1 0)))))

;; Cutouts for the button switches, designed for Kailh Chocs.

(define button-cutouts
  (let ((profile (λ (δ)
                   (union
                    (apply hull
                           (list-for ((s (list -1 1)))
                             (translate (circle 3/2) (* s 11/2) 0)))
                    (flush-south
                     (rectangle (- button-hole-size δ)
                                (* (- button-hole-size δ) 1/2))))))
        (z (λ (δ) (- (+ (second button-hole-depth) δ)))))
    (~> (profile 0)
        (linear-extrusion _ 0 (z 0))
        (hull _ (extrusion (profile 5) (translation 0 0 (z 5))))
        (rotate _ 90 2)
        (union _
               (flush-top (cuboid button-hole-size
                                  button-hole-size
                                  (first button-hole-depth)))

               (flush-top (cylinder 9/4 (z 5))))
        place-button
        (drop _ 1)
        (apply union _))))

(define port-cutout
  (union
   (~> (- button-hole-size chamfer-length chamfer-length)
       (cuboid _ _ 19/2)
       (minkowski-sum _ chamfer-kernel)
       flush-west
       place-button
       (take _ 1)
       car)
   (~> (rectangle 15/2 24/10)
       (minkowski-sum _ (regular-polygon 4 1/2))
       (linear-extrusion _ -5 50)
       place-port)))

;; A simple loop structure.  Several of them are placed around the lens mating
;; surface, to facilitate routing of the switch wiring.

(define (wiring-guide d)
  (let* ((c 3/2)
         (w 2)
         (profile (~> (rectangle (+ d w (- c)) 50)
                      flush-south
                      (minkowski-sum _ (regular-polygon 4 c)))))
    (~> (difference profile (offset profile (- w)))
        (linear-extrusion _ w)
        (rotate _ -90 0))))

;; This is the main cutout, meant to form the area where the PCB assembly can be
;; mounted.  It would be easiest to simply cut out a cylindrical space in the
;; bottom of the chassis part, but in order to allow for a compact final part
;; we'd like the cutout to follow the outer shape, so that the thickness of the
;; final part is as uniform as possible.  This also allows more space in the
;; inside of the chassis for the wiring.

;; It would be easiest to simply shrink the chassis itself suitably, then
;; subtract the shrunk version from the original chassis.  One problem are the
;; BTU mounts, which we don't really want to hollow out, as that would weaken
;; them.  We remove them before shrinking the part, by selecting them and
;; fairing them.  This may seem counter-intuitive, but fairing a portion of the
;; mesh essentially tries to give it the smoothest, simplest, "lowest energy"
;; form, relative to the surrounding mesh, which is kept fixed.  Here that is
;; functionally the same as cutting away the mount and smoothly patching the
;; resulting hole.

;; Once that is done, it would have been easiest to somehow offset the chassis,
;; but as no such operation is currently available we go about in the rather
;; circuitous way of sequentially applying the `deflate` and `smooth-shape`
;; operations.  Both contract the input mesh, the first favoring areas of low
;; curvature (i.e. smooth, flat areas), while the other favors areas of large
;; curvature (i.e. it shrinks sharp areas more, thus smoothing them).  Together
;; they sort of uniformly contract the part (except for the base, which we keep
;; unselected, since we want it to remain flat).

;; Once the cutout is suitably contracted, we further refine it, by adding parts
;; that will form the lens mating surface, bosses, etc.

(define main-cutout
  (~> (fair-chassis #true)

      ;; "Melt" away the BTU mounts from the cutout, to avoid thinning the
      ;; finished part under them.

      (fair _
            (difference
             (expand-selection
              (vertices-in
               (faces-partially-in
                (apply union (place-bearing
                              (flush-top (bounding-cylinder btu-radius 50))))))
              (if draft? 1 8))
             (vertices-in
              (bounding-halfspace 0 0 1 (- chamfer-length))))
            fair-parameter)

      ;; Deflate + smooth to contract the cutout inward, forming the walls.
      ;; (The let expression is a little tricky here: it seems to follow the
      ;; operations it's used in, but due to the mechanics of the threading
      ;; macro, it actually contains them.  This is one of those things on
      ;; should probably not do, but here we are...)

      (apply deflate _ volume 1 deflate-parameters)
      (smooth-shape _ volume smooth-parameter)
      (let ((volume (vertices-in
                     (bounding-halfspace 0 0 1 (- chamfer-length))))) _)

      ;; Postprocess the cutout for the board.  This ensures the bore accepting
      ;; the PCB is perfectly cylindrical (the previous contraction process is
      ;; not very precise) and adds cutouts for the button switches.

      (intersection _ (linear-extrusion (circle board-cutout-radius) 0 100))
      (union _
             (extrusion
              (circle board-cutout-radius)
              (translation 0 0 0)
              (translation 0 0 board-height)
              (transformation-append
               (let ((s (/ (- board-cutout-radius 1/2)
                           board-cutout-radius)))
                 (scaling s s 1))
               (translation 0 0 (+ board-height 1/2))))
             button-cutouts)

      ;; Further refine the cutout, by removing parts we want to keep in the
      ;; finished part.

      (apply difference
             _

             ;; Lens mating surface

             (place-lens
              (linear-extrusion (lens-cutout-shape
                                 (+ lens-cutout-gap 6/5)) -1 50))

             (append
              ;; Bosses

              (place-boss
               (minkowski-sum
                (octahedron 1 1 1/2)
                (linear-extrusion (circle (- boss-radius 1/2)) -1/2 -50)))

              ;; Wiring guides

              (place-guide (wiring-guide 5))))))

(define-output chassis
  (~> (fair-chassis #false)

      ;; Add a pawl, to arrest nut rotation.

      (union _ (~> (list-for ((s (list -1 1)))
                     (transform (regular-polygon 3 3/2)
                                (rotation (+ (* 60 s) 90))
                                (translation 0 (* 1/2 s btu-nut-radius))))
                   (apply hull _)
                   (linear-extrusion _ 0 5)
                   (rotate _ 90 1)
                   (translate _ (* 13/15 btu-nut-radius) 0 btu-mount-depth)
                   place-bearing
                   (apply union _)
                   (clip _ (plane 0 0 -1 0))))

      ;; Subtract the cutouts.

      (apply difference
             _

             main-cutout
             port-cutout
             (place-lens lens-cutout)

             ;; Bearing and boss thread cutouts

             (append
              (place-bearing (cylinder 13/4 50))
              (place-boss (scale (thread-cutout (+ 9/2 1/5) 1/2 13/2)
                                 1 1 -1))))))

;; This is a rubber, interference fit bottom cover, serving both for protection
;; of the PCB assembly, as well as as an anti-slip base pad.  (It also allows
;; pressing the reset switch, without requiring removal; what more could one
;; want?)

(define-output boot
  (difference
   (union
    (linear-extrusion (difference
                       (circle board-cutout-radius)
                       (circle (- board-cutout-radius 7))) 0 2)

    (linear-extrusion (circle (+ board-cutout-radius 4/3)) 0 -1))
   (place-board
    (translate (cuboid 10 30 10) 0 35/2 0))))

;; The buttons (or, more precisely, the button switch caps).  The function below
;; defines the basic shape in a parametric way, so that we can call it to
;; instantiate two versions, one slightly smaller than the other, and subtract
;; them to create the final cap.

(define (cap-shell δ h)
  (~> (let* ((l_0 (/ cap-size 2))
             (l_1 (- l_0 δ))
             (l (- l_1 cap-corner-radius))
             (y (- (* 3/2 cap-size) δ)))
        (linear-extrusion
         (apply hull
                (point (- l_1) y)
                (point l_1 y)
                (list-for ((s (list -1 1)))
                  (translate (circle cap-corner-radius)
                             (* s l) (- l)))) -50 h))

      (intersection _ (translate (sphere cap-top-radius)
                                 0 0 (- (second cap-height) cap-top-radius δ)))
      (difference _ (minkowski-sum (flush-top (cuboid 50 (* 1 cap-size) 50))
                                   chamfer-kernel))
      (difference _ (translate (sphere cap-top-radius)
                               (+ (/ cap-size 2) 4)
                               (+ cap-top-radius 2)
                               (- cap-top-radius 6 δ)))
      (difference _ (translate (sphere ball-radius)
                               0 (+ ball-offset cap-size) (- -3 ball-radius)))
      (clip _ (plane 0 0 -1 -9))))

(define-output cap
  (let ((ε 0))
    (apply union
           ;; Create and chamfer the shell.

           (minkowski-sum
            (difference (cap-shell 1/2 (- (second cap-height) 1/2))
                        (cap-shell (- cap-width 1/2)
                                   (+ (first cap-height) 1/2)))
            (octahedron 1 1 1/2))

           ;; Add the stem.

           (list-for ((s (list -1 1)))
             (let ((z (first cap-height)))
               (translate (extrusion
                           (rectangle (- 6/5 ε) (- 3 ε ε))
                           (transformation-append
                            (translation 0 0 z)
                            (scaling 11/6 4/3 1))
                           (translation 0 0 (- z 1/2))
                           (translation 0 0 (- z 7/2)))
                          (* s 57/20) 0 0))))))

;; Some parts that go on the final assembly.

(define bearings
  (apply union
         (append
          (place-bearing btu)
          (place-bearing
           (transform nut
                      (rotation 180 0)
                      (translation 0 0 btu-mount-depth))))))

(define caps
  (apply union (drop
                (place-button
                 (transform cap
                            (rotation 90 2)
                            (translation 0 0 0))) 1)))

;; Take the intersection between the main chassis and mounted parts, such as the
;; board, bearings and caps.  This intersection should be empty, or virtually
;; so, otherwise there will be interference and the parts won't fit.  Assuming
;; the peripheral parts have been modeled carefully, this allows testing the
;; part prior to production.

(define-output interference
  (intersection chassis
                (union ball (place-board board) bearings caps)))

;; Produce an assembly of the parts selected via the various `place-*?` options.
;; This can be displayed for inspection, to get an idea of the final part.

(define-output assembly
  (when~> chassis

          place-boot? (union _ boot)
          place-ball? (union _ ball)
          place-board? (union _
                              (place-board board)
                              (place-port (translate usb-connector 0 0 2)))
          place-bearings? (union _ bearings)
          place-caps? (union _ caps)
          place-switches? (union _ (apply union
                                          (drop
                                           (place-button
                                            (rotate switch 90 2)) 1)))

          (list? vertical-section)
          (clip _ (transform (plane 0 1 0 (second vertical-section))
                             (rotation (first vertical-section) 2)))

          (list? horizontal-section)
          (clip _ (transform
                   (plane 0 0 1 0)
                   (rotation (first horizontal-section) 0)
                   (translation 0 0 (second horizontal-section))))))

;; This geometry can be used with Cura (and presumably other slicers) to block
;; support generation where it is as inconvenient as it is unnecessary.

(define-output blockers (apply
                         union
                         (append
                          (place-guide
                           (~> (cuboid 9 5 20)
                               flush-top
                               (translate _ 0 0 -3)))

                          (~> (cylinder boss-radius 20)
                              flush-top
                              (translate _ 0 0 -5)
                              place-boss))))

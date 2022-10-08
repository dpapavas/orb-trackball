;; -*- mode:scheme; coding: utf-8 -*-

;; This program builds a model of the PMW3389DM-T3QU optical sensor chip +
;; LM19‐LSI lens assembly.  It is processed by Gamma, the solid modeling
;; language, but it should not be processed on its own.  Instead, it's imported
;; as a library by the main program, in trackball.scm and processed as a part of
;; it.  See comments there for more information.

(define-library (sensor)
  (import (scheme base) (srfi 1)
          (gamma base) (gamma transformation) (gamma polygons)
          (gamma polyhedra) (gamma volumes) (gamma selection)
          (gamma operations))

  (begin
    ;; This is a simple helper that takes the desired dimensions of a part and
    ;; reduces them so that they turn out right after chamfering.

    (define eroded
      (case-λ
       ((c f) (λ args (apply f (map (partial - _ (* c 1/2)) args))))
       ((f) (eroded 1 f))))

    (define full-chamfer-kernel (octahedron 1/2 1/2 1/4))
    (define half-chamfer-kernel (regular-polygon 4 1/4))

    ;; We start of with a simple rectangular rod with cross-section dimensions
    ;; matching those of the chip pin, i.e. a straightened version of the pin,
    ;; which we're going to bend into shape.  Note that the extrusion is
    ;; designed so as to make the sections denser around the area of the bend.
    ;; That's because the bend, as with all deforming operations, simply
    ;; displaces existing geometry, so that if the straight pin was a simple
    ;; six-faced cuboid, it wouldn't work.

    ;; Incidentally you can inspect the result of any operation, by placing a
    ;; `?` after its opening parenthesis.  For instance, to see the unbent pin
    ;; geometry, try to uncomment the first `?` below then running:

    ;; $ gamma -Ddraft -o : ../trackball.scm

    ;; To see the result after the bend, uncomment the second `?`, before
    ;; `deform` (after re-commenting the first; you shouldn't generally have
    ;; more than one `?` at any one time.  Nothing dramatic will happen; one of
    ;; them will "win out" in the end, but you can't generally know which.)
    ;; Also note the strange `-o :` output selection, which selects the
    ;; "question mark" output for inspection.

    ;; The deform operation itself, accepts a selection of the vertices that are
    ;; to be affected by the bend (called the region of interest, or ROI), then
    ;; one or more of vertex selection + transformation pairs.  For each such
    ;; pair the vertices selected by the the selection are transformed (rigidly)
    ;; by the transformation and the rest of the mesh (more precisely the part
    ;; contained in the ROI), is deformed accordingly.  (The last argument is a
    ;; tolerance parameter.)  You can, of course, deform arbitrarily complex
    ;; geometry in the same way, not just simple rods.

    (define pin
      (~> (rectangle 1/2 1/5)
          (#;? apply extrusion _ (list-for ((z (append
                                                (list 0)
                                                (linear-partition 1/2 3/2 10)
                                                (list 5))))
                                   (translation 0 0 z)))
          (#;? deform
            _

            (vertices-in
             (difference
              (translate (bounding-halfspace 0 0 -1 0) 0 0 1/2)
              (translate (bounding-plane 0 0 -1 0) 0 0 1/2)))

            (vertices-in
             (translate (bounding-halfspace 0 0 -1 0) 0 0 3/2))

            (transformation-append
             (translation 0 0 1)
             (rotation 90 0)
             (translation 0 0 -1))

            1/10000)))

    ;; An array of the pin above on each side of the chip.

    (define pins
      (apply
       union
       (list-for ((s (iota 8))
                  (t (iota 2)))
         (transform pin
                    (rotation 90 0)
                    (rotation (+ -90 (* 180 t)) 2)
                    (translation (+ 1 (* t (- 91/10 4/10)))
                                 (+ (* s 178/100) (* t 89/100)) 0)))))

    (define chip
      (translate
       (minkowski-sum ((eroded cuboid) 91/10 162/10 24/10) full-chamfer-kernel)
       535/100 (- 162/20 152/100) (- 6/10 24/20)))

    (define lens
      (translate
       (union
        (hull (extrusion (minkowski-sum
                          ((eroded rectangle) 845/100 1565/100)
                          half-chamfer-kernel) (translation 0 59/100 0))
              (extrusion (minkowski-sum
                          ((eroded rectangle) 847/100 165/10)
                          half-chamfer-kernel) (translation 0 59/100 -471/100)))

        (~> (with-curve-tolerance
                1/100
              (apply hull
                     (list-for ((s (list -1 1))
                                (t (list -1 1)))
                       (transform ((eroded 1/2 circle) 7)
                                  (translation (* s 2425/1000) (* t 3575/1000))))))
            (apply linear-extrusion _ ((eroded -1/2 (λ x x)) -471/100 -671/100))
            (minkowski-sum _ full-chamfer-kernel)))
       535/100 (- 566/100 295/1000) (- 6/10 7/10)))

    ;; Combine that parts above and position them, such that pin #1 is at the
    ;; origin.  This matches the convention used in KiCad and makes precise
    ;; placing easier.

    (define assembly (apply union (map (partial transform
                                   _
                                   (translation 0 0 (- 981/100 74/10 6/10))
                                   (scaling 1 -1 1))
                          (list chip pins lens))))

    ;; Define an output of the assembly scaled in 10mil units, which is the
    ;; convention in KiCad.  This can be saved to WRL with `-o
    ;; PMW3389DM-T3QU.wrl` for import into KiCad.

    (define-output PMW3389DM-T3QU (apply scale assembly (make-list 3 100/254))))

  (export assembly))

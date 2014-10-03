(in-package :plot)

(defparameter *default-padding* 10)

(defclass axis (line)
  ;; we'll go ahead and inherit any line-related properties from
  ;; the line class itself
  ;; min and max values being plotted on the axis
  ((min-value :accessor axis-min-value
	      :initarg :min)
   (max-value :accessor axis-max-value
	      :initarg :max)
   ;; list of major and minor ticks
   ;; ticks should probably be their own objects so we can just call
   ;; some generic draw-line method on them
   (major-ticks :accessor axis-major-ticks
		:initarg :major-ticks)
   (minor-ticks :accessor axis-minor-ticks
		:initarg :minor-ticks)
   ;; padding between the axis and the start of the plot
   (padding :accessor axis-padding
            :initarg :padding
            :initform *default-padding*)
   ;; label for the axis
   (label :accessor axis-label
	  :initarg :label
          :initform nil)
   ;; internal variable, you probably shouldn't use this directly
   (label-position :accessor axis-label-position
                   :initarg label-position
                   :initform nil)
   ;; orientation in degrees, default is 0
   (label-orientation :accessor axis-label-orientation
                      :initarg label-orientation
                      :initform 0)
   ;; formatters are functions that control the label/tick text
   (label-formatter :accessor axis-label-formatter
		    :initarg :label-formatter)
   (tick-formatter :accessor axis-tick-formatter
		   :initarg :tick-formatter)))
	      

(defclass axes (plot-object)
  ((x-axis :accessor axes-x-axis
	   :initarg :x-axis
	   :initform nil)
   (y-axis :accessor axes-y-axis
	   :initarg :y-axis
	   :initform nil)
   ;; I'm not sure what these are for, seemingly redundant with the
   ;; individual axes
   (x-pos  :accessor axes-x
	   :initarg :x
	   :initform nil)
   (y-pos  :accessor axes-y
	   :initarg :y
	   :initform nil)
   ;; offsets
   (x-off  :accessor axes-x-off
	   :initarg :x-off
	   :initform nil)
   (y-off  :accessor axes-y-off
	   :initarg :y-off
	   :initform nil)
   ;; how much space the axes are allowed to occupy
   ;; consider allowing this to be specified as a percentage
   (width  :accessor axes-width
           :initarg :width
           :initform nil)
   (height :accessor axes-height
           :initarg :height
           :initform nil)
   ;; the data that the plots hold
   (data-objects :accessor axes-data
                 :initarg :data
                 :initform nil)))

(defmethod initialize-instance :before ((ax axes) &rest args)
  (declare (ignore args))
  ())

(defmethod initialize-instance :after ((ax axes) &rest args)
  ;; after the axes have been initialized we should initialize the
  ;; individual axis elements and make sure the axes 
  ;; some parameters must be initialized so they'll go here if not
  ;; passed in otherwise
  (unless (getf args :width)
    (setf (axes-width ax) *default-axes-width*))
  (unless (getf args :height)
    (setf (axes-height ax) *default-axes-height*))
  (unless (getf args :x-off)
    (setf (axes-x-off ax) *default-x-offset*))
  (unless (getf args :y-off)
    (setf (axes-y-off ax) *default-y-offset*))

  ;; now that we can guarantee that the offset and dimensions are set,
  ;; we should also set the bounding box
  (unless (getf args :bbox)
    (let ((lower-left-x (axes-x-off ax))
          (lower-left-y (axes-y-off ax))
          (upper-right-x (+ (axes-x-off ax) (axes-width ax)))
          (upper-right-y (+ (axes-y-off ax) (axes-height ax))))
      (setf (bbox ax) `(,lower-left-x ,lower-left-y ,upper-right-x ,upper-right-y))))

  ;; now we should initialize the actual axes if they were not passed
  ;; in explicitly

  ;; WARNING! Creating your own axis objects is definitely something
  ;; the end-user should NOT do! The init functions will take care to
  ;; align the children axis objects properly relative to the parent.
  ;; Safety not guaranteed if this functionality is overwritten.
  (unless (getf args :x-axis)
    (setf (axes-x-axis ax) (make-instance 'axis
                                          :thickness *default-line-thickness*
                                          :color *default-line-color*
                                          :parent ax)))
  (unless (getf args :y-axis)
    (setf (axes-y-axis ax) (make-instance 'axis
                                          :thickness *default-line-thickness*
                                          :color *default-line-color*
                                          :parent ax)))

  (when (axes-data ax)
    (typecase (axes-data ax)
      (data-object
       (setf (axes-data ax) (list (axes-data ax))))
      (cons
       (dolist (obj (axes-data ax))
         (setf (plot-object-parent obj) ax)))))

  ;; once we've created the children, normalize them
  (normalize-axes ax))
  
(defmethod normalize-axes ((ax axes))
  "Normalizes the children axis objects so that they fit properly within
the bounding box of the parent axes."
  (let ((x-axis (axes-x-axis ax))
        (y-axis (axes-y-axis ax))
        (width (axes-width ax))
        (height (axes-height ax))
        (x-off (axes-x-off ax))
        (y-off (axes-y-off ax)))
        ;;(axes-bbox (bbox ax)))
    ;; Note that normalize-axes is brutal; it will force the child
    ;; axis objects to have the right coordinates regardless of what
    ;; they had before
    (setf (line-start-x x-axis) x-off)
    (setf (line-end-x x-axis) (+ x-off width))
    (setf (line-start-y x-axis) y-off)
    (setf (line-end-y x-axis) y-off)

    (setf (line-start-x y-axis) x-off)
    (setf (line-end-x y-axis) x-off)
    (setf (line-start-y y-axis) y-off)
    (setf (line-end-y y-axis) (+ y-off height))))

(defmethod scale-data-to-axes ((ax axes))
  "This function scales the data supplied to the axes by performing
the necessary affine transformations. ax should already know where
it lives in image space; now the trick is to transform the data also
into image space."
  ;; an axes object could hold multiple data-objects that all need to
  ;; be transformed
  (print (length (axes-data ax)))
  (loop
     for data in (axes-data ax)
     do
       (format t "x data: ~A~%" (data-obj-x-data data))
     collect
       (let* ((scaled-data (make-instance 'data-object 
                                          :color (data-obj-color data)
                                          :style (data-obj-style data)
                                          :type (data-obj-type data)
                                          :thickness (data-obj-thickness data)
                                          :parent (plot-object-parent data)))
              (x-axis (axes-x-axis ax))
              (y-axis (axes-y-axis ax))
                                        ;(min-x (axis-min-value x-axis))
                                        ;(max-x (axis-max-value x-axis))
                                        ;(min-y (axis-min-value y-axis))
                                        ;(max-y (axis-min-value y-axis))
              (x-padding (axis-padding x-axis))
              (y-padding (axis-padding y-axis))
              (axes-bbox (bbox ax))
              ;; assume x-data and y-data have been set
              (x-data (data-obj-x-data data))
              (y-data (data-obj-y-data data))
              ;; data max and min
              ;;(dummy (format t "~A~%" x-data))
              (x-data-max (apply #'max x-data))
              (y-data-max (apply #'max y-data))
              (x-data-min (apply #'min x-data))
              (y-data-min (apply #'min y-data))
              ;;(dummy2 (format t "here ~%"))
              ;; data deltas
              (x-axis-delta (- (elt axes-bbox 2) (elt axes-bbox 0) (* 2 x-padding)))
              (y-axis-delta (- (elt axes-bbox 3) (elt axes-bbox 1) (* 2 y-padding)))
              (x-data-delta (- x-data-max x-data-min))
              (y-data-delta (- y-data-max y-data-min))
              ;; scale factors
              (x-scale (/ x-axis-delta x-data-delta))
              (y-scale (/ y-axis-delta y-data-delta))
              ;; offsets
              (x-offset (- (elt axes-bbox 2) (* x-data-max x-scale) (* 2 x-padding)))
              (y-offset (- (elt axes-bbox 3) (* y-data-max y-scale) (* 2 y-padding)))
              )

         ;; currently we only accept sequences as data; at some point we
         ;; should add support for vectors
         ;; until we get a proper condition system up
         (assert (= (length x-data) (length y-data)))

         (labels ((scale-x (x)
                    (coerce 
                     (+ (* x x-scale) x-offset x-padding)
                     'float))
                  (scale-y (y)
                    (coerce 
                     (+ (* y y-scale) y-offset y-padding) 
                     'float)))
           ;;(format t "x-axis-delta: ~F, y-axis-delta: ~F~%" x-axis-delta y-axis-delta)
           ;;(format t "x-scale: ~F, y-scale: ~F~%" x-scale y-scale)
           (let ((scaled-x-data (mapcar #'scale-x x-data))
                 (scaled-y-data (mapcar #'scale-y y-data)))
             ;;(format t "~A~%" scaled-x-data)
             ;;(format t "~A~%" scaled-y-data)
             (setf (data-obj-x-data scaled-data) scaled-x-data)
             (setf (data-obj-y-data scaled-data) scaled-y-data)
             scaled-data)))))
                   
         

(defun cond-loop (x)
  (conditional-loop x))

(defmacro conditional-loop (x)
  "A macro to conditionally loop on x depending on its type. "
  (let ((iter-method (gensym))
        (iter-value (gensym)))
    `(progn
       (let ((,iter-method 
              (cond ((listp ,x)
                     :in)
                    ((arrayp ,x)
                     :across)
                    (t
                     (print "no type for x")
                     nil)))
             (,iter-value
              (cond ((listp ,x)
                     ',x)
                    ((arrayp ,x)
                     ,x))))
         (print ,iter-value)
         `(loop
             for n ,,iter-method ,,iter-value
             do
               (print n))))))


(defmethod draw-axis ((ax axis) context)
  ;;(with-context (context)
  (draw-line ax context))

(defmethod draw-plot-object ((ax axis) context)
  (with-context (context)
    (draw-line ax context)))

(defmethod copy-axis-line ((ax axis))
  "Creates a line with all the properties of the axis."
  (make-instance 'line 
                 :color (line-color ax)
                 :thickness (line-thickness ax)
                 :style (line-style ax)
                 :start-x (line-start-x ax)
                 :end-x (line-end-x ax)
                 :start-y (line-start-y ax)
                 :end-y (line-end-y ax)))


(defmethod draw-plot-object ((ax axes) context)
  (with-context (context)
    ;; do some math here to transform from the data coordinates to the
    ;; picture coordinates

    ;; hmm, we might not want to use the draw-plot-object generic to
    ;; draw the axes. reason being that axes know their coordinate
    ;; system, while the children of the axes do not. so the function
    ;; that draws the axes needs to take some sort of coords as an
    ;; argument. need to think carefully about whether we want to
    ;; expand the args of the generic or make the draw-axes function
    ;; special 

    (let* ((scaled-data (scale-data-to-axes ax))
           (x-axis (axes-x-axis ax))
           (y-axis (axes-y-axis ax))
           ;; (width (axes-width ax))
           ;; (height (axes-height ax))
           (parent-plot (plot-object-parent ax))
           (parent-image (plot-object-parent parent-plot))
           ;; (im-width (plot-image-width parent-image))
           (im-height (plot-image-height parent-image)))
      ;; at this point we are assuming the axes are normalized so that
      ;; the children's start/end points line up with the corners of
      ;; the bounding box

      ;; draw the axes themselves
      (dolist (axis `(,x-axis ,y-axis))
        ;; image-y = image-height - y
        (let ((axis-line (copy-axis-line axis)))
          (setf (line-start-y axis-line) (- im-height (line-start-y axis-line)))
          (setf (line-end-y axis-line) (- im-height (line-end-y axis-line)))
          (draw-plot-object axis-line context)))

      ;; now draw the data
      (dolist (data-obj scaled-data)
        (loop
           for x in (data-obj-x-data data-obj)
           for y in (data-obj-y-data data-obj)
           do
             
             (let ((data-point 
                    (make-instance 'point 
                                   :x x 
                                   :y (- im-height y)
                                   :color (data-obj-color data-obj)
                                   :weight (data-obj-thickness data-obj)
                                   )))
               (draw-plot-object data-point context)))))))

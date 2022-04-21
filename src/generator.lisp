(in-package #:seedable-rng)

(defstruct (generator
            (:constructor %%make-generator)
            (:conc-name nil)
            (:predicate nil)
            (:copier nil))
  (kernel (pcg:make-pcg) :type pcg:pcg)
  (internal-seed 0 :type u:ub64)
  (seed "" :type string))

(defun make-seed ()
  (let ((*random-state* (make-random-state t))
        (words nil))
    (dotimes (i 5)
      (push (u:random-elt +dictionary+) words))
    (format nil "~{~a~^-~}" words)))

(defun make-inherited-seed (generator)
  (let (words)
    (dotimes (i 5)
      (push (element generator +dictionary+) words))
    (format nil "~{~a~^-~}" words)))

(defun make-internal-seed (seed-string)
  (ldb (byte 128 64)
       (ironclad:octets-to-integer
        (ironclad:produce-digest
         (ironclad:update-digest
          (ironclad:make-digest :md5)
          (ironclad:ascii-string-to-byte-array seed-string))))))

(defun %make-generator (seed)
  (let ((internal-seed (make-internal-seed seed)))
    (%%make-generator :kernel (pcg:make-pcg :seed internal-seed)
                      :seed seed
                      :internal-seed internal-seed)))

(defun make-generator (&optional source)
  "Construct a generator suitable for generating random numbers. The type of `source` determines how
the generator is seeded:

null: If `source` is NIL, a seed is randomly generated. This is useful if you don't care about
deterministic results.

string: Seeded using this string. Any generator with the same string seed will result in the same
sequence of random numbers.

generator: If given another generator as the source, a seed will be generated using the seed of the
generator supplied. In this way, you can have distinct nested generators giving independently
deterministic results."
  (etypecase source
    (null (%make-generator (make-seed)))
    (string (%make-generator source))
    (generator (%make-generator (make-inherited-seed source)))))

(defun get-seed (generator)
  "Return the seed string of `generator`. In case an integer is needed, one is provided as a
secondary return value."
  (values (seed generator)
          (ash (internal-seed generator) -32)))

(u:fn-> bool (generator &optional u:f32) boolean)
(defun bool (generator &optional (probability 0.5f0))
  "Randomly generate a boolean value, with `probability` chance of a true result."
  (declare (optimize speed))
  (< (the u:f32 (pcg:pcg-random (kernel generator) 1f0)) probability))

(u:fn-> int (generator fixnum fixnum &optional boolean) fixnum)
(defun int (generator min max &optional (inclusive-p t))
  "Randomly generate an integer (fixnum) to be within the lower bound and upper bound denoted by
`min` and `max`. If `inclusive-p` is non-NIL (the default), then the range is inclusive."
  (declare (optimize speed))
  (when (> min max)
    (error 'invalid-range :generator generator :min min :max max))
  (values (pcg:pcg-random (kernel generator) min max inclusive-p)))

(u:fn-> int/parity (generator fixnum fixnum) fixnum)
(defun int/parity (generator min max)
  "Randomly generate an integer (fixnum) to be within the lower bound and upper bound denoted by
`min` and `max`. The parity (even or odd) of `min` determines the parity of the result."
  (declare (optimize speed))
  (when (> min max)
    (error 'invalid-range :generator generator :min min :max max))
  (values (+ min (* 2 (pcg:pcg-random-bounded% (kernel generator) (1+ (floor (- max min) 2)))))))

(u:fn-> float (generator u:f32 u:f32) u:f32)
(defun float (generator min max)
  "Randomly generate a single-precision floating point number to be within the lower bound and upper
bound denoted by `min` and `max`."
  (declare (optimize speed))
  (when (> min max)
    (error 'invalid-range :generator generator :min min :max max))
  (values (pcg:pcg-random (kernel generator) min max)))

(u:fn-> element (generator sequence &optional boolean) t)
(defun element (generator sequence &optional (empty-error-p t))
  "Randomly choose a single element from the given sequence."
  (let ((length (length sequence)))
    (if (zerop length)
        (when empty-error-p
          (error 'empty-sequence :generator generator))
        (elt sequence (pcg:pcg-random (kernel generator) length)))))

(u:fn-> shuffle (generator sequence) sequence)
(defun shuffle (generator sequence)
  "Randomly shuffle the given sequence, non-destructively."
  (loop :with result = (copy-seq sequence)
        :with end = (1- (length result))
        :for i :from (1- end) :downto 0
        :do (rotatef (elt result i)
                     (elt result (+ i (int generator 0 (- end i)))))
        :finally (return result)))

(u:fn-> die (generator u:ub16 &key (:modifier u:ub16) (:count u:ub16)) u:ub32)
(defun die (generator sides &key (modifier 0) (count 1))
  "Simulate rolling a die of `sides` sides `count` number of times, summing the results. `modifier`
is an additional value to sum with the final result."
  (declare (optimize speed))
  (loop :repeat count
        :sum (int generator 1 sides) :into result :of-type u:ub32
        :finally (return (+ result modifier))))

(in-package #:cl-user)

(defpackage #:seedable-rng
  (:local-nicknames
   (#:u #:mfiano-utils))
  (:use #:cl)
  (:shadow
   #:float)
  (:export
   #:bool
   #:die
   #:element
   #:float
   #:generator
   #:get-seed
   #:int
   #:int/parity
   #:invalid-range
   #:make-generator
   #:make-seed
   #:shuffle))

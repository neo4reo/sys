;;; -*- Mode: LISP;  Package: TV; Base: 8 -*-
;;;	** (c) Copyright 1980 Massachusetts Institute of Technology **

;;; Io stream stuff
(DEFFLAVOR STREAM-MIXIN ((IO-BUFFER NIL) (RUBOUT-HANDLER-BUFFER NIL)) ()
  (:INCLUDED-FLAVORS ESSENTIAL-WINDOW)
  (:SELECT-METHOD-ORDER :TYO :STRING-OUT :LINE-OUT :TYI :TYI-NO-HANG :LISTEN
			:PIXEL :SET-PIXEL
			:DRAW-CHAR :DRAW-LINE :DRAW-RECTANGLE :DRAW-LINES :DRAW-TRIANGLE)
  (:GETTABLE-INSTANCE-VARIABLES IO-BUFFER)
  (:INITABLE-INSTANCE-VARIABLES IO-BUFFER RUBOUT-HANDLER-BUFFER)
  (:DOCUMENTATION :MIXIN "Ordinary tv stream operations
Gives all the meaningful stream operations for a display, such as :TYO, :TYI, :RUBOUT-HANDLER,
:STRING-OUT, etc.  Include this flavor someplace so that the window can be passed to functions
that take streams as arguments, and especially if TERMINAL-IO is going to be bound to the
window."))

(DEFMETHOD (STREAM-MIXIN :BEFORE :INIT) (IGNORE)
  (LET ((DEFAULT-CONS-AREA PERMANENT-STORAGE-AREA))
    (FUNCALL-SELF ':WHICH-OPERATIONS))		;Pre-create this, certainly going to be used
  (OR (EQ 'IO-BUFFER (TYPEP IO-BUFFER))
      (LET (SIZE INPUT-FUNCTION OUTPUT-FUNCTION)
	(IF (NUMBERP IO-BUFFER)
	    (SETQ SIZE IO-BUFFER
		  INPUT-FUNCTION NIL
		  OUTPUT-FUNCTION 'KBD-DEFAULT-OUTPUT-FUNCTION)
	    (SETQ SIZE (OR (FIRST IO-BUFFER) 100)
		  INPUT-FUNCTION (SECOND IO-BUFFER)
		  OUTPUT-FUNCTION (OR (THIRD IO-BUFFER) 'KBD-DEFAULT-OUTPUT-FUNCTION)))
 	(SETQ IO-BUFFER (MAKE-IO-BUFFER SIZE INPUT-FUNCTION OUTPUT-FUNCTION))))
  (OR RUBOUT-HANDLER-BUFFER
      (SETQ RUBOUT-HANDLER-BUFFER (MAKE-ARRAY NIL ART-STRING 1000 NIL '(0 0)))))

(DEFMETHOD (STREAM-MIXIN :BEFORE :SELECT) (&REST IGNORE)
  (KBD-CLEAR-SELECTED-IO-BUFFER))

(DEFMETHOD (STREAM-MIXIN :BEFORE :DESELECT) (&REST IGNORE)
  (KBD-CLEAR-SELECTED-IO-BUFFER))

(DEFMETHOD (STREAM-MIXIN :SET-IO-BUFFER) (NEW-BUFFER)
  (WITHOUT-INTERRUPTS
    (KBD-CLEAR-SELECTED-IO-BUFFER)
    (SETQ IO-BUFFER NEW-BUFFER)))

(DEFMETHOD (STREAM-MIXIN :TYO) (CH)
  (SHEET-TYO SELF CH))

(DEFMETHOD (STREAM-MIXIN :STRING-OUT) (STRING &OPTIONAL (START 0) END)
  (SHEET-STRING-OUT SELF STRING START END))

(DEFMETHOD (STREAM-MIXIN :LINE-OUT) (STRING &OPTIONAL (START 0) END)
  (SHEET-STRING-OUT SELF STRING START END)
  (SHEET-CRLF SELF))

(DEFMETHOD (STREAM-MIXIN :FRESH-LINE) ()
  (IF (= CURSOR-X (SHEET-INSIDE-LEFT))
      (SHEET-CLEAR-EOL SELF)
      (SHEET-CRLF SELF)))

(DEFMETHOD (STREAM-MIXIN :READ-CURSORPOS) (&OPTIONAL (UNITS ':PIXEL))
  (MULTIPLE-VALUE-BIND (X Y)
      (SHEET-READ-CURSORPOS SELF)
    (SELECTQ UNITS
      (:PIXEL)
      (:CHARACTER
	(SETQ X (// X CHAR-WIDTH)
	      Y  (// Y LINE-HEIGHT)))
      (OTHERWISE
	(FERROR NIL "~S is not a known unit." UNITS)))
    (PROG () (RETURN X Y))))

(DEFMETHOD (STREAM-MIXIN :SET-CURSORPOS) (X Y &OPTIONAL (UNITS ':PIXEL))
  (SELECTQ UNITS
    (:PIXEL)
    (:CHARACTER
      (AND X (SETQ X (* X CHAR-WIDTH)))
      (AND Y (SETQ Y (* Y LINE-HEIGHT))))
    (OTHERWISE
      (FERROR NIL "~S is not a known unit." UNITS)))
  (SHEET-SET-CURSORPOS SELF X Y))

(DEFMETHOD (STREAM-MIXIN :BASELINE) ()
  BASELINE)

(DEFMETHOD (STREAM-MIXIN :SIZE-IN-CHARACTERS) ()
  (PROG ()
    (RETURN (// (SHEET-INSIDE-WIDTH) CHAR-WIDTH) (SHEET-NUMBER-OF-INSIDE-LINES))))

(DEFMETHOD (STREAM-MIXIN :COMPUTE-MOTION) (STRING &OPTIONAL (START 0) (END NIL)
						            (X CURSOR-X) (Y CURSOR-Y)
							    (CR-AT-END-P NIL)
							    (STOP-X 0) (STOP-Y NIL))
  (SHEET-COMPUTE-MOTION SELF X Y STRING START END CR-AT-END-P STOP-X STOP-Y))

(DEFMETHOD (STREAM-MIXIN :STRING-LENGTH) (STRING
					  &OPTIONAL (START 0) (END NIL) (STOP-X NIL)
						    (FONT CURRENT-FONT) (START-X 0))
  (SHEET-STRING-LENGTH SELF STRING START END STOP-X FONT START-X))

(DEFMETHOD (STREAM-MIXIN :CHARACTER-WIDTH) (CHAR &OPTIONAL (FONT CURRENT-FONT))
  (SHEET-CHARACTER-WIDTH SELF CHAR FONT))

(DEFMETHOD (STREAM-MIXIN :HOME-CURSOR) ()
  (SHEET-HOME SELF))

(DEFMETHOD (STREAM-MIXIN :HOME-DOWN) ()
  (SHEET-SET-CURSORPOS SELF 0 (* (// (- (SHEET-INSIDE-HEIGHT) LINE-HEIGHT)
				     LINE-HEIGHT)
				 LINE-HEIGHT))
  (AND MORE-VPOS (SETQ MORE-VPOS (LOGIOR 100000 MORE-VPOS)))) ;Delay until next time

(DEFMETHOD (STREAM-MIXIN :CLEAR-EOL) ()
  (SHEET-CLEAR-EOL SELF))

(DEFMETHOD (STREAM-MIXIN :CLEAR-EOF) ()
  (SHEET-CLEAR-EOF SELF))

(DEFMETHOD (STREAM-MIXIN :CLEAR-CHAR) ()
  (SHEET-CLEAR-CHAR SELF))

(DEFMETHOD (STREAM-MIXIN :DRAW-RECTANGLE) (RECTANGLE-WIDTH RECTANGLE-HEIGHT X Y
					   &OPTIONAL (ALU CHAR-ALUF))
  (PREPARE-SHEET (SELF)
    (%DRAW-RECTANGLE-CLIPPED RECTANGLE-WIDTH RECTANGLE-HEIGHT
			     (+ (SHEET-INSIDE-LEFT) X)
			     (+ (SHEET-INSIDE-TOP) Y)
			     ALU SELF)))

(DEFMETHOD (STREAM-MIXIN :BITBLT) (ALU WID HEI FROM-ARRAY FROM-X FROM-Y TO-X TO-Y)
  (PREPARE-SHEET (SELF)
    (BITBLT ALU
	    (MIN WID (- (SHEET-INSIDE-WIDTH) TO-X)) (MIN HEI (- (SHEET-INSIDE-HEIGHT) TO-Y))
	    FROM-ARRAY FROM-X FROM-Y
	    SCREEN-ARRAY (+ TO-X (SHEET-INSIDE-LEFT)) (+ TO-Y (SHEET-INSIDE-TOP)))))

(DEFMETHOD (STREAM-MIXIN :BITBLT-FROM-SHEET) (ALU WID HEI FROM-X FROM-Y TO-ARRAY TO-X TO-Y)
  (PREPARE-SHEET (SELF)
     (BITBLT ALU WID HEI
	     SCREEN-ARRAY (+ FROM-X (SHEET-INSIDE-LEFT)) (+ FROM-Y (SHEET-INSIDE-TOP))
	     TO-ARRAY TO-X TO-Y)))

(DEFMETHOD (STREAM-MIXIN :PIXEL) (X Y)
  (PREPARE-SHEET (SELF)
    (AREF SCREEN-ARRAY (+ X (SHEET-INSIDE-LEFT))  (+ Y (SHEET-INSIDE-TOP)))))

(DEFMETHOD (STREAM-MIXIN :SET-PIXEL) (X Y VAL)
  (PREPARE-SHEET (SELF)
    (ASET VAL SCREEN-ARRAY (+ X (SHEET-INSIDE-LEFT))  (+ Y (SHEET-INSIDE-TOP)))))

(DEFMETHOD (STREAM-MIXIN :DRAW-CHAR) (FONT CHAR X-BITPOS Y-BITPOS &OPTIONAL (ALU CHAR-ALUF)
				      &AUX (FIT (FONT-INDEXING-TABLE FONT)))
  (PREPARE-SHEET (SELF)
    (SETQ X-BITPOS (+ X-BITPOS (SHEET-INSIDE-LEFT))
	  Y-BITPOS (+ Y-BITPOS (SHEET-INSIDE-TOP)))
    (IF (NULL FIT)
	(%DRAW-CHAR FONT CHAR X-BITPOS Y-BITPOS ALU SELF)
	;;Wide character, draw in segments
	(DO ((CH (AREF FIT CHAR) (1+ CH))
	     (LIM (AREF FIT (1+ CHAR)))
	     (BPP (SHEET-BITS-PER-PIXEL SELF))
	     (X X-BITPOS (+ X (// (FONT-RASTER-WIDTH FONT) BPP))))
	    ((= CH LIM))
	  (%DRAW-CHAR FONT CH X Y-BITPOS ALU SELF)))))

(DEFMETHOD (STREAM-MIXIN :INSERT-LINE) (&OPTIONAL (N 1))
  (SHEET-INSERT-LINE SELF N))

(DEFMETHOD (STREAM-MIXIN :DELETE-LINE) (&OPTIONAL (N 1))
  (SHEET-DELETE-LINE SELF N))

(DEFMETHOD (STREAM-MIXIN :INSERT-CHAR) (&OPTIONAL (N 1))
  (SHEET-INSERT-CHAR SELF N))

(DEFMETHOD (STREAM-MIXIN :DELETE-CHAR) (&OPTIONAL (N 1))
  (SHEET-DELETE-CHAR SELF N))

(DEFMETHOD (STREAM-MIXIN :INSERT-STRING) (STRING &OPTIONAL (START 0) END (TYPE-TOO T))
  (SHEET-INSERT-STRING SELF STRING START END TYPE-TOO))

(DEFMETHOD (STREAM-MIXIN :DELETE-STRING) (STRING &OPTIONAL (START 0) END)
  (SHEET-DELETE-STRING SELF STRING START END))

(DEFMETHOD (STREAM-MIXIN :HANDLE-EXCEPTIONS) ()
  (OR (ZEROP (SHEET-EXCEPTIONS)) (SHEET-HANDLE-EXCEPTIONS SELF)))

(DEFMETHOD (STREAM-MIXIN :UNTYI) (CH)
  (IF RUBOUT-HANDLER
      (STORE-ARRAY-LEADER (1- (ARRAY-LEADER RUBOUT-HANDLER-BUFFER 1)) RUBOUT-HANDLER-BUFFER 1)
      (IO-BUFFER-UNGET IO-BUFFER CH)))

(DEFMETHOD (STREAM-MIXIN :LISTEN) ()
  (NOT (AND ( (ARRAY-LEADER RUBOUT-HANDLER-BUFFER 0)
	       (ARRAY-LEADER RUBOUT-HANDLER-BUFFER 1))
	    (IO-BUFFER-EMPTY-P IO-BUFFER)
	    (WITHOUT-INTERRUPTS
	      (IF (NEQ IO-BUFFER (KBD-GET-IO-BUFFER)) T
		  (AND (KBD-HARDWARE-CHAR-AVAILABLE)
		       (KBD-PROCESS-MAIN-LOOP-INTERNAL))
		  (IO-BUFFER-EMPTY-P KBD-IO-BUFFER))))))

(DEFMETHOD (STREAM-MIXIN :CLEAR-INPUT) ()
  (STORE-ARRAY-LEADER 0 RUBOUT-HANDLER-BUFFER 0)
  (STORE-ARRAY-LEADER 0 RUBOUT-HANDLER-BUFFER 1)
  (IO-BUFFER-CLEAR IO-BUFFER)
  (AND (EQ IO-BUFFER (KBD-GET-IO-BUFFER))
       (KBD-CLEAR-IO-BUFFER)))

(DEFMETHOD (STREAM-MIXIN :TYI) (&OPTIONAL IGNORE &AUX IDX)
  (COND ((> (ARRAY-LEADER RUBOUT-HANDLER-BUFFER 0)
	    (SETQ IDX (ARRAY-LEADER RUBOUT-HANDLER-BUFFER 1)))
	 (STORE-ARRAY-LEADER (1+ IDX) RUBOUT-HANDLER-BUFFER 1)
	 (AREF RUBOUT-HANDLER-BUFFER IDX))
	((NOT RUBOUT-HANDLER)
	 (COND ((KBD-IO-BUFFER-GET IO-BUFFER T))
	       (T
		(FUNCALL-SELF ':NOTE-INPUT-WAIT)
		(KBD-IO-BUFFER-GET IO-BUFFER))))
	(T
	 (STREAM-MIXIN-RUBOUT-HANDLER RUBOUT-HANDLER-BUFFER))))

(DEFMETHOD (STREAM-MIXIN :TYI-NO-HANG) (&OPTIONAL IGNORE)
  (COND ((NOT RUBOUT-HANDLER)
	 (KBD-IO-BUFFER-GET IO-BUFFER T))
	(T
	 (FERROR NIL ":TYI-NO-HANG from inside a rubout handler."))))

(DEFVAR RUBOUT-HANDLER-OPTIONS NIL)	;These three are bound upon entering the
(DEFVAR RUBOUT-HANDLER-STARTING-X)	; rubout handler.
(DEFVAR RUBOUT-HANDLER-STARTING-Y)
(DEFVAR RUBOUT-HANDLER-RE-ECHO-FLAG)
(DEFVAR RUBOUT-HANDLER-INSIDE NIL)

(DEFMETHOD (STREAM-MIXIN :RUBOUT-HANDLER) (RUBOUT-HANDLER-OPTIONS FUNCTION &REST ARGS &AUX II)
  (COND ((> (ARRAY-LEADER RUBOUT-HANDLER-BUFFER 0) (ARRAY-LEADER RUBOUT-HANDLER-BUFFER 1))
	 (COPY-ARRAY-PORTION RUBOUT-HANDLER-BUFFER
			     (ARRAY-LEADER RUBOUT-HANDLER-BUFFER 1)
			     (ARRAY-LEADER RUBOUT-HANDLER-BUFFER 0)
			     RUBOUT-HANDLER-BUFFER 0 (ARRAY-LENGTH RUBOUT-HANDLER-BUFFER))
	 (STORE-ARRAY-LEADER (- (ARRAY-LEADER RUBOUT-HANDLER-BUFFER 0)
				(ARRAY-LEADER RUBOUT-HANDLER-BUFFER 1))
			     RUBOUT-HANDLER-BUFFER 0))
	(T (STORE-ARRAY-LEADER 0 RUBOUT-HANDLER-BUFFER 0)))
  (STORE-ARRAY-LEADER 0 RUBOUT-HANDLER-BUFFER 1)
  (LET ((PROMPT-OPTION (ASSQ ':PROMPT RUBOUT-HANDLER-OPTIONS)))
    (AND PROMPT-OPTION				;Prompt if desired
	 (FUNCALL (CADR PROMPT-OPTION) SELF NIL)))
  (MULTIPLE-VALUE-BIND (RUBOUT-HANDLER-STARTING-X RUBOUT-HANDLER-STARTING-Y)
      (SHEET-READ-CURSORPOS SELF)
    (COND ((SETQ II (CADR (ASSQ ':INITIAL-INPUT RUBOUT-HANDLER-OPTIONS)))
	   (OR ( (ARRAY-LENGTH RUBOUT-HANDLER-BUFFER) (ARRAY-ACTIVE-LENGTH II))
	       (ADJUST-ARRAY-SIZE RUBOUT-HANDLER-BUFFER (ARRAY-ACTIVE-LENGTH II)))
	   (COPY-ARRAY-CONTENTS II RUBOUT-HANDLER-BUFFER)
	   (STORE-ARRAY-LEADER (ARRAY-ACTIVE-LENGTH II) RUBOUT-HANDLER-BUFFER 0)))
    ;; Output any "typeahead"
    (FUNCALL-SELF ':STRING-OUT RUBOUT-HANDLER-BUFFER)
    (DO ((RUBOUT-HANDLER T)			;Establish rubout handler
	 (RUBOUT-HANDLER-INSIDE T)
	 (RUBOUT-HANDLER-RE-ECHO-FLAG NIL NIL))
	(NIL)
      (*CATCH 'RUBOUT-HANDLER			;Throw here when rubbing out
	(PROGN
	  (ERRSET (RETURN (APPLY FUNCTION ARGS)))	;Call read type function
	  (SETQ RUBOUT-HANDLER-RE-ECHO-FLAG T)
	  (DO () (NIL) (FUNCALL-SELF ':TYI))))		;If error, force user to rub out
      ;;Maybe return when user rubs all the way back
      (AND (ZEROP (ARRAY-LEADER RUBOUT-HANDLER-BUFFER 0))
	   (LET ((FULL-RUBOUT-OPTION (ASSQ ':FULL-RUBOUT RUBOUT-HANDLER-OPTIONS)))
	     (AND FULL-RUBOUT-OPTION (RETURN NIL (CADR FULL-RUBOUT-OPTION))))))))

;;; Give a single character, or do rubout processing, throws to RUBOUT-HANDLER on editting.
(DEFUN STREAM-MIXIN-RUBOUT-HANDLER (RUBOUT-HANDLER-BUFFER)
  (DO ((RUBOUT-HANDLER NIL)
       (RUBBED-OUT-SOME NIL)
       (PASS-THROUGH (CDR (ASSQ ':PASS-THROUGH RUBOUT-HANDLER-OPTIONS)))
       (PROMPT (OR (ASSQ ':REPROMPT RUBOUT-HANDLER-OPTIONS)
		   (ASSQ ':PROMPT RUBOUT-HANDLER-OPTIONS)))
       (CH) (LEN))
      (NIL)
   NEXTLOOP
    (SETQ CH (FUNCALL-SELF ':TYI))
    (COND ((MEMQ CH PASS-THROUGH))		;Suppress special checks for these
	  ((= CH #\CLEAR)			;CLEAR flushes all buffered input
	   (STORE-ARRAY-LEADER 0 RUBOUT-HANDLER-BUFFER 0)
	   (SETQ RUBBED-OUT-SOME T)		;Will need to throw out
	   (MULTIPLE-VALUE-BIND (X-NOW Y-NOW) (SHEET-READ-CURSORPOS SELF)
	     (SHEET-CLEAR-BETWEEN-CURSORPOSES
	       SELF RUBOUT-HANDLER-STARTING-X RUBOUT-HANDLER-STARTING-Y X-NOW Y-NOW))
	   (SHEET-SET-CURSORPOS SELF RUBOUT-HANDLER-STARTING-X RUBOUT-HANDLER-STARTING-Y)
	   (COND ((ASSQ ':FULL-RUBOUT RUBOUT-HANDLER-OPTIONS)
		  (STORE-ARRAY-LEADER 0 RUBOUT-HANDLER-BUFFER 1)
		  (*THROW 'RUBOUT-HANDLER T)))
	   (GO NEXTLOOP))
	  ((OR (= CH #\FORM) (= CH #\VT))	;Retype buffered input
	   (FUNCALL-SELF ':TYO CH)		;Echo it
	   (IF (= CH #\FORM) (FUNCALL-SELF ':CLEAR-SCREEN) (FUNCALL-SELF ':TYO #\CR))
	   (AND PROMPT (FUNCALL (CADR PROMPT) SELF CH))
	   (MULTIPLE-VALUE (RUBOUT-HANDLER-STARTING-X RUBOUT-HANDLER-STARTING-Y)
	     (SHEET-READ-CURSORPOS SELF))
	   (FUNCALL-SELF ':STRING-OUT RUBOUT-HANDLER-BUFFER)
	   (GO NEXTLOOP))
	  ((= CH #\RUBOUT)
	   (COND ((NOT (ZEROP (SETQ LEN (ARRAY-LEADER RUBOUT-HANDLER-BUFFER 0))))
		  (STORE-ARRAY-LEADER (SETQ LEN (1- LEN)) RUBOUT-HANDLER-BUFFER 0)
		  (SETQ RUBBED-OUT-SOME T)
		  (MULTIPLE-VALUE-BIND (X Y)
		      (SHEET-COMPUTE-MOTION SELF RUBOUT-HANDLER-STARTING-X
					    RUBOUT-HANDLER-STARTING-Y
					    RUBOUT-HANDLER-BUFFER 0 LEN)
		    (AND RUBOUT-HANDLER-RE-ECHO-FLAG
			 (SETQ X RUBOUT-HANDLER-STARTING-X Y RUBOUT-HANDLER-STARTING-Y))
		    (MULTIPLE-VALUE-BIND (CX CY) (SHEET-READ-CURSORPOS SELF)
		      (SHEET-CLEAR-BETWEEN-CURSORPOSES SELF X Y CX CY))
		    (SHEET-SET-CURSORPOS SELF X Y)
		    (AND RUBOUT-HANDLER-RE-ECHO-FLAG
			 (FUNCALL-SELF ':STRING-OUT RUBOUT-HANDLER-BUFFER)))))
	   (COND ((AND (ZEROP LEN) (ASSQ ':FULL-RUBOUT RUBOUT-HANDLER-OPTIONS))
		  (STORE-ARRAY-LEADER 0 RUBOUT-HANDLER-BUFFER 1)
		  (*THROW 'RUBOUT-HANDLER T)))
	   (GO NEXTLOOP))
	  ((LDB-TEST %%KBD-CONTROL-META CH)
	   (BEEP)
	   (COND ((ASSQ ':FULL-RUBOUT RUBOUT-HANDLER-OPTIONS)
		  (STORE-ARRAY-LEADER 0 RUBOUT-HANDLER-BUFFER 1)
		  (*THROW 'RUBOUT-HANDLER T)))
	   (GO NEXTLOOP)))
    ;; If this is first character typed in, re-get starting cursorpos since while
    ;; waiting for input a notification may have been typed out.
    (AND (ZEROP (ARRAY-LEADER RUBOUT-HANDLER-BUFFER 0))
	 (MULTIPLE-VALUE (RUBOUT-HANDLER-STARTING-X RUBOUT-HANDLER-STARTING-Y)
	   (SHEET-READ-CURSORPOS SELF)))
    (FUNCALL-SELF ':TYO CH)
    (ARRAY-PUSH-EXTEND RUBOUT-HANDLER-BUFFER CH)
    (COND (RUBBED-OUT-SOME
	   (STORE-ARRAY-LEADER 0 RUBOUT-HANDLER-BUFFER 1)
	   (*THROW 'RUBOUT-HANDLER T))
	  (T
	   (STORE-ARRAY-LEADER (ARRAY-LEADER RUBOUT-HANDLER-BUFFER 0)
			       RUBOUT-HANDLER-BUFFER 1)
	   (RETURN CH)))))

(DEFMETHOD (STREAM-MIXIN :FORCE-KBD-INPUT) (CH)
  (IO-BUFFER-PUT IO-BUFFER CH))

(DEFMETHOD (STREAM-MIXIN :NOTIFY) (ARG) (NOTIFY-USER ARG SELF))

(DEFFLAVOR LIST-TYI-MIXIN () ()
  (:REQUIRED-METHODS :ANY-TYI)
  (:DOCUMENTATION :MIXIN "Filters possible lists out of the :TYI message"))

;;;For things only prepared to deal with keyboard input
(DEFMETHOD (LIST-TYI-MIXIN :TYI) (&OPTIONAL IGNORE)
  (DO ((CH)) (NIL)
    (AND (NUMBERP (SETQ CH (FUNCALL-SELF ':ANY-TYI)))
	 (RETURN CH))))

(DEFMETHOD (LIST-TYI-MIXIN :TYI-NO-HANG) (&OPTIONAL IGNORE)
  (DO ((CH)) (NIL)
    (AND (OR (NULL (SETQ CH (FUNCALL-SELF ':ANY-TYI-NO-HANG)))
	     (NUMBERP CH))
	 (RETURN CH))))

;;;For things only prepared to deal with fixnums
(DEFMETHOD (LIST-TYI-MIXIN :MOUSE-OR-KBD-TYI) ()
  (DO ((CH)) (NIL)
    (AND (NUMBERP (SETQ CH (FUNCALL-SELF ':ANY-TYI)))
	 (RETURN CH CH))
    (AND (LISTP CH) (EQ (CAR CH) ':MOUSE)
	 (RETURN (THIRD CH) CH))))

(DEFMETHOD (LIST-TYI-MIXIN :MOUSE-OR-KBD-TYI-NO-HANG) ()
  (DO ((CH)) (NIL)
    (AND (OR (NULL (SETQ CH (FUNCALL-SELF ':ANY-TYI-NO-HANG)))
	     (NUMBERP CH))
	 (RETURN CH CH))
    (AND (LISTP CH) (EQ (CAR CH) ':MOUSE)
	 (RETURN (THIRD CH) CH))))

(DEFMETHOD (LIST-TYI-MIXIN :LIST-TYI) ()
  "Only return lists"
  (DO ((CH)) (())
    (SETQ CH (FUNCALL-SELF ':ANY-TYI))
    (AND (LISTP CH) (RETURN CH))))

(DEFFLAVOR ANY-TYI-MIXIN () (LIST-TYI-MIXIN)
  (:INCLUDED-FLAVORS STREAM-MIXIN)
  (:DOCUMENTATION :MIXIN "Filters possible lists out of the :TYI message.
Provides the default :ANY-TYI message."))

(DEFMETHOD (ANY-TYI-MIXIN :ANY-TYI) STREAM-MIXIN-TYI-METHOD)

(DEFMETHOD (ANY-TYI-MIXIN :ANY-TYI-NO-HANG) STREAM-MIXIN-TYI-NO-HANG-METHOD)

(DEFFLAVOR PREEMPTABLE-READ-ANY-TYI-MIXIN
	((OLD-TYPEAHEAD NIL))	;NIL means not doing preemptable read
				;String means not doing preemptable read,
				; but have a buffered string
				;T means doing preemptable read
	()
  (:INCLUDED-FLAVORS ANY-TYI-MIXIN)
  :GETTABLE-INSTANCE-VARIABLES
  :SETTABLE-INSTANCE-VARIABLES)

(DEFMETHOD (PREEMPTABLE-READ-ANY-TYI-MIXIN :TYI) (&OPTIONAL IGNORE)
  (DO ((CHAR))
      (())
    (SETQ CHAR (FUNCALL-SELF ':ANY-TYI))
    (COND ((NUMBERP CHAR) (RETURN CHAR))
	  ((AND RUBOUT-HANDLER-INSIDE (EQ OLD-TYPEAHEAD T))
	   (SETQ OLD-TYPEAHEAD (STRING-APPEND RUBOUT-HANDLER-BUFFER))
	   (FUNCALL-SELF ':UNTYI CHAR)
	   (RETURN #\CLEAR)))))

(DEFMETHOD (PREEMPTABLE-READ-ANY-TYI-MIXIN :PREEMPTABLE-READ) (OPTIONS FUN &REST ARGS)
  (DO ((TYPEAHEAD OLD-TYPEAHEAD NIL)
       (RESULT) (FLAG))
      (())
    (SETQ OLD-TYPEAHEAD T)
    (UNWIND-PROTECT
      (MULTIPLE-VALUE (RESULT FLAG)
	(LEXPR-FUNCALL-SELF ':RUBOUT-HANDLER (APPEND '((:FULL-RUBOUT :FULL-RUBOUT))
						     (AND (STRINGP TYPEAHEAD)
							  `((:INITIAL-INPUT ,TYPEAHEAD)))
						     OPTIONS)
			    FUN ARGS))
      (AND (EQ OLD-TYPEAHEAD T)
	   (SETQ OLD-TYPEAHEAD NIL)))
    (AND (NEQ FLAG ':FULL-RUBOUT)
	 (RETURN RESULT NIL))
    ;; Determine whether a mouse character caused the full-rubout
    (SETQ RESULT (FUNCALL-SELF ':TYI-NO-HANG))
    (COND (RESULT
	   (AND (LISTP RESULT)
		(RETURN RESULT ':MOUSE-CHAR))
	   (FUNCALL-SELF ':UNTYI RESULT)))
    (AND (SETQ FLAG (CADR (ASSQ ':FULL-RUBOUT OPTIONS)))
	 (RETURN NIL FLAG))))


(DEFFLAVOR LINE-TRUNCATING-MIXIN () ()
  (:INCLUDED-FLAVORS STREAM-MIXIN)
  (:DOCUMENTATION :MIXIN "Causes stream output functions to truncate if the
SHEET-TRUNCATE-LINE-OUT-FLAG in the window is set."))

(DEFWRAPPER (LINE-TRUNCATING-MIXIN :TYO) (IGNORE . BODY)
  `(*CATCH 'LINE-OVERFLOW
     . ,BODY))

(DEFMETHOD (LINE-TRUNCATING-MIXIN :BEFORE :END-OF-LINE-EXCEPTION) ()
  (OR (ZEROP (SHEET-TRUNCATE-LINE-OUT-FLAG))
      (*THROW 'LINE-OVERFLOW T)))

(DEFMETHOD (LINE-TRUNCATING-MIXIN :LINE-OUT) (STRING &OPTIONAL (START 0) END)
  (FUNCALL-SELF ':STRING-OUT STRING START END)
  (SHEET-CRLF SELF))

(DEFMETHOD (LINE-TRUNCATING-MIXIN :STRING-OUT) (STRING &OPTIONAL (START 0) END)
  (OR END (SETQ END (STRING-LENGTH STRING)))
  (DO ((I START (1+ CR-IDX))
       (CR-IDX))
      (( I END))
    (SETQ CR-IDX (STRING-SEARCH-CHAR #\CR STRING I END))
    (*CATCH 'LINE-OVERFLOW
      (SHEET-STRING-OUT SELF STRING I (OR CR-IDX END)))
    (OR CR-IDX (RETURN NIL))
    (SHEET-CRLF SELF)))

(DEFFLAVOR TRUNCATING-WINDOW () (LINE-TRUNCATING-MIXIN WINDOW)
  (:DEFAULT-INIT-PLIST :TRUNCATE-LINE-OUT-FLAG 1))

(DEFFLAVOR AUTOEXPOSING-MORE-MIXIN () ()
  (:INCLUDED-FLAVORS WINDOW))

(DEFMETHOD (AUTOEXPOSING-MORE-MIXIN :BEFORE :MORE-EXCEPTION) ()
  (FUNCALL-SELF ':EXPOSE))

(DEFFLAVOR GRAPHICS-MIXIN () ()
  (:INCLUDED-FLAVORS ESSENTIAL-WINDOW))

(DEFMETHOD (GRAPHICS-MIXIN :DRAW-LINE) (FROM-X FROM-Y TO-X TO-Y
					&OPTIONAL (ALU CHAR-ALUF) (DRAW-END-POINT T))
  (SETQ FROM-X (+ FROM-X (SHEET-INSIDE-LEFT))
	FROM-Y (+ FROM-Y (SHEET-INSIDE-TOP))
	TO-X (+ TO-X (SHEET-INSIDE-LEFT))
	TO-Y (+ TO-Y (SHEET-INSIDE-TOP)))
  (DO ((FROM-VISIBILITY (DRAW-LINE-CLIP-VISIBILITY FROM-X FROM-Y)
			(DRAW-LINE-CLIP-VISIBILITY FROM-X FROM-Y))
       (TO-VISIBILITY (DRAW-LINE-CLIP-VISIBILITY TO-X TO-Y))
       (EXCHANGED NIL))
      ;;When completely visible, draw the line
      ((AND (ZEROP FROM-VISIBILITY) (ZEROP TO-VISIBILITY))
       (AND EXCHANGED (PSETQ FROM-X TO-X TO-X FROM-X FROM-Y TO-Y TO-Y FROM-Y))
       (PREPARE-SHEET (SELF)
	 (%DRAW-LINE FROM-X FROM-Y TO-X TO-Y ALU DRAW-END-POINT SELF)))
    ;;If all off the screen, dont draw anything
    (OR (ZEROP (LOGAND FROM-VISIBILITY TO-VISIBILITY)) (RETURN NIL))
    ;;Exchange points to try to make to point visible
    (AND (ZEROP FROM-VISIBILITY)
	 (PSETQ FROM-X TO-X TO-X FROM-X FROM-Y TO-Y TO-Y FROM-Y
		FROM-VISIBILITY TO-VISIBILITY TO-VISIBILITY FROM-VISIBILITY
		EXCHANGED (NOT EXCHANGED)))
    ;;If TO-X = FROM-X then FROM-VISIBILITY = 0, 4 or 8 so there is no danger
    ;; of divide by zero in the next "Push"
    (COND ((LDB-TEST 0001 FROM-VISIBILITY)	;Push toward left edge
	   (SETQ FROM-Y (+ FROM-Y (// (* (- TO-Y FROM-Y) (- (SHEET-INSIDE-LEFT) FROM-X))
				      (- TO-X FROM-X)))
		 FROM-X (SHEET-INSIDE-LEFT)))
	  ((LDB-TEST 0101 FROM-VISIBILITY)	;Push toward right edge
	   (SETQ FROM-Y (+ FROM-Y (// (* (- TO-Y FROM-Y) (- (SHEET-INSIDE-RIGHT) FROM-X))
				      (- TO-X FROM-X)))
		 FROM-X (SHEET-INSIDE-RIGHT))))
    (COND ((LDB-TEST 0201 FROM-VISIBILITY)	;Push toward top
	   ;;It is possible that TO-Y = FROM-Y at this point because of the effects of
	   ;; the last "Push", but in that case TO-X is probably equal to FROM-X as well
	   ;; (or at least close to it) so we needn't draw anything:
	   (AND (= TO-Y FROM-Y) (RETURN NIL))
	   (SETQ FROM-X (+ FROM-X (// (* (- TO-X FROM-X) (- (SHEET-INSIDE-TOP) FROM-Y))
				      (- TO-Y FROM-Y)))
		 FROM-Y (SHEET-INSIDE-TOP)))
	  ((LDB-TEST 0301 FROM-VISIBILITY)	;Push toward bottom
	   ;; Same:
	   (AND (= TO-Y FROM-Y) (RETURN NIL))
	   (SETQ FROM-X (+ FROM-X (// (* (- TO-X FROM-X) (- (SHEET-INSIDE-BOTTOM) FROM-Y))
				      (- TO-Y FROM-Y)))
		 FROM-Y (SHEET-INSIDE-BOTTOM))))))

(DECLARE-FLAVOR-INSTANCE-VARIABLES (GRAPHICS-MIXIN)
(DEFUN DRAW-LINE-CLIP-VISIBILITY (POINT-X POINT-Y &AUX VISIBILITY)
  (SETQ VISIBILITY (COND ((< POINT-X (SHEET-INSIDE-LEFT)) 1)
			 ((> POINT-X (SHEET-INSIDE-RIGHT)) 2)
			 (T 0)))
  (COND ((< POINT-Y (SHEET-INSIDE-TOP)) (LOGIOR 4 VISIBILITY))
	((> POINT-Y (SHEET-INSIDE-BOTTOM)) (LOGIOR 8 VISIBILITY))
	(T VISIBILITY))))

;This never draws any end points, thus it is good for making closed polygons.
;Calls the :DRAW-LINE method to do the clipping.
(DEFMETHOD (GRAPHICS-MIXIN :DRAW-LINES) (ALU X1 Y1 &REST END-XS-AND-YS)
  (DO ((X2) (Y2) (METH (GET-HANDLER-FOR SELF ':DRAW-LINE))) ((NULL END-XS-AND-YS))
    (SETQ X2 (CAR END-XS-AND-YS)
	  Y2 (CADR END-XS-AND-YS)
	  END-XS-AND-YS (CDDR END-XS-AND-YS))
    (FUNCALL METH NIL X1 Y1 X2 Y2 ALU NIL)
    (SETQ X1 X2
	  Y1 Y2)))

;This clips in microcode
(DEFMETHOD (GRAPHICS-MIXIN :DRAW-TRIANGLE) (X1 Y1 X2 Y2 X3 Y3 &OPTIONAL (ALU CHAR-ALUF))
  (PREPARE-SHEET (SELF)
    (%DRAW-TRIANGLE (+ X1 (SHEET-INSIDE-LEFT)) (+ Y1 (SHEET-INSIDE-TOP))
		    (+ X2 (SHEET-INSIDE-LEFT)) (+ Y2 (SHEET-INSIDE-TOP))
		    (+ X3 (SHEET-INSIDE-LEFT)) (+ Y3 (SHEET-INSIDE-TOP))
		    ALU SELF)))

;;; This new X circle drawing is not altogether satisfactory.
(DEFMETHOD (GRAPHICS-MIXIN :DRAW-CIRCLE) (CENTER-X CENTER-Y RADIUS &OPTIONAL (ALU CHAR-ALUF))
  (SETQ CENTER-X (+ CENTER-X (SHEET-INSIDE-LEFT))
	CENTER-Y (+ CENTER-Y (SHEET-INSIDE-TOP))
	RADIUS (SMALL-FLOAT RADIUS))
  (PREPARE-SHEET (SELF)
    (DO ((X RADIUS)
	 (Y 0.0s0)
	 (OFX -1 FX)
	 (OFY -1 FY)
	 (FX) (FY)
	 ( (- (* 0.9s0 (// RADIUS))))
	 (FLAG NIL))
	((AND FLAG (> Y 0)))
      (SETQ FX (FIX (+ CENTER-X X))
	    FY (FIX (- CENTER-Y Y)))
      (OR (< FX (SHEET-INSIDE-LEFT)) ( FX (SHEET-INSIDE-RIGHT))
	  (< FY (SHEET-INSIDE-TOP)) ( FY (SHEET-INSIDE-BOTTOM))
	  (AND (= FX OFX) (= FY OFY))
	  (ASET (SELECT ALU
		  (ALU-IOR 1)
		  (ALU-ANDCA 0)
		  (ALU-XOR (1+ (AREF SCREEN-ARRAY FX FY))))
		SCREEN-ARRAY FX FY))
      (SETQ X (+ X (*  Y))
	    Y (- Y (*  X)))
      (OR FLAG (SETQ FLAG (MINUSP Y))))))

(DEFMETHOD (GRAPHICS-MIXIN :DRAW-FILLED-IN-CIRCLE) (CENTER-X CENTER-Y RADIUS
						    &OPTIONAL (ALU CHAR-ALUF))
  (SETQ RADIUS (SMALL-FLOAT RADIUS))
  (PREPARE-SHEET (SELF)
    (DO ((X 0.0s0)
	 (Y RADIUS)
	 (FY NIL NFY) (NFY)
	 (FX) (NFX)
	 ( (- (* 0.9s0 (// RADIUS))))
	 (WIDTH) (NWIDTH)
	 (FLAG NIL))
	(NIL)
      (SETQ NWIDTH (FIX (* X 2))
	    NFY (FIX (- CENTER-Y Y))
	    NFX (FIX (- CENTER-X X)))
      (IF (EQ NFY FY)				;If same line
	  (AND (> NWIDTH WIDTH)			;and this line wider
	       (SETQ WIDTH NWIDTH FX NFX))	;remember to draw it
	  ;; Different lines, draw last one
	  (AND FY (DRAW-RECTANGLE-INSIDE-CLIPPED WIDTH 1 FX FY ALU SELF))
	  (SETQ WIDTH NWIDTH FX NFX FY NFY)	;remember new values
	  (IF ( WIDTH 0)
	      (AND FLAG (RETURN))
	      (SETQ FLAG T)))
      (SETQ Y (+ Y (*  X))
	    X (- X (*  Y))))))

(DEFMETHOD (GRAPHICS-MIXIN :DRAW-FILLED-IN-CHORD) (CENTER-X CENTER-Y RADIUS THETA-1 THETA-2
						    &OPTIONAL (ALU CHAR-ALUF))
  (PREPARE-SHEET (SELF)
    (DO ((Y (- RADIUS) (1+ Y))
	 (X 0)
	 (U0 0) (U1 0)				;Clipped plane 1
	 (V0 0) (V1 0)				;Clipped plane 2
	 (CO-X0 (FIX (* -1000.0 (SIN THETA-1))))
	 (CO-Y0 (FIX (*  1000.0 (COS THETA-1))))
	 (CO-X1 (FIX (* -1000.0 (SIN THETA-2))))
	 (CO-Y1 (FIX (*  1000.0 (COS THETA-2))))
	 (FLAG (> (ABS (- THETA-1 THETA-2)) 3.14159))
	 (R2 (* RADIUS RADIUS)))
	((> Y RADIUS))
      (SETQ X (ISQRT (- R2 (* Y Y))))		;Unclipped line
      (SETQ U0 (- X) U1 X
	    V0 (- X) V1 X)			;Init clipped lines
      
      (AND (PLUSP (- (* CO-Y0 Y) (* CO-X0 U1)))	;Clip with first plane
	   (SETQ U1 (IF (= 0 CO-X0) 0 (// (* CO-Y0 Y) CO-X0))))
      (AND (PLUSP (- (* CO-Y0 Y) (* CO-X0 U0)))
	   (SETQ U0 (IF (= 0 CO-X0) 0 (// (* CO-Y0 Y) CO-X0))))
      
      (AND (MINUSP (- (* CO-Y1 Y) (* CO-X1 V1)))	;Clip with second plane
	   (SETQ V1 (IF (= 0 CO-X1) 0 (// (* CO-Y1 Y) CO-X1))))
      (AND (MINUSP (- (* CO-Y1 Y) (* CO-X1 V0)))
	   (SETQ V0 (IF (= 0 CO-X1) 0 (// (* CO-Y1 Y) CO-X1))))
      
      ;; Ok, we have two lines, [U0 U1] and [V0 V1].
      ;; If the angle was greater than pi, then draw both of them,
      ;; otherwise draw their intersection
      (COND (FLAG
	     (AND (> U1 U0)
		  (FUNCALL-SELF ':DRAW-LINE
				(+ CENTER-X U0) (+ CENTER-Y Y)
				(+ CENTER-X U1) (+ CENTER-Y Y)
				ALU T))
	     (AND (> V1 V0)
		  (FUNCALL-SELF ':DRAW-LINE 
				(+ CENTER-X V0) (+ CENTER-Y Y)
				(+ CENTER-X V1) (+ CENTER-Y Y)
				ALU T)))
	    (T					;Compute intersection
	     (LET ((LEFT  (MAX U0 V0))
		   (RIGHT (MIN U1 V1)))
	       (AND (> RIGHT LEFT)
		    (FUNCALL-SELF ':DRAW-LINE 
				  (+ CENTER-X LEFT)  (+ CENTER-Y Y)
				  (+ CENTER-X RIGHT) (+ CENTER-Y Y)
				  ALU T))))))))

;;; Given an edge and a number of sides, draw something
;;; The sign of N determines which side of the line the figure is drawn on.
;;; If the line is horizontal, the rest of the polygon is in the positive direction
;;; when N is positive.
(DEFMETHOD (GRAPHICS-MIXIN :DRAW-REGULAR-POLYGON) (X1 Y1 X2 Y2 N &OPTIONAL (ALU CHAR-ALUF)
								 &AUX THETA)
  (SETQ THETA (* 3.14159 (1- (// 2.0 N)))
	N (ABS N))  
  (PREPARE-SHEET (SELF)
    (DO ((I 2 (1+ I))
	 (SIN-THETA (SIN THETA))
	 (COS-THETA (COS THETA))
	 (X0 X1) (Y0 Y1)
	 (X3) (Y3))
	(( I N))
      (SETQ X3 (+ (- (- (* X1 COS-THETA)
			(* Y1 SIN-THETA))
		     (* X2 (1- COS-THETA)))
		  (* Y2 SIN-THETA))
	    Y3 (- (- (+ (* X1 SIN-THETA)
			(* Y1 COS-THETA))
		     (* X2 SIN-THETA))
		  (* Y2 (1- COS-THETA))))
      (%DRAW-TRIANGLE (+ (SHEET-INSIDE-LEFT) (FIX X0)) (+ (SHEET-INSIDE-TOP) (FIX Y0))
		      (+ (SHEET-INSIDE-LEFT) (FIX X2)) (+ (SHEET-INSIDE-TOP) (FIX Y2))
		      (+ (SHEET-INSIDE-LEFT) (FIX X3)) (+ (SHEET-INSIDE-TOP) (FIX Y3))
		      ALU SELF)
      (SETQ X1 X2 Y1 Y2
	    X2 X3 Y2 Y3))))

;;; Display vectors of points
(DEFMETHOD (GRAPHICS-MIXIN :DRAW-CURVE) (PX PY &OPTIONAL END (ALU CHAR-ALUF))
  (OR END (SETQ END (ARRAY-ACTIVE-LENGTH PX)))
  (DO ((I 1 (1+ I))
       (X0)
       (X1 (FIX (AREF PX 0)))
       (Y0)
       (Y1 (FIX (AREF PY 0)))
       (METH (GET-HANDLER-FOR SELF ':DRAW-LINE)))
      (( I END))
    (SETQ X0 X1)
    (OR (SETQ X1 (AREF PX I)) (RETURN NIL))
    (SETQ X1 (FIX X1))
    (SETQ Y0 Y1)
    (OR (SETQ Y1 (AREF PY I)) (RETURN NIL))
    (SETQ Y1 (FIX Y1))
    (FUNCALL METH NIL X0 Y0 X1 Y1 ALU NIL)))

(DEFMETHOD (GRAPHICS-MIXIN :DRAW-WIDE-CURVE) (PX PY WIDTH &OPTIONAL END (ALU CHAR-ALUF))
  (OR END (SETQ END (ARRAY-ACTIVE-LENGTH PX)))
  (SETQ WIDTH (// WIDTH 2.0s0))
  (PREPARE-SHEET (SELF)
    (DO ((I 0 (1+ I))
	 (X0) (Y0)
	 (X1) (Y1)
	 (PX1) (PY1)
	 (PX2) (PY2)
	 (PX3) (PY3)
	 (PX4) (PY4))
	(( I END))
      (SETQ X0 X1)
      (OR (SETQ X1 (AREF PX I)) (RETURN NIL))
      (SETQ Y0 Y1)
      (OR (SETQ Y1 (AREF PY I)) (RETURN NIL))
      (OR (= I 0)
	  (LET ((DX (- X1 X0))
		(DY (- Y1 Y0))
		LEN)
	    (SETQ LEN (SMALL-FLOAT (SQRT (+ (* DX DX) (* DY DY)))))
	    (AND (ZEROP LEN) (= I 1) (SETQ LEN 1))
	    (COND ((NOT (ZEROP LEN))
		   (PSETQ DX (// (* WIDTH DY) LEN)
			  DY (// (* WIDTH DX) LEN))
		   (IF (= I 1)
		       (SETQ PX1 (FIX (- X0 DX)) PY1 (FIX (+ Y0 DY))
			     PX2 (FIX (+ X0 DX)) PY2 (FIX (- Y0 DY)))
		       (SETQ PX1 PX3 PY1 PY3 PX2 PX4 PY2 PY4))
		   (SETQ PX3 (FIX (- X1 DX)) PY3 (FIX (+ Y1 DY))
			 PX4 (FIX (+ X1 DX)) PY4 (FIX (- Y1 DY)))
		   (%DRAW-TRIANGLE (+ (SHEET-INSIDE-LEFT) PX1) (+ (SHEET-INSIDE-TOP) PY1)
				   (+ (SHEET-INSIDE-LEFT) PX2) (+ (SHEET-INSIDE-TOP) PY2)
				   (+ (SHEET-INSIDE-LEFT) PX4) (+ (SHEET-INSIDE-TOP) PY4)
				   ALU SELF)
		   (%DRAW-TRIANGLE (+ (SHEET-INSIDE-LEFT) PX1) (+ (SHEET-INSIDE-TOP) PY1)
				   (+ (SHEET-INSIDE-LEFT) PX3) (+ (SHEET-INSIDE-TOP) PY3)
				   (+ (SHEET-INSIDE-LEFT) PX4) (+ (SHEET-INSIDE-TOP) PY4)
				   ALU SELF))))))))
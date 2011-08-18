;;;-*- Mode:LISP; Package:FORMAT -*-
;;; ** (c) Copyright 1980 Massachusetts Institute of Technology **

;;; (FQUERY OPTIONS FORMAT-STRING &REST FORMAT-ARGS)
;;; OPTIONS is a PLIST.  Defined indicators are:
;;; :MAKE-COMPLETE boolean.  Send a :MAKE-COMPLETE message to the stream if it understands it.
;;; :TYPE one of :TYI, :READLINE.  How typing is gathered and echoed.
;;; :CHOICES an alist.
;;; :FRESH-LINE boolean.  Send a FRESH-LINE to the stream initially.
;;; :CONDITION symbol.  Signalled before asking.
;;; :LIST-CHOICES boolean.  After prompting in parentheses.
;;; :BEEP boolean.  Before printing message.
;;; :CLEAR-INPUT boolean.  Before printing message.
;;; :SELECT boolean.  Select the window and select back.
;;; :HELP-FUNCTION function.  Called with STREAM, CHOICES and TYPE-FUNCTION as arguments.

(DEFVAR Y-OR-N-P-CHOICES '(((T "Yes.") #/Y #/T #\SP #\HAND-UP)
			   ((NIL "No.") #/N #\RUBOUT #\HAND-DOWN)))
(DEFVAR YES-OR-NO-P-CHOICES '((T "Yes") (NIL "No")))

(DEFVAR FQUERY-FORMAT-STRING)
(DEFVAR FQUERY-FORMAT-ARGS)
(DEFVAR FQUERY-LIST-CHOICES)
(DEFVAR FQUERY-CHOICES)
(DEFVAR FQUERY-HELP-FUNCTION)

(DEFUN FQUERY (OPTIONS FQUERY-FORMAT-STRING &REST FQUERY-FORMAT-ARGS
					    &AUX (MAKE-COMPLETE T)
						 (TYPE-FUNCTION (GET ':TYI 'FQUERY-FUNCTION))
						 (FQUERY-CHOICES Y-OR-N-P-CHOICES)
						 (FRESH-LINE T)
						 (CONDITION ':FQUERY)
						 (FQUERY-LIST-CHOICES T)
						 (FQUERY-HELP-FUNCTION 'DEFAULT-FQUERY-HELP)
						 BEEP-P CLEAR-INPUT SELECT
						 TYPEIN VAL HANDLED-P
						 OLD-SELECTED-WINDOW)
  (TV:DOPLIST (OPTIONS VAL KEY)
    (SELECTQ KEY
      (:MAKE-COMPLETE (SETQ MAKE-COMPLETE VAL))
      (:TYPE (SETQ TYPE-FUNCTION (OR (GET VAL 'FQUERY-FUNCTION)
				     (FERROR NIL "~S is not a valid type" VAL))))
      (:CHOICES (SETQ FQUERY-CHOICES VAL))
      (:BEEP (SETQ BEEP-P VAL))
      (:CLEAR-INPUT (SETQ CLEAR-INPUT VAL))
      (:SELECT (SETQ SELECT VAL))
      (:FRESH-LINE (SETQ FRESH-LINE VAL))
      (:CONDITION (SETQ CONDITION VAL))
      (:LIST-CHOICES (SETQ FQUERY-LIST-CHOICES VAL))
      (:HELP-FUNCTION (SETQ FQUERY-HELP-FUNCTION VAL))
      (OTHERWISE (FERROR NIL "~S is not a valid keyword" KEY))))
  (AND CONDITION
       (MULTIPLE-VALUE (HANDLED-P VAL)
	 (SIGNAL CONDITION OPTIONS FQUERY-FORMAT-STRING FQUERY-FORMAT-ARGS)))
  (IF HANDLED-P VAL
      (UNWIND-PROTECT
	(PROGN
	  (COND ((AND SELECT
		      (MEMQ ':SELECT (FUNCALL QUERY-IO ':WHICH-OPERATIONS)))
		 (FUNCALL QUERY-IO ':OUTPUT-HOLD-EXCEPTION)
		 (SETQ OLD-SELECTED-WINDOW TV:SELECTED-WINDOW)
		 (FUNCALL QUERY-IO ':SELECT)))		      
	  (DO-NAMED TOP () (NIL)
	    (AND BEEP-P (BEEP))
	    (AND CLEAR-INPUT (FUNCALL QUERY-IO ':CLEAR-INPUT))
	    (AND FRESH-LINE (FUNCALL QUERY-IO ':FRESH-LINE))
	    (SETQ TYPEIN (FUNCALL TYPE-FUNCTION ':READ QUERY-IO))
	    (DOLIST (CHOICE FQUERY-CHOICES)
	      (COND ((FUNCALL TYPE-FUNCTION ':MEMBER TYPEIN (CDR CHOICE))
		     (SETQ CHOICE (CAR CHOICE))
		     (COND ((LISTP CHOICE)
			    (FUNCALL TYPE-FUNCTION ':ECHO (CADR CHOICE) QUERY-IO)
			    (SETQ CHOICE (CAR CHOICE))))
		     (AND MAKE-COMPLETE
			  (MEMQ ':MAKE-COMPLETE (FUNCALL QUERY-IO ':WHICH-OPERATIONS))
			  (FUNCALL QUERY-IO ':MAKE-COMPLETE))
		     (RETURN-FROM TOP CHOICE))))
	    (SETQ BEEP-P T
		  CLEAR-INPUT T
		  FRESH-LINE T			;User spazzed, will need fresh line
		  FQUERY-LIST-CHOICES T)))	;and should list options
	(AND OLD-SELECTED-WINDOW (FUNCALL OLD-SELECTED-WINDOW ':SELECT NIL)))))

(DEFUN FQUERY-PROMPT (STREAM &REST IGNORE)
  (AND FQUERY-FORMAT-STRING
       (LEXPR-FUNCALL #'FORMAT STREAM FQUERY-FORMAT-STRING FQUERY-FORMAT-ARGS))
  (AND FQUERY-LIST-CHOICES
       (DO ((CHOICES FQUERY-CHOICES (CDR CHOICES))
	    (FIRST-P T NIL)
	    (MANY (> (LENGTH FQUERY-CHOICES) 2))
	    (CHOICE))
	   ((NULL CHOICES)
	    (OR FIRST-P
		(FUNCALL STREAM ':STRING-OUT ") ")))
	 (FUNCALL STREAM ':STRING-OUT (COND (FIRST-P "(")
					    ((NOT (NULL (CDR CHOICES))) ", ")
					    (MANY ", or ")
					    (T " or ")))
	 (SETQ CHOICE (CADAR CHOICES))
	 (IF (NUMBERP CHOICE)
	     (FORMAT STREAM "~:C" CHOICE)
	     (FUNCALL STREAM ':STRING-OUT CHOICE)))))

(DEFUN DEFAULT-FQUERY-HELP (STREAM CHOICES TYPE)
  TYPE						;Not relevant
  (DO ((CHOICES CHOICES (CDR CHOICES))
       (FIRST-P T NIL)
       (CHOICE))
      ((NULL CHOICES)
       (OR FIRST-P
	   (FUNCALL STREAM ':STRING-OUT ") ")))
    (FUNCALL STREAM ':STRING-OUT (COND (FIRST-P "(Type ")
				       ((NOT (NULL (CDR CHOICES))) ", ")
				       (T " or ")))
    (SETQ CHOICE (CAR CHOICES))
    ;Print the first input which selects this choice.
    ;Don't confuse the user by mentioning possible alternative inputs.
    (FORMAT STREAM  (IF (FIXP (CADR CHOICE)) "~:C" "~A") (CADR CHOICE))
    ;If that would echo as something else, say so
    (IF (LISTP (CAR CHOICE))
	(FORMAT STREAM " (~A)" (CADAR CHOICE)))))

(DEFPROP :TYI TYI-FQUERY-FUNCTION FQUERY-FUNCTION)
(DEFSELECT TYI-FQUERY-FUNCTION
  (:READ (STREAM)
    (DO ((CH)) (NIL)
      (FQUERY-PROMPT STREAM)
      (SETQ CH (FUNCALL STREAM ':TYI))
      (OR (AND (= CH #\HELP) (NOT (NULL FQUERY-HELP-FUNCTION)))
	  (RETURN CH))
      (FUNCALL FQUERY-HELP-FUNCTION STREAM FQUERY-CHOICES #'TYI-FQUERY-FUNCTION)))
  (:ECHO (ECHO STREAM)
    (FUNCALL STREAM ':STRING-OUT ECHO))
  (:MEMBER (CHAR LIST)
    (MEM #'CHAR-EQUAL CHAR LIST)))

(DEFPROP :READLINE READLINE-FQUERY-FUNCTION FQUERY-FUNCTION)
(DEFSELECT READLINE-FQUERY-FUNCTION
  (:READ (STREAM &AUX STRING)
    (SETQ STRING (FUNCALL STREAM ':RUBOUT-HANDLER '((:PASS-THROUGH (#\HELP))	;Just in case
						    (:PROMPT FQUERY-PROMPT))
			  #'FQUERY-READLINE-WITH-HELP STREAM))
    (STRING-TRIM '(#\SP) STRING))
  (:ECHO (ECHO STREAM)
    ECHO STREAM)
  (:MEMBER (STRING LIST)
    (MEM #'STRING-EQUAL STRING LIST)))

(DEFUN FQUERY-READLINE-WITH-HELP (STREAM)
  (DO ((STRING (MAKE-ARRAY 20. ':TYPE 'ART-STRING ':LEADER-LIST '(0)))
       (CH))
      (NIL)
    (SETQ CH (FUNCALL STREAM ':TYI))
    (COND ((OR (NULL CH) (= CH #\CR))
	   (RETURN STRING))
	  ((AND (= CH #\HELP) FQUERY-HELP-FUNCTION)
	   (FUNCALL FQUERY-HELP-FUNCTION STREAM FQUERY-CHOICES #'READLINE-FQUERY-FUNCTION)
	   (AND (MEMQ ':REFRESH-RUBOUT-HANDLER (FUNCALL STREAM ':WHICH-OPERATIONS))
		(FUNCALL STREAM ':REFRESH-RUBOUT-HANDLER)))
	  ((LDB-TEST %%KBD-CONTROL-META CH))
	  (T (ARRAY-PUSH-EXTEND STRING CH)))))

(DEFVAR Y-OR-N-P-OPTIONS `(:FRESH-LINE NIL
			   :LIST-CHOICES NIL))

(DEFUN Y-OR-N-P (&OPTIONAL MESSAGE (STREAM QUERY-IO))
  (LET ((QUERY-IO STREAM))
    (FQUERY Y-OR-N-P-OPTIONS (AND MESSAGE "~&~A") MESSAGE)))

(DEFVAR YES-OR-NO-P-OPTIONS `(:FRESH-LINE NIL
			      :LIST-CHOICES NIL
			      :BEEP T
			      :TYPE :READLINE
			      :CHOICES ,YES-OR-NO-P-CHOICES))

(DEFUN YES-OR-NO-P (&OPTIONAL MESSAGE (STREAM QUERY-IO))
  (LET ((QUERY-IO STREAM))
    (FQUERY YES-OR-NO-P-OPTIONS (AND MESSAGE "~&~A") MESSAGE)))

(DEFVAR YES-OR-NO-QUIETLY-P-OPTIONS `(:TYPE :READLINE
				      :CHOICES ,YES-OR-NO-P-CHOICES))

;;; -*-Mode:LISP; Package:ZWEI-*-
;;; ** (c) Copyright 1980 Massachusetts Institute of Technology **

;;; The editor stream

(DEFVAR *STREAM-COMTAB*)

(DEFFLAVOR EDITOR-STREAM-MIXIN
       ((TV:UNRCHF NIL)
	*STREAM-SHEET*
	*STREAM-START-BP*
	*STREAM-BP*
	*STREAM-BLINKER*
	(*STREAM-REQUIRE-ACTIVATION* NIL)
	(*STREAM-ACTIVATION-NEEDED* NIL)
	(*COMTAB* *STREAM-COMTAB*)
	(*MODE-LINE-LIST*  '("EDITOR-STREAM " "(" *MODE-NAME-LIST*
			     (*MODE-QUANTITY-NAME* " <" *MODE-QUANTITY-NAME* ">")
			     ")" (*STREAM-ACTIVATION-NEEDED* " {Not activating}"
							     :ELSE "")))
	*INTERVAL*)
       ()
  (:INCLUDED-FLAVORS SELF-IS-STANDARD-INPUT-EDITOR TOP-LEVEL-EDITOR TV:LIST-TYI-MIXIN)
  (:INITABLE-INSTANCE-VARIABLES *STREAM-REQUIRE-ACTIVATION* *INTERVAL*)
  (:INIT-KEYWORDS :IBEAM-BLINKER-P))

(DEFFLAVOR EDITOR-STREAM-WINDOW
	((GLITCH-AT-END-OF-PAGE NIL))
	(SELF-IS-STANDARD-INPUT-EDITOR TOP-LEVEL-EDITOR
	 EDITOR-WINDOW-WITH-POP-UP-MINI-BUFFER-MIXIN EDITOR-STREAM-MIXIN ZWEI-WINDOW)
  (:DEFAULT-INIT-PLIST :MORE-P T :RIGHT-MARGIN-CHARACTER-FLAG 0))

(DEFUN INITIALIZE-STREAM-COMTAB ()
  (COND ((NOT (BOUNDP '*STREAM-COMTAB*))
	 (SETQ *STREAM-COMTAB* (SET-COMTAB NIL '(#\END COM-ACTIVATE
						 #\CR COM-ACTIVATE
						 #\CLEAR COM-STREAM-CLEAR
						 #\FF COM-RECENTER-TO-TOP
						 #/A COM-QUICK-ARGLIST-INTO-BUFFER
						 #/ COM-QUICK-ARGLIST-INTO-BUFFER)
					   (MAKE-COMMAND-ALIST '(COM-REQUIRE-ACTIVATION))))
	 (SET-COMTAB-INDIRECTION *STREAM-COMTAB* *STANDARD-COMTAB*))))

(ADD-INITIALIZATION "INITIALIZE-STREAM-COMTAB" '(INITIALIZE-STREAM-COMTAB)
		    '(:NORMAL) '*EDITOR-INITIALIZATION-LIST*)

(DEFMETHOD (EDITOR-STREAM-MIXIN :AFTER :INIT) (INIT-PLIST)
  (OR (BOUNDP '*STREAM-SHEET*)
      (SETQ *STREAM-SHEET* (TV:MAKE-WINDOW 'ZWEI-WINDOW)))
  (SETQ *WINDOW* (FUNCALL *STREAM-SHEET* ':ZWEI-WINDOW)
	*STREAM-BLINKER* (WINDOW-POINT-BLINKER *WINDOW*))
  (OR (BOUNDP '*INTERVAL*)
      (SETQ *INTERVAL* (OR (WINDOW-INTERVAL *WINDOW*) (CREATE-INTERVAL NIL NIL T))))
  (OR (EQ *INTERVAL* (WINDOW-INTERVAL *WINDOW*))
      (SET-WINDOW-INTERVAL *WINDOW* *INTERVAL*))
  (PUSH *WINDOW* *WINDOW-LIST*)
  (AND (GET INIT-PLIST ':IBEAM-BLINKER-P)
       (LET ((BLINKER (TV:MAKE-BLINKER *STREAM-SHEET* 'STREAM-IBEAM-BLINKER
				       ':EDITOR-STREAM SELF ':VISIBILITY NIL )))
            (PUSH `(STREAM-BLINK-IBEAM . ,BLINKER)
		  (WINDOW-SPECIAL-BLINKER-LIST *WINDOW*))))
  (SETQ *STREAM-START-BP* (COPY-BP (INTERVAL-FIRST-BP *INTERVAL*) ':NORMAL)
	*STREAM-BP* (WINDOW-POINT *WINDOW*))
  (PUSH 'STREAM-PRE-COMMAND-HOOK *COMMAND-HOOK*)
  (PUSH 'STREAM-COMMAND-HOOK *POST-COMMAND-HOOK*))

(DEFMETHOD (EDITOR-STREAM-WINDOW :BEFORE :INIT) (IGNORE)
  (SETQ *STREAM-SHEET* SELF))

(DEFMETHOD (EDITOR-STREAM-WINDOW :AFTER :REFRESH) (&OPTIONAL IGNORE)
  (OR TV:RESTORED-BITS-P
      (NOT (TV:SHEET-EXPOSED-P *STREAM-SHEET*))
      (STREAM-REDISPLAY T)))

;;; Use this macro to surround code which simulates redisplay by calling SHEET- functions,
;;; It will suppress it if redisplay is pending, and setup abort it if an end of screen
;;; glitch occurs.
(DEFMACRO STREAM-IMMEDIATE-OUTPUT (&BODY BODY)
  `(OR (STREAM-MAYBE-REDISPLAY)
       (*CATCH 'END-OF-PAGE-GLITCH
	 (CONDITION-BIND ((END-OF-PAGE-GLITCH #'STREAM-END-OF-PAGE-GLITCH))
	   . ,BODY))))

(DEFMETHOD (EDITOR-STREAM-MIXIN :TYO) (CH)
  (INSERT-MOVING *STREAM-BP* CH)
  (STREAM-IMMEDIATE-OUTPUT
    (TV:SHEET-TYO *STREAM-SHEET* CH)))

(DEFMETHOD (EDITOR-STREAM-MIXIN :STRING-OUT) (STR &OPTIONAL (START 0) END)
  (INSERT-MOVING *STREAM-BP* (IF (AND (ZEROP START) (NULL END)) STR
				 (NSUBSTRING STR START END)))
  (STREAM-IMMEDIATE-OUTPUT
    (TV:SHEET-STRING-OUT *STREAM-SHEET* STR START END)))

(DEFMETHOD (EDITOR-STREAM-MIXIN :LINE-OUT) (STR &OPTIONAL (START 0) END)
  (INSERT-MOVING *STREAM-BP* (IF (AND (ZEROP START) (NULL END)) STR
				 (NSUBSTRING STR START END)))
  (INSERT-MOVING *STREAM-BP* #\CR)
  (STREAM-IMMEDIATE-OUTPUT
    (TV:SHEET-STRING-OUT *STREAM-SHEET* STR START END)
    (TV:SHEET-CRLF *STREAM-SHEET*)))

(DEFMETHOD (EDITOR-STREAM-MIXIN :UNTYI) (CH)
  (SETQ TV:UNRCHF CH))

(DEFMETHOD (EDITOR-STREAM-MIXIN :LISTEN) ()
  (NOT (AND (NULL TV:UNRCHF)
	    (OR (NOT RUBOUT-HANDLER) (BP-= *STREAM-BP* (INTERVAL-LAST-BP *INTERVAL*)))
	    TV:(IO-BUFFER-EMPTY-P IO-BUFFER)
	    TV:(OR (NEQ IO-BUFFER (KBD-GET-IO-BUFFER))
		(IO-BUFFER-EMPTY-P KBD-IO-BUFFER)))))

(DEFMETHOD (EDITOR-STREAM-MIXIN :CLEAR-INPUT) ()
  (SETQ TV:UNRCHF NIL)
  (AND RUBOUT-HANDLER (DELETE-INTERVAL *STREAM-BP* (INTERVAL-LAST-BP *INTERVAL*)))
  TV:(IO-BUFFER-CLEAR IO-BUFFER))

(DEFVAR *EDITOR-STREAM-ALREADY-KNOWS* NIL)

(DEFMETHOD (EDITOR-STREAM-MIXIN :ANY-TYI) (&OPTIONAL IGNORE)
  (COND (TV:UNRCHF
	 (IF (AND RUBOUT-HANDLER (NUMBERP TV:UNRCHF) (LDB-TEST %%KBD-CONTROL-META TV:UNRCHF))
	     (FUNCALL-SELF ':STREAM-RUBOUT-HANDLER)
	     (PROG1 TV:UNRCHF (SETQ TV:UNRCHF NIL))))
	((AND RUBOUT-HANDLER
	      (NOT (BP-= *STREAM-BP* (INTERVAL-LAST-BP *INTERVAL*))))
	 (PROG1 (BP-CHAR *STREAM-BP*)      ;Give buffered character if any
		(IBP *STREAM-BP*)))
	((NOT RUBOUT-HANDLER) 
	 (OR *EDITOR-STREAM-ALREADY-KNOWS*
	     (STREAM-REDISPLAY))
	 (COND ((TV:KBD-IO-BUFFER-GET TV:IO-BUFFER T))
	       (T
		(FUNCALL-SELF ':NOTICE ':INPUT-WAIT)
		(TV:KBD-IO-BUFFER-GET TV:IO-BUFFER))))
	(T
	 (LET ((*EDITOR-STREAM-ALREADY-KNOWS* T))
	   (FUNCALL-SELF ':STREAM-RUBOUT-HANDLER)))))

(DEFMETHOD (EDITOR-STREAM-MIXIN :TYI-NO-HANG) (&OPTIONAL IGNORE)
  (AND RUBOUT-HANDLER
       (FERROR NIL ":TYI-NO-HANG while inside RUBOUT-HANDLER"))
  (TV:KBD-IO-BUFFER-GET TV:IO-BUFFER T))

(DEFVAR *STREAM-PASS-THROUGH* NIL)

(DEFMETHOD (EDITOR-STREAM-MIXIN :RUBOUT-HANDLER) (RUBOUT-HANDLER-ARGS FUNCTION
						  &REST ARGS &AUX TEM)
  (MOVE-BP *STREAM-START-BP* (INTERVAL-LAST-BP *INTERVAL*))
  (COND ((AND TV:UNRCHF (NOT (LDB-TEST %%KBD-CONTROL-META TV:UNRCHF)))
	 (IF (EQ TV:UNRCHF (BP-CHAR-BEFORE *STREAM-START-BP*))	;Try to do the right thing
	     (DBP *STREAM-START-BP*)
	     (INSERT-MOVING *STREAM-BP* TV:UNRCHF)
	     (STREAM-IMMEDIATE-OUTPUT
	       (TV:SHEET-TYO *STREAM-SHEET* TV:UNRCHF)))
	 (SETQ TV:UNRCHF NIL)))
  (LET ((PROMPT-OPTION (ASSQ ':PROMPT RUBOUT-HANDLER-ARGS)))
    (COND (PROMPT-OPTION				;Prompt if desired
	   (FUNCALL (CADR PROMPT-OPTION) SELF NIL)
	   (MOVE-BP *STREAM-START-BP* (INTERVAL-LAST-BP *INTERVAL*)))))
  (STREAM-MAYBE-REDISPLAY)
  (DO ((RUBOUT-HANDLER T)			;Establish rubout handler
       (*STREAM-PASS-THROUGH* (CDR (ASSQ ':PASS-THROUGH RUBOUT-HANDLER-ARGS))))
      (())
    (WITH-BP (START-OF-MSG-BP *STREAM-START-BP* ':NORMAL)
      (WITH-BP (END-OF-MSG-BP *STREAM-START-BP* ':NORMAL)
	(*CATCH 'RUBOUT-HANDLER
	  (PROGN
	    (CATCH-ERROR                          ;Catch errors from within read
	      (CONDITION-BIND ((NIL #'STREAM-READ-ERROR-HANDLER))
		(RETURN (APPLY FUNCTION ARGS))))
	    (MOVE-BP *STREAM-START-BP* *STREAM-BP*)
	    (MOVE-BP END-OF-MSG-BP *STREAM-START-BP*)
	    (MOVE-BP *STREAM-BP* (INTERVAL-LAST-BP *INTERVAL*))
	    (MUST-REDISPLAY *WINDOW* DIS-BPS)
	    (STREAM-REDISPLAY)
	    (DO () (NIL) (FUNCALL-SELF ':TYI))))
	(DELETE-INTERVAL START-OF-MSG-BP END-OF-MSG-BP T)
	(MUST-REDISPLAY *WINDOW* DIS-TEXT)
	(STREAM-REDISPLAY)))
    ;; When a rubout or other editing operation is done, throws back to that
    ;; catch to reread the input.  But if the :FULL-RUBOUT option was specified
    ;; and everything was rubbed out, we return NIL and the specified value.
    (AND (BP-= *STREAM-START-BP* (INTERVAL-LAST-BP *INTERVAL*))
	 (SETQ TEM (ASSQ ':FULL-RUBOUT RUBOUT-HANDLER-ARGS))
	 (RETURN NIL (CADR TEM)))))

(DEFMETHOD (EDITOR-STREAM-MIXIN :AFTER :RUBOUT-HANDLER) (&REST IGNORE)
  (AND *ZTOP-KILL-RING-SAVE-P*
       (KILL-RING-SAVE-INTERVAL *STREAM-START-BP* (POINT))))

(DEFMETHOD (EDITOR-STREAM-MIXIN :FRESH-LINE) ()
  (OR (ZEROP (BP-INDEX *STREAM-BP*))
      (FUNCALL-SELF ':TYO #\CR)))

(DEFMETHOD (EDITOR-STREAM-MIXIN :REDISPLAY) (&OPTIONAL (DEGREE DIS-ALL))
  (SETF (WINDOW-REDISPLAY-DEGREE *WINDOW*) DEGREE)
  (STREAM-REDISPLAY))

(DEFWRAPPER (EDITOR-STREAM-MIXIN :EDIT) (IGNORE . BODY)
  `(PROGN
     (BIND (LOCF (TV:SHEET-MORE-VPOS *STREAM-SHEET*)) NIL)
     . ,BODY))

(DEFMETHOD (EDITOR-STREAM-MIXIN :STREAM-RUBOUT-HANDLER) (&AUX (RUBOUT-HANDLER NIL) CHAR)
  (SETQ CHAR (FUNCALL-SELF ':ANY-TYI))
  (COND ((MEMQ CHAR *STREAM-PASS-THROUGH*)	;Ignore special characters
	 CHAR)
	;; Just typeout self-inserting printing characters
	((AND (NUMBERP CHAR)
	      (OR (< CHAR 40)
		  (AND ( CHAR #/A) ( CHAR #/Z))
		  (AND ( CHAR #/a) ( CHAR #/z)))
	      (EQ 'COM-STANDARD (COMMAND-LOOKUP CHAR *COMTAB*)))
	 (INSERT-MOVING *STREAM-BP* CHAR)
	 (STREAM-IMMEDIATE-OUTPUT
	   (TV:SHEET-TYO *STREAM-SHEET* CHAR))
	 CHAR)
	(T
	 (SETQ TV:UNRCHF CHAR)
	 (MOVE-BP *STREAM-BP* (INTERVAL-LAST-BP *INTERVAL*))
	 (STREAM-REDISPLAY T)
	 (FAKE-OUT-TOP-LINE *WINDOW* *INTERVAL*)
	 (CONDITION-BIND ((BARF #'STREAM-BARF))
	   (LET ((*STREAM-ACTIVATION-NEEDED* NIL))
	     (FUNCALL-SELF ':EDIT)))
	 (MULTIPLE-VALUE-BIND (X Y) (TV:BLINKER-READ-CURSORPOS *STREAM-BLINKER*)
	   (TV:SHEET-SET-CURSORPOS *STREAM-SHEET* X Y))
	 (FUNCALL *STREAM-BLINKER* ':SET-FOLLOW-P T)	;Make the blinker follow again
	 (TV:BLINKER-SET-VISIBILITY *STREAM-BLINKER*
				    (IF (EQ *STREAM-SHEET* TV:SELECTED-WINDOW)
					':BLINK T))
	 (MOVE-BP *STREAM-BP* *STREAM-START-BP*)
	 (*THROW 'RUBOUT-HANDLER T))))

;;; Catch all errors from inside read and make a copy of the text so far so the error message
;;; looks reasonable
(DECLARE-FLAVOR-INSTANCE-VARIABLES (EDITOR-STREAM-MIXIN)
(DEFUN STREAM-READ-ERROR-HANDLER (&REST IGNORE)
  (INSERT-INTERVAL *STREAM-BP* *STREAM-START-BP* *STREAM-BP* T)
  (MUST-REDISPLAY *WINDOW* DIS-TEXT)
  NIL))

;;; Given a BP and a line-number, fake out the PLINE structure to think that that BP
;;; is displayed on that PLINE
(DEFUN FAKE-OUT-TOP-LINE (WINDOW BUFFER &AUX START-LINE START-INDEX START-PLINE LAST-BP SHEET)
  (SETQ LAST-BP (INTERVAL-LAST-BP BUFFER)
	SHEET (WINDOW-SHEET WINDOW))
  (SETQ START-PLINE (DO ((PLINE 0 (1+ PLINE))
			 (N-PLINES (WINDOW-N-PLINES WINDOW))
			 (LINE))
			(( PLINE N-PLINES) (1- N-PLINES))
		      (SETQ LINE (PLINE-LINE WINDOW PLINE))
		      (AND (OR (NULL LINE)
			       (> (LINE-TICK LINE) (PLINE-TICK WINDOW PLINE)))
			   (RETURN (1- PLINE)))))
  (IF (MINUSP START-PLINE)
      (LET ((BP (OR (WINDOW-START-BP WINDOW) (INTERVAL-FIRST-BP (WINDOW-INTERVAL WINDOW)))))
	(SETQ START-LINE (BP-LINE BP)
	      START-INDEX (BP-INDEX BP)
	      START-PLINE 0))
      (SETQ START-LINE (PLINE-LINE WINDOW START-PLINE)
	    START-INDEX (PLINE-TO-INDEX WINDOW START-PLINE))
      (AND (> START-INDEX (LINE-LENGTH START-LINE))	;Includes CR
	   (SETQ START-LINE (LINE-NEXT START-LINE)
		 START-INDEX 0
		 START-PLINE (1+ START-PLINE))))
  (DO-NAMED LINES
      ((LINE START-LINE (LINE-NEXT LINE))
       (FROM-INDEX START-INDEX 0)
       (TO-INDEX)
       (PLINE START-PLINE)
       (N-PLINES (WINDOW-N-PLINES WINDOW))
       (STOP-LINE (BP-LINE LAST-BP))
       (LH (TV:SHEET-LINE-HEIGHT SHEET))
       (I) (TW))
      ((NULL LINE))
    (SETQ TO-INDEX (IF (EQ LINE STOP-LINE) (BP-INDEX LAST-BP)
		       (LINE-LENGTH LINE)))
    (DO NIL (NIL)
      (MULTIPLE-VALUE (TW NIL I)
	(TV:SHEET-COMPUTE-MOTION SHEET 0 0 LINE FROM-INDEX TO-INDEX NIL 0 LH))
      (OR (NUMBERP I)
	  (SETQ I (1+ (LINE-LENGTH LINE))))
      (SETF (PLINE-LINE WINDOW PLINE) LINE)
      (SETF (PLINE-FROM-INDEX WINDOW PLINE) FROM-INDEX)
      (SETF (PLINE-TO-INDEX WINDOW PLINE) I)
      (SETF (PLINE-TICK WINDOW PLINE) *TICK*)
      (SETF (PLINE-MARKING-LEFT WINDOW PLINE) NIL)
      (SETF (PLINE-TEXT-WIDTH WINDOW PLINE)
	    (IF ( I (LINE-LENGTH LINE)) TW
		(+ TW (TV:SHEET-CHAR-WIDTH SHEET))))
      (SETQ FROM-INDEX I)
      (AND ( (SETQ PLINE (1+ PLINE)) N-PLINES) (RETURN-FROM LINES))
      (AND (> FROM-INDEX TO-INDEX) (RETURN)))
    (AND (EQ LINE STOP-LINE)
	 (RETURN NIL))))

(DEFUN STREAM-END-OF-PAGE-GLITCH (IGNORE)
  (*THROW 'END-OF-PAGE-GLITCH T))

;;; Do editor style redisplay if typing into some odd place, so that causality works right
;;; Return NIL otherwise, so character can just be SHEET-TYO'ed, eg
(DECLARE-FLAVOR-INSTANCE-VARIABLES (EDITOR-STREAM-MIXIN)
(DEFUN STREAM-MAYBE-REDISPLAY (&AUX (DEGREE (WINDOW-REDISPLAY-DEGREE *WINDOW*)))
  (OR (ZEROP (TV:SHEET-EXCEPTIONS *STREAM-SHEET*))
      (TV:SHEET-HANDLE-EXCEPTIONS *STREAM-SHEET*))
  (COND ((AND (BP-= *STREAM-BP* (INTERVAL-LAST-BP *INTERVAL*))
	      ( DEGREE DIS-NONE)
	      (NOT RUBOUT-HANDLER))			;Always redisplay on typein
	 ;; Turn off editor blinkers if faking redisplay
	 (DOLIST (BL (WINDOW-SPECIAL-BLINKER-LIST *WINDOW*))
	   (TV:BLINKER-SET-VISIBILITY (CDR BL) NIL))
	 NIL)
	(T
	 (MUST-REDISPLAY *WINDOW* DIS-TEXT)
	 (STREAM-REDISPLAY)
	 T))))

(DECLARE-FLAVOR-INSTANCE-VARIABLES (EDITOR-STREAM-MIXIN)
(DEFUN STREAM-REDISPLAY (&OPTIONAL FORCE-TO-COMPLETION &AUX (TERMINAL-IO *STREAM-SHEET*))
  (TV:PROCESS-TYPEAHEAD TV:IO-BUFFER
			#'(LAMBDA (CH)
			    (COND ((NLISTP CH) CH)
				  ((EQ (CAR CH) 'REDISPLAY) NIL)
				  (T CH))))
  (BIND (LOCF (TV:SHEET-MORE-VPOS *STREAM-SHEET*)) NIL)
  (REDISPLAY *WINDOW* ':POINT NIL NIL FORCE-TO-COMPLETION)
  (FUNCALL *STREAM-BLINKER* ':SET-FOLLOW-P T)
  (TV:BLINKER-SET-VISIBILITY *STREAM-BLINKER* (IF (EQ *STREAM-SHEET* TV:SELECTED-WINDOW)
						  ':BLINK T))))

;;; Command hook, throw out if character is to be passed through
(DECLARE-FLAVOR-INSTANCE-VARIABLES (EDITOR-STREAM-MIXIN)
(DEFUN STREAM-PRE-COMMAND-HOOK (CHAR)
  (COND ((MEMQ CHAR *STREAM-PASS-THROUGH*)
	 (SETQ TV:UNRCHF CHAR)
	 (*THROW 'EXIT-TOP-LEVEL NIL)))))

(DECLARE-FLAVOR-INSTANCE-VARIABLES (EDITOR-STREAM-MIXIN)
(DEFUN STREAM-BARF (&REST ARGS)
  (LET ((TERMINAL-IO *STREAM-SHEET*))
    (LEXPR-FUNCALL #'FERROR NIL (CDR ARGS)))))

;;; Command hook, if at the end of the buffer after the command, send through the buffered
;;; input.  *STREAM-ACTIVATION-NEEDED* means we were elsewhere than the end of the buffer
;;; once upon a time, and shouldnt activate until the user requests it.
;;; *STREAM-REQUIRE-ACTIVATION* is the user-settable flag the enables this mode
(DECLARE-FLAVOR-INSTANCE-VARIABLES (EDITOR-STREAM-MIXIN)
(DEFUN STREAM-COMMAND-HOOK (CHAR)
  (COND ((BP-= (POINT) (INTERVAL-LAST-BP *INTERVAL*))
	 (OR *STREAM-ACTIVATION-NEEDED*
	     (NOT (OR (< CHAR 200) (MEMQ CHAR '(#\TAB #\CR #\CLEAR #\RUBOUT))))
	     (NEQ (WINDOW-SHEET *WINDOW*) *STREAM-SHEET*)
	     (EQ *LAST-COMMAND-TYPE* 'INDENT-NEW-LINE)
	     (COM-ACTIVATE)))			;Automatically activate
	(T
	 (SETQ *STREAM-ACTIVATION-NEEDED* *STREAM-REQUIRE-ACTIVATION*)))))

;;; The C-CR command
(DECLARE-FLAVOR-INSTANCE-VARIABLES (EDITOR-STREAM-MIXIN)
(DEFCOM COM-ACTIVATE "Force out buffered input." ()
  (COND ((WINDOW-MARK-P *WINDOW*)		;If there is a region
	 (WITH-BP (BP (INTERVAL-LAST-BP *INTERVAL*) ':NORMAL)
	   (INSERT-INTERVAL BP (POINT) (MARK))	;copy it to the end
	   (DELETE-INTERVAL *STREAM-START-BP* BP T))
	 (AND (= (BP-CHAR-BEFORE (INTERVAL-LAST-BP *INTERVAL*)) #\CR)
	      (DELETE-INTERVAL (FORWARD-CHAR (INTERVAL-LAST-BP *INTERVAL*) -1)
			       (INTERVAL-LAST-BP *INTERVAL*) T))
	 (SETF (WINDOW-MARK-P *WINDOW*) NIL)
	 (MUST-REDISPLAY *WINDOW* DIS-TEXT)))
  (MOVE-BP (POINT) (INTERVAL-LAST-BP *INTERVAL*))
  (SETQ *STREAM-ACTIVATION-NEEDED* NIL)		;So that mode line updated right
  (MUST-REDISPLAY *WINDOW* DIS-BPS)
  (REDISPLAY *WINDOW* ':NONE)
  (REDISPLAY-MODE-LINE)
  (*THROW 'EXIT-TOP-LEVEL T)))

;;; Turn off normal activation, such as when moving in a lot of forms to be executed
(DECLARE-FLAVOR-INSTANCE-VARIABLES (EDITOR-STREAM-MIXIN)
(DEFCOM COM-REQUIRE-ACTIVATION
  "Turn off normal end of the buffer activation for the editor stream" ()
  (SETQ *STREAM-REQUIRE-ACTIVATION* (NOT (ZEROP *NUMERIC-ARG*)))
  DIS-NONE))

(DECLARE-FLAVOR-INSTANCE-VARIABLES (EDITOR-STREAM-MIXIN)
(DEFCOM COM-STREAM-CLEAR "Delete the form being typed in" ()
  (SETQ *CURRENT-COMMAND-TYPE* 'KILL)
  (LET ((POINT (POINT)))
    (MOVE-BP POINT (INTERVAL-LAST-BP *INTERVAL*))
    (KILL-INTERVAL *STREAM-START-BP* POINT T NIL))
  DIS-TEXT))

(DECLARE-FLAVOR-INSTANCE-VARIABLES (EDITOR-STREAM-MIXIN)
(DEFCOM COM-RECENTER-TO-TOP "Glitch screen to show start of form at top" ()
  (RECENTER-WINDOW *WINDOW* ':START *STREAM-START-BP*)
  DIS-NONE))

(DECLARE-FLAVOR-INSTANCE-VARIABLES (EDITOR-STREAM-MIXIN)
(DEFCOM COM-QUICK-ARGLIST-INTO-BUFFER "Insert arglist result into buffer" ()
  (LET ((STRING ;(QUICK-ARGLIST NIL)	;Someone broke this beyond repair
	  (WITH-OUTPUT-TO-STRING (S) (QUICK-ARGLIST S)))
	(BP (SKIP-OVER-BLANK-LINES-AND-COMMENTS *STREAM-START-BP* T)))
    (INSERT-MOVING BP *COMMENT-BEGIN*)
    (INSERT-MOVING BP STRING)
    (INSERT-MOVING BP #\CR))
  DIS-TEXT))

;;; Special ibeam blinker
(DEFFLAVOR STREAM-IBEAM-BLINKER (EDITOR-STREAM) (TV:IBEAM-BLINKER)
  (:DEFAULT-INIT-PLIST :HALF-PERIOD 32)
  (:INITABLE-INSTANCE-VARIABLES EDITOR-STREAM))

(DEFMETHOD (STREAM-IBEAM-BLINKER :COMPUTE-BLINKER-POSITION) (POINT)
  (FUNCALL EDITOR-STREAM ':COMPUTE-BLINKER-POSITION POINT))

(DEFMETHOD (EDITOR-STREAM-MIXIN :COMPUTE-BLINKER-POSITION) (POINT)
  (AND (EQ (BP-TOP-LEVEL-NODE POINT) *INTERVAL*)
       *STREAM-ACTIVATION-NEEDED*
       (NOT (BP-= *STREAM-START-BP* POINT))
       (FIND-BP-IN-WINDOW-COORDS *STREAM-START-BP* *WINDOW*)))

;;; Blink the ibeam if it isnt at point and we are going to need to activate
(DECLARE-FLAVOR-INSTANCE-VARIABLES (EDITOR-STREAM-MIXIN)
(DEFUN STREAM-BLINK-IBEAM (BLINKER WINDOW POINT IGNORE &AUX X Y)
  WINDOW
  (MULTIPLE-VALUE (X Y)
    (FUNCALL BLINKER ':COMPUTE-BLINKER-POSITION POINT))
  (COND (X
	 (TV:BLINKER-SET-CURSORPOS BLINKER X Y)
	 (TV:BLINKER-SET-VISIBILITY BLINKER ':BLINK))
	(T (TV:BLINKER-SET-VISIBILITY BLINKER NIL)))))

(DEFMETHOD (EDITOR-STREAM-WINDOW :AFTER :SET-INTERVAL) (INTERVAL)
  (MOVE-BP *STREAM-START-BP* (INTERVAL-LAST-BP INTERVAL))
  (SETQ *STREAM-BP* (WINDOW-POINT *WINDOW*))
  (MOVE-BP *STREAM-BP* *STREAM-START-BP*))

;;;The actual editor top level, a lisp listener in an editor window
(DEFFLAVOR EDITOR-TOP-LEVEL ()
	   (TV:LISTENER-MIXIN EDITOR-STREAM-WINDOW TV:FULL-SCREEN-HACK-MIXIN))
(DEFVAR *ZDT-WINDOW*)

(DEFUN ZDT (ON-P)
  (COND (ON-P
	 (INITIALIZE-STREAM-COMTAB)
	 (OR (BOUNDP '*ZDT-WINDOW*)
	     (SETQ *ZDT-WINDOW* (TV:MAKE-WINDOW 'EDITOR-TOP-LEVEL)))
	 (FUNCALL *ZDT-WINDOW* ':SELECT T))
	(T
	 (FUNCALL *ZDT-WINDOW* ':DESELECT T))))

;;; Streams that type into a particular window
(DEFFLAVOR EDITOR-STREAM-FROM-WINDOW (*WINDOW*) (EDITOR-STREAM-MIXIN)
  (:INITABLE-INSTANCE-VARIABLES *WINDOW*)
  (:GETTABLE-INSTANCE-VARIABLES *WINDOW*))

(DEFMETHOD (EDITOR-STREAM-FROM-WINDOW :BEFORE :INIT) (IGNORE)
  (AND (BOUNDP '*WINDOW*)
       (SETQ *STREAM-SHEET* (WINDOW-SHEET *WINDOW*)
	     *INTERVAL* (WINDOW-INTERVAL *WINDOW*))))

(DEFVAR *STREAMS-FROM-WINDOWS* NIL)

(DEFUN MAKE-EDITOR-STREAM-FROM-WINDOW (WINDOW)
  (OR (DOLIST (STREAM *STREAMS-FROM-WINDOWS*)
	(AND (EQ WINDOW (FUNCALL STREAM ':*WINDOW*))
	     (RETURN STREAM)))
      (LET ((INIT-PLIST (LIST ':*WINDOW* WINDOW)))
	(LET ((STREAM (INSTANTIATE-FLAVOR 'EDITOR-STREAM-FROM-WINDOW (LOCF INIT-PLIST)
					  T NIL TV:SHEET-AREA)))
	  (PUSH STREAM *STREAMS-FROM-WINDOWS*)
	  STREAM))))

;;; Some less useful messages

(DEFMETHOD (EDITOR-STREAM-MIXIN :UNTYO-MARK) ()
  (FUNCALL-SELF ':READ-BP))

(DEFMETHOD (EDITOR-STREAM-MIXIN :READ-BP) ()
  (COPY-BP *STREAM-BP*))

(DEFMETHOD (EDITOR-STREAM-MIXIN :UNTYO) (MARK)
  (DELETE-INTERVAL MARK *STREAM-BP* T)
  (MUST-REDISPLAY *WINDOW* DIS-TEXT)
  (STREAM-REDISPLAY))

(DEFMETHOD (EDITOR-STREAM-MIXIN :SET-BP) (BP)
  (MOVE-BP *STREAM-BP* BP)
  (MUST-REDISPLAY *WINDOW* DIS-BPS)
  (STREAM-REDISPLAY))

(DEFMETHOD (EDITOR-STREAM-MIXIN :DELETE-TEXT) ()
  (DELETE-INTERVAL *INTERVAL*)
  (MUST-REDISPLAY *WINDOW* DIS-TEXT)
  (STREAM-REDISPLAY))

(DEFMETHOD (EDITOR-STREAM-MIXIN :DELETE-INTERVAL) (FROM-BP &OPTIONAL TO-BP IN-ORDER-P)
  (DELETE-INTERVAL FROM-BP TO-BP IN-ORDER-P)
  (MUST-REDISPLAY *WINDOW* DIS-TEXT)
  (STREAM-REDISPLAY))

(DEFMETHOD (EDITOR-STREAM-MIXIN :TEXT-DELETED) ()
  (MUST-REDISPLAY *WINDOW* DIS-TEXT)
  (STREAM-REDISPLAY))

;;; Clear the screen by scrolling everything off of it
(DEFMETHOD (EDITOR-STREAM-MIXIN :CLEAR-SCREEN) ()
  (RECENTER-WINDOW *WINDOW* ':RELATIVE (- (WINDOW-N-PLINES *WINDOW*) 1))
  (STREAM-REDISPLAY))

(DEFMETHOD (EDITOR-STREAM-MIXIN :READ-CURSORPOS) (&OPTIONAL (UNITS ':PIXEL))
  (MUST-REDISPLAY *WINDOW* DIS-TEXT)
  (STREAM-REDISPLAY T)
  (MULTIPLE-VALUE-BIND (X Y)
      (FIND-BP-IN-WINDOW-COORDS *STREAM-BP* *WINDOW*)
    (SELECTQ UNITS
      (:PIXEL)
      (:CHARACTER
       (SETQ X (// X (TV:SHEET-CHAR-WIDTH (WINDOW-SHEET *WINDOW*)))
	     Y  (// Y (TV:SHEET-LINE-HEIGHT (WINDOW-SHEET *WINDOW*)))))
      (OTHERWISE
       (FERROR NIL "~S is not a known unit." UNITS)))
    (VALUES X Y)))

(DEFMETHOD (EDITOR-STREAM-MIXIN :SET-CURSORPOS) (X Y &OPTIONAL (UNITS ':PIXEL))
  (SELECTQ UNITS
    (:PIXEL)
    (:CHARACTER
      (AND X (SETQ X (* X (TV:SHEET-CHAR-WIDTH (WINDOW-SHEET *WINDOW*)))))
      (AND Y (SETQ Y (* Y (TV:SHEET-LINE-HEIGHT (WINDOW-SHEET *WINDOW*))))))
    (OTHERWISE
      (FERROR NIL "~S is not a known unit." UNITS)))
  (MUST-REDISPLAY *WINDOW* DIS-TEXT)
  (STREAM-REDISPLAY T)
  (MOVE-BP *STREAM-BP* (BP-FROM-COORDS *WINDOW* X Y))
  (MUST-REDISPLAY *WINDOW* DIS-TEXT)
  (STREAM-REDISPLAY))

(DEFUN BP-FROM-COORDS (WINDOW X Y &AUX SHEET LINE PLINE CHAR-POS LH REAL-PLINE START END)
  (SETQ SHEET (WINDOW-SHEET WINDOW))
  (SETQ LH (TV:SHEET-LINE-HEIGHT SHEET)
	PLINE (SETQ REAL-PLINE (// Y LH)))
  (COND ((MINUSP PLINE)
	 (SETQ PLINE 0))
	(( PLINE (WINDOW-N-PLINES WINDOW))
	 (SETQ PLINE (WINDOW-N-PLINES WINDOW))))
  (DO NIL ((OR (NULL (PLINE-LINE WINDOW PLINE))
	       (ZEROP (PLINE-FROM-INDEX WINDOW PLINE))))
    (AND (ZEROP PLINE) (RETURN))
    (SETQ PLINE (1- PLINE)))
  ;; If there is no line there, extend the buffer until there is one
  (OR (SETQ LINE (PLINE-LINE WINDOW PLINE))
      (DO ((I 0 (1+ I))
	   (P PLINE (1- P)))
	  ((PLINE-LINE WINDOW P)
	   (LET ((LAST-BP (INTERVAL-LAST-BP *INTERVAL*)))
	     (DOTIMES (J I)
	       (INSERT LAST-BP #\CR))
	     (SETQ LINE (BP-LINE LAST-BP))))))
  (SETQ START (PLINE-FROM-INDEX WINDOW PLINE))
  (LET ((BP (INTERVAL-FIRST-BP (WINDOW-INTERVAL WINDOW))))
    (AND (EQ LINE (BP-LINE BP)) (SETQ START (MIN START (BP-INDEX BP)))))
  (LET ((BP (INTERVAL-LAST-BP (WINDOW-INTERVAL WINDOW))))
    (AND (EQ LINE (BP-LINE BP)) (SETQ END (BP-INDEX BP))))
  (MULTIPLE-VALUE (NIL NIL CHAR-POS)		;Find character to right
    (TV:SHEET-COMPUTE-MOTION SHEET 0 (* PLINE LH) LINE START END NIL
			     (MAX 0 X)
			     (* REAL-PLINE LH)))
  ;; If there is no such index, extend the line
  (IF CHAR-POS
      (CREATE-BP LINE CHAR-POS)
      (INDENT-TO (CREATE-BP LINE (LINE-LENGTH LINE)) X SHEET)))

(DEFMETHOD (EDITOR-STREAM-MIXIN :HOME-CURSOR) ()
  (FUNCALL-SELF ':SET-CURSORPOS 0 0))

(DEFMETHOD (EDITOR-STREAM-MIXIN :CLEAR-EOL) ()
  (DELETE-INTERVAL *STREAM-BP* (END-LINE *STREAM-BP* 0 T) T)
  (MUST-REDISPLAY *WINDOW* DIS-TEXT)
  (STREAM-REDISPLAY))

(DEFMETHOD (EDITOR-STREAM-MIXIN :CLEAR-EOF) ()
  (DELETE-INTERVAL *STREAM-BP* (INTERVAL-LAST-BP *INTERVAL*) T)
  (MUST-REDISPLAY *WINDOW* DIS-TEXT)
  (STREAM-REDISPLAY))

(DEFMETHOD (EDITOR-STREAM-MIXIN :CLEAR-CHAR) ()
  (LET ((LINE (BP-LINE *STREAM-BP*))
	(IDX (BP-INDEX *STREAM-BP*)))
    (ASET #\SP LINE IDX)
    (MUNG-LINE LINE))
  (MUST-REDISPLAY *WINDOW* DIS-TEXT)
  (STREAM-REDISPLAY))

(DEFMETHOD (EDITOR-STREAM-MIXIN :INSERT-LINE) (&OPTIONAL (NLINES 1))
  (DOTIMES (I NLINES)
    (INSERT *STREAM-BP* #\CR))
  (MUST-REDISPLAY *WINDOW* DIS-TEXT)
  (STREAM-REDISPLAY))

(DEFMETHOD (EDITOR-STREAM-MIXIN :DELETE-LINE) (&OPTIONAL (NLINES 1))
  (DELETE-INTERVAL *STREAM-BP* (FORWARD-LINE *STREAM-BP* NLINES T) T)
  (MUST-REDISPLAY *WINDOW* DIS-TEXT)
  (STREAM-REDISPLAY))

(DEFMETHOD (EDITOR-STREAM-MIXIN :INSERT-CHAR) (&OPTIONAL (NCHARS 1))
  (DOTIMES (I NCHARS)
    (INSERT *STREAM-BP* #\SP))
  (MUST-REDISPLAY *WINDOW* DIS-TEXT)
  (STREAM-REDISPLAY))

(DEFMETHOD (EDITOR-STREAM-MIXIN :DELETE-CHAR) (&OPTIONAL (NCHARS 1))
  (DELETE-INTERVAL *STREAM-BP* (FORWARD-CHAR *STREAM-BP* NCHARS T) T)
  (MUST-REDISPLAY *WINDOW* DIS-TEXT)
  (STREAM-REDISPLAY))

;;; Editors always insert, this should be close, therefore.
(DEFMETHOD (EDITOR-STREAM-MIXIN :INSERT-STRING) (STRING &OPTIONAL (START 0) END)
  (FUNCALL-SELF ':STRING-OUT STRING START END))

(DEFFLAVOR SELF-IS-STANDARD-INPUT-EDITOR () ()
  (:INCLUDED-FLAVORS TOP-LEVEL-EDITOR))

(DEFMETHOD (SELF-IS-STANDARD-INPUT-EDITOR :TERMINAL-STREAMS) ()
  (VALUES SELF SI:SYN-TERMINAL-IO SI:SYN-TERMINAL-IO SI:SYN-TERMINAL-IO))

;;; This is for things that don't have normal window included
(DEFFLAVOR EDITOR-STREAM-WITHOUT-WINDOW-MIXIN () ()
  (:INCLUDED-FLAVORS EDITOR-STREAM-MIXIN))

(DEFMETHOD (EDITOR-STREAM-WITHOUT-WINDOW-MIXIN :HOME-DOWN)
	   EDITOR-STREAM-WITHOUT-WINDOW-MIXIN-PASS-ON-MESSAGE-TO-WINDOW)

(DEFMETHOD (EDITOR-STREAM-WITHOUT-WINDOW-MIXIN :SIZE)
	   EDITOR-STREAM-WITHOUT-WINDOW-MIXIN-PASS-ON-MESSAGE-TO-WINDOW)

(DEFMETHOD (EDITOR-STREAM-WITHOUT-WINDOW-MIXIN :INSIDE-SIZE)
	   EDITOR-STREAM-WITHOUT-WINDOW-MIXIN-PASS-ON-MESSAGE-TO-WINDOW)

(DEFMETHOD (EDITOR-STREAM-WITHOUT-WINDOW-MIXIN :REFRESH)
	   EDITOR-STREAM-WITHOUT-WINDOW-MIXIN-PASS-ON-MESSAGE-TO-WINDOW)

(DEFMETHOD (EDITOR-STREAM-WITHOUT-WINDOW-MIXIN :BEEP)
	   EDITOR-STREAM-WITHOUT-WINDOW-MIXIN-PASS-ON-MESSAGE-TO-WINDOW)

(DEFMETHOD (EDITOR-STREAM-WITHOUT-WINDOW-MIXIN :SIZE-IN-CHARACTERS)
	   EDITOR-STREAM-WITHOUT-WINDOW-MIXIN-PASS-ON-MESSAGE-TO-WINDOW)

(DEFMETHOD (EDITOR-STREAM-WITHOUT-WINDOW-MIXIN :COMPUTE-MOTION)
	   EDITOR-STREAM-WITHOUT-WINDOW-MIXIN-PASS-ON-MESSAGE-TO-WINDOW)

(DEFMETHOD (EDITOR-STREAM-WITHOUT-WINDOW-MIXIN :STRING-LENGTH)
	   EDITOR-STREAM-WITHOUT-WINDOW-MIXIN-PASS-ON-MESSAGE-TO-WINDOW)

(DEFMETHOD (EDITOR-STREAM-WITHOUT-WINDOW-MIXIN :CHARACTER-WIDTH)
	   EDITOR-STREAM-WITHOUT-WINDOW-MIXIN-PASS-ON-MESSAGE-TO-WINDOW)

(DEFMETHOD (EDITOR-STREAM-WITHOUT-WINDOW-MIXIN :FORCE-KBD-INPUT)
	   EDITOR-STREAM-WITHOUT-WINDOW-MIXIN-PASS-ON-MESSAGE-TO-WINDOW)

(DEFMETHOD (EDITOR-STREAM-WITHOUT-WINDOW-MIXIN :HANDLE-EXCEPTIONS)
	   EDITOR-STREAM-WITHOUT-WINDOW-MIXIN-PASS-ON-MESSAGE-TO-WINDOW)

(DEFMETHOD (EDITOR-STREAM-WITHOUT-WINDOW-MIXIN :NOTICE)	;for :INPUT-WAIT
	   EDITOR-STREAM-WITHOUT-WINDOW-MIXIN-PASS-ON-MESSAGE-TO-WINDOW)

(DEFUN EDITOR-STREAM-WITHOUT-WINDOW-MIXIN-PASS-ON-MESSAGE-TO-WINDOW (&REST REST)
  (LEXPR-FUNCALL (WINDOW-SHEET *WINDOW*) REST))

;;; Editor top level major mode
(DEFVAR *ZTOP-PRIN1* NIL)			;Set this to 'ZTOP-EVALUATION-PRIN1
(DEFVAR *ZTOP-GRIND-EVALUATION-RESULT-P* T)	;and these variables take effect
(DEFVAR *ZTOP-COMMENT-EVALUATION-RESULT-P* "; ")

(DEFVAR *ZTOP-EVALUATION-PRIN1-STREAM*)

;;; Something suitable for binding PRIN1 to
(DEFUN ZTOP-EVALUATION-PRIN1 (EXP &OPTIONAL (*ZTOP-EVALUATION-PRIN1-STREAM* STANDARD-OUTPUT))
  (AND *ZTOP-COMMENT-EVALUATION-RESULT-P*
       (FUNCALL *ZTOP-EVALUATION-PRIN1-STREAM* ':STRING-OUT
		*ZTOP-COMMENT-EVALUATION-RESULT-P*))
  (IF *ZTOP-GRIND-EVALUATION-RESULT-P*
      (GRIND-TOP-LEVEL EXP 90. 'ZTOP-EVALUATION-PRIN1-IO NIL 'DISPLACED NIL)
      (PRIN1 EXP 'ZTOP-EVALUATION-PRIN1-IO)))

(DEFUN ZTOP-EVALUATION-PRIN1-IO (OP &REST REST)
  (PROG1 (LEXPR-FUNCALL *ZTOP-EVALUATION-PRIN1-STREAM* OP REST)
	 (AND (EQ OP ':TYO) (= (CAR REST) #\CR) *ZTOP-COMMENT-EVALUATION-RESULT-P*
	      (FUNCALL *ZTOP-EVALUATION-PRIN1-STREAM* ':STRING-OUT
		       *ZTOP-COMMENT-EVALUATION-RESULT-P*))))

(DEFVAR *PACKAGE*)

(DEFUN ZTOP-TOP-LEVEL (ZTOP-WINDOW &AUX (PRIN1 *ZTOP-PRIN1*)
					(PACKAGE PACKAGE) (*PACKAGE* PACKAGE))
  (DO () (NIL)
    (*CATCH 'ZTOP-TOP-LEVEL
      (SI:LISP-TOP-LEVEL1 ZTOP-WINDOW))))

(DEFVAR *LAST-ZTOP-BUFFER* NIL)

(DEFMAJOR COM-ZTOP-MODE ZTOP-MODE "ZTOP"
	  "Sets things up for zmacs buffer editor top level." () 
  (COMMAND-HOOK (MAKE-ZTOP-COMMAND-HOOK *INTERVAL* *WINDOW*) *POST-COMMAND-HOOK*)
  (SETQ *SPACE-INDENT-FLAG* T)
  (SETQ *PARAGRAPH-DELIMITER-LIST* NIL)
  (SETQ *COMMENT-START* 'LISP-FIND-COMMENT-START-AND-END)
  (SET-COMTAB *MODE-COMTAB* '(#\END COM-FINISH-ZTOP-EVALUATION
			      #\CR COM-FINISH-ZTOP-EVALUATION
			      #\ABORT COM-ZTOP-ABORT
			      #\TAB COM-INDENT-FOR-LISP
			      #\RUBOUT COM-TAB-HACKING-RUBOUT
			      #\RUBOUT COM-RUBOUT))
  (PROGN (AND (TYPEP *INTERVAL* 'FILE-BUFFER)
	      (SETQ *LAST-ZTOP-BUFFER* *INTERVAL*))))

(DEFUN MAKE-ZTOP-BUFFER (&OPTIONAL (NAME "ZTOP") &AUX BUFFER)
  (SETQ BUFFER (CREATE-ONE-BUFFER-TO-GO NAME))
  (SETF (BUFFER-SAVED-MAJOR-MODE BUFFER) 'ZTOP-MODE)
  (BIND (LOCF (WINDOW-INTERVAL *WINDOW*)) BUFFER)
  (MAKE-ZTOP-COMMAND-HOOK BUFFER *WINDOW*)  
  BUFFER)

(DEFVAR *ZTOP-COMMAND-HOOK-ALIST* NIL)

(LOCAL-DECLARE ((SPECIAL TV:IO-BUFFER))
(DEFUN MAKE-ZTOP-COMMAND-HOOK (BUFFER WINDOW &AUX ZTOP-WINDOW HOOK-CLOSURE HOOK)
  (COND ((SETQ HOOK (ASSQ BUFFER *ZTOP-COMMAND-HOOK-ALIST*))
	 (SETQ HOOK (CDR HOOK) HOOK-CLOSURE (FSYMEVAL HOOK)
	       ZTOP-WINDOW (SYMEVAL-IN-CLOSURE HOOK-CLOSURE '*ZTOP-WINDOW*))
	 (FUNCALL ZTOP-WINDOW ':SET-STREAM-WINDOW WINDOW))
	(T
	 (SETQ ZTOP-WINDOW (LET ((INIT-PLIST (LIST ':*WINDOW* WINDOW
						   ':*ZMACS-SG* SYS:%CURRENT-STACK-GROUP)))
			     (INSTANTIATE-FLAVOR 'ZTOP-STREAM-FROM-WINDOW (LOCF INIT-PLIST)
						 T NIL TV:SHEET-AREA)))
	 (AND (TYPEP BUFFER 'FILE-BUFFER)
	      (FUNCALL (BUFFER-GENERIC-PATHNAME BUFFER) ':PUTPROP ZTOP-WINDOW 'ZTOP-WINDOW))
	 (SETQ HOOK-CLOSURE (LET-CLOSED ((*ZTOP-INTERVAL* BUFFER)
					 (*ZTOP-WINDOW* ZTOP-WINDOW))
					#'(LAMBDA (IGNORE)
					    (AND (EQ *INTERVAL* *ZTOP-INTERVAL*)
						 (FUNCALL *ZTOP-WINDOW* ':COMMAND-HOOK
							  *CURRENT-COMMAND-TYPE*))))
	       HOOK (GENSYM))
	 (FSET HOOK HOOK-CLOSURE)
	 (PUTPROP HOOK 1000 'COMMAND-HOOK-PRIORITY)
	 (PUSH (CONS BUFFER HOOK) *ZTOP-COMMAND-HOOK-ALIST*)))
  HOOK))

(DEFVAR *ZTOP-IBEAM-BLINKER-P* T)

(DEFFLAVOR ZTOP-STREAM-FROM-WINDOW () (ZTOP-STREAM-MIXIN EDITOR-STREAM-FROM-WINDOW))

(DEFFLAVOR ZTOP-STREAM-MIXIN
	(*ZMACS-SG*
	 *ZTOP-SG*
	 *STREAM-START-BP*
	 (*RUBOUT-HANDLER-ARGS* NIL)
	 (*RUBOUT-HANDLER-STATE* ':VIRGIN))
	(EDITOR-STREAM-WITHOUT-WINDOW-MIXIN EDITOR-STREAM-MIXIN)
  (:DEFAULT-INIT-PLIST :IBEAM-BLINKER-P *ZTOP-IBEAM-BLINKER-P*)
  (:INITABLE-INSTANCE-VARIABLES *ZMACS-SG*)
  (:GETTABLE-INSTANCE-VARIABLES *STREAM-START-BP*))

(DEFMETHOD (ZTOP-STREAM-MIXIN :AFTER :INIT) (IGNORE)
  (SETQ *ZTOP-SG* (MAKE-STACK-GROUP "ZTOP" ':REGULAR-PDL-SIZE 40000
					   ':SPECIAL-PDL-SIZE 4000))
  (STACK-GROUP-PRESET *ZTOP-SG* 'ZTOP-TOP-LEVEL SELF))

(DEFMETHOD (ZTOP-STREAM-MIXIN :SET-STREAM-WINDOW) (WINDOW)
  (COND ((NEQ WINDOW *WINDOW*)
	 (SETQ *WINDOW* WINDOW
	       *STREAM-SHEET* (WINDOW-SHEET *WINDOW*)
	       *STREAM-BLINKER* (WINDOW-POINT-BLINKER *WINDOW*)
	       *STREAM-BP* (WINDOW-POINT *WINDOW*))
	 (OR (EQ *RUBOUT-HANDLER-STATE* ':VIRGIN)
	     (SETQ *RUBOUT-HANDLER-STATE* ':EDITING)))))

(DEFMETHOD (ZTOP-STREAM-MIXIN :BEFORE :RUBOUT-HANDLER) (ARGS &REST IGNORE)
  (SETQ *STREAM-ACTIVATION-NEEDED* NIL
	*PACKAGE* PACKAGE
	*RUBOUT-HANDLER-ARGS* ARGS
	*RUBOUT-HANDLER-STATE* (IF TV:UNRCHF ':EDITING ':VIRGIN)))

(DEFMETHOD (ZTOP-STREAM-MIXIN :AFTER :RUBOUT-HANDLER) (&REST IGNORE)
  ;;Get package for evaling in
  (SETQ PACKAGE (SYMEVAL-IN-STACK-GROUP 'PACKAGE *ZMACS-SG*))
  (STREAM-REDISPLAY T))				;Redisplay typeahead

;;; This method gets called when the buffer is empty, co-call the other stack group
(DEFMETHOD (ZTOP-STREAM-MIXIN :STREAM-RUBOUT-HANDLER) ()
  ;; If everything has been typed out correctly, update the window datastructure
  (AND (< (WINDOW-REDISPLAY-DEGREE *WINDOW*) DIS-TEXT)
       (FAKE-OUT-TOP-LINE *WINDOW* *INTERVAL*))
  (SETQ *ZTOP-SG* SYS:%CURRENT-STACK-GROUP)
  (WITH-BP (OLD-STREAM-BP *STREAM-BP* ':NORMAL)
    (AND (FUNCALL *ZMACS-SG*) (*THROW 'RUBOUT-HANDLER T))
    (MOVE-BP *STREAM-BP* OLD-STREAM-BP))
  (FUNCALL-SELF ':ANY-TYI))

;;; This gets called by the editor after each command
(DEFMETHOD (ZTOP-STREAM-MIXIN :COMMAND-HOOK) (TYPE &AUX (OLD-STATE *RUBOUT-HANDLER-STATE*))
  (AND (ASSQ ':FULL-RUBOUT *RUBOUT-HANDLER-ARGS*) (BP-= *STREAM-START-BP* *STREAM-BP*)
       (SETQ OLD-STATE ':EDITING TYPE ':FULL-RUBOUT))
  (SETQ *RUBOUT-HANDLER-STATE*
	(COND ((AND (BP-= *STREAM-BP* (INTERVAL-LAST-BP *INTERVAL*))
		    (MEMQ TYPE '(SELF-INSERT INSERT-CR ACTIVATE-ZTOP :FULL-RUBOUT)))
	       ':NORMAL)
	      ((EQ *RUBOUT-HANDLER-STATE* ':VIRGIN)
	       ':VIRGIN)
	      (T
	       ':EDITING)))
  (COND ((EQ *RUBOUT-HANDLER-STATE* ':NORMAL)
	 (AND (NEQ OLD-STATE ':NORMAL)		;If we were editing
	      (MOVE-BP *STREAM-BP* *STREAM-START-BP*))
	 (SETQ *ZMACS-SG* SYS:%CURRENT-STACK-GROUP)
	 (FUNCALL CURRENT-PROCESS ':ADD-COROUTINE-STACK-GROUP *ZTOP-SG*)
	 (LET ((NORMAL-EXIT-P NIL))
	   (UNWIND-PROTECT
	     (PROGN
	       (FUNCALL *ZTOP-SG* (EQ OLD-STATE ':EDITING))
	       (SETQ NORMAL-EXIT-P T))
	     (OR NORMAL-EXIT-P (EH:SG-THROW *ZTOP-SG* 'ZTOP-TOP-LEVEL T))))
	 (SETQ PACKAGE (SYMEVAL-IN-STACK-GROUP '*PACKAGE* *ZTOP-SG*))
	 (AND (NEQ OLD-STATE ':NORMAL)
	      (MUST-REDISPLAY *WINDOW* DIS-BPS))
	 (COND (TV:UNRCHF
		(FUNCALL STANDARD-INPUT ':UNTYI TV:UNRCHF)
		(SETQ TV:UNRCHF NIL))))
	(T
	 (SETQ *STREAM-ACTIVATION-NEEDED* (OR (EQ *RUBOUT-HANDLER-STATE* ':EDITING)
					      (NOT (BP-= *STREAM-START-BP*
							 (INTERVAL-LAST-BP *INTERVAL*))))))))

(DEFVAR *ZTOP-KILL-RING-SAVE-P* T)

;;; This is like the DO-IT command in HENRY's ZTOP
(DEFCOM COM-FINISH-ZTOP-EVALUATION "Force out buffered input." ()
  (LET ((ZTOP-BUFFER *INTERVAL*) ZTOP-WINDOW STREAM-START-BP)
    (OR (SETQ ZTOP-WINDOW (FUNCALL (BUFFER-GENERIC-PATHNAME *INTERVAL*) ':GET 'ZTOP-WINDOW))
	(SETQ ZTOP-BUFFER (OR *LAST-ZTOP-BUFFER* (MAKE-ZTOP-BUFFER))
	      ZTOP-WINDOW (FUNCALL (BUFFER-GENERIC-PATHNAME ZTOP-BUFFER) ':GET 'ZTOP-WINDOW)))
    (SETQ STREAM-START-BP (FUNCALL ZTOP-WINDOW ':*STREAM-START-BP*))
    (COND ((WINDOW-MARK-P *WINDOW*)		;If there is a region
	   (SETF (WINDOW-MARK-P *WINDOW*) NIL)
	   (WITH-BP (BP (INTERVAL-LAST-BP ZTOP-BUFFER) ':NORMAL)
	     (INSERT-INTERVAL BP (POINT) (MARK))	;copy it to the end
	     (DELETE-INTERVAL STREAM-START-BP BP T))
	   (COND ((NEQ *INTERVAL* ZTOP-BUFFER)
		  (FUNCALL (BUFFER-GENERIC-PATHNAME ZTOP-BUFFER) ':PUTPROP PACKAGE ':PACKAGE)
		  (MAKE-BUFFER-CURRENT ZTOP-BUFFER))))
	  ((NEQ *INTERVAL* ZTOP-BUFFER)
	   (BARF "There is no region"))))
  (LET ((LAST-BP (INTERVAL-LAST-BP *INTERVAL*)))
    (LET ((CH (BP-CHAR-BEFORE LAST-BP)))
      (COND ((= CH #\CR)
	     (DELETE-INTERVAL (FORWARD-CHAR LAST-BP -1) LAST-BP T))
	    ((= (LIST-SYNTAX CH) LIST-ALPHABETIC)
	     (INSERT LAST-BP #\SP))))
    (MOVE-BP (POINT) LAST-BP))
  (SETQ *CURRENT-COMMAND-TYPE* 'ACTIVATE-ZTOP)
  DIS-TEXT)

(DEFCOM COM-SELECT-LAST-ZTOP-BUFFER "Move to the most recently used ZTOP mode buffer." ()
  (MAKE-BUFFER-CURRENT (OR *LAST-ZTOP-BUFFER* (MAKE-ZTOP-BUFFER)))
  DIS-TEXT)

(DEFCOM COM-ZTOP-ABORT "Abort the rubout handler" ()
  (FUNCALL (FUNCALL (BUFFER-GENERIC-PATHNAME *INTERVAL*) ':GET 'ZTOP-WINDOW)
	   ':ZTOP-ABORT)
  DIS-TEXT)

(DEFMETHOD (ZTOP-STREAM-MIXIN :ZTOP-ABORT) ()
  (EH:SG-THROW *ZTOP-SG* 'SYS:COMMAND-LEVEL T))

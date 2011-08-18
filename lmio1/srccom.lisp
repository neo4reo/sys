;;; LISP Machine Source Compare -*-Mode:LISP;Package:SRCCOM-*-

(DEFVAR *OUTPUT-STREAM*)

(DEFSTRUCT (FILE :ARRAY-LEADER (:MAKE-ARRAY (:LENGTH 100.)))
  (FILE-LENGTH 0)				;Number of lines
  FILE-NAME
  (FILE-TYPE "File")				;What kind of source it has
  FILE-STREAM					;Input stream
  FILE-MAJOR-MODE				;Symbol
  )

;;; Get a line from the file, or the stream
(DEFUN GET-FILE-LINE (FILE LINE-NO)
  (IF (< LINE-NO (FILE-LENGTH FILE))
      (AREF FILE LINE-NO)
      (MULTIPLE-VALUE-BIND (LINE EOF)
	  (FUNCALL (FILE-STREAM FILE) ':LINE-IN T)
	(COND ((NOT (AND EOF (OR (NULL LINE) (EQUAL LINE ""))))
	       (ARRAY-PUSH-EXTEND FILE LINE)
	       LINE)))))

(DEFVAR *PRINT-LABELS* T)

(DEFUN LINE-LAST-LABEL (FILE LINE-NO)
  (AND *PRINT-LABELS*
       (DO ((I (1- LINE-NO) (1- I))
	    (MODE (FILE-MAJOR-MODE FILE))
	    (LINE))
	   ((< I 0))
	 (AND (LINE-INTERESTING-P (SETQ LINE (AREF FILE I)) MODE)
	      (RETURN LINE)))))

(DEFUN LINE-INTERESTING-P (LINE MODE &AUX LEN)
  (AND (PLUSP (SETQ LEN (ARRAY-ACTIVE-LENGTH LINE)))
       (SELECTQ MODE
	 ((:LISP :ZTOP) (= (AREF LINE 0) #/())
	 ((:TEXT :BOLIO) (= (AREF LINE 0) #/.))
	 (OTHERWISE (NOT (MEMQ (AREF LINE 0) '(#\SP #\TAB)))))))

;;; Compare two lines
;;; *** FOR NOW NO HAIR FOR COMMENTS, WHITESPACE, ETC. ***
(DEFUN COMPARE-LINES (LINE-1 LINE-2)
  (COND ((NULL LINE-1) (NULL LINE-2))
	((NULL LINE-2) NIL)
	(T (%STRING-EQUAL LINE-1 0 LINE-2 0 NIL))))

(DEFVAR *PATHNAME-DEFAULTS* (FS:MAKE-PATHNAME-DEFAULTS))

(DEFUN SOURCE-COMPARE (FILENAME-1 FILENAME-2 &OPTIONAL (OUTPUT-STREAM STANDARD-OUTPUT)
					     &AUX FILE-1 FILE-2)
  (SETQ FILENAME-1 (FS:MERGE-AND-SET-PATHNAME-DEFAULTS FILENAME-1 *PATHNAME-DEFAULTS*
						       ':UNSPECIFIC ':OLDEST)
	FILENAME-2 (FS:MERGE-PATHNAME-DEFAULTS FILENAME-2 FILENAME-1))
  (UNWIND-PROTECT
    (PROGN
      (SETQ FILE-1 (CREATE-FILE FILENAME-1)
	    FILE-2 (CREATE-FILE FILENAME-2))
      (SOURCE-COMPARE-FILES FILE-1 FILE-2 OUTPUT-STREAM))
    (AND FILE-1 (FUNCALL (FILE-STREAM FILE-1) ':CLOSE))
    (AND FILE-2 (FUNCALL (FILE-STREAM FILE-2) ':CLOSE))))

(DEFUN CREATE-FILE (FILENAME &AUX STREAM MODE)
  (SETQ STREAM (OPEN FILENAME '(:IN)))
  (LET ((GENERIC-PATHNAME (FUNCALL FILENAME ':GENERIC-PATHNAME)))
    (FS:FILE-READ-PROPERTY-LIST GENERIC-PATHNAME STREAM)
    (SETQ MODE (OR (FUNCALL GENERIC-PATHNAME ':GET ':MODE) ':LISP)))
  (MAKE-FILE FILE-STREAM STREAM
	     FILE-NAME (FUNCALL STREAM ':TRUENAME)
	     FILE-MAJOR-MODE MODE))

;;; Useful interface for automatic comparison
(DEFUN PROMPTED-SOURCE-COMPARE (FILE-1 FILE-2)
  (MULTIPLE-VALUE (FILE-1 FILE-2)
    (GET-SRCCOM-FILE-NAMES FILE-1 FILE-2))
  (AND FILE-1
       (*CATCH 'SYS:COMMAND-LEVEL
	 (SOURCE-COMPARE FILE-1 FILE-2))))

(LOCAL-DECLARE ((SPECIAL FILE-1 FILE-2))

(DEFUN GET-SRCCOM-FILE-NAMES (FILE-1 FILE-2)
  (DECLARE (RETURN-LIST FILE-1 FILE-2))
  (DO-NAMED TOP
      ((STR) (COMMA-POS))
      (NIL)
    (PROG ()
      (*CATCH 'SYS:COMMAND-LEVEL
	(RETURN (SETQ STR (FUNCALL QUERY-IO ':RUBOUT-HANDLER
				   '((:PROMPT GET-SRCCOM-FILE-NAMES-PROMPT))
				   #'READLINE QUERY-IO))))
      (RETURN-FROM TOP NIL))			;If caught
    (COND ((EQUAL STR "")
	   (RETURN FILE-1 FILE-2))
	  ((SETQ COMMA-POS (STRING-SEARCH-CHAR #/, STR))
	   (SETQ FILE-1 (FS:MERGE-PATHNAME-DEFAULTS (SUBSTRING STR 0 COMMA-POS) FILE-2)
		 FILE-2 (FS:MERGE-PATHNAME-DEFAULTS (SUBSTRING STR (1+ COMMA-POS)) FILE-1)))
	  (T
	   (SETQ FILE-1 (FS:MERGE-PATHNAME-DEFAULTS STR FILE-2))))))

(DEFUN GET-SRCCOM-FILE-NAMES-PROMPT (STREAM IGNORE)
  (FORMAT STREAM "~&Going to compare ~A with ~A~@
		  ~2X(Type Return, <file-1>, <file-1,file-2>, or Abort): "
	  FILE-1 FILE-2))

);LOCAL-DECLARE

;;; Main loop
(DEFUN SOURCE-COMPARE-FILES (FILE-1 FILE-2 &OPTIONAL (*OUTPUT-STREAM* STANDARD-OUTPUT))
  (DO ((LINE-NO-1 0 (1+ LINE-NO-1))
       (LINE-NO-2 0 (1+ LINE-NO-2))
       (LINE-1) (LINE-2))
      (NIL)
    ;; Files are current matched up, check the next two lines
    (SETQ LINE-1 (GET-FILE-LINE FILE-1 LINE-NO-1)
	  LINE-2 (GET-FILE-LINE FILE-2 LINE-NO-2))
    (OR (COMPARE-LINES LINE-1 LINE-2)
	(MULTIPLE-VALUE (LINE-NO-1 LINE-NO-2 LINE-1)
	  (HANDLE-DIFFERENCE FILE-1 LINE-NO-1 FILE-2 LINE-NO-2)))
    (OR LINE-1 (RETURN NIL)))			;When NULL lines match both files are at EOF
  (CLOSE (FILE-STREAM FILE-1))
  (CLOSE (FILE-STREAM FILE-2))
  NIL)

(DEFVAR *DIFFERENCE-PRINTER* 'PRINT-DIFFERENCES)

;;; First difference detected, look ahead for a match
(DEFUN HANDLE-DIFFERENCE (FILE-1 DIFF-LINE-NO-1 FILE-2 DIFF-LINE-NO-2
			  &AUX (NEW-LINE-NO-1 DIFF-LINE-NO-1) (NEW-LINE-NO-2 DIFF-LINE-NO-2)
			       LINE)
  (DO-NAMED TOP () (NIL)
    ;; Check next line from first file against lines in the second file
    (DO ((NEW-LINE-1 (GET-FILE-LINE FILE-1 (SETQ NEW-LINE-NO-1 (1+ NEW-LINE-NO-1))))
	 (LINE-NO-2 DIFF-LINE-NO-2 (1+ LINE-NO-2)))
	(NIL)
      (SETQ LINE (GET-FILE-LINE FILE-2 LINE-NO-2))
      (COND ((AND (COMPARE-LINES NEW-LINE-1 LINE)
		  (CHECK-POTENTIAL-MATCH FILE-1 NEW-LINE-NO-1 FILE-2 LINE-NO-2))
	     (SETQ NEW-LINE-NO-2 LINE-NO-2)
	     (RETURN-FROM TOP)))
      (AND (= LINE-NO-2 NEW-LINE-NO-2) (RETURN)))
    ;; Check next line from second file against lines from the first file
    (DO ((NEW-LINE-2 (GET-FILE-LINE FILE-2 (SETQ NEW-LINE-NO-2 (1+ NEW-LINE-NO-2))))
	 (LINE-NO-1 DIFF-LINE-NO-1 (1+ LINE-NO-1)))
	(NIL)
      (SETQ LINE (GET-FILE-LINE FILE-1 LINE-NO-1))
      (COND ((AND (COMPARE-LINES LINE NEW-LINE-2)
		  (CHECK-POTENTIAL-MATCH FILE-1 LINE-NO-1 FILE-2 NEW-LINE-NO-2))
	     (SETQ NEW-LINE-NO-1 LINE-NO-1)
	     (RETURN-FROM TOP)))
      (AND (= LINE-NO-1 NEW-LINE-NO-1) (RETURN))))
  (FUNCALL *DIFFERENCE-PRINTER*
	   FILE-1 DIFF-LINE-NO-1 NEW-LINE-NO-1
	   FILE-2 DIFF-LINE-NO-2 NEW-LINE-NO-2)
  (VALUES NEW-LINE-NO-1 NEW-LINE-NO-2 LINE))

(DEFVAR *LINES-NEEDED-TO-MATCH* 3)

;;; Found a potential match, check ahead to see if it is ok
(DEFUN CHECK-POTENTIAL-MATCH (FILE-1 LINE-NO-1 FILE-2 LINE-NO-2)
  (DO ((I *LINES-NEEDED-TO-MATCH* (1- I))
       (LINE-1) (LINE-2))
      (( I 0) T)
    (SETQ LINE-NO-1 (1+ LINE-NO-1)
	  LINE-NO-2 (1+ LINE-NO-2))
    (SETQ LINE-1 (GET-FILE-LINE FILE-1 LINE-NO-1)
	  LINE-2 (GET-FILE-LINE FILE-2 LINE-NO-2))
    (OR (COMPARE-LINES LINE-1 LINE-2)
	(RETURN NIL))))

;;; We are back in synch, print the differences
(DEFUN PRINT-DIFFERENCES (FILE-1 DIFF-LINE-NO-1 SAME-LINE-NO-1
			  FILE-2 DIFF-LINE-NO-2 SAME-LINE-NO-2)
  (PRINT-DIFFS-1 FILE-1 DIFF-LINE-NO-1 SAME-LINE-NO-1)
  (PRINT-DIFFS-1 FILE-2 DIFF-LINE-NO-2 SAME-LINE-NO-2)
  (FORMAT *OUTPUT-STREAM* "~&***************~2%"))

(DEFVAR *LINES-TO-PRINT-BEFORE* 0)
(DEFVAR *LINES-TO-PRINT-AFTER* 1)

(DEFUN PRINT-DIFFS-1 (FILE DIFF-LINE-NO SAME-LINE-NO &AUX LABEL)
  (SETQ DIFF-LINE-NO (MAX 0 (- DIFF-LINE-NO *LINES-TO-PRINT-BEFORE*))
	SAME-LINE-NO (+ SAME-LINE-NO *LINES-TO-PRINT-AFTER*))
  (FORMAT *OUTPUT-STREAM* "~&**** ~A ~A, Line #~D"
	  (FILE-TYPE FILE) (FILE-NAME FILE) DIFF-LINE-NO)
  (COND ((SETQ LABEL (LINE-LAST-LABEL FILE DIFF-LINE-NO))
	 (FUNCALL *OUTPUT-STREAM* ':STRING-OUT ", After /"")
	 (IF (LET ((WHICH-OPERATIONS (FUNCALL *OUTPUT-STREAM* ':WHICH-OPERATIONS)))
	       (AND (MEMQ ':READ-CURSORPOS WHICH-OPERATIONS)
		    (MEMQ ':SIZE-IN-CHARACTERS WHICH-OPERATIONS)))
	     (FUNCALL *OUTPUT-STREAM* ':STRING-OUT LABEL 0
		      (MIN (- (FUNCALL *OUTPUT-STREAM* ':SIZE-IN-CHARACTERS)
			      (FUNCALL *OUTPUT-STREAM* ':READ-CURSORPOS ':CHARACTER)
			      1)
			   (STRING-LENGTH LABEL)))
	     (FUNCALL *OUTPUT-STREAM* ':STRING-OUT (SUBSTRING LABEL 0
							      (MIN 25.
								   (STRING-LENGTH LABEL)))))
	 (FUNCALL *OUTPUT-STREAM* ':TYO #/")))
  (FUNCALL *OUTPUT-STREAM* ':TYO #\CR)
  (PRINT-FILE-SEGMENT FILE DIFF-LINE-NO SAME-LINE-NO))

(DEFUN PRINT-FILE-SEGMENT (FILE START-LINE-NO END-LINE-NO)
  (DO ((LINE-NO START-LINE-NO (1+ LINE-NO))
       (LINE))
      ((= LINE-NO END-LINE-NO))
    (OR (SETQ LINE (GET-FILE-LINE FILE LINE-NO))
	(RETURN))
    (FUNCALL *OUTPUT-STREAM* ':LINE-OUT LINE)))

;;; Merging
(DEFVAR *MERGE-LINE-NO*)

(DEFUN SOURCE-COMPARE-AUTOMATIC-MERGE (FILENAME-1 FILENAME-2 OUTPUT-FILENAME
				       &AUX FILE-1 FILE-2)
  (UNWIND-PROTECT
    (PROGN
      (SETQ FILE-1 (CREATE-FILE FILENAME-1)
	    FILE-2 (CREATE-FILE FILENAME-2))
      (WITH-OPEN-FILE (OUTPUT-STREAM OUTPUT-FILENAME '(:OUT))
	(SOURCE-COMPARE-AUTOMATIC-MERGE-1 FILE-1 FILE-2 OUTPUT-STREAM)))
    (AND FILE-1 (FUNCALL (FILE-STREAM FILE-1) ':CLOSE))
    (AND FILE-2 (FUNCALL (FILE-STREAM FILE-2) ':CLOSE))))

(DEFUN SOURCE-COMPARE-AUTOMATIC-MERGE-1 (FILE-1 FILE-2 *OUTPUT-STREAM*)
  (LET ((*DIFFERENCE-PRINTER* 'PRINT-AUTOMATIC-MERGE)
	(*MERGE-LINE-NO* 0))
    (SOURCE-COMPARE-FILES FILE-1 FILE-2 *OUTPUT-STREAM*)
    (PRINT-FILE-SEGMENT FILE-1 *MERGE-LINE-NO* (FILE-LENGTH FILE-1))))

(DEFVAR *RECORD-MERGE-BOUNDS-P* NIL)
(DEFVAR *MERGE-RECORD*)
(DEFVAR *MERGE-THIS-RECORD*)

(DEFUN SOURCE-COMPARE-AUTOMATIC-MERGE-RECORDING (FILE-1 FILE-2 OUTPUT-STREAM
						 &AUX (*RECORD-MERGE-BOUNDS-P* T)
						      (*MERGE-RECORD* NIL)
						      *MERGE-THIS-RECORD*)
  (SOURCE-COMPARE-AUTOMATIC-MERGE-1 FILE-1 FILE-2 OUTPUT-STREAM)
  (DOLIST (RECORD (SETQ *MERGE-RECORD* (NREVERSE *MERGE-RECORD*)))
    (SETF (ZWEI:BP-STATUS (FIRST RECORD)) ':MOVES)
    (SETF (ZWEI:BP-STATUS (THIRD RECORD)) ':MOVES)
    (SETF (ZWEI:BP-STATUS (FIFTH RECORD)) ':MOVES))
  *MERGE-RECORD*)

(DEFUN PRINT-AUTOMATIC-MERGE (FILE-1 DIFF-LINE-NO-1 SAME-LINE-NO-1
			      FILE-2 DIFF-LINE-NO-2 SAME-LINE-NO-2)
  (PRINT-FILE-SEGMENT FILE-1 *MERGE-LINE-NO* DIFF-LINE-NO-1)
  (COND (*RECORD-MERGE-BOUNDS-P*
	 (SETQ *MERGE-THIS-RECORD* NIL)
	 (RECORD-MERGE-BOUND)))
  (FUNCALL *OUTPUT-STREAM* ':LINE-OUT "*** MERGE LOSSAGE ***")
  (PRINT-AUTOMATIC-MERGE-1 FILE-1 DIFF-LINE-NO-1 SAME-LINE-NO-1)
  (PRINT-AUTOMATIC-MERGE-1 FILE-2 DIFF-LINE-NO-2 SAME-LINE-NO-2)
  (FUNCALL *OUTPUT-STREAM* ':LINE-OUT "*** END OF MERGE LOSSAGE ***")
  (COND (*RECORD-MERGE-BOUNDS-P*
	 (RECORD-MERGE-BOUND)
	 (PUSH (NREVERSE *MERGE-THIS-RECORD*) *MERGE-RECORD*)))
  (SETQ *MERGE-LINE-NO* SAME-LINE-NO-1))

(DEFUN PRINT-AUTOMATIC-MERGE-1 (FILE DIFF-LINE-NO SAME-LINE-NO)
  (FORMAT *OUTPUT-STREAM* "*** FILE ~A HAS:~%" (FILE-NAME FILE))
  (AND *RECORD-MERGE-BOUNDS-P* (RECORD-MERGE-BOUND))
  (PRINT-FILE-SEGMENT FILE DIFF-LINE-NO SAME-LINE-NO)
  (AND *RECORD-MERGE-BOUNDS-P* (RECORD-MERGE-BOUND)))

(DEFUN RECORD-MERGE-BOUND ()
  (PUSH (ZWEI:COPY-BP (FUNCALL *OUTPUT-STREAM* ':READ-BP) ':NORMAL) *MERGE-THIS-RECORD*))

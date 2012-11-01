;;; -*- Mode: Lisp; Package: User; Base: 8.; Patch-File: T -*-
;;; Patch file for System version 78.20
;;; Reason: New site setting scheme
;;; Written 12/17/81 23:56:21 by MMcM,
;;; while running on Lisp Machine One from band 3
;;; with System 78.19, ZMail 38.3, microcode 836, 60Hz.



; From file QMISC > LISPM; AI:
#8R SYSTEM-INTERNALS:(COMPILER-LET ((PACKAGE (PKG-FIND-PACKAGE "SYSTEM-INTERNALS")))

(DEFUN DEFSITE-1 (NEW-SITE OPTIONS)
  (SETQ STATUS-FEATURE-LIST (CONS NEW-SITE (DELQ SITE-NAME STATUS-FEATURE-LIST)))
  (SETQ SITE-NAME NEW-SITE)
  (SETQ SITE-OPTION-ALIST (LOOP FOR (KEY EXP) IN OPTIONS
				COLLECT `(,KEY . ,(EVAL EXP)))))

)

; From file QMISC > LISPM; AI:
#8R SYSTEM-INTERNALS:(COMPILER-LET ((PACKAGE (PKG-FIND-PACKAGE "SYSTEM-INTERNALS")))

;;; Site stuff
(DEFUN UPDATE-SITE-CONFIGURATION-INFO ()
  (MAYBE-MINI-LOAD-FILE-ALIST SITE-FILE-ALIST)
  (INITIALIZATIONS 'SITE-INITIALIZATION-LIST T))

)

; From file NSITE.LISP SRC:<MMCM> XX:
#8R SYSTEM-INTERNALS:(COMPILER-LET ((PACKAGE (PKG-FIND-PACKAGE "SYSTEM-INTERNALS")))

(FUNDEFINE 'SET-SITE)

)

; From file PATHNM > LMIO; AI:
#8R FILE-SYSTEM:(COMPILER-LET ((PACKAGE (PKG-FIND-PACKAGE "FILE-SYSTEM")))

(DEFUN ADD-LOGICAL-PATHNAME-HOST (LOGICAL-HOST PHYSICAL-HOST TRANSLATIONS &AUX LOG DEFDEV)
  (OR (SETQ LOG (GET-PATHNAME-HOST LOGICAL-HOST))
      (PUSH (SETQ LOG (MAKE-INSTANCE 'LOGICAL-HOST ':NAME LOGICAL-HOST))
	    *PATHNAME-HOST-LIST*))
  (SETQ PHYSICAL-HOST (OR (GET-PATHNAME-HOST PHYSICAL-HOST)
			  (FERROR NIL "There is no host named ~S" PHYSICAL-HOST)))
  (FUNCALL LOG ':SET-HOST PHYSICAL-HOST)
  (FUNCALL LOG ':SET-TRANSLATIONS
	   (LOOP FOR (LOGICAL-DIRECTORY PHYSICAL-DIRECTORY) IN TRANSLATIONS
		 WITH HOST = (DEFAULT-PATHNAME NIL PHYSICAL-HOST NIL NIL T)
		 AND DEVICE AND DIRECTORY
		 DO (MULTIPLE-VALUE (DEVICE DIRECTORY)
		      (FUNCALL HOST ':PARSE-NAMESTRING T PHYSICAL-DIRECTORY))
		 WHEN (MEMQ DIRECTORY '(NIL :UNSPECIFIC))
		 DO (FERROR NIL
  "No directory specified in ~A, you probably forgot some delimiter characters."
			    PHYSICAL-DIRECTORY)
		 WHEN (NULL DEFDEV)
		 DO (SETQ DEFDEV DEVICE)
		 COLLECT (MAKE-LOGICAL-PATHNAME-TRANSLATION
			   LOGICAL-DIRECTORY LOGICAL-DIRECTORY
			   PHYSICAL-DEVICE DEVICE
			   PHYSICAL-DIRECTORY DIRECTORY)))
  (FUNCALL LOG ':SET-DEFAULT-DEVICE DEFDEV)
  LOG)

)

; From file PATHNM > LMIO; AI:
#8R FILE-SYSTEM:(COMPILER-LET ((PACKAGE (PKG-FIND-PACKAGE "FILE-SYSTEM")))

;;; This would be an initialization, except that this file is loaded too early.
(DEFUN DEFINE-SYS-LOGICAL-DEVICE ()
  (LET ((SYS-HOST (ADD-LOGICAL-PATHNAME-HOST
		    "SYS" (SI:GET-SITE-OPTION ':SYS-HOST)
		    (SI:GET-SITE-OPTION ':SYS-DIRECTORY-TRANSLATIONS))))
    (FUNCALL (FUNCALL SYS-HOST ':HOST) ':SET-SITE SI:SITE-NAME)))

)

; From file QMISC > LISPM; AI:
#8R SYSTEM-INTERNALS:(COMPILER-LET ((PACKAGE (PKG-FIND-PACKAGE "SYSTEM-INTERNALS")))


;;; Set by major local network
;;; A function called with a host (string or host-object), a system-type and a local net
;;; address.
(DEFVAR NEW-HOST-VALIDATION-FUNCTION)

(DEFUN SET-SYS-HOST (HOST-NAME &OPTIONAL OPERATING-SYSTEM-TYPE HOST-ADDRESS
					 SITE-FILE-DIRECTORY
			       &AUX HOST-OBJECT)
  (CHECK-ARG HOST-NAME (OR (STRINGP HOST-NAME) (TYPEP HOST-NAME 'HOST)) "a host name")
  (CHECK-ARG OPERATING-SYSTEM-TYPE (OR (NULL OPERATING-SYSTEM-TYPE)
				       (GET OPERATING-SYSTEM-TYPE 'SYSTEM-TYPE-FLAVOR))
	     "an operating system type")
  (AND (SETQ HOST-OBJECT (OR (FS:GET-PATHNAME-HOST HOST-NAME)
			     (SI:PARSE-HOST HOST-NAME T T)))
       OPERATING-SYSTEM-TYPE
       (NEQ OPERATING-SYSTEM-TYPE (FUNCALL HOST-OBJECT ':SYSTEM-TYPE))
       (FERROR NIL "~A is ~A, not ~A" HOST-OBJECT
	       (FUNCALL HOST-OBJECT ':SYSTEM-TYPE) OPERATING-SYSTEM-TYPE))
  (SETQ HOST-OBJECT (FUNCALL NEW-HOST-VALIDATION-FUNCTION (OR HOST-OBJECT HOST-NAME)
			     OPERATING-SYSTEM-TYPE HOST-ADDRESS))
  (FS:CHANGE-LOGICAL-PATHNAME-HOST "SYS" HOST-OBJECT)
  (AND SITE-FILE-DIRECTORY
       (FS:CHANGE-LOGICAL-PATHNAME-DIRECTORY "SYS" "SITE" SITE-FILE-DIRECTORY))
  T)


)

; From file CHSAUX > LMIO; AI:
#8R CHAOS:(COMPILER-LET ((PACKAGE (PKG-FIND-PACKAGE "CHAOS")))


(DEFUN NEW-HOST-VALIDATION-FUNCTION (HOST SYSTEM-TYPE ADDRESS)
  (COND ((NOT (STRINGP HOST))
	 (AND ADDRESS
	      (NOT (MEMQ ADDRESS (FUNCALL HOST ':CHAOS-ADDRESSES)))
	      (FERROR NIL "~O is not a valid chaosnet address for ~A" ADDRESS HOST))
	 HOST)
	(T
	 (LET ((STATUS-PKT (GET-HOST-STATUS-PACKET ADDRESS)))
	   (OR STATUS-PKT (FERROR NIL "Cannot connect to ~A at ~O" HOST ADDRESS))
	   (LET ((STRING (PKT-STRING STATUS-PKT)))
	     (OR (FQUERY NIL "Host is ~A, ok? "
			 (SUBSTRING STRING 0 (MIN (STRING-LENGTH STRING) 32.
						  (OR (STRING-SEARCH-SET '(200 0) STRING)
						      32.))))
		 (FERROR NIL "Incorrect host specified"))))
	 (SI:DEFINE-HOST HOST ':HOST-NAMES `(,HOST)
			      ':SYSTEM-TYPE SYSTEM-TYPE
			      ':CHAOS `(,ADDRESS))
	 (SETQ HOST (SI:PARSE-HOST HOST))
	 (AND (EQ CHAOS:MY-ADDRESS ADDRESS) (SETQ SI:LOCAL-HOST HOST))
	 HOST)))

(SETQ SI:NEW-HOST-VALIDATION-FUNCTION 'NEW-HOST-VALIDATION-FUNCTION)

)

; From file SYSDCL > LISPM; AI:
#8R SYSTEM-INTERNALS:(COMPILER-LET ((PACKAGE (PKG-FIND-PACKAGE "SYSTEM-INTERNALS")))

(DEFCONST SITE-FILE-ALIST
	  '(("SYS: SITE; SITE QFASL >" "SI")
	    ))

(DEFCONST HOST-TABLE-FILE-ALIST
	  '(
#-XEROX	    ("SYS: SITE; HSTTBL QFASL >" "CHAOS")
	    ("SYS: SITE; LMLOCS QFASL >" "SI")
	    ))

)

; From file HOST > LISPM2; AI:
#8R SYSTEM-INTERNALS:(COMPILER-LET ((PACKAGE (PKG-FIND-PACKAGE "SYSTEM-INTERNALS")))

;;; This is the function written out in the host table.
(DEFUN DEFINE-HOST (NAME &REST OPTIONS &AUX ELEM OLD-P)
  (IF (NULL (SETQ ELEM (ASSOC NAME HOST-ALIST)))
      (SETQ ELEM (MAKE-HOST-ALIST-ELEM NAME NAME))
      (SETQ OLD-P T)
      (SETF (HOST-ADDRESSES ELEM) NIL))
  (SETF (HOST-SITE-NAME ELEM) SITE-NAME)
  (LOOP FOR (OPTION VALUE) ON OPTIONS BY 'CDDR
	DO (SELECTQ OPTION
	     (:HOST-NAMES (SETF (HOST-NAME-LIST ELEM) VALUE))
	     (:SYSTEM-TYPE (SETF (HOST-SYSTEM-TYPE-INTERNAL ELEM) VALUE))
	     (:MACHINE-TYPE)
	     (OTHERWISE (PUTPROP (LOCF (HOST-ADDRESSES ELEM)) VALUE OPTION))))
  (IF (NOT OLD-P)
      (PUSH ELEM HOST-ALIST)
      (LET ((OLD-INSTANCE (HOST-INSTANCE ELEM)))
	(AND OLD-INSTANCE
	     (LET ((FLAVOR (COMPUTE-HOST-FLAVOR ELEM)))
	       (AND (NEQ FLAVOR (TYPEP OLD-INSTANCE))
		    (LET ((NEW-INSTANCE (MAKE-INSTANCE FLAVOR ':ALIST-ELEM ELEM)))
		      ;; If incorrect flavor, make new one now.
		      (STRUCTURE-FORWARD OLD-INSTANCE NEW-INSTANCE))))))))

)

; From file CHSAUX > LMIO; AI:
#8R CHAOS:(COMPILER-LET ((PACKAGE (PKG-FIND-PACKAGE "CHAOS")))

(DEFUN CHAOS-UNKNOWN-HOST-FUNCTION (NAME)
  (DOLIST (HOST (SI:GET-SITE-OPTION ':CHAOS-HOST-TABLE-SERVER-HOSTS))
    (WITH-OPEN-STREAM (STREAM (OPEN-STREAM HOST "HOSTAB" ':ERROR NIL))
      (COND ((NOT (STRINGP STREAM))
	     (FUNCALL STREAM ':LINE-OUT NAME)
	     (FUNCALL STREAM ':FORCE-OUTPUT)
	     (DO ((LIST NIL)
		  (LINE) (EOF)
		  (LEN) (SP) (PROP))
		 (NIL)
	       (MULTIPLE-VALUE (LINE EOF)
		 (FUNCALL STREAM ':LINE-IN))
	       (AND EOF
		    (RETURN (COND (LIST
				   (PUTPROP LIST (STABLE-SORT (GET LIST ':HOST-NAMES)
							      #'(LAMBDA (X Y)
								  (< (STRING-LENGTH X)
								     (STRING-LENGTH Y))))
					    ':HOST-NAMES)
				   (APPLY #'SI:DEFINE-HOST LIST)))))
	       (SETQ LEN (STRING-LENGTH LINE)
		     SP (STRING-SEARCH-CHAR #\SP LINE 0 LEN))
	       (SETQ PROP (INTERN (SUBSTRING LINE 0 SP) "")
		     SP (1+ SP))
	       (SELECTQ PROP
		 (:ERROR
		  (RETURN NIL))
		 (:NAME
		  (LET ((NAME (SUBSTRING LINE SP LEN)))
		    (OR LIST (SETQ LIST (NCONS NAME)))
		    (PUSH NAME (GET LIST ':HOST-NAMES))))
		 ((:SYSTEM-TYPE MACHINE-TYPE)
		  (PUTPROP LIST (INTERN (SUBSTRING LINE SP LEN) "") PROP))
		 (OTHERWISE
		  (LET ((FUNCTION (GET PROP 'HOST-ADDRESS-PARSER)))
		    (OR FUNCTION (SETQ FUNCTION (GET ':CHAOS 'HOST-ADDRESS-PARSER)))
		    (PUSH (FUNCALL FUNCTION PROP LINE SP LEN)
			  (GET LIST PROP))))))
	     (RETURN T))))))

)

; From file CHSAUX > LMIO; AI:
#8R CHAOS:(COMPILER-LET ((PACKAGE (PKG-FIND-PACKAGE "CHAOS")))

;;; System system transformation
(DEFUN GENERATE-HOST-TABLE-1 (INPUT-FILE OUTPUT-FILE)
  (WITH-OPEN-FILE (INPUT-STREAM INPUT-FILE '(:READ))
    (WITH-OPEN-FILE (OUTPUT-STREAM OUTPUT-FILE '(:PRINT))
      (FORMAT OUTPUT-STREAM "~
;;; -*- Mode: LISP;~@[ Package: ~A;~] Base: 8 -*-
;;; *** THIS FILE WAS AUTOMATICALLY GENERATED BY A PROGRAM, DO NOT EDIT IT ***
;;; Host table made from ~A by ~A at ~\DATIME\~%"
	      SI:*FORCE-PACKAGE* (FUNCALL INPUT-STREAM ':TRUENAME) USER-ID)
      (DO ((LINE) (EOF)
	   (I) (J)
	   (NI) (NJ)
	   (HOSTL) (NAMEL) (DELIM))
	  (NIL)
	(MULTIPLE-VALUE (LINE EOF)
	  (FUNCALL INPUT-STREAM ':LINE-IN NIL))
	(AND EOF (RETURN))
	(MULTIPLE-VALUE (I J)
	  (PARSE-HOST-TABLE-TOKEN LINE 0))
	(COND ((AND I (STRING-EQUAL LINE "HOST" I 0 J NIL))
	       ;; Host name
	       (MULTIPLE-VALUE (NI NJ)
		 (PARSE-HOST-TABLE-TOKEN LINE (1+ J)))
	       (MULTIPLE-VALUE (I J DELIM)
		 (PARSE-HOST-TABLE-TOKEN LINE (1+ NJ)))
	       (SETQ HOSTL (NCONS (SUBSTRING LINE NI NJ)))
	       (IF (= DELIM #/[)
		   (DO ((L NIL)
			(I1) (J1))
		       ((= DELIM #/])
			(SETQ J (1+ J))		;,
			(NREVERSE L))
		     (MULTIPLE-VALUE (I1 J1 DELIM)
		       (PARSE-HOST-TABLE-TOKEN LINE (1+ J)))
		     (IF (= DELIM #\SP)
			 (MULTIPLE-VALUE (I J DELIM)
			   (PARSE-HOST-TABLE-TOKEN LINE (1+ J1)))
			 (SETQ I I1 J J1 J1 I1))
		     (ADD-HOST-TABLE-ADDRESS LINE I1 J1 I J HOSTL))
		   (LET ((I1 I) (J1 J))
		     (IF (= DELIM #\SP)
			 (MULTIPLE-VALUE (I J)
			   (PARSE-HOST-TABLE-TOKEN LINE (1+ J)))
			 (SETQ I I1 J J1 J1 I1))
		     (ADD-HOST-TABLE-ADDRESS LINE I1 J1 I J HOSTL)))
	       (COND ((OR (GET HOSTL ':CHAOS)	;If there were any chaosnet addresses
			  ;; Include some popular ARPA sites for speed in SUPDUP/TELNET
			  (AND (EQ SI:SITE-NAME ':MIT)
			       (MEMBER (CAR HOSTL) '("MIT-DMS" "SU-AI" "S1-A" "CMU-10A"
						     "SRI-KL"))))
		      (DOTIMES (K 2)
			(MULTIPLE-VALUE (I J DELIM)
			  (PARSE-HOST-TABLE-TOKEN LINE (1+ J))))
		      (PUTPROP HOSTL (INTERN (SUBSTRING LINE I J) "") ':SYSTEM-TYPE)
		      (MULTIPLE-VALUE (I J DELIM)
			(PARSE-HOST-TABLE-TOKEN LINE (1+ J)))
		      (PUTPROP HOSTL (INTERN (SUBSTRING LINE I J) "") ':MACHINE-TYPE)
		      (MULTIPLE-VALUE (I J DELIM)
			(PARSE-HOST-TABLE-TOKEN LINE (1+ J)))
		      (OR I (SETQ DELIM -1))
		      (SETQ NAMEL (NCONS (CAR HOSTL)))
		      (AND (= DELIM #/[)
			   (DO () ((= DELIM #/])
				   (SETQ NAMEL (STABLE-SORT NAMEL
							    #'(LAMBDA (X Y)
								(< (STRING-LENGTH X)
								   (STRING-LENGTH Y))))))
			     (MULTIPLE-VALUE (I J DELIM)
			       (PARSE-HOST-TABLE-TOKEN LINE (1+ J)))
			     (PUSH (SUBSTRING LINE I J) NAMEL)))
		      (PUTPROP HOSTL NAMEL ':HOST-NAMES)
		      (PKG-BIND (OR SI:*FORCE-PACKAGE* PACKAGE)
			(SI:GRIND-TOP-LEVEL `(SI:DEFINE-HOST ,(CAR HOSTL)
							     . ,(MAPCAR #'(LAMBDA (X) `',X)
									(CDR HOSTL)))
					    95. OUTPUT-STREAM)
			(TERPRI OUTPUT-STREAM))))))))))

)

; From file QFILE > LMIO; AI:
#8R FILE-SYSTEM:(COMPILER-LET ((PACKAGE (PKG-FIND-PACKAGE "FILE-SYSTEM")))

(DEFUN CHANGE-PROPERTIES-CHAOS (HOST PATHNAME ERROR-P PROPERTIES
				&AUX STRING HOST-UNIT PKT SUCCESS)
  (SETQ HOST-UNIT (FUNCALL HOST ':GET-HOST-UNIT))
  (SETQ STRING (CHANGE-PROPERTIES-STRING PROPERTIES PATHNAME))
  (MULTIPLE-VALUE (PKT SUCCESS STRING)
    (FUNCALL HOST-UNIT ':COMMAND NIL NIL NIL STRING))
  (COND (SUCCESS
	 (CHAOS:RETURN-PKT PKT)
	 T)
	((NOT ERROR-P)
	 (PROG1 (STRING-APPEND STRING) (CHAOS:RETURN-PKT PKT)))
	(T
	 (UNWIND-PROTECT
	   (FILE-PROCESS-ERROR STRING PATHNAME T)
	   (CHAOS:RETURN-PKT PKT))
	 (CHANGE-PROPERTIES-CHAOS HOST PATHNAME ERROR-P PROPERTIES))))

)

; From file QFILE > LMIO; AI:
#8R FILE-SYSTEM:(COMPILER-LET ((PACKAGE (PKG-FIND-PACKAGE "FILE-SYSTEM")))

(DEFUN CHANGE-PROPERTIES-STRING (PROPERTIES &OPTIONAL PATHNAME)
  (WITH-OUTPUT-TO-STRING (STREAM)
    (FORMAT STREAM "CHANGE-PROPERTIES~%")
    (AND PATHNAME (FORMAT STREAM "~A~%" (FUNCALL PATHNAME ':STRING-FOR-HOST)))
    (TV:DOPLIST (PROPERTIES PROP IND)
      (FORMAT STREAM "~A " IND)
      (FUNCALL (DO ((L *KNOWN-DIRECTORY-PROPERTIES* (CDR L)))
		   ((NULL L) 'PRINC)
		 (AND (MEMQ IND (CDAR L))
		      (RETURN (CADAAR L))))
	       PROP STREAM)
      (FUNCALL STREAM ':TYO #\CR))))

)

; From file QFILE > LMIO; AI:
#8R FILE-SYSTEM:(COMPILER-LET ((PACKAGE (PKG-FIND-PACKAGE "FILE-SYSTEM")))

(DEFMETHOD (FILE-DATA-STREAM-MIXIN :CHANGE-PROPERTIES)
	   (ERROR-P &REST PROPERTIES &AUX SUCCESS STRING)
  (SELECTQ STATUS
    ((:OPEN :EOF :SYNC-MARKED :ASYNC-MARKED)
     (MULTIPLE-VALUE (STRING SUCCESS)
       (FUNCALL-SELF ':COMMAND NIL (CHANGE-PROPERTIES-STRING PROPERTIES)))
     (OR SUCCESS
	 (AND (NULL ERROR-P) STRING)
	 (FILE-PROCESS-ERROR STRING SELF NIL)))
    (OTHERWISE (FERROR NIL "~S in illegal state for change properties" SELF))))

)

; From file LTOP > LISPM; AI:
#8R SYSTEM-INTERNALS:(COMPILER-LET ((PACKAGE (PKG-FIND-PACKAGE "SYSTEM-INTERNALS")))

(LET ((ELEM (ASSOC "HOST-TABLE-INITIALIZATION" SITE-INITIALIZATION-LIST)))
  (SETQ SITE-INITIALIZATION-LIST (CONS ELEM (DELQ ELEM SITE-INITIALIZATION-LIST))))

;; Now fix up the site initialization list.  The host table loading initialization
;; is the first one, from QMISC.  Next comes the host reseting one from HOST.  Then
;; the SYS: initialization from PATHNM.  When loading the system now, the host
;; table is loaded via MINI with explicit host pathnames, and so must come before
;; SYS:.  When changing the site, the host table is loaded from SYS:, so that must
;; be setup before.  Therefore, move the host table initialization (the CAR) to
;; just after the SYS: one.
(LET ((POS (LET ((ELEM (ASSOC "DEFINE-SYS-LOGICAL-DEVICE"
			      SITE-INITIALIZATION-LIST)))
	     (MEMQ ELEM SITE-INITIALIZATION-LIST))))
  ;; If there is a chaosnet, move the setting up of hosts to after loading the
  ;; host table.
  (LET ((ELEM (ASSOC "SITE-CHAOS-PATHNAME-INITIALIZE" SITE-INITIALIZATION-LIST)))
    (COND (ELEM
	   (SETQ SITE-INITIALIZATION-LIST (DELQ ELEM SITE-INITIALIZATION-LIST))
	   (PUSH ELEM (CDR POS)))))
  (PUSH (POP SITE-INITIALIZATION-LIST) (CDR POS)))

)


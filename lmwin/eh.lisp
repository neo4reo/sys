;;; New error handler.       DLW 1/5/78  -*-Mode:LISP; Package:EH-*-

(DEFVAR ERROR-MESSAGE-PRINLEVEL 2)	;These are used when printing error messages
(DEFVAR ERROR-MESSAGE-PRINLENGTH 4)	; and values of variables in frames.
(DEFVAR FUNCTION-PRINLEVEL 3)		; Used for printing LAMBDA expressions.
(DEFVAR FUNCTION-PRINLENGTH 5)

;; The error table, read from SYS: UBIN; UCADR TBL nnn into MICROCODE-ERROR-TABLE,
;; describes the symbolic meaning of certain microcode pcs.
;; Its data is rearranged into other variables below.
;; ERROR-TABLE relates the micro pc to a symbolic name of error,
;; called an ETE, which will then have properties saying how to handle
;; the error.  The properties are defined in LISPM2;EHR.
;; ETE stands for error table entry, although that is only accurate for
;; microcode errors.  It is a list whose car is a symbol which has
;; some interesting properties for recovering from and reporting the error.
;; They are set up in the file LISPM2;EHR > (Error Handler Routines...)

;; Actual error table read in from file
(DEFVAR MICROCODE-ERROR-TABLE)
;; Ucode version number to which the loaded value of MICROCODE-ERROR-TABLE pertains.
(DEFVAR MICROCODE-ERROR-TABLE-VERSION-NUMBER 0)

;; ASSURE-TABLE-PROCESSED looks at MICROCODE-ERROR-TABLE
;; and produces these lists.
(DEFVAR CALLS-SUB-LIST)			;Alist of micropcs to symbols.
(DEFVAR RESTART-LIST)			;Alist of symbols to micropcs.
(DEFVAR ARG-POPPED-LIST)		;Alist of micropcs just after where
					;misc insns pop their args.
					;The cdr of the element says where the arg went:
					;a place to find it if the error is after the pop.
(DEFVAR DEFAULT-ARG-LOCATIONS-LIST)	;Alist of microfun symbols to where there args
					;live in the absense of info to contrary.
(DEFVAR STACK-WORDS-PUSHED-LIST)	;Alist of micropcs, of error or on stack at error,
					;to how many words that subroutine had pushed
					;on the stack since it was called, up to the time
					;it called the next subroutine or got the error.
(DEFVAR ERROR-TABLE)			;List of ETEs.
(DEFVAR ERROR-TABLE-NUMBER -1)		;Microcode version number for ERROR-TABLE.
(DEFVAR BEGIN-QARYR)			;See SG-ERRING-FUNCTION
(DEFVAR END-QARYR)			;..

;; An error immediately runs the first level error handler stack group
;; whose job is to initialize a second level error handler stack group
;; in which the error handler actually runs.

;; SECOND-LEVEL-COUNT is a count for giving each second level error handler a distinct name.
(DEFVAR SECOND-LEVEL-ERROR-HANDLER-COUNT 0)
;; Error handler stack groups that were exited and can be reused.
(DEFVAR FREE-SECOND-LEVEL-ERROR-HANDLER-SG-LIST NIL)
;; Last second level error handler to be running.
;; This is so that each of them can tell
;; when it is returned to whether some other one
;; has been running in the meanwhile.
(DEFVAR LAST-SECOND-LEVEL-ERROR-HANDLER-SG NIL)
;; This variable is bound to T in every second-level error handler to identify them.
(DEFVAR ERROR-HANDLER-RUNNING NIL)
;; Controls whether the error message is reprinted in RUN-SG
(DEFVAR ERROR-HANDLER-REPRINT-ERROR T)

(DEFVAR ERROR-HANDLER-IO NIL)	;If non-NIL, stream EH should use

;; Conditions.  Condition handlers are run by the second level error handler.
;; These variables are part of the mechanism by which condition handlers
;; ask to proceed from the error.
(DEFVAR CONDITION-PROCEED-FLAG)		;Communicate from condition handlers to PROCEED.
(DEFVAR CONDITION-PROCEED-VALUE)	;See READ-OBJECT.

;; ERRSET-STATUS is T within an errset.
;; ERRSET-PRINT-MSG is T if the error message should be printed anyway.
;; ERRSET is T if the error handler should be entered despite being in an errset.
(DEFVAR ERRSET-STATUS NIL)
(DEFVAR ERRSET-PRINT-MSG NIL)
(DEFVAR ERRSET NIL)
(REMPROP 'ERRSET ':SOURCE-FILE-NAME)  ;Avoid error message when macro defined

;; This is funcalled after printing the error message.
(DEFVAR ERROR-MESSAGE-HOOK NIL)

;; Here are the error handler's main operating parameters.
(DEFVAR ERROR-SG)		;The stack group that got the error.
(DEFVAR CURRENT-FRAME)		;The SG-AP of the frame that the error handler is looking at.
(DEFVAR ORIGINAL-FRAME)		;The SG-AP of the frame that got the error.
(DEFVAR INNERMOST-VISIBLE-FRAME)  ;Frames on stack inside of this can't be moved to.
				  ;Also, this can point at a frame that isn't really
				  ;active (is inside of SG-AP), to allow that
				  ;frame to be selected even though it isn't active.
;; T if we should regard the innermost frame as interesting
;; even if it is a call to a normally uninteresting function.
;; This is set when we break on entry to or exit from an uninteresting function.
(DEFVAR INNERMOST-FRAME-IS-INTERESTING NIL)

;; This is a random gensymmed object which is returned
;; from SG-EVAL to indicate that an error occurred within.
(DEFVAR ERROR-FLAG (NCONS NIL))

;; Number of levels of backtrace to print automatically upon error.
(DEFVAR ERROR-MESSAGE-BACKTRACE-LENGTH 3)

;; Number of instructions to disassemble for M-L, etc., if we
;; can't determine the amount of room on the screen.
;; Also minimum number to be shown.
(DEFVAR DISASSEMBLE-INSTRUCTION-COUNT 10.)

;; Calls to these functions should not be mentioned as frames
;; when stack-censoring is going on in interpreted functions.
;; This should include all functions that have &QUOTE args and are open-compiled.
;; *EVAL and APPLY-LAMBDA are there for peculiar reasons.
(DEFVAR UNINTERESTING-FUNCTIONS '(SI:*EVAL SI:APPLY-LAMBDA SETQ PROG PROG* PROGN
				  LET LET* DO DO-NAMED RETURN RETURN-FROM
				  MULTIPLE-VALUE MULTIPLE-VALUE-LIST
				  BREAKON-THIS-TIME COND AND OR STORE))

;;; These datatypes are OK to call print on
(DEFVAR GOOD-DATA-TYPES '(DTP-SYMBOL DTP-FIX DTP-EXTENDED-NUMBER DTP-SMALL-FLONUM 
			  DTP-LIST DTP-U-ENTRY DTP-FEF-POINTER DTP-ARRAY-POINTER
			  DTP-STACK-GROUP DTP-CLOSURE DTP-ENTITY DTP-INSTANCE))
;;; These point to something (as opposed to being Inums)
(DEFVAR POINTER-TYPES '(DTP-NULL DTP-SYMBOL DTP-SYMBOL-HEADER DTP-EXTENDED-NUMBER
			DTP-GC-FORWARD DTP-EXTERNAL-VALUE-CELL-POINTER DTP-ONE-Q-FORWARD
			DTP-HEADER-FORWARD DTP-LOCATIVE DTP-LIST
			DTP-FEF-POINTER DTP-ARRAY-POINTER DTP-STACK-GROUP
			DTP-CLOSURE DTP-SELECT-METHOD DTP-INSTANCE DTP-INSTANCE-HEADER
			DTP-ENTITY))

;;; These are names of errors which should not be caught by ERRSET
(DEFVAR ERRSET-INVISIBLE-ETES '(:BREAK PDL-OVERFLOW MAR-BREAK BREAKPOINT STEP-BREAK
				REGION-TABLE-OVERFLOW VIRTUAL-MEMORY-OVERFLOW AREA-OVERFLOW))
;;; Same except conditions signalled with FERROR/CERROR rather than microcode ETEs
(DEFVAR ERRSET-INVISIBLE-CONDITIONS '(:TRACE-ERROR-BREAK))

;;; Table of stack groups being stepped and stack groups stepping them
(DEFVAR SG-STEPPING-TABLE NIL)

;; This is a temporary kludge, which will be fixed by modifying the installed
;; LISP-REINITIALIZE when this thing gets installed.

(SETQ %INITIALLY-DISABLE-TRAPPING NIL)

;; Save a stack group's state on its stack so we can use it and then restore the state.
;; The information goes on the pdl in a fake frame belonging to the function FOOTHOLD.
;; Each Q is saved as 2 words (pointer and tag) to avoid data type problems.
;; You must call this before pushing a call block, even if calling SG-RUN-GOODBYE,
;; in order to clean up the QBBFL and the U-STACK Q's.
(DEFUN SG-SAVE-STATE (SG &OPTIONAL SUPPRESS-PDL-GROWING &AUX P NEW-AP RP PP)
  (OR SUPPRESS-PDL-GROWING (SG-MAYBE-GROW-PDLS SG))	;Make sure there is room to do this
  (SETQ RP (SG-REGULAR-PDL SG)
	PP (SG-REGULAR-PDL-POINTER SG))
  (SETQ NEW-AP (+ PP %LP-CALL-BLOCK-LENGTH))
  (ASET (DPB (- NEW-AP (SG-IPMARK SG)) %%LP-CLS-DELTA-TO-OPEN-BLOCK
	     (DPB (- NEW-AP (SG-AP SG)) %%LP-CLS-DELTA-TO-ACTIVE-BLOCK
		  0))
	RP (+ NEW-AP %LP-CALL-STATE))
  (ASET (DPB (FEF-INITIAL-PC #'FOOTHOLD) %%LP-EXS-EXIT-PC 0)
	RP (+ NEW-AP %LP-EXIT-STATE))
  (ASET 0 RP (+ NEW-AP %LP-ENTRY-STATE))
  (ASET #'FOOTHOLD RP (+ NEW-AP %LP-FEF))
  (SETQ PP (1+ NEW-AP))
  (DO I 0 (1+ I) (> I SG-PDL-PHASE)
      (SETQ P (AP-LEADER SG I))
      (ASET (IF (MEMQ (Q-DATA-TYPES (%P-DATA-TYPE P)) POINTER-TYPES)
		(%P-CONTENTS-AS-LOCATIVE P)
		(%P-POINTER P))
	    RP PP)
      (ASET (%P-LDB %%Q-ALL-BUT-POINTER P)
	    RP (1+ PP))
      (SETQ PP (+ PP 2)))
  (SETF (SG-REGULAR-PDL-POINTER SG) (1- PP))	;Index of last valid word
  (SETF (SG-FLAGS-QBBFL SG) 0)			;Clear QBBFL left over from previous frame
  (SETF (SG-IPMARK SG) NEW-AP)
  (SETF (SG-AP SG) NEW-AP))

;;; This function isn't normally called, it just exists to name state-save frames.
;;; If this function is ever returned to (see (:METHOD PROCESS :INTERRUPT))
;;; then it will restore the saved state and resume it.
;;; Do not trace nor redefine this function!
(DEFUN FOOTHOLD () (FUNCALL %ERROR-HANDLER-STACK-GROUP '(RESUME-FOOTHOLD)))

;; Pop the saved state from the pdl into the current state.
(DEFUN SG-RESTORE-STATE (SG &OPTIONAL (N-FRAMES-BACK 2))
  (LET ((PP (SG-AP SG))
	(RP (SG-REGULAR-PDL SG)))
    (LOOP REPEAT N-FRAMES-BACK DO (SETQ PP (SG-PREVIOUS-ACTIVE SG PP)))
    (AND (NULL PP)
	 (FERROR NIL "~S state not saved" SG))
    (OR (EQ (AREF RP PP) #'FOOTHOLD)
	(FERROR NIL "Saved state for ~S at ~S[~S] clobbered." SG RP PP))
    (SETQ PP (1+ PP))
    (DO I 0 (1+ I) (> I SG-PDL-PHASE)
      (%P-STORE-TAG-AND-POINTER (AP-LEADER SG I)
				(AREF RP (1+ PP))
				(AREF RP PP))
      (SETQ PP (+ PP 2)))))

;;; Low level routines for manipulating the stacks of a stack group.
;;; Call SG-SAVE-STATE before calling any of these.

(DEFUN SG-REGPDL-PUSH (X SG &AUX PP)
  (SETQ PP (1+ (SG-REGULAR-PDL-POINTER SG)))
  (ASET X (SG-REGULAR-PDL SG) PP)
  (%P-STORE-CDR-CODE (ALOC (SG-REGULAR-PDL SG) PP) CDR-NEXT)
  (SETF (SG-REGULAR-PDL-POINTER SG) PP)
  (SETF (SG-PDL-PHASE SG) (1+ (SG-PDL-PHASE SG)))
  X)

(DEFUN SG-REGPDL-POP (SG &AUX PP)
  (SETF (SG-PDL-PHASE SG) (1- (SG-PDL-PHASE SG)))
  (SETQ PP (SG-REGULAR-PDL-POINTER SG))
  (SETF (SG-REGULAR-PDL-POINTER SG) (1- PP))
  (AREF (SG-REGULAR-PDL SG) PP))

(DEFUN SG-SPECPDL-PUSH (X SG FLAG &AUX PP PDL)
  (SETQ PP (1+ (SG-SPECIAL-PDL-POINTER SG)))
  (SETF (SG-SPECIAL-PDL-POINTER SG) PP)
  (SETQ PDL (SG-SPECIAL-PDL SG))
  (ASET X PDL PP)
  (%P-STORE-FLAG-BIT (ALOC PDL PP) FLAG)
  X)

(DEFUN SG-SPECPDL-POP (SG &AUX PP)
  (SETQ PP (SG-SPECIAL-PDL-POINTER SG))
  (SETF (SG-SPECIAL-PDL-POINTER SG) (1- PP))
  (AREF (SG-SPECIAL-PDL SG) PP))

;; This simulates the CBM (or P3ZERO) routine in the microcode.
;; It is what a CALL instruction does.
;; You must call SG-SAVE-STATE before calling this.
(DEFUN SG-OPEN-CALL-BLOCK (SG DESTINATION FUNCTION &AUX PP NEW-IPMARK)
  (SETQ PP (SG-REGULAR-PDL-POINTER SG))
  (SETQ NEW-IPMARK (+ PP %LP-CALL-BLOCK-LENGTH))
  (SG-REGPDL-PUSH (DPB (- NEW-IPMARK (SG-IPMARK SG)) %%LP-CLS-DELTA-TO-OPEN-BLOCK
		       (DPB (- NEW-IPMARK (SG-AP SG)) %%LP-CLS-DELTA-TO-ACTIVE-BLOCK
			    (DPB DESTINATION %%LP-CLS-DESTINATION 0)))
		  SG)
  (SG-REGPDL-PUSH 0 SG)
  (SG-REGPDL-PUSH 0 SG)
  (SG-REGPDL-PUSH FUNCTION SG)
  (SETF (SG-IPMARK SG) NEW-IPMARK))

;; Running things in the other stack group.

;; Call a function in another stack group and return the value it "returns".
;; Actually, the function should call this stack group back with the "value" as argument.
;; If the value is the symbol LOSE, we throw to QUIT.
;; The call block and args should already be on the regpdl of the other stack group,
;; hence SG-SAVE-STATE should be outside this function.
;; Nothing will automatically make the function know who you are;
;; provide your own stack group as an argument to it if necessary.
;; Before returning, SG-RESTORE-STATE is done since it's generally desired.
(DEFUN RUN-SG (SG &AUX RESULT)
  (%P-STORE-CDR-CODE (ALOC (SG-REGULAR-PDL SG)	;Terminate arg list assumed there
			   (SG-REGULAR-PDL-POINTER SG))
		     CDR-NIL)
  (SETF (SG-CURRENT-STATE SG) SG-STATE-INVOKE-CALL-ON-RETURN)
  (SETQ LAST-SECOND-LEVEL-ERROR-HANDLER-SG %CURRENT-STACK-GROUP)
  (SETF (SG-FLAGS-MAR-MODE SG) 0)			;Turn off the MAR (why??)
  (STACK-GROUP-RESUME SG NIL)
  (SETQ RESULT (CAR %CURRENT-STACK-GROUP-CALLING-ARGS-POINTER))
  (SG-RESTORE-STATE SG)
  (COND ((AND ERROR-HANDLER-RUNNING ERROR-HANDLER-REPRINT-ERROR)
	 (COND ((NEQ %CURRENT-STACK-GROUP LAST-SECOND-LEVEL-ERROR-HANDLER-SG)
	        (TERPRI)
	        (PRINT-ERROR-MESSAGE SG (SG-TRAP-TAG SG) 'RETURN)))
	 (SETQ LAST-SECOND-LEVEL-ERROR-HANDLER-SG %CURRENT-STACK-GROUP)))
  (COND ((EQ RESULT 'LOSE)
	 (*THROW 'QUIT NIL)))
  RESULT)

;; Restart a stack group and mark the error handler stack group as free.
;; This is used for throwing, etc.
(DEFUN SG-RUN-GOODBYE (SG)
  (%P-STORE-CDR-CODE (ALOC (SG-REGULAR-PDL SG)	;Terminate arg list
			   (SG-REGULAR-PDL-POINTER SG))
		     CDR-NIL)
  (SETF (SG-CURRENT-STATE SG) SG-STATE-INVOKE-CALL-ON-RETURN)
  (WITHOUT-INTERRUPTS
    (AND ERROR-HANDLER-RUNNING (FREE-SECOND-LEVEL-ERROR-HANDLER-SG %CURRENT-STACK-GROUP))
    (STACK-GROUP-RESUME SG NIL)))

;; Mark a second level error handler stack group as available for re-use.
(DEFUN FREE-SECOND-LEVEL-ERROR-HANDLER-SG (SG)
  (COND ((NEQ SG %CURRENT-STACK-GROUP)
	 ;; Freeing the error handler, but not current stack group, so cause it to
	 ;; do a LEAVING-ERROR-HANDLER first
	 (SG-FUNCALL SG #'LEAVING-ERROR-HANDLER)))
  (WITHOUT-INTERRUPTS
    (PUSH SG FREE-SECOND-LEVEL-ERROR-HANDLER-SG-LIST)
    (AND CURRENT-PROCESS (FUNCALL CURRENT-PROCESS ':REVOKE-RUN-REASON SG))))

;; Unwind the stack group until the M-AP is DEST-AP.
;; If GOODBYE-P is T, it returns the specified value from that frame,
;; otherwise it comes back to the EH.
(DEFUN SG-UNWIND-TO-FRAME (SG DEST-FRAME GOODBYE-P &OPTIONAL VALUE (LABEL T) &AUX N)
  (IF (> INNERMOST-VISIBLE-FRAME (SG-AP SG))
      (SETF (SG-AP SG) INNERMOST-VISIBLE-FRAME))
  (SETQ N (DO ((FRAME (SG-AP SG) (SG-PREVIOUS-ACTIVE SG FRAME))
	       (N 1 (1+ N)))
	      ((= FRAME DEST-FRAME) N)))
  (SG-UNWIND SG LABEL VALUE N (IF GOODBYE-P NIL %CURRENT-STACK-GROUP)
	     (IF GOODBYE-P 'FREE 'CALL))
  (COND ((NULL GOODBYE-P)			;Flush the call back to this SG
	 (LET ((RP (SG-REGULAR-PDL SG)) (FRAME (SG-AP SG)))
	   (IF (NEQ (AREF RP FRAME) %CURRENT-STACK-GROUP)
	       (FERROR NIL "Second-level EH stack-group not found on pdl where expected"))
	   (IF ( (SG-REGULAR-PDL-POINTER SG) (1+ FRAME))
	       (FERROR NIL "Second-level EH stack-group called with wrong number of args"))
	   (SETF (SG-IPMARK SG) (SG-PREVIOUS-OPEN SG FRAME))
	   (SETF (SG-AP SG)
		 (SETQ CURRENT-FRAME (SETQ ORIGINAL-FRAME (SG-PREVIOUS-ACTIVE SG FRAME))))
	   (SETF (SG-FLAGS-QBBFL SG)		; Must correspond to current frame to work!
		 (RP-BINDING-BLOCK-PUSHED RP CURRENT-FRAME))
	   (DOTIMES (I 5)
	     (SG-REGPDL-POP SG))))))

(DEFUN SG-UNWIND-TO-FRAME-AND-REINVOKE (SG FRAME
			&OPTIONAL (FORM (GET-FRAME-FUNCTION-AND-ARGS SG FRAME))
			&AUX RP PP)
  ;; Unwind back to point where frame to be retried is about to return.
  ;; This gets rid of its unwind-protects but not its special bindings
  ;; and leaves any ADI associated with calling it on the stack too.
  (SG-UNWIND-TO-FRAME SG FRAME NIL)
  ;; Next line prevents total disaster if error in the code below
  (SETQ INNERMOST-VISIBLE-FRAME (SG-AP SG))
  ;; Now we would like to get rid of any associated special bindings
  ;; but unfortunately we can't distinguish closure/instance bindings
  ;; made before function entry with those made by the function itself.
  ;; So leave them all and hope for the best.
  ;; Get rid of the saved microstack for that frame.  There will at least
  ;; be an entry for XUWR1+1.
  (SETQ RP (SG-REGULAR-PDL SG)
	PP (SG-REGULAR-PDL-POINTER SG))
  (AND (ZEROP (RP-MICRO-STACK-SAVED RP FRAME))
       (FERROR NIL "Where's my saved microstack?"))
  (DO ((SP (SG-SPECIAL-PDL SG))
       (SPP (SG-SPECIAL-PDL-POINTER SG) (1- SPP))
       (P))
      (NIL)
    (SETQ P (ALOC SP SPP))
    (OR (= (%P-DATA-TYPE P) DTP-FIX) (FERROR NIL "Where's my saved microstack?"))
    (AND (%P-FLAG-BIT P)
	 (RETURN (SETF (SG-SPECIAL-PDL-POINTER SG) (1- SPP)))))
  (SETF (RP-MICRO-STACK-SAVED RP FRAME) 0)
  ;; Now rebuild the frame as if it was an open call block about to be called
  (SETF (SG-PDL-PHASE SG)		;PP gets M-AP minus one
	(LOGAND (- (SG-PDL-PHASE SG) (- PP (SETQ PP (1- FRAME)))) 1777))
  (SETF (SG-REGULAR-PDL-POINTER SG) PP)
  ;Put back the function.  Convert from a name to a function.
  (SG-REGPDL-PUSH (FUNCALL #'FUNCTION (CAR FORM)) SG)
  (DOLIST (X (CDR FORM))		;Put args back
    (SG-REGPDL-PUSH X SG))
  (%P-STORE-CDR-CODE (ALOC RP (SG-REGULAR-PDL-POINTER SG)) CDR-NIL)
  (SETF (SG-IPMARK SG) FRAME)
  (SETF (SG-AP SG) (SG-PREVIOUS-ACTIVE SG FRAME))
  ;; Now send the SG on its way
  (SETF (SG-CURRENT-STATE SG) SG-STATE-INVOKE-CALL-ON-RETURN))

;; The CONTINUATION is a function called with one argument in the newly-reset
;; stack-group.  ARGUMENT is that argument.
;; If PROCESS-P, rather than doing it now, in this process, we simply
;; leave the stack-group in such a state that the next time it is called,
;; e.g. by the scheduler, it will do it.
(DEFUN UNWIND-SG (SG CONTINUATION ARGUMENT PROCESS-P)
  (SETF (SG-INST-DISP SG) 0)  ;SG-MAIN-DISPATCH
  (LET ((ST (SG-CURRENT-STATE SG)))
    (COND ((NOT (OR (= ST SG-STATE-AWAITING-INITIAL-CALL)
		    (= ST 0)))
	   (SG-UNWIND SG T ARGUMENT NIL CONTINUATION (IF PROCESS-P 'SETUP 'CALL)))
	  (T	;SG has not been run, don't unwind, but do leave in same state
	   (STACK-GROUP-PRESET SG CONTINUATION ARGUMENT)
	   (OR PROCESS-P (STACK-GROUP-RESUME SG NIL))))
    (OR PROCESS-P (SETF (SG-CURRENT-STATE SG) SG-STATE-EXHAUSTED))))

;; Eval a form in a specified stack group using a foothold.
(DEFUN SG-EVAL (SG FORM &OPTIONAL REBIND-STREAMS &AUX (PREV-FH (SG-FOOTHOLD-DATA SG)))
  (SG-SAVE-STATE SG)
  (SETF (SG-FOOTHOLD-DATA SG) (SG-AP SG))
  (SG-OPEN-CALL-BLOCK SG 0 (IF REBIND-STREAMS 'FH-STREAM-BINDING-EVALER 'FH-EVALER))
  (SG-REGPDL-PUSH FORM SG)
  (SG-REGPDL-PUSH + SG)
  (SG-REGPDL-PUSH * SG)
  (SG-REGPDL-PUSH %CURRENT-STACK-GROUP SG)
  (SG-REGPDL-PUSH ERROR-HANDLER-RUNNING SG)
  (SG-REGPDL-PUSH PREV-FH SG)
  (AND REBIND-STREAMS (SG-REGPDL-PUSH TERMINAL-IO SG))
  (RUN-SG SG))

(DEFUN SG-FUNCALL (SG FUNCTION &REST ARGUMENTS)
  (SG-APPLY SG FUNCTION ARGUMENTS))

(DEFUN SG-APPLY (SG FUNCTION ARGUMENTS &AUX (PREV-FH (SG-FOOTHOLD-DATA SG)))
  (SG-SAVE-STATE SG)
  (SETF (SG-FOOTHOLD-DATA SG) (SG-AP SG))
  (SG-OPEN-CALL-BLOCK SG 0 'FH-APPLIER)
  (SG-REGPDL-PUSH FUNCTION SG)
  (SG-REGPDL-PUSH ARGUMENTS SG)
  (SG-REGPDL-PUSH + SG)
  (SG-REGPDL-PUSH * SG)
  (SG-REGPDL-PUSH %CURRENT-STACK-GROUP SG)
  (SG-REGPDL-PUSH ERROR-HANDLER-RUNNING SG)
  (SG-REGPDL-PUSH PREV-FH SG)
  (RUN-SG SG))

(DEFUN SG-THROW (SG LABEL VALUE &OPTIONAL IGNORE)
  (SG-SAVE-STATE SG)
  (SG-OPEN-CALL-BLOCK SG 0 'FH-THROWER)
  (SG-REGPDL-PUSH LABEL SG)
  (SG-REGPDL-PUSH VALUE SG)
  (SG-RUN-GOODBYE SG))

(DEFUN SG-UNWIND (SG LABEL VALUE COUNT ACTION DISPOSAL)
  "DISPOSAL is SETUP just to set up the call, CALL to make the call and not free the EH,
   FREE to make the call and free the EH"
  (SG-SAVE-STATE SG)
  (AND COUNT (SETQ COUNT (1+ COUNT)))  ;Make up for the frame pushed by SG-SAVE-STATE.
  (SG-OPEN-CALL-BLOCK SG 0 'FH-UNWINDER)
  (SG-REGPDL-PUSH LABEL SG)
  (SG-REGPDL-PUSH VALUE SG)
  (SG-REGPDL-PUSH COUNT SG)
  (SG-REGPDL-PUSH ACTION SG)
  (%P-STORE-CDR-CODE (ALOC (SG-REGULAR-PDL SG)	;Terminate arg list
			   (SG-REGULAR-PDL-POINTER SG))
		     CDR-NIL)
  (SETF (SG-CURRENT-STATE SG) SG-STATE-INVOKE-CALL-ON-RETURN)
  (WITHOUT-INTERRUPTS
    (AND ERROR-HANDLER-RUNNING (EQ DISPOSAL 'FREE)
	 (FREE-SECOND-LEVEL-ERROR-HANDLER-SG %CURRENT-STACK-GROUP))
    (OR (EQ DISPOSAL 'SETUP) (STACK-GROUP-RESUME SG NIL))))

;; The FH- functions are those intended to run in the other stack group.
;; Those that come back should be started up with RUN-SG.
;; They must be given the error handler stack group as an argument
;; so that they can call it back.  This they must do without making any other
;; intervening active call blocks on the stack, so that the foothold data
;; can be found from the SG-AP when it returns.  They must also be given ERROR-HANDLER-RUNNING
;; as an argument, so that if it is T they can do an unwind protect that
;; does FREE-SECOND-LEVEL-ERROR-HANDLER-SG on the stack group that they aren't going to return
;; to in that case.  They must also be given the previous foothold's offset so that
;; SG-FOOTHOLD-DATA can be reset in case of a throw.

;; Those that do not come back should be started up with SG-RUN-GOODBYE.

(DEFUN FH-APPLIER (FN ARGS NEW-+ NEW-* SG EH-P PREV-FH)
  (UNWIND-PROTECT
    (LET ((+ NEW-+) (* NEW-*) (EVALHOOK NIL) (ERRSET-STATUS NIL))
      (*CATCH 'SYS:COMMAND-LEVEL
	      (FUNCALL SG (MULTIPLE-VALUE-LIST (APPLY FN ARGS))))
      ;; This is in case the catch catches.
      (FUNCALL SG 'LOSE))
    ;; This is reached only if we throw through this frame.
    (SETF (SG-FOOTHOLD-DATA %CURRENT-STACK-GROUP) PREV-FH)
    (AND EH-P (FREE-SECOND-LEVEL-ERROR-HANDLER-SG SG))))

(DEFUN FH-EVALER (FORM NEW-+ NEW-* SG EH-P PREV-FH)
  (UNWIND-PROTECT
    (LET ((+ NEW-+) (* NEW-*) (EVALHOOK NIL) (ERRSET-STATUS NIL))
      (*CATCH 'SYS:COMMAND-LEVEL
	      (FUNCALL SG (MULTIPLE-VALUE-LIST (EVAL FORM))))
      ;; This is in case the catch catches.
      (FUNCALL SG 'LOSE))
    (SETF (SG-FOOTHOLD-DATA %CURRENT-STACK-GROUP) PREV-FH)
    (AND EH-P (FREE-SECOND-LEVEL-ERROR-HANDLER-SG SG))))

(DEFUN FH-STREAM-BINDING-EVALER (FORM NEW-+ NEW-* SG EH-P PREV-FH EH-TERMINAL-IO)
  (DECLARE (SPECIAL OLD-TERMINAL-IO OLD-STANDARD-OUTPUT OLD-STANDARD-INPUT))
  (UNWIND-PROTECT
    (LET ((OLD-TERMINAL-IO TERMINAL-IO) 
	  (OLD-STANDARD-OUTPUT STANDARD-OUTPUT) (OLD-STANDARD-INPUT STANDARD-INPUT)
	  (+ NEW-+) (* NEW-*) (EVALHOOK NIL) (ERRSET-STATUS NIL)
	  WIN-P RESULT)
      (LET ((TERMINAL-IO EH-TERMINAL-IO)
	    (STANDARD-INPUT 'SI:TERMINAL-IO-SYN-STREAM)
	    (STANDARD-OUTPUT 'SI:TERMINAL-IO-SYN-STREAM))
        (*CATCH 'SYS:COMMAND-LEVEL
		(SETQ RESULT (MULTIPLE-VALUE-LIST (EVAL FORM))
		      WIN-P T)))
      (COND (WIN-P
	     (SETQ TERMINAL-IO OLD-TERMINAL-IO
		   STANDARD-OUTPUT OLD-STANDARD-OUTPUT
		   STANDARD-INPUT OLD-STANDARD-INPUT)
	     (FUNCALL SG RESULT))
	    (T (FUNCALL SG 'LOSE))))
    (SETF (SG-FOOTHOLD-DATA %CURRENT-STACK-GROUP) PREV-FH)
    (AND EH-P (FREE-SECOND-LEVEL-ERROR-HANDLER-SG SG))))

(DEFUN FH-THROWER (LABEL VALUE)
  (*THROW LABEL VALUE))

(DEFUN FH-UNWINDER (LABEL VALUE COUNT ACTION)
  (*UNWIND-STACK LABEL VALUE COUNT ACTION))

;; Various utility ANALYSIS functions.

;; These functions take an SG and a FRAME, and return the
;; previous open or active stack frame.
;Result is NIL if this is the bottom frame
(DEFUN SG-PREVIOUS-OPEN (SG FRAME)
  (LET ((DELTA (RP-DELTA-TO-OPEN-BLOCK (SG-REGULAR-PDL SG) FRAME)))
    (IF (ZEROP DELTA) NIL (- FRAME DELTA))))

;Result is NIL if this is the bottom frame
(DEFUN SG-PREVIOUS-ACTIVE (SG FRAME)
  (LET ((DELTA (RP-DELTA-TO-ACTIVE-BLOCK (SG-REGULAR-PDL SG) FRAME)))
    (IF (ZEROP DELTA) NIL (- FRAME DELTA))))

;; Returns NIL if there is no next.
(DEFUN SG-NEXT-OPEN (SG FRAME)
  (DO ((THIS-FRAME (SG-IPMARK SG) (SG-PREVIOUS-OPEN SG THIS-FRAME))
       (NEXT-FRAME NIL THIS-FRAME))
      ((= THIS-FRAME FRAME) NEXT-FRAME)))

;; Returns NIL if there is no next.
;; Given NIL as arg, returns the bottom frame (whose SG-PREVIOUS-ACTIVE is NIL).
(DEFUN SG-NEXT-ACTIVE (SG FRAME)
  (DO ((THIS-FRAME INNERMOST-VISIBLE-FRAME (SG-PREVIOUS-ACTIVE SG THIS-FRAME))
       (NEXT-FRAME NIL THIS-FRAME))
      ((COND (FRAME (<= THIS-FRAME FRAME))
	     (T (NULL THIS-FRAME)))
       NEXT-FRAME)))

;; Returns T if specified frame is an active frame.
(DEFUN SG-FRAME-ACTIVE-P (SG FRAME)
  (EQ FRAME (SG-NEXT-ACTIVE SG (SG-PREVIOUS-ACTIVE SG FRAME))))

;; Scan several open frames up or down from a given one.
;; We return two values; the first is the offset of the frame found,
;; and the second is T if the specified number of frames were found
;; before the top or bottom of the stack.
(DEFUN SG-NEXT-NTH-OPEN (SG FRAME &OPTIONAL (COUNT 1))
  (COND ((= COUNT 0) FRAME)
	((MINUSP COUNT)
	 (DO ((P FRAME (SG-PREVIOUS-OPEN SG P))
	      (I 0 (1- I))
	      (PP NIL P))
	     (())
	   (AND (OR (NULL P) (= I COUNT))
		(RETURN (OR P PP) P))))
	(T (DO ((P FRAME (SG-NEXT-OPEN SG P))
		(I 0 (1+ I))
		(PP NIL P))
	       (())
	     (AND (OR (NULL P) (= I COUNT))
		  (RETURN (OR P PP) P))))))

;; Scan several active frames up or down from a given one.
;; We return two values; the first is the offset of the frame found,
;; and the second is T if the specified number of frames were found
;; before the top or bottom of the stack.
(DEFUN SG-NEXT-NTH-ACTIVE (SG FRAME &OPTIONAL (COUNT 1))
  (COND ((= COUNT 0) FRAME)
	((MINUSP COUNT)
	 (DO ((P FRAME (SG-PREVIOUS-ACTIVE SG P))
	      (I 0 (1- I))
	      (PP NIL P))
	     (())
	   (AND (OR (NULL P) (= I COUNT))
		(RETURN (OR P PP) P))))
	(T (DO ((P FRAME (SG-NEXT-ACTIVE SG P))
		(I 0 (1+ I))
		(PP NIL P))
	       (())
	     (AND (OR (NULL P) (= I COUNT))
		  (RETURN (OR P PP) P))))))

(DEFUN FEF-INSTRUCTION (FEF PC)
  (LET ((IDX (// PC 2)))
    (COND ((ZEROP (LOGAND 1 PC))
	   (%P-LDB-OFFSET %%Q-LOW-HALF FEF IDX))
	  ((%P-LDB-OFFSET %%Q-HIGH-HALF FEF IDX)))))

;Takes a functional object, and returns a Lisp object which is its "name".
(DEFUN FUNCTION-NAME (FUNCTION)
  (SELECT (%DATA-TYPE FUNCTION)
    (DTP-FEF-POINTER (FEF-NAME FUNCTION))
    (DTP-U-ENTRY (MICRO-CODE-ENTRY-NAME-AREA (%POINTER FUNCTION)))
    (DTP-LIST (COND ((MEMQ (CAR FUNCTION) '(NAMED-LAMBDA NAMED-SUBST))
		     (IF (ATOM (CADR FUNCTION)) (CADR FUNCTION)
			 (CAADR FUNCTION)))
		    (T FUNCTION)))
    (DTP-CLOSURE (FUNCTION-NAME (CAR (%MAKE-POINTER DTP-LIST FUNCTION))))
    (DTP-STACK-GROUP (SG-NAME FUNCTION))
    (DTP-SYMBOL FUNCTION)
    (OTHERWISE FUNCTION)))

;; Scan several active frames up or down from a given one,
;; being smart about calls to interpreted functions.
;; We return two values; the first is the offset of the frame found,
;; and the second is T if the specified number of frames were found
;; before the top or bottom of the stack.
(DEFUN SG-NEXT-NTH-INTERESTING-ACTIVE (SG FRAME &OPTIONAL (COUNT 1))
  (COND ((= COUNT 0) FRAME)
	((MINUSP COUNT)
	 (DO ((P FRAME (SG-PREVIOUS-INTERESTING-ACTIVE SG P))
	      (I 0 (1- I))
	      (PP NIL P))
	     (())
	   (AND (OR (NULL P) (= I COUNT))
		(RETURN (OR P PP) P))))
	(T (DO ((P FRAME (SG-NEXT-INTERESTING-ACTIVE SG P))
		(I 0 (1+ I))
		(PP NIL P))
	       (())
	     (AND (OR (NULL P) (= I COUNT))
		  (RETURN (OR P PP) P))))))

;; Return the next frame, counting all the actual frames of parts of an
;; interpreted function as if they were one frame.
(DEFUN SG-NEXT-INTERESTING-ACTIVE (SG FRAME &AUX (RP (SG-REGULAR-PDL SG)))
  (COND ((ATOM (RP-FUNCTION-WORD RP FRAME))
	 (SG-NEXT-ACTIVE SG FRAME))
	(T (DO ((NEW-FRAME (SG-NEXT-ACTIVE SG FRAME) (SG-NEXT-ACTIVE SG NEW-FRAME)))
	       ((OR (NULL NEW-FRAME)
		    (NOT (MEMQ (FUNCTION-NAME (RP-FUNCTION-WORD RP NEW-FRAME))
			       UNINTERESTING-FUNCTIONS)))
		NEW-FRAME)
	     ;; Make provisions for showing uninteresting fns
	     ;; when we are stepping thru them.
	     (AND (= NEW-FRAME INNERMOST-VISIBLE-FRAME)
		  INNERMOST-FRAME-IS-INTERESTING
		  (RETURN (SG-NEXT-ACTIVE SG FRAME)))))))

(DEFUN SG-PREVIOUS-INTERESTING-ACTIVE (SG FRAME)
  (COND ((MEMQ (FUNCTION-NAME (RP-FUNCTION-WORD (SG-REGULAR-PDL SG) FRAME))
	       UNINTERESTING-FUNCTIONS)
	 (SG-PREVIOUS-ACTIVE SG FRAME))
	(T (SG-OUT-TO-INTERESTING-ACTIVE SG (SG-PREVIOUS-ACTIVE SG FRAME)))))

;; Given a frame, find out if it is one of the frames of a call to an interpreted function.
;; If so, return the outermost frame of this call to the interpreted function.
;; If not, return the original frame.
(DEFUN SG-OUT-TO-INTERESTING-ACTIVE (SG FRAME &AUX (RP (SG-REGULAR-PDL SG)))
  (COND ((NULL FRAME) NIL)
	((AND (= FRAME INNERMOST-VISIBLE-FRAME)
	      INNERMOST-FRAME-IS-INTERESTING)
	 FRAME)
	((NOT (MEMQ (FUNCTION-NAME (RP-FUNCTION-WORD RP FRAME)) UNINTERESTING-FUNCTIONS))
	 FRAME)
	(T (DO ((NEW-FRAME FRAME (SG-PREVIOUS-ACTIVE SG NEW-FRAME)))
	       ((OR (NULL NEW-FRAME)
		    (NOT (MEMQ (FUNCTION-NAME (RP-FUNCTION-WORD RP NEW-FRAME))
			       UNINTERESTING-FUNCTIONS)))
		(COND ((NULL NEW-FRAME) FRAME)
		      ((ATOM (RP-FUNCTION-WORD RP NEW-FRAME)) FRAME)
		      (T NEW-FRAME)))))))

;; Return a name for the "function" to tell the user about
;; corresponding to the macro instruction in which an error happened.
(DEFUN SG-ERRING-FUNCTION (SG)
  (LET ((CURRENT-UPC (SG-TRAP-MICRO-PC SG))
	(FRAME (SG-AP SG))
	(RP (SG-REGULAR-PDL SG)))
    (IF (AND ( BEGIN-QARYR CURRENT-UPC) (< CURRENT-UPC END-QARYR))
	;; Not in a function at all.  Return the array it is in.
	(RP-FUNCTION-WORD RP (SG-IPMARK SG))
	;; Normal case.  If in a compiled function, see if it "called" an open-coded fcn.
	(LET ((FUNCTION (RP-FUNCTION-WORD RP FRAME))
	      (PC (1- (RP-EXIT-PC RP FRAME))))
	  (SELECT (%DATA-TYPE FUNCTION)
	    (DTP-U-ENTRY
	      (MICRO-CODE-ENTRY-NAME-AREA (%POINTER FUNCTION)))
	    (DTP-FEF-POINTER 
	      (LET ((INST (FEF-INSTRUCTION FUNCTION PC)))
		(LET ((OP (LDB 1104 INST))
		      (DEST (LDB 1503 INST))
		      (DISP (LDB 0011 INST)))
		  (COND ((< OP 11)
			 (NTH OP '(FUNCALL FUNCALL MOVE-INSTRUCTION CAR
				   CDR CADR CDDR CDAR CAAR)))
			((= OP 11)
			 (NTH DEST '(ND1-UNUSED *PLUS *DIF *TIMES ;*'s to avoid confusion
				     *QUO *LOGAND *LOGXOR *LOGIOR))) ;with argument-number
			((= OP 12)
			 (NTH DEST '(= > < EQ CDR CDDR 1+ 1-)))
			((= OP 13)
			 (NTH DEST '(ND3-UNUSED BIND BIND SET-NIL
				     SET-ZERO PUSH-E MOVEM POP)))
			((= OP 14)
			 'A-BRANCH-INSTRUCTION)
			((< DISP 100) 'LIST)
			((< DISP 200) 'LIST-IN-AREA)
			((< DISP 220) 'UNBIND)
			((< DISP 240) 'A-POP-PDL-INSTRUCTION)
			(T (MICRO-CODE-SYMBOL-NAME-AREA (- DISP 200)))))))
	    (OTHERWISE FUNCTION))))))

;; Return the name of the localno'th local of function, or nil if unavailable or none such.
;; This is only meaningful for fefs if localno > 0.
;; If localno = 0 it will get the name of the rest arg, if there is one,
;; for any type of function.
(DEFUN LOCAL-NAME (FUNCTION LOCALNO &AUX ARGL)
  (COND ((= (%DATA-TYPE FUNCTION) DTP-FEF-POINTER)
	 (COMPILER:DISASSEMBLE-LOCAL-NAME FUNCTION LOCALNO))
	((AND (ZEROP LOCALNO)
	      (LISTP (SETQ ARGL (COND ((LISTP FUNCTION)
				       (SELECTQ (CAR FUNCTION)
					 (LAMBDA (CADR FUNCTION))
					 (NAMED-LAMBDA (CADDR FUNCTION))))
				      ((LEGITIMATE-FUNCTION-P FUNCTION)
				       (ARGLIST FUNCTION T))))))
	 (CADR (MEMQ '&REST ARGL)))))

;; Return the name of the argno'th arg of function, or nil if
;; not known or function doesn't want that many args.
;; Rest args don't count.
(DEFUN ARG-NAME (FUNCTION ARGNO &AUX ARGL)
  (COND ((= (%DATA-TYPE FUNCTION) DTP-FEF-POINTER)
	 (COMPILER:DISASSEMBLE-ARG-NAME FUNCTION ARGNO))
	((LISTP (SETQ ARGL (COND ((LISTP FUNCTION)
				  (SELECTQ (CAR FUNCTION)
				    ((LAMBDA SUBST) (CADR FUNCTION))
				    ((NAMED-LAMBDA NAMED-SUBST) (CADDR FUNCTION))))
				 ((LEGITIMATE-FUNCTION-P FUNCTION)
				  (ARGLIST FUNCTION T)))))
	 (DO ((ARGL ARGL (CDR ARGL))
	      (I ARGNO))
	     ((OR (NULL ARGL)
		  (EQ (CAR ARGL) '&AUX)
		  (EQ (CAR ARGL) '&REST)
		  (EQ (CAR ARGL) '&KEY)))
	   (OR (MEMQ (CAR ARGL) LAMBDA-LIST-KEYWORDS)
	       (COND (( I 0)
		      (RETURN (CAR ARGL)))
		     (T (SETQ I (1- I)))))))))

;; Functions for finding the special pdl info associated with a stack frame.

;;;Return the range of the special pdl bound by this frame, or NIL if does not hack any
;;;specials.
(DEFUN SG-FRAME-SPECIAL-PDL-RANGE (SG FRAME &AUX (RP (SG-REGULAR-PDL SG)))
  (AND (NOT (ZEROP (RP-BINDING-BLOCK-PUSHED RP FRAME)))
       (LET ((SP (SG-SPECIAL-PDL SG)))
	 (DO ((FRAME1 (SG-AP SG) (SG-PREVIOUS-ACTIVE SG FRAME1))
	      (J (SG-SPECIAL-PDL-POINTER SG))
	      (I))
	     ((NULL FRAME1))
	   (COND ((NOT (ZEROP (RP-BINDING-BLOCK-PUSHED RP FRAME1)))
		  (DO () ((= (%P-DATA-TYPE (ALOC-CAREFUL SP J)) DTP-LOCATIVE))
		    ;; Space back over a random non-binding frame
		    (DO () ((NOT (ZEROP (%P-FLAG-BIT (ALOC-CAREFUL SP J)))))
		      (SETQ J (1- J)))
		    (SETQ J (1- J)))
		  ;; Make I and J inclusive brackets for this binding frame
		  (SETQ I (1- J))
		  (DO () ((NOT (ZEROP (%P-FLAG-BIT (ALOC-CAREFUL SP I)))))
		    (SETQ I (- I 2)))
		  (AND (= FRAME1 FRAME) (RETURN I J))
		  (SETQ J (1- I))))))))

;Return special pdl index corresponding to beginning of this frame's data.
;If no specials in this frame, return index pointing after last data from
;outside this frame.
(DEFUN SG-FRAME-SPECIAL-PDL-INDEX (SG FRAME &AUX (RP (SG-REGULAR-PDL SG)))
  (LET ((SP (SG-SPECIAL-PDL SG)))
    (DO ((FRAME1 (SG-AP SG) (SG-PREVIOUS-ACTIVE SG FRAME1))
	 (J (SG-SPECIAL-PDL-POINTER SG)))
	((NULL FRAME1))
      (COND ((NOT (ZEROP (RP-BINDING-BLOCK-PUSHED RP FRAME1)))
	     (DO () ((= (%P-DATA-TYPE (ALOC-CAREFUL SP J)) DTP-LOCATIVE))
	       ;; Space back over a random non-binding frame
	       (DO () ((NOT (ZEROP (%P-FLAG-BIT (ALOC-CAREFUL SP J)))))
		 (SETQ J (1- J)))
	       (SETQ J (1- J)))
	     ;; Space back to beginning of a binding block.
	     (SETQ J (1- J))
	     (DO () ((NOT (ZEROP (%P-FLAG-BIT (ALOC-CAREFUL SP J)))))
	       (SETQ J (- J 2)))
	     (SETQ J (1- J))))
      (AND (= FRAME1 FRAME) (RETURN J)))))

;Functions to extract the argument and local variable values from a frame.

;Return list of the function and args that were invoked (as best as it can).
;Doesn't work, of course, for functions which modify their arguments.
;Note that this tries to get the original name of the function so that
;if it has been redefined and you are doing c-m-R the new version will be called.
(DEFUN GET-FRAME-FUNCTION-AND-ARGS (SG FRAME &AUX FUNCTION NARGS-SUPPLIED
				    (RP (SG-REGULAR-PDL SG))
				    LEXPR-CALL REST-ARG-VALUE ANS)
      (SETQ FUNCTION (RP-FUNCTION-WORD RP FRAME)
	    NARGS-SUPPLIED (RP-NUMBER-ARGS-SUPPLIED RP FRAME))  ;Really slots on stack
      (MULTIPLE-VALUE (REST-ARG-VALUE NIL LEXPR-CALL)
	(SG-REST-ARG-VALUE SG FRAME))
      ;; Analyze the function
      (SETQ FUNCTION (FUNCTION-NAME FUNCTION))
      ;; Get the individual args.
      (DO ((I NARGS-SUPPLIED (1- I)))		;Cons them up in reverse order
	  ((ZEROP I))
	(SETQ ANS (CONS (AREF RP (+ FRAME I)) ANS)))   ;+1 -1
      ;; NCONC the rest arg if any was supplied separately from the regular args
      (AND LEXPR-CALL (SETQ ANS (NCONC ANS (COPYLIST REST-ARG-VALUE))))
      (CONS FUNCTION ANS))

;; Get the value of the ARGNUMth arg of the specified frame, and its location.
(DEFUN SG-FRAME-ARG-VALUE (SG FRAME ARGNUM)
  (DECLARE (RETURN-LIST VALUE LOCATION))
  (PROG FUNCTION ((ARG-NAME (ARG-NAME (FUNCTION-NAME (RP-FUNCTION-WORD (SG-REGULAR-PDL SG)
								       FRAME))
				      ARGNUM)))
	(MULTIPLE-VALUE-BIND (START END)
	    (SG-FRAME-SPECIAL-PDL-RANGE SG FRAME)
	  (COND (START
		 (DO ((SP (SG-SPECIAL-PDL SG))
		      (I START (+ 2 I)))
		     ((>= I END))
		   (AND (EQ (SYMBOL-FROM-VALUE-CELL-LOCATION (AREF SP (1+ I)))
			    ARG-NAME)
			(RETURN-FROM FUNCTION (AREF SP I) (ALOC SP I)))))))
	(RETURN (AREF (SG-REGULAR-PDL SG) (+ FRAME ARGNUM 1))
		(ALOC (SG-REGULAR-PDL SG) (+ FRAME ARGNUM 1)))))

;; Get the value of the LOCALNUMth local variable of the specified frame, and its location.
(DEFUN SG-FRAME-LOCAL-VALUE (SG FRAME LOCALNUM) 
  (DECLARE (RETURN-LIST VALUE LOCATION))
  (PROG FUNCTION ((LOCAL-NAME (LOCAL-NAME (RP-FUNCTION-WORD (SG-REGULAR-PDL SG) FRAME)
					  LOCALNUM)))
	(MULTIPLE-VALUE-BIND (START END)
	    (SG-FRAME-SPECIAL-PDL-RANGE SG FRAME)
	  (COND (START
		 (DO ((SP (SG-SPECIAL-PDL SG))
		      (I START (+ 2 I)))
		     ((>= I END))
		   (AND (EQ (SYMBOL-FROM-VALUE-CELL-LOCATION (AREF SP (1+ I)))
			    LOCAL-NAME)
			(MULTIPLE-VALUE-BIND (VALUE LOC)
			    (SYMEVAL-IN-STACK-GROUP LOCAL-NAME SG FRAME)
			  (RETURN-FROM FUNCTION VALUE LOC)))))))
	(LET* ((RP (SG-REGULAR-PDL SG))
	       (RPIDX (+ LOCALNUM CURRENT-FRAME (RP-LOCAL-BLOCK-ORIGIN RP CURRENT-FRAME))))
	  (RETURN (AREF RP RPIDX) (ALOC RP RPIDX)))))

;; Get the value of the rest arg in a given frame.
;; The first value is the value of the rest arg (nil if the frame has none).
;; The second value is T if the function expects to have one.
;; The third value indicates a rest arg explicitly passed as one;
;; it can conceivably be T even if the second is nil, if something strange
;; has happened, and an extraneous rest arg has been passed.
(DEFUN SG-REST-ARG-VALUE (SG FRAME &AUX
			     (RP (SG-REGULAR-PDL SG))
			     (AP FRAME)
			     LEXPR-CALL ARGS-INFO REST-ARG
			     (FUNCTION (RP-FUNCTION-WORD RP AP))
			     (NARGS-SUPPLIED (RP-NUMBER-ARGS-SUPPLIED RP AP))
			     (NARGS-EXPECTED NARGS-SUPPLIED))
  (COND ((LEGITIMATE-FUNCTION-P FUNCTION)
	 (SETQ ARGS-INFO (ARGS-INFO FUNCTION))
	 (SETQ REST-ARG (LDB-TEST 2402 ARGS-INFO))
	 (SETQ NARGS-EXPECTED (LDB %%ARG-DESC-MAX-ARGS ARGS-INFO))))
  (AND (NOT (ZEROP (RP-ADI-PRESENT RP AP)))
       (DO I (- AP %LP-CALL-BLOCK-LENGTH) (- I 2) NIL
	   (SELECT (LDB %%ADI-TYPE (AREF RP I))
	     ((ADI-FEXPR-CALL ADI-LEXPR-CALL)
	      (RETURN (SETQ LEXPR-CALL T))))	;Last arg supplied is a rest arg
	   (AND (ZEROP (%P-FLAG-BIT (ALOC RP (1- I))))
		(RETURN NIL))))
  (PROG () (RETURN 
	     (COND (LEXPR-CALL (AREF RP (+ AP NARGS-SUPPLIED)))
		   ((LISTP FUNCTION)
		    (COND ((> NARGS-SUPPLIED NARGS-EXPECTED)
			   (%MAKE-POINTER DTP-LIST
					  (ALOC RP (+ AP NARGS-EXPECTED 1))))
			  (T NIL)))
		   (T (AREF RP (+ AP (RP-LOCAL-BLOCK-ORIGIN RP AP)))))
	     REST-ARG
	     LEXPR-CALL)))

;; T if things like ARGS-INFO will work for this function.
(DEFUN LEGITIMATE-FUNCTION-P (FUNCTION)
  (OR (= (%DATA-TYPE FUNCTION) DTP-FEF-POINTER)
      (= (%DATA-TYPE FUNCTION) DTP-U-ENTRY)
      (AND (LISTP FUNCTION) (MEMQ (CAR FUNCTION) '(LAMBDA NAMED-LAMBDA SUBST NAMED-SUBST)))))

;; Return the number of spread args present in a given frame.
;; This will not count any args which are part of a rest arg.
(DEFUN SG-NUMBER-OF-SPREAD-ARGS (SG FRAME &AUX
				    (RP (SG-REGULAR-PDL SG)) (AP FRAME)
				    ARGS-INFO REST-ARG-P NARGS-EXPECTED NARGS-VISIBLE
				    (FUNCTION (RP-FUNCTION-WORD RP AP))
				    (NARGS-SUPPLIED (RP-NUMBER-ARGS-SUPPLIED RP AP)))
  (COND ((LEGITIMATE-FUNCTION-P FUNCTION)
	 (SETQ ARGS-INFO (ARGS-INFO FUNCTION))
	 (SETQ REST-ARG-P (LDB-TEST 2402 ARGS-INFO))
	 (SETQ NARGS-EXPECTED (LDB %%ARG-DESC-MAX-ARGS ARGS-INFO))))
  ;; See if this is a lexpr-call.  If so, the last "arg" is a rest arg, so decrement nargs.
  (AND (NOT (ZEROP (RP-ADI-PRESENT RP AP)))
       (DO I (- AP %LP-CALL-BLOCK-LENGTH) (- I 2) NIL
	   (SELECT (LDB %%ADI-TYPE (AREF RP I))
	     ((ADI-FEXPR-CALL ADI-LEXPR-CALL)
	      (RETURN (SETQ NARGS-SUPPLIED (1- NARGS-SUPPLIED)))))
	   (AND (ZEROP (%P-FLAG-BIT (ALOC RP (1- I))))
		(RETURN NIL))))
  ;; The args that can be asked for are the ones supplied,
  ;; except that FEFs make slots for all args they expect whether supplied or not.
  (SETQ NARGS-VISIBLE
	(COND ((= (%DATA-TYPE FUNCTION) DTP-FEF-POINTER)
	       (MAX NARGS-SUPPLIED NARGS-EXPECTED))
	      (T NARGS-SUPPLIED)))
  ;; If function is known to take a rest arg, any unexpected args
  ;; are part of it, so they don't count as there this way.
  (AND REST-ARG-P (> NARGS-SUPPLIED NARGS-EXPECTED)
       (SETQ NARGS-VISIBLE NARGS-EXPECTED))
  NARGS-VISIBLE)

;; These functions know about the location tags used in the ERROR-TABLE
;; entries, and how to creates locatives to them, fetch from them,
;; and store into them.
;;   There is the issue that the contents may be illegal datatypes.
;; Have to think about if there are screw cases, etc.

; Analysis
(DEFUN SG-CONTENTS (SG LOC)
  (SELECTQ LOC
    (M-A (SG-AC-A SG))
    (M-B (SG-AC-B SG))
    (M-C (SG-AC-C SG))
    (M-D (SG-AC-C SG))
    (M-E (SG-AC-E SG))
    (M-T (SG-AC-T SG))
    (M-R (SG-AC-R SG))
    (M-Q (SG-AC-Q SG))
    (M-I (SG-AC-I SG))
    (M-J (SG-AC-J SG))
    (M-S (SG-AC-S SG))
    (M-K (SG-AC-K SG))
    (A-QCSTKG SG)
    (A-SG-PREVIOUS-STACK-GROUP (SG-PREVIOUS-STACK-GROUP SG))
    (PP (AREF (SG-REGULAR-PDL SG) (SG-REGULAR-PDL-POINTER SG)))
    (RMD (%P-CONTENTS-OFFSET (SG-SAVED-VMA SG) 0))
    (OTHERWISE
      (COND ((AND (LISTP LOC) (EQ (CAR LOC) 'PP))
	     (AREF (SG-REGULAR-PDL SG) (+ (SG-REGULAR-PDL-POINTER SG) (CADR LOC))))
	    ((BAD-HACKER LOC "Unknown tag"))))))

;; Metamorphosis
(DEFUN SG-STORE (X SG LOC)
  (SELECTQ LOC
    (M-A (SETF (SG-AC-A SG) X))
    (M-B (SETF (SG-AC-B SG) X))
    (M-C (SETF (SG-AC-C SG) X))
    (M-D (SETF (SG-AC-C SG) X))
    (M-E (SETF (SG-AC-E SG) X))
    (M-T (SETF (SG-AC-T SG) X))
    (M-R (SETF (SG-AC-R SG) X))
    (M-Q (SETF (SG-AC-Q SG) X))
    (M-I (SETF (SG-AC-I SG) X))
    (M-J (SETF (SG-AC-J SG) X))
    (M-S (SETF (SG-AC-S SG) X))
    (M-K (SETF (SG-AC-K SG) X))
    (A-QCSTKG (ERROR T "You can't store in this!"))
    (A-SG-PREVIOUS-STACK-GROUP (SETF (SG-PREVIOUS-STACK-GROUP SG) X))
    (PP (ASET X (SG-REGULAR-PDL SG) (SG-REGULAR-PDL-POINTER SG)))
    (RMD (%P-STORE-CONTENTS (SG-SAVED-VMA SG) X))	;Offset???
    (OTHERWISE
      (COND ((AND (LISTP LOC) (EQ (CAR LOC) 'PP))
	     (ASET X (SG-REGULAR-PDL SG) (+ (SG-REGULAR-PDL-POINTER SG) (CADR LOC))))
	    ((BAD-HACKER LOC "Unknown tag"))))))

;; Getllocativepointersis
(DEFUN SG-LOCATE (SG LOC)
  (SELECTQ LOC
    (M-A (LOCF (SG-AC-A SG)))
    (M-B (LOCF (SG-AC-B SG)))
    (M-C (LOCF (SG-AC-C SG)))
    (M-D (LOCF (SG-AC-D SG)))
    (M-E (LOCF (SG-AC-E SG)))
    (M-T (LOCF (SG-AC-T SG)))
    (M-R (LOCF (SG-AC-R SG)))
    (M-Q (LOCF (SG-AC-Q SG)))
    (M-I (LOCF (SG-AC-I SG)))
    (M-J (LOCF (SG-AC-J SG)))
    (M-S (LOCF (SG-AC-S SG)))
    (M-K (LOCF (SG-AC-K SG)))
    (A-QCSTKG (%MAKE-POINTER DTP-LOCATIVE SG))
    (A-SG-PREVIOUS-STACK-GROUP (LOCF (SG-PREVIOUS-STACK-GROUP SG)))
    (PP (ALOC (SG-REGULAR-PDL SG) (SG-REGULAR-PDL-POINTER SG)))
    (RMD (%MAKE-POINTER DTP-LOCATIVE (SG-SAVED-VMA SG)))
    (OTHERWISE
      (COND ((AND (LISTP LOC) (EQ (CAR LOC) 'PP))
	     (ALOC (SG-REGULAR-PDL SG) (+ (SG-REGULAR-PDL-POINTER SG) (CADR LOC))))
	    ((BAD-HACKER LOC "Unknown tag"))))))

;Get the special-pdl pointer for the running SG
(DEFUN GET-OWN-SPECIAL-PDL-POINTER (SP)
  (- (1- (%STRUCTURE-BOXED-SIZE SP))
     (+ (ARRAY-LEADER-LENGTH SP) 3 (%P-LDB-OFFSET %%ARRAY-LONG-LENGTH-FLAG SP 0))))

;An ALOC that only works for 1-dimensional arrays.  It avoids referencing the
;word pointed to since if the special-pdl pointer being used is confused that
;might be an external-value-cell-pointer, causing an error.  This doesn't
;do bounds checking.
(DEFUN ALOC-CAREFUL (ARRAY INDEX)
  (%MAKE-POINTER-OFFSET DTP-LOCATIVE
			ARRAY
			(+ INDEX 1 (%P-LDB-OFFSET %%ARRAY-LONG-LENGTH-FLAG ARRAY 0))))

;;; Find out whether this is a pointer to an unbound value or function cell.
(DEFUN LOCATIVE-BOUNDP (LOCATIVE)
  (LOOP FOR DTP = (%P-DATA-TYPE LOCATIVE)
	DO (SELECT DTP
	     (DTP-NULL
	      (RETURN NIL))
	     ((DTP-EXTERNAL-VALUE-CELL-POINTER
	       DTP-ONE-Q-FORWARD)
	      (SETQ LOCATIVE (%P-CONTENTS-AS-LOCATIVE LOCATIVE)))
	     (OTHERWISE
	      (RETURN T)))))

(DEFUN SYMBOL-FROM-VALUE-CELL-LOCATION (LOC &AUX SYM)
  (COND ((AND ( (%POINTER LOC) A-MEMORY-VIRTUAL-ADDRESS)	;Microcode location
	      (< (%POINTER LOC) IO-SPACE-VIRTUAL-ADDRESS))	; forwarded from value cell
	 (OR (DOLIST (SYM A-MEMORY-LOCATION-NAMES)
	       (AND (= (%POINTER LOC) (%P-LDB-OFFSET %%Q-POINTER SYM 1)) (RETURN SYM)))
	     (DOLIST (SYM M-MEMORY-LOCATION-NAMES)
	       (AND (= (%POINTER LOC) (%P-LDB-OFFSET %%Q-POINTER SYM 1)) (RETURN SYM)))
	     LOC))
	((AND (SYMBOLP (SETQ SYM (%FIND-STRUCTURE-HEADER LOC)))	;Regular symbol's
	      (= (%POINTER-DIFFERENCE LOC SYM) 1))		; internal value-cell
	 SYM)
	(T LOC)))						;not a symbol

;;; Find the value of a symbol in the binding environment of a specified stack group.
;;; Note that this cannot get an error even if the sg is in some funny state, unlike
;;; SG-EVAL.  Don't call this if the stack-group could be running in another process
;;; and thus changing its state.  If the variable is unbound, the first value is NIL.
;;; The second value is th elocation of the binding, or NIL if there is none.
;;; If FRAME is specified, we get the value visible in that frame.
(DEFUN SYMEVAL-IN-STACK-GROUP (SYM SG &OPTIONAL FRAME)
  (DECLARE (RETURN-LIST VALUE LOCATION))
  (IF (EQ SG %CURRENT-STACK-GROUP)
      (SYMEVAL SYM)
      ;ELSE
      (DO-NAMED RESULT
		((VCL (VALUE-CELL-LOCATION SYM))
		 (SP (SG-SPECIAL-PDL SG))
		 (SPP (OR (AND FRAME (SG-NEXT-INTERESTING-ACTIVE SG FRAME)
			       (SG-FRAME-SPECIAL-PDL-INDEX
				 SG (SG-NEXT-INTERESTING-ACTIVE SG FRAME)))
			  (SG-SPECIAL-PDL-POINTER SG))))
		()
	(OR (ZEROP (SG-IN-SWAPPED-STATE SG))	;If its bindings are swapped out
	    ( SPP 0)
	    (DO ((I SPP (1- I))			;then search through them
		 (P))
		(( I 0))
	      (SETQ P (ALOC-CAREFUL SP I))
	      (SELECT (%P-DATA-TYPE P)
		(DTP-LOCATIVE			;If this is a binding pair
		 (SETQ P (%MAKE-POINTER-OFFSET DTP-LOCATIVE P -1))
		 (IF (EQ (AREF SP I) VCL)	;and is for this variable, then return
		     (IF (LOCATIVE-BOUNDP P)	;the saved value, invz'ing if necc
			 (RETURN-FROM RESULT (CAR P) P)
			 (RETURN-FROM RESULT NIL NIL))
		     (SETQ I (1- I))))		;Space over second Q of binding pair
		(OTHERWISE ))))			;Ignore non-binding blocks
	;; The variable isn't bound in that stack group, so we want its global value.
	;; Must ignore bindings in our own stack group.
	(SETQ SP (SG-SPECIAL-PDL %CURRENT-STACK-GROUP)
	      SPP (GET-OWN-SPECIAL-PDL-POINTER SP))
	(LET ((LOCATION (AND (BOUNDP SYM) (LOCF (SYMEVAL SYM)))))
	  (DO ((VAL (AND LOCATION (SYMEVAL SYM)))
	       (I SPP (1- I))
	       (P))
	      (( I 0) (RETURN-FROM RESULT VAL LOCATION))
	    (SETQ P (ALOC-CAREFUL SP I))
	    (SELECT (%P-DATA-TYPE P)
	      (DTP-LOCATIVE
	       (SETQ P (%MAKE-POINTER-OFFSET DTP-LOCATIVE P -1))
	       (COND ((EQ (AREF SP I) VCL)
		      (SETQ LOCATION (AND (LOCATIVE-BOUNDP P) P))
		      (SETQ VAL (AND LOCATION (CAR P)))))
	       (SETQ I (1- I)))
	      (OTHERWISE )))))))

;;; Not a fully general SET-IN-STACK-GROUP, this quite deliberately only allows
;;; you to change the value of a binding extant in that stack group, not the
;;; global value.  Returns T if it succeeds, NIL if it fails.
;;; Don't call this if the stack-group could be running in another process
;;; and thus changing its state.
(DEFUN REBIND-IN-STACK-GROUP (SYM VALUE SG)
  (LET ((VCL (VALUE-CELL-LOCATION SYM))
	(SP (SG-SPECIAL-PDL SG))
	(SPP (SG-SPECIAL-PDL-POINTER SG)))
    (COND ((EQ SG %CURRENT-STACK-GROUP) (SET SYM VALUE) T)
	  ((OR (ZEROP (SG-IN-SWAPPED-STATE SG)) ( SPP 0)) NIL)	;Abnormal binding state
	  (T (DO ((I SPP (1- I))		;Search through bindings
		  (P))
		 (( I 0))
	       (SETQ P (ALOC-CAREFUL SP I))
	       (SELECT (%P-DATA-TYPE P)
		 (DTP-LOCATIVE			;If this is a binding pair
		  (SETQ P (%MAKE-POINTER-OFFSET DTP-LOCATIVE P -1))
		  (COND ((EQ (AREF SP I) VCL)	; and is for this variable, then win.
			 (RPLACA P VALUE)	;RPLACA invz's if necessary
			 (RETURN T)))
		  (SETQ I (1- I)))		;Space over second Q of binding pair
		(OTHERWISE )))))))		;Ignore non-binding blocks

(DEFUN USE-COLD-LOAD-STREAM (STRING)
  (SETQ TERMINAL-IO TV:COLD-LOAD-STREAM)
  (FUNCALL TERMINAL-IO ':HOME-CURSOR)
  (FUNCALL TERMINAL-IO ':CLEAR-EOL)
  (FORMAT TERMINAL-IO "--> ~A, using the cold load stream <--~2%" STRING))

(DEFMACRO PRINT-CAREFULLY (TYPE &BODY BODY)
  `(MULTIPLE-VALUE-BIND (NIL .ERROR.)
       (CATCH-ERROR (PROGN . ,BODY) NIL)
     (COND (.ERROR.
	    (MULTIPLE-VALUE (NIL .ERROR.)
	      (CATCH-ERROR (FORMAT T "<<Error printing ~A>>" ,TYPE) NIL))
	    (IF .ERROR. (USE-COLD-LOAD-STREAM (FORMAT NIL "<<Error printing ~A>>" ,TYPE)))))))

;; Various initialization routines.

(DEFUN ASSURE-TABLE-LOADED (&AUX (IBASE 8) (BASE 8))
  (COND ((NOT (= MICROCODE-ERROR-TABLE-VERSION-NUMBER %MICROCODE-VERSION-NUMBER))
	 (LOAD-ERROR-TABLE)
	 (OR (= MICROCODE-ERROR-TABLE-VERSION-NUMBER %MICROCODE-VERSION-NUMBER)
	     (BREAK 'CANNOT-GET-ERROR-TABLE T)))))

(DEFUN LOAD-ERROR-TABLE (&AUX LOGIN-HOST)
  (STORE (SYSTEM-COMMUNICATION-AREA %SYS-COM-DESIRED-MICROCODE-VERSION)
	 %MICROCODE-VERSION-NUMBER)
  (COND ((OR (NULL USER-ID) (STRING-EQUAL USER-ID ""))
	 (SETQ LOGIN-HOST (FUNCALL (FS:GET-PATHNAME-HOST "SYS") ':HOST))
	 (LOGIN "LISPM" LOGIN-HOST NIL)))
  (LOAD (FUNCALL (FS:PARSE-PATHNAME "SYS: UBIN; UCADR")
		 ':NEW-TYPE-AND-VERSION "TBL" %MICROCODE-VERSION-NUMBER)
	"EH")
  (AND LOGIN-HOST (LOGOUT)))

;; Divides up MICROCODE-ERROR-TABLE into CALLS-SUB-LIST, RESTART-LIST, and ERROR-TABLE.
(DEFUN ASSURE-TABLE-PROCESSED ()
  (COND ((NOT (= MICROCODE-ERROR-TABLE-VERSION-NUMBER ERROR-TABLE-NUMBER))
	 (SETQ ERROR-TABLE NIL
	       CALLS-SUB-LIST NIL
	       RESTART-LIST NIL
	       STACK-WORDS-PUSHED-LIST NIL
	       ARG-POPPED-LIST NIL
	       DEFAULT-ARG-LOCATIONS-LIST NIL)
	 (DO ET MICROCODE-ERROR-TABLE (CDR ET) (NULL ET)
	     (SELECTQ (CADAR ET)
	       (RESTART (PUSH (CONS (CADDAR ET) (1+ (CAAR ET))) RESTART-LIST))
	       (CALLS-SUB (PUSH (CONS (CAAR ET) (CADDAR ET)) CALLS-SUB-LIST))
	       (ARG-POPPED (PUSH (CONS (CAAR ET) (CDDAR ET)) ARG-POPPED-LIST))
	       (DEFAULT-ARG-LOCATIONS (PUSH (CDDAR ET) DEFAULT-ARG-LOCATIONS-LIST))
	       (STACK-WORDS-PUSHED
		(PUSH (CONS (CAAR ET) (CADDAR ET)) STACK-WORDS-PUSHED-LIST))
	       (OTHERWISE (PUSH (CAR ET) ERROR-TABLE))))
	 (SETQ BEGIN-QARYR (OR (CDR (ASSQ 'BEGIN-QARYR RESTART-LIST)) 0)
	       END-QARYR (OR (CDR (ASSQ 'END-QARYR RESTART-LIST)) 0)
	       ERROR-TABLE-NUMBER MICROCODE-ERROR-TABLE-VERSION-NUMBER))))

;; Call this when it is apparent that some hacker set things up wrong.
(DEFUN BAD-HACKER (&REST ARGS)
  (FORMAT T "~%~%Foo, a hacker has screwn up somewhere.  Error:~%")
  (DO AL ARGS (CDR AL) (NULL AL) (PRINC (CAR AL)) (TYO #\SP))
  (TERPRI) (TERPRI))

;; Turn on error trapping mode.
(DEFUN ENABLE-TRAPPING (&OPTIONAL (X 1))
  (SETQ %MODE-FLAGS (DPB X %%M-FLAGS-TRAP-ENABLE %MODE-FLAGS)))

(DEFUN TRAPPING-ENABLED-P NIL 
  (NOT (ZEROP (LDB %%M-FLAGS-TRAP-ENABLE %MODE-FLAGS))))

(DEFUN P-PRIN1-CAREFUL (LOCATIVE &AUX)
  (LET ((DTP (Q-DATA-TYPES (%P-DATA-TYPE LOCATIVE))))
    (COND ((MEMQ DTP GOOD-DATA-TYPES)
	   (PRINT-CAREFULLY "printing" (PRIN1 (CAR LOCATIVE))))
	  (T (FORMAT T "#<~A ~O>" DTP (%P-POINTER LOCATIVE))))))

;; Initialize the error handler at warm boot time.
(ADD-INITIALIZATION "ERROR-HANDLER-INITIALIZE" '(INITIALIZE) '(WARM))

;;; Waiting until the first error to do these things loses
;;; because they let other processes run, which could get errors and crash the machine.
(DEFUN INITIALIZE ()
  (SETQ ERROR-HANDLER-RUNNING NIL)
  (SETQ ERRSET-STATUS NIL)		;Set to T if an errset exists and should be obeyed
  (ASSURE-TABLE-LOADED)			;Gets the right UCONS/UCADR TABLE file loaded.
  (ASSURE-TABLE-PROCESSED)		;Processes the contents of UCONS/UCADR TABLE.
  )

;; This is the function that runs in the first level error handler
;; It is called only at boot time.  From then on it just keeps coroutining.
(DEFUN LISP-ERROR-HANDLER (&AUX M SG SG2 ETE CONDITION (INHIBIT-SCHEDULING-FLAG T))
  ;; Return to boot code.  We are called back by the first error.
  (SETQ M (STACK-GROUP-RESUME %CURRENT-STACK-GROUP-PREVIOUS-STACK-GROUP NIL))
  (DO ((ERRSET-FLAG NIL NIL)	;These must be reinitialized each time through the loop!
       (ERRSET-PRINT-MSG NIL NIL))
      (NIL)			;Do forever, once for each error
    (SETQ SG %CURRENT-STACK-GROUP-PREVIOUS-STACK-GROUP)
    (ASSURE-DISPATCH-SET-UP)	;Set up command dispatch table.
    ;; Compute and store the ETE for this error.
    (SETF (SG-TRAP-TAG SG)
	  (SETQ ETE (OR M (CDR (ASSQ (SG-TRAP-MICRO-PC SG) ERROR-TABLE)))))
    (SETF (SG-PROCESSING-ERROR-FLAG SG) 0) ;Re-enable error trapping in that SG
    (SETF (SG-INST-DISP SG) 0)	;Turn off single-step mode (for foothold)
    (SETQ CONDITION (GET (CAR ETE) 'SIGNAL))
    (AND CONDITION (SETQ CONDITION (FUNCALL CONDITION SG ETE)))
    ;; Every error should signal SOMETHING, except for a few specific exceptions.
    (OR CONDITION
	(EQ (CAR ETE) 'FERROR)
	(SETQ CONDITION `(:ERROR . ,ETE)))
    ;; All branches of this COND must end in resuming some other SG.
    (SETQ M
	  (COND ((AND (EQ (CAR ETE) 'STEP-BREAK)
		      (SETQ SG2 (CDR (ASSQ SG SG-STEPPING-TABLE))))
		 (SETF (SG-CURRENT-STATE SG) SG-STATE-RESUMABLE)
		 (FUNCALL SG2 SG))
		((EQ (CAR ETE) 'RESUME-FOOTHOLD)
		 (SG-RESTORE-STATE SG 1)
		 (SETF (SG-CURRENT-STATE SG) SG-STATE-RESUMABLE)
		 (STACK-GROUP-RESUME SG NIL))
		((AND (NOT (MEMQ (CAR ETE) ERRSET-INVISIBLE-ETES))
		      (NOT (AND (EQ (CAR ETE) 'FERROR)
				(MEMQ (CADR ETE) ERRSET-INVISIBLE-CONDITIONS)))
		      (NOT (SYMEVAL-IN-STACK-GROUP 'ERRSET SG))
		      (SETQ ERRSET-FLAG (SYMEVAL-IN-STACK-GROUP 'ERRSET-STATUS SG))
		      (NOT (SETQ ERRSET-PRINT-MSG
				 (SYMEVAL-IN-STACK-GROUP 'ERRSET-PRINT-MSG SG)))
		      (NOT (AND CONDITION (SG-CONDITION-HANDLED-P SG (CAR CONDITION)))))
		 ;; If we are in an errset, and don't want the message, throw now.
		 (SG-THROW SG 'ERRSET-CATCH NIL T))
		(T
		 ;; Otherwise, obtain a second level error handler sg
		 ;; and tell it what to work on.
		 (SETQ SG2 (OR (POP FREE-SECOND-LEVEL-ERROR-HANDLER-SG-LIST)
			       (MAKE-STACK-GROUP
				 (FORMAT NIL "SECOND-LEVEL-ERROR-HANDLER-~D"
					 (SETQ SECOND-LEVEL-ERROR-HANDLER-COUNT
					       (1+ SECOND-LEVEL-ERROR-HANDLER-COUNT)))
				 ':SAFE 0)))
		 (STACK-GROUP-PRESET SG2 'SECOND-LEVEL-ERROR-HANDLER
				     SG M ERRSET-FLAG ERRSET-PRINT-MSG CONDITION
				     (COND ((EQ SG SI:SCHEDULER-STACK-GROUP)
					    "Error in the scheduler")
					   ((AND (BOUNDP 'TV:KBD-PROCESS)
						 (EQ SG (PROCESS-STACK-GROUP TV:KBD-PROCESS)))
					    "Error in the keyboard process")
					   ((AND (BOUNDP 'TV:MOUSE-PROCESS)
						 (EQ SG (PROCESS-STACK-GROUP TV:MOUSE-PROCESS)))
					    "Error in the mouse process")))
		 (FUNCALL SG2))))))

;; Invoke the error handler to look at a particular stack group.
;; A window or process may also be supplied, and a stack group found from it.
;; Supplying NIL means find a process which is waiting to be looked at.
;; If a process is supplied or known, it is arrested while we are invoked.
;; This works differently from real errors; it just runs the error handler
;; in the same stack group and process that EH is called in
;; ERROR-HANDLER-RUNNING is NOT set.
;; The catch tag EXIT is used to return from EH.
(DEFUN EH (&OPTIONAL PROCESS
	   &AUX PKG SG ARREST-REASON
		ORIGINAL-FRAME CURRENT-FRAME INNERMOST-VISIBLE-FRAME
		INNERMOST-FRAME-IS-INTERESTING
		CONDITION-PROCEED-VALUE CONDITION-PROCEED-FLAG
		(ERROR-HANDLER-RUNNING NIL))
  (AND (NULL PROCESS)
       (SETQ PROCESS (TV:FIND-PROCESS-IN-ERROR)))
  (COND ((NULL PROCESS) "cannot find a process")
	(T
	 ;; If arg is a window or stream, extract process from it.
	 (OR (TYPEP PROCESS ':STACK-GROUP) (TYPEP PROCESS 'SI:PROCESS)
	     (SETQ PROCESS (FUNCALL PROCESS ':PROCESS)))
	 ;; If arg is process or was converted to one, stop it.
	 (COND ((TYPEP PROCESS 'SI:PROCESS)
		(FUNCALL PROCESS ':ARREST-REASON CURRENT-PROCESS)
		(SETQ ARREST-REASON CURRENT-PROCESS)
		(SETQ SG (PROCESS-STACK-GROUP PROCESS)))
	       (T (SETQ SG PROCESS PROCESS NIL)))
	 (OR (TYPEP SG ':STACK-GROUP) (FERROR NIL "~S not a stack group" SG))
	 (SETQ INNERMOST-VISIBLE-FRAME (SG-AP SG))
	 (SETQ ORIGINAL-FRAME INNERMOST-VISIBLE-FRAME)
	 (SETQ CURRENT-FRAME (SG-OUT-TO-INTERESTING-ACTIVE SG ORIGINAL-FRAME))
	 ;; Although we get the package each time around the r-e-p loop, we must get it
	 ;; here as well, so that when the error message is printed it will be in the
	 ;; right package.
	 (SETQ PKG (SYMEVAL-IN-STACK-GROUP 'PACKAGE SG))
	 (UNWIND-PROTECT
	   (*CATCH 'QUIT
	     (*CATCH 'SYS:COMMAND-LEVEL
	       (PKG-BIND (IF (EQ (TYPEP PKG) 'PACKAGE) PKG "USER")
		 (PRINT-CAREFULLY "frame"
		   (FORMAT T "~&~S  Backtrace: " SG)
		   (SHORT-BACKTRACE SG NIL 3)
		   (SHOW-FUNCTION-AND-ARGS SG)))))
	   (*CATCH 'EXIT (COMMAND-LOOP SG (SG-TRAP-TAG SG))))
	 (AND ARREST-REASON (FUNCALL PROCESS ':REVOKE-ARREST-REASON ARREST-REASON)))))

;; What CURRENT-PROCESS was at entry to SECOND-LEVEL-ERROR-HANDLER
;; which may have bound it to NIL.
(DEFVAR REAL-CURRENT-PROCESS)
(DEFVAR ERRSET-INSIDE-ERROR NIL)	;Setting this to T allows debugging inside EH
					;by disabling the error handler's own ERRSETs
 
;This is a list of variables whose values are to be inherited from the stack group
;in error by portions of the error handler inside an INHERITING-VARIABLES-FROM special
;form.  Each element can be just a variable, or a list of the variable and a
;validate function, which receives the value as its argument and returns either
;the same value or a corrected value if it doesn't like that one.
(DEFVAR *INHERITED-VARIABLES*
    '((PACKAGE VALIDATE-PACKAGE)
      (READTABLE VALIDATE-READTABLE)
      (BASE VALIDATE-BASE)
      (IBASE VALIDATE-BASE)
      *NOPOINT))

(DEFMACRO INHERITING-VARIABLES-FROM ((SG) &BODY BODY)
  `(PROG ((.L. *INHERITED-VARIABLES*) .VAR. .VAL.)
     LP (SETQ .VAR. (IF (ATOM (CAR .L.)) (CAR .L.) (CAAR .L.))
	      .VAL. (SYMEVAL-IN-STACK-GROUP .VAR. ,SG))
	(BIND (VALUE-CELL-LOCATION .VAR.)
	      (IF (ATOM (CAR .L.)) .VAL. (FUNCALL (CADAR .L.) .VAL.)))
	(OR (ATOM (SETQ .L. (CDR .L.))) (GO LP))
	(RETURN (PROGN . ,BODY))))

(DEFUN VALIDATE-PACKAGE (P)
  (IF (TYPEP P 'PACKAGE) P SI:PKG-USER-PACKAGE))

(DEFUN VALIDATE-BASE (B)
  (IF (MEMQ B '(8 10.)) B 8))		;These are the only reasonable bases for debugging

(DEFUN VALIDATE-READTABLE (R)
  (IF (EQ (TYPEP R) 'READTABLE) R SI:INITIAL-READTABLE))

;; This is the function at the top level in each second level error handler sg.
(DEFUN SECOND-LEVEL-ERROR-HANDLER (SG M ERRSET-FLAG ERRSET-PRINT-MSG CONDITION MSG
				   &AUX (ERRSET ERRSET-INSIDE-ERROR)
					(PACKAGE SI:PKG-USER-PACKAGE)
					(INHIBIT-SCHEDULING-FLAG
					  (EQUAL MSG "Error in the scheduler"))
					(ERROR-HANDLER-RUNNING T)
					(ERROR-HANDLER-REPRINT-ERROR T)
					(ETE (SG-TRAP-TAG SG)) BREAK-FLAG
					(TERMINAL-IO (OR ERROR-HANDLER-IO
							 (SYMEVAL-IN-STACK-GROUP
							   'TERMINAL-IO SG)
							 TV:COLD-LOAD-STREAM))
					(STANDARD-INPUT SI:SYN-TERMINAL-IO)
					(STANDARD-OUTPUT SI:SYN-TERMINAL-IO)
					(QUERY-IO SI:SYN-TERMINAL-IO)
					;; In case we want to set CURRENT-PROCESS to nil.
					(CURRENT-PROCESS CURRENT-PROCESS)
					;; And some things will wonder what it had been.
					(REAL-CURRENT-PROCESS CURRENT-PROCESS)
					ORIGINAL-FRAME CURRENT-FRAME
					INNERMOST-VISIBLE-FRAME INNERMOST-FRAME-IS-INTERESTING
					CONDITION-PROCEED-VALUE CONDITION-PROCEED-FLAG)
  (IF (MEMQ (CAR M) '(FERROR :BREAK))		;Get rid of call to error-handler sg
      (LET ((RP (SG-REGULAR-PDL SG)) (AP (SG-AP SG)) (TT (SG-TRAP-TAG SG)))
	(IF (NEQ (AREF RP AP) %ERROR-HANDLER-STACK-GROUP)
	    (FERROR NIL "%ERROR-HANDLER-STACK-GROUP not found on pdl where expected"))
	(IF ( (RP-DESTINATION RP AP) 0)	;D-IGNORE
	    (FERROR NIL "%ERROR-HANDLER-STACK-GROUP called with bad destination"))
	(IF ( (SG-REGULAR-PDL-POINTER SG) (1+ AP))
	    (FERROR NIL "%ERROR-HANDLER-STACK-GROUP called with wrong number of args"))
	(SETF (SG-IPMARK SG) (SG-PREVIOUS-OPEN SG AP))
	(SETF (SG-AP SG) (SETQ AP (SG-PREVIOUS-ACTIVE SG AP)))
	(SETF (SG-FLAGS-QBBFL SG)		;Must correspond to current frame to work!
	      (RP-BINDING-BLOCK-PUSHED RP AP))
	(DOTIMES (I 5)				;Pop p3zero, function, and arg
	  (SG-REGPDL-POP SG))
	;; Now, if current frame is a foothold, restore to the previous state.  This will
	;; normally be the case for :BREAK
	(IF (EQ (AREF RP AP) #'FOOTHOLD) (SG-RESTORE-STATE SG 0))
	(SETF (SG-TRAP-TAG SG) TT)))
  ;; These catches are so that quitting out of the condition handler restores the
  ;; normal flow of the error handler rather than quitting out of the whole program.
  (*CATCH 'QUIT
    (*CATCH 'SYS:COMMAND-LEVEL
      ;; If we have a condition to signal, do so (in the debugged stack group)
      ;; and maybe return or restart if it says so.
      (AND CONDITION
	   (LET ((CONDITION-PROCEED-FLAG T)
		 (TRAP-ON-CALL (SG-FLAGS-TRAP-ON-CALL SG))
		 CONDITION-PROCEED-VALUE CONDITION-RESULT)
	     (SETF (SG-FLAGS-TRAP-ON-CALL SG) 0)
	     (UNWIND-PROTECT
	       (SETQ CONDITION-RESULT (SG-APPLY SG #'SIGNAL CONDITION))
	       (SETF (SG-FLAGS-TRAP-ON-CALL SG) TRAP-ON-CALL))
	     (COND ((EQ (CAR CONDITION-RESULT) 'RETURN)
		    (SETQ CONDITION-PROCEED-VALUE (CADR CONDITION-RESULT))
		    (COM-PROCEED SG ETE))
		   ((EQ (CAR CONDITION-RESULT) 'ERROR-RESTART)
		    (COM-ERROR-RESTART SG ETE))
		   ((EQ (CAR CONDITION-RESULT) 'RETURN-VALUE)
		    (SG-UNWIND-TO-FRAME SG (SG-AP SG) T (CADR CONDITION-RESULT))))))))
  ;; If non-printing errset, throw to it once condition is processed.
  (AND ERRSET-FLAG (NOT ERRSET-PRINT-MSG)
       (SG-THROW SG 'ERRSET-CATCH NIL))
  ;; Otherwise, decide whether to break or to go to top level.
  (SETQ BREAK-FLAG (SG-BREAK-P SG ETE CONDITION))
  (SETQ INNERMOST-VISIBLE-FRAME (SG-AP SG))
  (SETQ ORIGINAL-FRAME INNERMOST-VISIBLE-FRAME)
  (SETQ CURRENT-FRAME ORIGINAL-FRAME)
  (DO ((RP (SG-REGULAR-PDL SG)))
      ((NOT (LET ((F (FUNCTION-NAME (RP-FUNCTION-WORD RP CURRENT-FRAME))))
	      (AND (SYMBOLP F) (GET F ':ERROR-REPORTER)))))
    (SETQ CURRENT-FRAME (SG-PREVIOUS-ACTIVE SG CURRENT-FRAME)))
  (SETQ CURRENT-FRAME (SG-OUT-TO-INTERESTING-ACTIVE SG CURRENT-FRAME))
  (AND MSG (USE-COLD-LOAD-STREAM MSG))
  ;; If not running in the scheduler, give us a run reason in case we died after
  ;; becoming inactive, before getting back to the scheduler.
  (OR (NULL CURRENT-PROCESS)
      (FUNCALL CURRENT-PROCESS ':RUN-REASON %CURRENT-STACK-GROUP))
  ;; Try to see if TERMINAL-IO is reasonable and if not fix it.
  ;; Don't do this if being caught by an errset, since only going to print,
  ;; not going to do anything interactive.
  (IF (NOT ERRSET-FLAG)
      (LET ((WO (ERRSET (FUNCALL TERMINAL-IO ':WHICH-OPERATIONS) NIL))
	    (ERROR-HANDLER-REPRINT-ERROR NIL))
	(IF (NULL WO) (USE-COLD-LOAD-STREAM "TERMINAL-IO clobbered")
	    (COND ((MEMQ ':NOTICE (CAR WO))
		   (LET (;; :NOTICE can change TERMINAL-IO of a background process
			 (OLD-TIO TERMINAL-IO)
			 ;; Send this message in non-erring stack
			 (WINDOW-BAD (FUNCALL TERMINAL-IO ':NOTICE ':ERROR)))
		     (IF (NEQ TERMINAL-IO OLD-TIO)
			 (SG-FUNCALL SG #'SET 'TERMINAL-IO TERMINAL-IO))
		     (IF (EQ WINDOW-BAD 'TV:COLD-LOAD-STREAM)
			 (USE-COLD-LOAD-STREAM "window-system problems"))))))))
  ;; These catches are so that quitting out of the printing of the error message
  ;; or out of the special commands leaves you in the error handler at its
  ;; normal command level rather than quitting out of the whole program.
  (*CATCH 'QUIT
    (*CATCH 'SYS:COMMAND-LEVEL
      ;; Print the error message, using appropriate package, base, etc.
      (INHERITING-VARIABLES-FROM (SG)
	(PRINT-CAREFULLY "error message"
	  ;; Print a brief message if not going to eh command level, else a long msg
	  (COND ((AND BREAK-FLAG (NOT ERRSET-FLAG))
		 (SHOW SG ETE)
		 (OR (EQ BASE IBASE)
		     (FORMAT T "~& Warning: BASE is ~D. but IBASE is ~D.~%" BASE IBASE)))
		(T (PRINT-ERROR-MESSAGE SG ETE T)))))
      (AND ERRSET-FLAG (SG-THROW SG 'ERRSET-CATCH NIL))
      ;; Discard type-ahead
      (FUNCALL STANDARD-INPUT ':CLEAR-INPUT)
      ;; Offer any special commands, such as wrong-package correction.
      (IF (SETQ M (GET (CAR ETE) 'OFFER-SPECIAL-COMMANDS))
	  (FUNCALL M SG ETE))))
  ;; Setting this causes the previous error to be reprinted if BREAK-FLAG is NIL
  (SETQ LAST-SECOND-LEVEL-ERROR-HANDLER-SG %CURRENT-STACK-GROUP)
  ;; If this error isn't interesting to break on,
  ;; return to previous error break loop rather than going to EH command level.
  (OR BREAK-FLAG (SG-THROW SG 'SYS:COMMAND-LEVEL NIL))
  ;;SG-TRAP-TAG is part of the state restored by SG-RESTORE-STATE in case of BREAK.
  ;;Thus, it does not win to have COMMAND-LOOP refetch it.
  (COMMAND-LOOP SG ETE))

;; Decide whether an error break loop is useful for this error.
;; It is unless the error was a simple error in the form immediately
;; typed in to the error handler (not inside any functions).
(DEFUN SG-BREAK-P (SG IGNORE CONDITION)
  (OR (NULL (SG-FOOTHOLD-DATA SG))
      (NOT (SELECTQ (CAR CONDITION)
	     (:WRONG-NUMBER-OF-ARGUMENTS
	       (EQ (LET ((FRAME (SG-PREVIOUS-ACTIVE SG (SG-PREVIOUS-ACTIVE SG (SG-AP SG))))
			 (RP (SG-REGULAR-PDL SG)))
		     (RP-FUNCTION-WORD RP FRAME))
		   #'FH-STREAM-BINDING-EVALER))
	     ((:UNDEFINED-VARIABLE :UNDEFINED-FUNCTION)
	      (EQ (LET ((FRAME (SG-PREVIOUS-ACTIVE SG (SG-AP SG)))
			(RP (SG-REGULAR-PDL SG)))
		    (RP-FUNCTION-WORD RP FRAME))
		  #'FH-STREAM-BINDING-EVALER))))))



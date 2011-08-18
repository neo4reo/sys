(COMMENT CORE 160 LIST 140000 SYMBOL 13000 FIXNUM 40000 BIGNUM 10000) ;-*-LISP-*-

;	** (c) Copyright 1980 Massachusetts Institute of Technology **

(SETQ MSGFILES (LIST TYO))  ;HIC SEZ THIS WILL DO SOMETHING USEFUL

(CRUNIT DSK LISPM)
(SSTATUS GCWHO 1)

(DEFPROP TECO (LISPT FASL DSK LIBLSP) AUTOLOAD)
(DEFPROP LEDIT (LEDIT FASL DSK LIBLSP) AUTOLOAD)
(DEFPROP FLOAD (LEDIT FASL DSK LIBLSP) AUTOLOAD)
(DEFPROP CLOAD (LEDIT FASL DSK LIBLSP) AUTOLOAD)
(DEFPROP BS (BS FASL DSK LIBLSP) AUTOLOAD)

(SETQ PURE 2)	;SUPPOSEDLY DOING THIS AND NEVER CALLING PURIFY
		;WILL CAUSE (SSTATUS UUOLINKS) TO WORK.  WHAT A CROCK!

(FASLOAD UTIL FASL)		;LOAD STUFF INCLUDING READFILE

;(LOAD '(MACROS > DSK LISPM2))	;", `, MACRO SENDING-OVER FACILITY
(SETQ MISC-INSTRUCTION-LIST NIL MISC-FUNCTION-LIST NIL) ;FOR DEFMIC

;VARIABLES THAT GET SET UP ACCORDING TO MODE:
;  COLD-LOAD, UCADR-LOAD.  OTHERWISE, QCMP MODE.
;  FOR-CADR GETS SET T IF THIS STUFF INTENDED FOR CADR. THIS SWITCH
;SHOULD AFFECT ONLY MICROASSEMBLER AND COLD-LOAD, NOT COMPILER.
(DEFUN LOAD-UP (INTERPF)
  (PROG ()
	(SETQ FOR-CADR NIL)
	(SETQ COLD-LOAD NIL)
	(SETQ UCADR-LOAD NIL)
	(COND ((ATOM INTERPF) (SETQ INTERPF (LIST INTERPF))))
	(COND ((MEMQ 'COLD-LOAD INTERPF)
	       (SETQ COLD-LOAD T)
	       (SETQ FOR-CADR T)
	       (SETQ GC-OVERFLOW '(LAMBDA (X) NIL)))
	      ((MEMQ 'QCMP INTERPF))	;LOAD QCMP IF NEITHER COLD-LOAD NOR UCADR-LOAD
	      ((MEMQ 'UCADR INTERPF)
	       (SETQ FOR-CADR T)
	       (SETQ UCADR-LOAD T))
	      (T (ERROR INTERPF 'UNKNOWN-MODE)))
	(TERPRI)	;HERE WE GO
	(COND (COLD-LOAD 
		(ALLOC '(LIST (300000 340000 0.05)   ;NEEDS 310000, ONLY MAKES A LITTLE GARBAGE
		         FIXNUM (50000 100000 0.10)  ;ONLY NEEDS 52000, BUT MAKES LOTSA GARBAGE
		         SYMBOL 14000)))	     ;REALLY ONLY NEEDS 7000
	      (UCADR-LOAD
		(ALLOC '(LIST 350000))
		(ALLOC '(FIXNUM 100000))
		(ALLOC '(BIGNUM 20000))))
	(FASLOAD (LISPM)UTIL1 FASL)
	(READFILE '((LISPM)QCOM >))
	(COND ((NOT UCADR-LOAD)
	       (FASLOAD (LISPM2)QCFILE FASL)	;FOR MEMQL & BARF ONLY, IF MAKING COLD
	       (COND ((NOT COLD-LOAD)			;ONLY WHEN BUILDING QCMP
		      (LOAD '((LISPM2)DEFMAC FASL))	;DEFMACRO
		      (READFILE '((LISPM2)LMMAC >))	;STANDARD MACROS
		      (LOAD '((LISPM2)NSTRUC FASL))	;NECESSARY TO READ IN SGDEFS
		      (READFILE '((LISPM2)SGDEFS >))	;SGFCTN USES THESE
		      (READFILE '((LMIO)TVDEFS >))
		      (FASLOAD (LISPM)QCP1 FASL)
		      (FASLOAD (LISPM)QCP2 FASL)
		       ))
	       (SETQ MACROS-TO-BE-SENT-OVER NIL)	;DON'T SEND THESE OVER AS PART OF THE
							;COLD LOAD, THEY WILL BE LOADED LATER
							;BY THE MACHINE ITSELF.
	       (FASLOAD (LISPM)UTIL2 FASL)
	       ;(FASLOAD (LIBLSP) ITER) ;?
	       (READFILE '((LISPM)QDEFS >))
	       (COND (COLD-LOAD
			(READFILE '((LISPM)COLD >))
			(FASLOAD (LISPM)COLDF FASL)
			(FASLOAD (LISPM)FROID FASL)
			(SETQ BYPASS-INTERNAL-COMPILE-FLAG T
			      ;; NOTE WELL: These files get loaded into the SI package, always
			      QFASL-FILE-LIST '(
				((LMFONT)CPTFON QFASL)
				((LISPM)QRAND QFASL)
				((LMIO)QIO QFASL)
				;((LMIO)RDTBL QFASL) ;done specially
				((LMIO)READ QFASL)
				((LMIO)PRINT QFASL)
				((LMWIN)COLD QFASL)
				((LISPM)SGFCTN QFASL)
				((LISPM)QEV QFASL)
				((LISPM)LTOP QFASL)
				((LISPM)QFASL QFASL)
				((LMIO)MINI QFASL)
				((LISPM)LFL QFASL) )) ))
	       (READFILE '((LISPM)DEFMIC >))
	       (FASLOAD (LISPM)QLF FASL)
;	       (FASLOAD (LISPM)MC FASL)		;LONG LIVE LMI ..
;	       (FASLOAD (LISPM)ULAP FASL)
	       (COND ((NULL COLD-LOAD)	;IF MAKING COMPILER
		      (FASLOAD (LISPM)FASD FASL) ))
	       (LOADUP-FINALIZE))
	      (UCADR-LOAD
	        (FASLOAD (LISPM)CADRLP FASL)
		(FASLOAD (LISPM) CDMP FASL)
		(FASLOAD (LCADR)WMCR FASL)
		(READFILE '((LISPM)DEFMIC >))   ;TO GET QLVAL S FOR MISC INSTRUCTIONS.
		(READFILE '((DSK LMCONS)CADREG >))
		(READFILE '((DSK LISPM)CADSYM >)) )
  )

	(SETQ ^W NIL)
	(COND ((AND (NOT COLD-LOAD) (NOT UCADR-LOAD))	 ;MAKING A QCMP
	       (SETQ MACROS-TO-BE-SENT-OVER NIL) ;DON'T SEND STANDARD MACROS 
	       (SETQ COMPILING-FOR-LISPM T)	 ; AS PART OF EVERY QFASL FILE!
						 ;THEY WILL GET INTO THE MACHINE SOMEHOW
	       (PDUMP)))
	(RETURN 'READY)))

(DEFUN DEFVAR MACRO (X) (RPLACA X 'SETQ))	;UP YOURS, NIL
(DEFUN LET MACRO (X)
  (CONS (LIST* 'LAMBDA (MAPCAR 'CAR (CADR X)) (CDDR X))
	(MAPCAR 'CADR (CADR X))))

(PROGN
 (SETQ ^W NIL)
 (PRINT 
    '(DESIRED-FUNCTION? (QCMP OR COLD-LOAD OR UCADR)))
 (PRINT '-->)
 (LOAD-UP (READ))
 (COND (UCADR-LOAD 
	(ASSEMBLE '(UCADR > DSK LCADR)))
       (COLD-LOAD  
	(PRINT '(TEST-MAKE-COLD))
	(TEST-MAKE-COLD))
       (T 'READY)))
;HAD BETTER NOT BE ANYTHING AFTER THIS OR THE READ WILL LOSE.
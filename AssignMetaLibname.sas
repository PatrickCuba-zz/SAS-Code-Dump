DATA LIBMAC_ERR_LOOKUP;
	INFILE CARDS DSD DLM=',' TRUNCOVER;
	INPUT ERROR : $10.
          DESC  : $34.;
	CARDS;
LIBNAME, NO LIBNAME PROVIDED
ENGINE, Unable to Locate Libname Engine
PORT, Unable to locate Port Number
HOST, Unable to locate Host
SCHEMA, Unable to locate Schema Name
DISCONNECT, Unable to locate DISCONNECT value
IP, Unable to locate IP value
USERID, Unable to locate USER ID
PASSWORD, Unable to locate Password
;


%MACRO ASSIGNMETALIBNAME(LIB=);
* For testing Purposes ... ;
	%let IOMServer      = %nrquote(stbe905a);
	%let metaPort       = %nrquote(19561);
	%let metaServer     = %nrquote(crxsashpdb02);
	%let metaRepository = %nrquote(Foundation);

	options metaport       = &metaPort 
	        metaserver     = "&metaServer" 
	        metarepository = "&metaRepository";

	* FETCH CURRENT LOG DISPLAY SETTINGS... ;
	%LET NOTES = %SYSFUNC(GETOPTION(NOTES));
	%LET MPRINT = %SYSFUNC(GETOPTION(MPRINT));
	%LET MLOGIC = %SYSFUNC(GETOPTION(MLOGIC));
	%LET SYMBOLGEN = %SYSFUNC(GETOPTION(SYMBOLGEN));

	%LET metaPort = %SYSFUNC(GETOPTION(metaPort));
	%LET metaServer = %SYSFUNC(GETOPTION(metaServer));
	%LET metaRepository = %SYSFUNC(GETOPTION(metaRepository));
	%let IOMServer = %SYSFUNC(GETOPTION(IOMServer));

	%PUT METAPORT: &metaPort.;
	%PUT metaServer: &metaServer.;
	%PUT metaRepository: &metaRepository.;
	%PUT IOMServer: &IOMServer.;

	%LET ___ENGINE=;
	%LET ___SCHEMA=;
	%LET ___ID=;
	%LET ___PW=;
	%LET ___HOST=;
	%LET ___PORT=;
	%LET ___DISCONNECT=;
	%LET ___IP=;

	* ERROR TRAPPING ;
	DATA FMT1(KEEP=START LABEL FMTNAME) 
	     FMT2(KEEP=START1 LABEL FMTNAME RENAME=START1=START);
		SET LIBMAC_ERR_LOOKUP;
		LENGTH LABEL $34. FMTNAME $10.;
		START=2**(_N_-1);
		FMTNAME='_LMACERRN';
		LABEL=ERROR;
		OUTPUT FMT1;

		START1=ERROR;
		LABEL=DESC;
		FMTNAME='$_LMACERRC';
		OUTPUT FMT2;
		CALL SYMPUT('__NUM', _N_);
	RUN;

	PROC FORMAT CNTLIN=FMT1;
	PROC FORMAT CNTLIN=FMT2;
	QUIT;

	PROC DATASETS LIB=WORK NOLIST NODETAILS;
		DELETE FMT1 FMT2;
	QUIT;

	* DISPLAY NOTHING FROM THIS MACRO ;
	OPTIONS NONOTES NOMPRINT NOMLOGIC NOSYMBOLGEN;

	DATA _NULL_;
		LENGTH LIBURI LIBRARY LIBENGINE LIBNAME LIBSCHEMA LIBSCHEMAURI LIBSCHEMANAME HOSTURI 
               CONNPROPS HOSTNAME HOSTPROPS PROPURI HOSTNAME AUTHNAME AUTHURI CONNURI CONNNAME 
               CONPROPURI CONPROPNAME DISCONNECT IP LOGINURI USERID PASSWORD $256;
		N=1;
		RC=1;
		DO WHILE (RC > 0);
			* GO TO THE SASLIBRARY AND ITERATE DOWN THE LIST UNTIL LIBRARY IS FOUND                  ;
	        N+1;
			RC = METADATA_GETNOBJ("omsobj:SASLibrary?@Id contains '.'", N, LIBURI); 
			IF RC>0 THEN RC=METADATA_GETATTR(LIBURI,"Libref",LIBRARY); * FETCH LIBRARY NAME          ;
			IF UPCASE(COMPRESS(LIBRARY)) = "&LIB." THEN DO;            * MATCH                       ;
				RC=METADATA_GETATTR(LIBURI,"Engine",LIBENGINE);        * GET ATTRIBUTES              ;
				RC=METADATA_GETATTR(LIBURI,"Name",LIBNAME);            * NAME AND ENGINE             ;
				I=0;
				DO UNTIL(RC<0);
					I+1;
	            	RC=METADATA_GETNASL(LIBURI,I,LIBSCHEMA);           * NAVIGATE ASSOCIATIONS       ;
					IF LIBSCHEMA="UsingPackages" THEN DO;
						J=0;
						DO UNTIL(RC1<0);
							J+1;                                       * SCHEMA                      ;
			            	RC1=METADATA_GETNASN(LIBURI,LIBSCHEMA,J,LIBSCHEMAURI); 
							RC1=METADATA_GETATTR(LIBSCHEMAURI,"SchemaName",LIBSCHEMANAME);
							RC1=-4;
						END;						
						RC1=-4;
					END;

					IF LIBSCHEMA="UsingPrototype" THEN DO;             * NAVIGATE AND GET CONNECTION ;
						V=0;                                           * AND IP                      ;
						DO UNTIL(RC9<0);
							V+1;                                       * SCHEMA                      ;
			            	RC8=METADATA_GETNASN(LIBURI,LIBSCHEMA,V,CONNURI); 
							RC9=METADATA_GETNASL(CONNURI,V,CONNNAME); 
							IF CONNNAME="Properties" THEN DO;
								W=0;
								DO UNTIL(RC10<0);
									W+1;                               * DISCONNECT VALUE            ;
									RC10=METADATA_GETNASN(CONNURI,CONNNAME,W,CONPROPURI); 
									RC11=METADATA_GETNASL(CONPROPURI,W,CONPROPNAME); 
									IF CONPROPNAME = "ExternalIdentities" THEN DO;
										DO UNTIL(RC12<0);
											RC12=METADATA_GETATTR(CONPROPURI,"DefaultValue",DISCONNECT); 
											RC12=-4;
										END;
									END;                               * IP                          ;
									IF CONPROPNAME = "Extensions" THEN DO; 
										DO UNTIL(RC13<0);
											RC13=METADATA_GETATTR(CONPROPURI,"DefaultValue",IP); 
											RC13=-4;
										END;
									END;
								END;
							END;
						END;						
					END;

					IF LIBSCHEMA="LibraryConnection" THEN DO;          * NAVIGATE AND GET HOST, PORT ;
						M=0;                                           * AUTHENTICATION DOMAIN       ;
						DO UNTIL(RC2<0);
							M+1;
			            	RC2=METADATA_GETNASN(LIBURI,LIBSCHEMA,M,HOSTURI); 
							N=0;
							DO UNTIL(RC3<0);
								N+1;
				            	RC3=METADATA_GETNASL(HOSTURI,N,HOSTPROPS); 
								IF HOSTPROPS="Properties" THEN DO;
									O=0;
									DO UNTIL(RC4<0);
										O+1;
										RC4=METADATA_GETNASN(HOSTURI,HOSTPROPS,O,PROPURI); 
										RC5=METADATA_GETATTR(PROPURI,"DefaultValue",HOSTNAME); 
										IF COMPRESS(HOSTNAME, "'")*1^=. THEN PORTNUM=COMPRESS(HOSTNAME,"'");
										ELSE HOST=COMPRESS(HOSTNAME,"'");
										_ERROR_=0;
									END;
								END;
								IF HOSTPROPS="Domain" THEN DO;
									P=0;
									DO UNTIL(RC6<0);
										P+1;
										RC6=METADATA_GETNASN(HOSTURI,HOSTPROPS,P,AUTHURI); 
										RC7=METADATA_GETATTR(AUTHURI,"Name",AUTHNAME); 
									END;
								END;
							END;
							RC2=METADATA_GETATTR(HOSTURI,"Properties",HOSTNAME); 
							RC2=-4;
						END;
					END;
				END;
			END;
			ELSE RC=1; 
		END;

		* USE THE AUTHENTICATION DOMAIN TO FETCH USER & PWD ;
		RC14 = METADATA_GETNASN(AUTHURI, "Logins", 1, LOGINURI); 
	    IF RC14 > 0 THEN DO;
	        RC15 = METADATA_GETATTR(LOGINURI, "UserID", USERID); 
	        RC16 = METADATA_GETATTR(LOGINURI, "Password", PASSWORD); 
        END;

		* ERROR CHECK ;
		X=0;
		IF LIBNAME='' THEN X+1;
		IF LIBENGINE='' THEN X+2;
		IF PORTNUM='' THEN X+4;
		IF HOST='' THEN X+8;
		IF LIBSCHEMANAME='' THEN X+16;
		IF DISCONNECT='' THEN X+32;
		IF IP='' THEN X+64;
	    IF USERID='' THEN X+128;
	    IF PASSWORD='' THEN X+256;

		VAL=X;
		NUM=&__NUM.;
		DO UNTIL(VAL=0 OR NUM=0);
		    MAX=2**(NUM-1);
			IF MAX<=VAL THEN DO;
				VAL=SUM(VAL, -1*MAX);
				Y=PUT(PUT(MAX, _LMACERRN.), $_LMACERRC.);
				PUT 'ERROR: ' Y;
			END;
			NUM=SUM(NUM,-1);
		END;

		CALL SYMPUT('___ENGINE', COMPRESS(LIBENGINE));
		CALL SYMPUT('___PORT', COMPRESS(PORTNUM));
		CALL SYMPUT('___HOST', COMPRESS(HOST));
		CALL SYMPUT('___SCHEMA', COMPRESS(LIBSCHEMANAME));
		CALL SYMPUT('___DISCONNECT', COMPRESS(DISCONNECT));
		CALL SYMPUT('___IP', COMPRESS(IP));
        CALL SYMPUT("___ID", COMPRESS(USERID));
        CALL SYMPUT("___PW", COMPRESS(PASSWORD));

		CALL MISSING(LIBURI, LIBRARY, LIBENGINE, LIBNAME, LIBSCHEMA, LIBSCHEMAURI, HOSTURI, 
                     CONNPROPS, HOSTNAME, HOSTPROPS, PROPURI, HOSTNAME, AUTHNAME,  LIBSCHEMANAME,
                     AUTHURI, CONNURI, CONNNAME, CONPROPURI, CONPROPNAME, DISCONNECT, IP,
                     LOGINURI, USERID, PASSWORD);
	RUN;

	* RETURN OPTIONS TO WHAT THEY WERE... ;
	OPTIONS &NOTES. &MPRINT. &MLOGIC. &SYMBOLGEN.;

	%put INFO: [retrieveCredentials] notes = &notes.;
	%put INFO: [retrieveCredentials] mprint = &mprint.;
	%put INFO: [retrieveCredentials] mlogic = &mlogic.;
	%put INFO: [retrieveCredentials] symbolgen = &symbolgen.;

	LIBNAME &LIB. &___ENGINE. DISCONNECT=&___DISCONNECT IP=&___IP SCHEMA="&___SCHEMA." USER="&___ID." PASSWORD="&___PW." HOST="&___HOST." SERV="&___PORT.";
%MEND;
%ASSIGNMETALIBNAME(LIB=COIRPDET);

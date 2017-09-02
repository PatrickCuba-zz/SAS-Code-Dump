/*************************************************************************/
/* Program : Create Connect String and Assign Library                    */
/*                                                                       */
/* Author  : Patrick Cuba                                                */
/* Date    : Dec 2016                                                    */
/*                                                                       */
/* Description :                                                         */
/* Create Connect String and Assign Library                              */
/*                                                                       */
/*************************************************************************/
/* Modification History                                                  */
/* 0.1 xxDec2016 P. Cuba - Initial Version                               */
/*************************************************************************/

%Macro ConnectString(FindLibname=);

	%Let Mprint=%Sysfunc(Getoption(Mprint));
	%Let Mlogic=%Sysfunc(Getoption(Mlogic));
	%Let SymbolGen=%Sysfunc(Getoption(SymbolGen));
	%Let MLogicNest=%Sysfunc(Getoption(MLogicNest));

	Options NoMprint NoMLogic NoSymbolgen;

	%Global ConnectString LibraryType;

	%Let Property_Max=0;
	%Let CProperty_Max=0;
	%Let AuthDomain=;
	%Let schema=;
	%Let Path=;
	%Let Engine=;

	Data _Null_;
		length liburi name libref engine isDBMS PreAssign proprc prop value 
	           Assoc_uri Connection AuthDomain conn_uri Connection Port 
			   RemoteAddress ServerShortName Service domainuri AuthDomain conn_uri upasnuri 
	           path type schema $200.;
		liburi='';
		nlibobj=0;
		librc=1;

		** Initialise attributes ;
		name='';
		engine='';
		isDBMS='';
		libref='';
		PreAssign='';
		prop='';
		value='';
		Assoc_uri='';
		AuthDomain='';
		Connection='';
		Port='';
		RemoteAddress='';
		ServerShortName='';
		Service='';
		domainuri='';
		AuthDomain='';
		conn_uri='';
		upasnuri='';

	    Do While (librc>0); *** Scan through Each Library ;
			nlibobj+1;
			librc=metadata_getnobj("omsobj:SASLibrary?@Id contains '.'",nlibobj,liburi);
			 
			 ** Attributes ** ;
		     rc=metadata_getattr(liburi,'Name',name);                
		     rc=metadata_getattr(liburi,'Engine',engine);
	         rc=metadata_getattr(liburi,'IsDBMSLibname', isDBMS);    * Is it an External Library or not ? ;
			 rc=metadata_getattr(liburi,'Libref',libref);            * Libref to Assign ;
			 rc=metadata_getattr(liburi,'IsPreassigned', PreAssign); * Assigned elsewhere - do not assign here !!! ;
		   	 rc=metadata_getattr(liburi,'Domain',AuthDomain);        * Fetch the authentication domain ;

			 If Upcase(libref) = Upcase("&FindLibname.") Then Do;                      * Search String ;
			 	
				If PreAssign=1 Then Do;
					Putlog "NOTE: Library is preassigned, no further processing... ";
					Stop;
				End;

				Call Symput('Engine', Strip(Engine));


			    n=1;
			    uprc=metadata_getnasn(liburi,'UsingPackages',n,upasnuri);
			    if uprc > 0 then do;
			       call missing(type,id,path,mdschemaname,schema);
			       rc=metadata_resolve(upasnuri,type,id);
		           if type='Directory' then do;
				      rc=metadata_getattr(upasnuri,'DirectoryName',path);

					  Call Symput('Path', '"'||Strip(path)||'"');
		              end; 
		              else if type='DatabaseSchema' then do;
		               rc=metadata_getattr(upasnuri,'Name',mdschemaname);
		               rc=metadata_getattr(upasnuri,'SchemaName',schema);

						Call Symput('schema', 'SCHEMA='||schema);

		              end; 
		            n+1;
		            uprc=metadata_getnasn(liburi,'UsingPackages',n,upasnuri);
				  end; 

				If isDBMS eq "1" Then Do;
					Putlog "NOTE: Library is a Database";
					Call Symput('LibraryType', 'DBMS');

					*** Process through the Library Properties ;
					nprop=0;
					proprc=1;
					do while(nprop < proprc); * getnprp returns the number of properties ;
						nprop+1;
						proprc=metadata_getnprp(liburi, nprop, prop, value);

						prop=Tranwrd(Tranwrd(prop, 'Library.DBMS.Property.', ''), '.Name.xmlKey.txt', '');
						If compress(prop) ne 'OtherOpt' then value=Compress(prop||'='||value);

						Call Symput(Compress('Property_'||nprop), value);
						Call Symput('Property_Max', nprop);
					end;

					*** Get Associations ;
	 				rc=metadata_getnasn(liburi, "LibraryConnection", 1, conn_uri);

				    rc= metadata_getattr(conn_uri, "Name", Connection); 
				    rc= metadata_getattr(conn_uri, "Port", Port);
				    rc= metadata_getattr(conn_uri, "RemoteAddress", RemoteAddress); 
				    rc= metadata_getattr(conn_uri, "ServerShortName", ServerShortName);
				    rc= metadata_getattr(conn_uri, "Service", Service);

			        rc2= metadata_getnasn(conn_uri, "Domain", 1, domainuri);
			        if rc2 > 0 then do;
						rc3= metadata_getattr(domainuri, "Name", AuthDomain);
						Call Symput('AuthDomain', 'AUTHDOMAIN="'||Strip(AuthDomain)||'"');		
					End;

					*** Process through the Connection Properties ;
					nprop=0;
					proprc=1;
					do while(nprop < proprc); * getnprp returns the number of properties ;
						nprop+1;
						proprc=metadata_getnprp(conn_uri, nprop, prop, value);
						if proprc then do;
							prop=Compress(substr(prop,16+Length('Property.')), '.Name.xmlKey.txt');

							Call Symput(Compress('CProperty_'||nprop), Compbl(Strip(prop)||'='||value));
							Call Symput('CProperty_Max', nprop);
						end;
					end;
				End;
				Else Do;
					PutLog "NOTE: Library is a SAS Library";
					Call Symput('LibraryType', 'BASE');
				End;
			 End;
		End;
	Run;

	%Let ConnectString=;
	%Do P1=1 %To &Property_Max.;
		%Let ConnectString=&ConnectString. &&Property_&P1. ;
	%End;
	%Let ConnectString=&ConnectString. &AuthDomain.;
	%Do P2=1 %To &CProperty_Max.;
		%Let ConnectString=&ConnectString. &&CProperty_&P2. ;
	%End;
	%Let ConnectString=&ConnectString. &schema. &Path.;

	%If &Engine.= %Then %Put NOTE: Library not found, nothing to assign ;
	%Else %Do;
		%Put NOTE: Use GLOBAL Macro variable: ConnectString for pass through queries;
		%Put NOTE: Use GLOBAL Macro LibraryType: BASE/DBMS in your code for Library Type (BASE=SAS and DBMS=Not SAS);
		%Put NOTE: LibraryType=&LibraryType.;
		%Put NOTE: Assign Libref &FindLibname.;
		Libname &FindLibname. &Engine. &ConnectString.;
	%End;
	;
 
	Options &Mprint &MLogic &Symbolgen &MLogicNest;

%mend;

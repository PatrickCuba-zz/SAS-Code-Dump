/*************************************************************************/
/* Program : Assign Metdata Lib                                          */
/*                                                                       */
/* Author  : Patrick Cuba                                                */
/* Date    : Dec 2016                                                    */
/*                                                                       */
/* Description :                                                         */
/* Assign Metdata Library                                                */
/*                                                                       */
/*************************************************************************/
/* Modification History                                                  */
/* 0.1 xxDec2016 P. Cuba - Initial Version                               */
/*************************************************************************/

%Macro AssignMetaLib(FindLibname=);
	%If &FindLibname^= %Then %Do;
		%Let AssignLibref=;

		Data _Null_;
			Length AmendedFindLibname $255.;
			FindLibname="&FindLibname.";
			_Cnt=Countw(FindLibname);
			Do _x=1 To _Cnt;
				X=Compress("'"||Scan(FindLibname, _x, ' ')||"'");
				AmendedFindLibname=Compbl(AmendedFindLibname||' '||X);
			End;
			Call Symputx('FindLibname', Upcase(AmendedFindLibname));
		Run;

		data _Null_;
		  keep name libref engine;
		  length liburi upasnuri $256 name $128 type id $17 libref engine $8 ;

		  call missing(liburi,upasnuri,name,engine,libref);

		  nlibobj=1;
		  librc=metadata_getnobj("omsobj:SASLibrary?@Id contains '.'",nlibobj,liburi);

		  /* Loop Through Metadata to find the Libref we are after */
		  do while (librc>0);

		     /* Get Library attributes */
		     rc=metadata_getattr(liburi,'Name',name);
		     rc=metadata_getattr(liburi,'Engine',engine);
			 rc=metadata_getattr(liburi,'Libref',libref);
			 
			    n=1;
			    uprc=metadata_getnasn(liburi,'UsingPackages',n,upasnuri);

			    if uprc > 0 then do;
			       call missing(type,id);
			       rc=metadata_resolve(upasnuri,type,id);

				 	If Upcase(libref) in (&FindLibname.) Then Do;
						  Cmd=CompBL('Libname '||libref||' META Library="'||Strip(Name)||'" Metaout=DATAREG;');
						  Cnt+1;
						  Call Symput(Compress('AssignLibref_'||Cnt),Cmd);
						  Call Symput('Max_Assign', Cnt);
					End;

		            n+1;
		            uprc=metadata_getnasn(liburi,'UsingPackages',n,upasnuri);
				  end; /* if uprc > 0 */

			 nlibobj+1;
		     librc=metadata_getnobj("omsobj:SASLibrary?@Id contains '.'",nlibobj,liburi);
		  end; /* do while (librc>0) */
		run;

		%Do ___Y =1 %To &Max_Assign.;
			%If &&AssignLibref_&___Y.= %Then %Do;
				%Put WARNING: Libref &FindLibname. Not Found in Metadata;
			%End;
			%Else %Do;
				&&AssignLibref_&___Y.;
			%End;
		%End;
	%End;
	%Else %Do;
		%Put WARNING: Unable to assign library, Specify FindLibname= clause;
	%End;

%Mend;

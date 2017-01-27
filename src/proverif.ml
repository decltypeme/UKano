(*************************************************************
 *                                                           *
 *  UKano                                                    *
 *                                                           *
 *  Lucca Hirschi                                            *
 *                                                           *
 *  Copyright (C) Lucca Hirschi 2015-2017                    *
 *                                                           *
 *************************************************************)

open Unix
open Printf
      
(* This is only for printing purpose. *)
let log s = printf "%s\n" s
let logError s = printf "[ERROR] %s\n" s; exit(0)
let header = "##############################"

	       
(***********************************************************)
(*               PARSING PROVERIF                          *)
(***********************************************************)
(* Possible outputs *)
let result = "RESULT"
let okEquivalence = "RESULT Observational equivalence is true (bad not derivable)."
let noEquivalence = "RESULT Observational equivalence cannot be proved (bad derivable)."
let okQuery = "true"
let noQuery = "false"

let parseQueryAnswer s =
  let err _ = logError "ProVerif was not found or ProVerif crashed. Please puruse manually (launch ProVerif on generated files)." in
  let regexpIs = Str.regexp_string "is" in
  let last = String.length s in
  try let isPresent = Str.search_backward regexpIs s last in (* last position of "is" *)
      let isBeforeFalse _ =
	try
	  let falsePresent = Str.search_backward
			       (Str.regexp_string noQuery)
			       s last in (* last position of "true" *)
	  if falsePresent > isPresent
	  then false       (* 'false' after last 'is' -> NO *)
	  else err ()
	with Not_found -> err () (* no 'true' nor 'false' *)
      in
      try
	let truePresent = Str.search_backward
			    (Str.regexp_string okQuery)
			    s last in (* last position of "true" *)
	if truePresent > isPresent
	then true	   (* 'true' after last 'is' -> OK *)
	else isBeforeFalse () (* no 'true' after the last 'is', maybe 'false ? *)
      with Not_found ->  isBeforeFalse ()  (* no 'true', maybe 'false' ? *)
  with Not_found -> err ()	(* no 'is' *)


(***********************************************************)
(*               BASIC IO                                  *)
(***********************************************************)
       
(* Run a command and return its results as a list of strings,
   one per line. *)
let read_process_lines command =
  let lines = ref [] in
  let in_channel = Unix.open_process_in command in
  begin
    try
      while true do
	lines := input_line in_channel :: !lines
      done;
    with End_of_file ->
      ignore (Unix.close_process_in in_channel)
  end;
  List.rev !lines
	   
let launchProverif pathProverif pathFile =
  let command = sprintf "%s -in pitype %s" pathProverif pathFile in
  log command;
  read_process_lines command

  
let verifyBoth pathProverif sFO sWA namesId =
  let establishedFO = ref false in
  let establishedWA = ref false in
  let establishedWAPart = ref false in
  log (header^" VERIFICATION OF FRAME OPACITY "^header);
  log (sprintf "We now launch Proverif (path: '%s') on '%s' to verify Frame Opacity ..." pathProverif sFO);
  let outputFO = launchProverif pathProverif sFO in
  if List.length outputFO = 0
  then logError "ProVerif was not found or ProVerif crashed. Please puruse manually (launch ProVerif on generated files)."
  else begin
      log "[...]";
      let regexpResult = Str.regexp_string result in
      let subResults = List.filter (fun l -> Str.string_match regexpResult l 0) outputFO in
      List.iter (fun l -> log l) subResults;
      let okFO = (List.length subResults == 1) && ((=) okEquivalence (List.hd subResults)) in
      let noFO = (List.length subResults == 1) && ((=) noEquivalence (List.hd subResults)) in
      if okFO
      then begin
	  establishedFO := true;
	  log "\n===> Frame Opacity has been established.";
	end
      else (if noFO
	    then log "\n===> Frame Opacity could not be established."
	    else logError "Proverif's output could not be parsed. Please pursue manually (launch ProVerif on the generated files).")
    end;

  log ("\n"^header^" VERIFICATION OF WELL-AUTHENTICATION "^header);
  log (sprintf "We now launch Proverif (path: '%s') on '%s' to verify Well-Authentication ..." pathProverif sWA);
  let outputWA = launchProverif pathProverif sWA in
  if List.length outputWA = 0
  then logError "ProVerif was not found or ProVerif crashed. Please puruse manually (launch ProVerif on generated files)."
  else begin
      log "[...]";
      let regexpResult = Str.regexp_string result in
      let subResults = List.filter (fun l -> Str.string_match regexpResult l 0) outputWA in
      List.iter (fun l -> log l) subResults;
      let subOk = List.filter (fun l -> parseQueryAnswer l) subResults in
      let subNo = List.filter (fun l -> not(parseQueryAnswer l)) subResults in
      let okWA = (List.length subResults == List.length subOk) in
      let noWA = (List.length subOk == 0) in
      if (List.length subResults == 0)
      then logError "Proverif's output could not be parsed. Please pursue manually (launch ProVerif on the generated files)."
      else (if okWA
	    then begin
		establishedWA := true;
		log "\n===> Well Authentication has been established.";
	      end
	    else begin
		log (sprintf "\n===> Well Authentication has been established for %d over %d tests.
			      Please verify that the following queries correspond to safe conditionals."
			     (List.length subOk) (List.length subResults));
		List.iter (fun l -> log ("Well-Athentication could not be established for : "^l)) subNo;
	      end);
    end;
  
  log ("\n"^header^" CONCLUSION "^header);
  if !establishedFO && (!establishedWA || !establishedWAPart)
  then begin
      if not(!establishedWA)
      then log "===> Frame Opacity and Well-Authentication have been established (providing the conditionals listed above are safe)."
      else log "===> Frame Opacity and Well-Authentication have been established.";
      if List.length namesId == 0
      then log "\n===========> Therefore, the input protocol ensures Unlinkability."
      else let strNames = String.concat "," namesId in
	   log (sprintf "\n===========> Therefore, the input protocol ensures Unlinkability and Anonymity w.r.t. identity names %s." strNames);
    end
  else log "===> Frame Opacity or Well-Authentication could not be established. This does not necessarily implies that the input protocol
	    violates unlinkability or anonymity.\n\t1. Indeed, it may be the case that ProVerif could not established the conditions
	    (due to over-approximations) while they actually hold --- in that case, please refer to the ProVerif's manual. \n\t2. Or the
	    conditions do not hold. In that case, UKano cannot currently conclude on your protocol. If you think that is the case, please
	    send your input protocol at lucca.hirschi@lsv.ens-cachan.fr so that we can investigate further and improve UKano."

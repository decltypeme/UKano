(*************************************************************
 *                                                           *
 *  UKano                                                    *
 *                                                           *
 *  Lucca Hirschi                                            *
 *                                                           *
 *  Copyright (C) Lucca Hirschi 2015-2017                    *
 *                                                           *
 *************************************************************)

(*

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details (in file LICENSE).

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

 *)
open Types
open Parsing_helper

let gc = ref false
let out_file = ref ""
let out_n = ref 0
let pathProverif = ref "./proverif"
		       
(* This is only for debugging purpose. *)
let log s = Display.Text.print_string s;Display.Text.newline()

(* Helping message *)
let helpMess = 			(* TODO *)
  ("Only typed ProVerif files are accepted (the option '-in pitype' is enabled by default). See the folder './examples/' for examples\n"^
     "of files in the correct format. They can be used to bootsrap your own file. For more details, see the README file at the root of\n"^
       "the project.\n")
let welcomeMess =
  "UKano 0.1. Cryptographic privacy verifier, by Lucca Hirschi. Based on Proverif 1.91, by Bruno Blanchet and Vincent Cheval."
    
(*********************************************
                 Interface
 **********************************************) 

let display_process p biproc =
  incr Param.process_number;
  let text_bi,text_bi_maj = 
    if biproc
    then "bi","Bip"
    else "","P" in
  
  Display.Text.print_string (text_bi_maj^"rocess "^(string_of_int !Param.process_number)^":\n");
  Display.Text.display_process_occ "" p;
  Display.Text.newline()


(*********************************************
               Analyser
 **********************************************)     
		      
let first_file = ref true

let anal_file s =
  if (s = "help" || s="") then begin Printf.printf "Error, you should enter a filename.\n%s\n" (Ukano.helpMess); exit(0); end;
  if not (!first_file) then
    Parsing_helper.user_error "Error: You can analyze a single ProVerif file for each run of UKano.\nPlease rerun UKano with your second file.\n";
  first_file := false;

  let p0, second_p0 = Pitsyntax.parse_file s in
  
  let p0 =
    if !Param.move_new then
      Pitransl.move_new p0
    else p0 in
  
  (* Compute reductions rules from equations *)
  TermsEq.record_eqs_with_destr();
  
  (* Check if destructors are deterministic *)
  Destructor.check_deterministic !Pitsyntax.destructors_check_deterministic;
  
  (* Display the original processes *)
  let p = Simplify.prepare_process p0 in
  Pitsyntax.set_need_vars_in_names();
  incr Param.process_number;
  print_string "Process:\n";
  Display.Text.display_process_occ "" p;
  Display.Text.newline();

  
  (* Compute filename for the two produced ProVerif files *)
  let fileNameC1, fileNameC2 =
    try let splitDot = (Str.split (Str.regexp_string ".") s) in
	let prefix =
	  if List.length splitDot = 1
	  then List.hd splitDot
	  else  String.concat "." (List.rev (List.tl (List.rev splitDot))) in
	let prefixRel = if prefix.[0] = '/' then "."^prefix else prefix in
	(prefixRel^"_FOpa.pi", prefixRel^"_WAuth.pi")
    with _ -> ("OUTPUT_FOpa.pi","OUTPUT_WAuth.pi") in
  (* Compute and create the two ProVerif files checking the two conditions *)
  Ukano.transBoth p s fileNameC1 fileNameC2;
  (* Verify the conditions using ProVerif *)
  Proverif.verifyBoth (!pathProverif) fileNameC1 fileNameC2 []


(********************)
(* Handling options *)
(********************)
let _ =
  Arg.parse
    [ "-gc", Arg.Set gc, 
      "\t\t\tdisplay gc statistics (optional)";
      "--help",  Arg.Unit (fun () -> Printf.printf "%s\n" helpMess),
      "\t\tprint help message";
      "--proverif",  Arg.String (fun path -> pathProverif := path),
      "\t\tpath of the ProVerif executable to use (optional, default: './proverif')"
    ]
    anal_file welcomeMess;
  if !gc then Gc.print_stat stdout

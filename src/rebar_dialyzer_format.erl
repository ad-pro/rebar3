-module(rebar_dialyzer_format).

-export([format/1, bad_arg/2]).

-define(NR, "\033[0;31m").
-define(NG, "\033[0;32m").
-define(NB, "\033[0;34m").
-define(NW, "\033[0;37m").
-define(BR, "\033[1;31m").
-define(BG, "\033[1;32m").
-define(BB, "\033[1;34m").
-define(BW, "\033[1;37m").
-define(R,  "\033[0m").

format(Warning) ->
    Str = try
              format_warning(Warning, fullpath)
          catch
              _:_ ->
                  dialyzer:format_warning(Warning, fullpath)
          end,
    case strip(Str) of
        ":0: " ++ Unknown ->
            Unknown;
        Warning1 ->
            Warning1
    end.

strip(Warning) ->
    string:strip(Warning, right, $\n).

%%format(Fmt, Args) ->
%%    Args2 = [format("~s\033[1;37m", [A]) || A <- Args],
%%    format(Fmt, Args2).

format(Fmt, Args) ->
    io_lib:format(lists:flatten(Fmt ++ ?R), Args).


%% Mostrly from: https://github.com/erlware/erlware_commons/blob/49bc69e35a282bde4a0a6a8f211b5f77d8585256/src/ec_cmd_log.erl#L220
%%colorize(Color, Msg) when is_integer(Color) ->
%%    colorize(Color, false, Msg).

%% colorize(Color, false, Msg) when is_integer(Color) ->
%%     lists:flatten(format("\033[~B;~Bm~s\033[0m", [0, Color, Msg]));
%% colorize(Color, true, Msg) when is_integer(Color) ->
%%     lists:flatten(format("\033[~B;~Bm~s\033[0m", [1, Color, Msg])).


%%bw(M) ->
%%    colorize(37, true, M).

%% Based on: https://github.com/erlang/otp/blob/a2670f0822fc6729df956c8ec8c381340ff0a5fb/lib/dialyzer/src/dialyzer.erl#L290

format_warning({Tag, {File, Line, _MFA}, Msg}, FOpt) ->
    format_warning({Tag, {File, Line}, Msg}, FOpt);
format_warning({_Tag, {File, Line}, Msg}, FOpt) when is_list(File),
                                                     is_integer(Line) ->
    F = case FOpt of
            fullpath -> re:replace(File, "^.*/_build/", "_build/");
            basename -> filename:basename(File)
        end,
    String = lists:flatten(message_to_string(Msg)),
    lists:flatten(format("~s:~w~n~s", [F, Line, String])).


%%-----------------------------------------------------------------------------
%% Message classification and pretty-printing below. Messages appear in
%% categories and in more or less alphabetical ordering within each category.
%%-----------------------------------------------------------------------------

%%----- Warnings for general discrepancies ----------------
message_to_string({apply, [Args, ArgNs, FailReason,
                           SigArgs, SigRet, Contract]}) ->
    format(?BW"Fun application with arguments "?R"~s ",
           [bad_arg(ArgNs, Args)]) ++
        call_or_apply_to_string(ArgNs, FailReason, SigArgs, SigRet, Contract);
message_to_string({app_call, [M, F, Args, Culprit, ExpectedType, FoundType]}) ->
    format(?BW "The call" ?R " ~s:~s~s " ?BW "requires that"
           ?R " ~s " ?BW "is of type " ?NG "~s" ?BW " not " ?NR "~s"
           ?R "\n",
           [M, F, Args, Culprit, ExpectedType, FoundType]);
message_to_string({bin_construction, [Culprit, Size, Seg, Type]}) ->
    format(?BW "Binary construction will fail since the"?NB" ~s "?BW"field"?R
           " ~s"?BW" in segment"?R" ~s"?BW" has type"?R" ~s\n",
           [Culprit, Size, Seg, Type]);
message_to_string({call, [M, F, Args, ArgNs, FailReason,
                          SigArgs, SigRet, Contract]}) ->
    format(?BW "The call" ?R " ~w:~w~s ", [M, F, bad_arg(ArgNs, Args)]) ++
        call_or_apply_to_string(ArgNs, FailReason, SigArgs, SigRet, Contract);
message_to_string({call_to_missing, [M, F, A]}) ->
    format(?BW"Call to missing or unexported function "?R"~w:~w/~w\n",
           [M, F, A]);
message_to_string({exact_eq, [Type1, Op, Type2]}) ->
    format(?BW"The test "?R"~s ~s ~s"?BW" can never evaluate to 'true'\n",
           [Type1, Op, Type2]);
message_to_string({fun_app_args, [Args, Type]}) ->
    format(?BW"Fun application with arguments "?R"~s"?BW" will fail"
           " since the function has type "?R"~s\n", [Args, Type]);
message_to_string({fun_app_no_fun, [Op, Type, Arity]}) ->
    format(?BW"Fun application will fail since "?R"~s "?BW"::"?R" ~s"
           " is not a function of arity "?R"~w\n", [Op, Type, Arity]);
message_to_string({guard_fail, []}) ->
    ?BW "Clause guard cannot succeed.\n" ?R;
message_to_string({guard_fail, [Arg1, Infix, Arg2]}) ->
    format(?BW "Guard test "?R"~s ~s ~s"?BW" can never succeed\n",
           [Arg1, Infix, Arg2]);
message_to_string({neg_guard_fail, [Arg1, Infix, Arg2]}) ->
    format(?BW "Guard test not("?R"~s ~s ~s"?BW") can never succeed\n",
           [Arg1, Infix, Arg2]);
message_to_string({guard_fail, [Guard, Args]}) ->
    format(?BW "Guard test "?R"~w~s"?BW" can never succeed\n",
           [Guard, Args]);
message_to_string({neg_guard_fail, [Guard, Args]}) ->
    format(?BW"Guard test not("?R"~w~s"?BW") can never succeed\n",
           [Guard, Args]);
message_to_string({guard_fail_pat, [Pat, Type]}) ->
    format(?BW"Clause guard cannot succeed. The "?R"~s"?BW" was matched"
           " against the type "?R"~s\n", [Pat, Type]);
message_to_string({improper_list_constr, [TlType]}) ->
    format(?BW "Cons will produce an improper list"
           " since its "?NB"2"?R"nd"?BW" argument is"?R" ~s\n", [TlType]);
message_to_string({no_return, [Type|Name]}) ->
    NameString =
        case Name of
            [] -> ?BW "The created fun ";
            [F, A] -> format(?BW "Function " ?NR "~w/~w ", [F, A])
        end,
    case Type of
        no_match -> NameString ++ ?BW "has no clauses that will ever match\n" ?R;
        only_explicit -> NameString ++ ?BW "only terminates with explicit exception\n" ?R;
        only_normal -> NameString ++ ?BW "has no local return\n" ?R;
        both -> NameString ++ ?BW "has no local return\n" ?R
    end;
message_to_string({record_constr, [RecConstr, FieldDiffs]}) ->
    format(?BW"Record construction "?R"~s"?BW" violates the"
           " declared type of field "?R"~s\n", [RecConstr, FieldDiffs]);
message_to_string({record_constr, [Name, Field, Type]}) ->
    format(?BW"Record construction violates the declared type for "?R"#~w{}" ?BW
           " since "?R"~s"?BW" cannot be of type "?R"~s\n",
           [Name, Field, Type]);
message_to_string({record_matching, [String, Name]}) ->
    format(?BW"The "?R"~s"?BW" violates the"
           " declared type for "?R"#~w{}\n", [String, Name]);
message_to_string({record_match, [Pat, Type]}) ->
    format(?BW"Matching of "?R"~s"?BW" tagged with a record name violates the"
           " declared type of "?R"~s\n", [Pat, Type]);
message_to_string({pattern_match, [Pat, Type]}) ->
    format(?BW"The ~s"?BW" can never match the type "?NG"~s\n",
           [bad_pat(Pat), Type]);
message_to_string({pattern_match_cov, [Pat, Type]}) ->
    format(?BW "The ~s"?BW" can never match since previous"
           " clauses completely covered the type "?NG"~s\n",
           [bad_pat(Pat), Type]);
message_to_string({unmatched_return, [Type]}) ->
    format(?BW "Expression produces a value of type "?R"~s"?BW","
           " but this value is unmatched\n", [Type]);
message_to_string({unused_fun, [F, A]}) ->
    format(?BW "Function "?NR"~w/~w"?BW" will never be called\n", [F, A]);
%%----- Warnings for specs and contracts -------------------
message_to_string({contract_diff, [M, F, _A, Contract, Sig]}) ->
    format(?BW"Type specification "?R"~w:~w~s"?BW
           " is not equal to the success typing: "?R"~w:~w~s\n",
           [M, F, Contract, M, F, Sig]);
message_to_string({contract_subtype, [M, F, _A, Contract, Sig]}) ->
    format(?BW"Type specification "?R"~w:~w~s"?BW
           " is a subtype of the success typing: "?R"~w:~w~s\n",
           [M, F, Contract, M, F, Sig]);
message_to_string({contract_supertype, [M, F, _A, Contract, Sig]}) ->
    format(?BW"Type specification "?R"~w:~w~s"?BW
           " is a supertype of the success typing: "?R"~w:~w~s\n",
           [M, F, Contract, M, F, Sig]);
message_to_string({contract_range, [Contract, M, F, ArgStrings, Line, CRet]}) ->
    format(?BW"The contract "?R"~w:~w~s"?BW" cannot be right because the"
           " inferred return for "?R"~w~s"?BW" on line "?R"~w"?BW" is "?R"~s\n",
           [M, F, Contract, F, ArgStrings, Line, CRet]);
message_to_string({invalid_contract, [M, F, A, Sig]}) ->
    format(?BW "Invalid type specification for function" ?R " ~w:~w/~w."
           ?BW " The success typing is" ?R " ~s\n", [M, F, A, Sig]);
message_to_string({extra_range, [M, F, A, ExtraRanges, SigRange]}) ->
    format(?BW"The specification for "?R"~w:~w/~w"?BW" states that the function"
           " might also return "?R"~s"?BW" but the inferred return is "?R"~s\n",
           [M, F, A, ExtraRanges, SigRange]);
message_to_string({overlapping_contract, [M, F, A]}) ->
    format(?BW"Overloaded contract for "?R"~w:~w/~w"?BW" has overlapping"
           " domains; such contracts are currently unsupported and are simply "
           "ignored\n", [M, F, A]);
message_to_string({spec_missing_fun, [M, F, A]}) ->
    format(?BW"Contract for function that does not exist: "?R"~w:~w/~w\n",
           [M, F, A]);
%%----- Warnings for opaque type violations -------------------
message_to_string({call_with_opaque, [M, F, Args, ArgNs, ExpArgs]}) ->
    format(?BW"The call "?R"~w:~w~s"?BW" contains "?R"~s"?BW" when "?R"~s\n",
           [M, F, Args, form_positions(ArgNs), form_expected(ExpArgs)]);
message_to_string({call_without_opaque, [M, F, Args, [{N,_,_}|_] = ExpectedTriples]}) ->
    format([?BW, "The call", ?R, " ~w:~w~s ", ?BW, "does not have" ?R " ~s\n"],
           [M, F, bad_arg(N, Args), form_expected_without_opaque(ExpectedTriples)]);
message_to_string({opaque_eq, [Type, _Op, OpaqueType]}) ->
    format(?BW"Attempt to test for equality between a term of type "?R"~s"?BW
           " and a term of opaque type "?R"~s\n", [Type, OpaqueType]);
message_to_string({opaque_guard, [Arg1, Infix, Arg2, ArgNs]}) ->
    format(?BW"Guard test "?R"~s ~s ~s"?BW" contains "?R"~s\n",
           [Arg1, Infix, Arg2, form_positions(ArgNs)]);
message_to_string({opaque_guard, [Guard, Args]}) ->
    format(?BW"Guard test "?R"~w~s"?BW" breaks the opaqueness of its"
           " argument\n", [Guard, Args]);
message_to_string({opaque_match, [Pat, OpaqueType, OpaqueTerm]}) ->
    Term = if OpaqueType =:= OpaqueTerm -> "the term";
              true -> OpaqueTerm
           end,
    format(?BW"The attempt to match a term of type "?R"~s"?BW" against the"
           ?R" ~s"?BW" breaks the opaqueness of "?R"~s\n",
           [OpaqueType, Pat, Term]);
message_to_string({opaque_neq, [Type, _Op, OpaqueType]}) ->
    format(?BW"Attempt to test for inequality between a term of type "?R"~s"
           ?BW" and a term of opaque type "?R"~s\n", [Type, OpaqueType]);
message_to_string({opaque_type_test, [Fun, Args, Arg, ArgType]}) ->
    format(?BW"The type test "?R"~s~s"?BW" breaks the opaqueness of the term "
           ?R"~s~s\n", [Fun, Args, Arg, ArgType]);
message_to_string({opaque_size, [SizeType, Size]}) ->
    format(?BW"The size "?R"~s"?BW" breaks the opaqueness of "?R"~s\n",
           [SizeType, Size]);
message_to_string({opaque_call, [M, F, Args, Culprit, OpaqueType]}) ->
    format(?BW"The call "?R"~s:~s~s"?BW" breaks the opaqueness of the term"?R
           " ~s :: ~s\n", [M, F, Args, Culprit, OpaqueType]);
%%----- Warnings for concurrency errors --------------------
message_to_string({race_condition, [M, F, Args, Reason]}) ->
    format(?BW"The call "?R"~w:~w~s ~s\n", [M, F, Args, Reason]);
%%----- Warnings for behaviour errors --------------------
message_to_string({callback_type_mismatch, [B, F, A, ST, CT]}) ->
    format(?BW"The inferred return type of"?R" ~w/~w (~s) "?BW
           "has nothing in common with"?R" ~s, "?BW"which is the expected"
           " return type for the callback of"?R" ~w "?BW"behaviour\n",
           [F, A, ST, CT, B]);
message_to_string({callback_arg_type_mismatch, [B, F, A, N, ST, CT]}) ->
    format(?BW"The inferred type for the"?R" ~s "?BW"argument of"?R
           " ~w/~w (~s) "?BW"is not a supertype of"?R" ~s"?BW", which is"
           "expected type for this argument in the callback of the"?R" ~w "
           ?BW"behaviour\n",
           [ordinal(N), F, A, ST, CT, B]);
message_to_string({callback_spec_type_mismatch, [B, F, A, ST, CT]}) ->
    format(?BW"The return type "?R"~s"?BW" in the specification of "?R
           "~w/~w"?BW" is not a subtype of "?R"~s"?BW", which is the expected"
           " return type for the callback of "?R"~w"?BW" behaviour\n",
           [ST, F, A, CT, B]);
message_to_string({callback_spec_arg_type_mismatch, [B, F, A, N, ST, CT]}) ->
    format(?BW"The specified type for the "?R"~s"?BW" argument of "?R
           "~w/~w (~s)"?BW" is not a supertype of "?R"~s"?BW", which is"
           " expected type for this argument in the callback of the "?R"~w"
           ?BW" behaviour\n", [ordinal(N), F, A, ST, CT, B]);
message_to_string({callback_missing, [B, F, A]}) ->
    format(?BW"Undefined callback function "?R"~w/~w"?BW" (behaviour " ?R
           "'~w'"?BW")\n",[F, A, B]);
message_to_string({callback_info_missing, [B]}) ->
    format(?BW "Callback info about the " ?NR "~w" ?BW
           " behaviour is not available\n" ?R, [B]);
%%----- Warnings for unknown functions, types, and behaviours -------------
message_to_string({unknown_type, {M, F, A}}) ->
    format(?BW"Unknown type "?NR"~w:~w/~w", [M, F, A]);
message_to_string({unknown_function, {M, F, A}}) ->
    format(?BW"Unknown function "?NR"~w:~w/~w", [M, F, A]);
message_to_string({unknown_behaviour, B}) ->
    format(?BW"Unknown behaviour "?NR"~w", [B]).

%%-----------------------------------------------------------------------------
%% Auxiliary functions below
%%-----------------------------------------------------------------------------

call_or_apply_to_string(ArgNs, FailReason, SigArgs, SigRet,
                        {IsOverloaded, Contract}) ->
    PositionString = form_position_string(ArgNs),
    case FailReason of
        only_sig ->
            case ArgNs =:= [] of
                true ->
                    %% We do not know which argument(s) caused the failure
                    format(?BW "will never return since the success typing arguments"
                            " are " ?R "~s\n", [SigArgs]);
                false ->
                    format(?BW "will never return since it differs in the" ?R
                           " ~s " ?BW "argument from the success typing"
                           " arguments:" ?R " ~s\n",
                           [PositionString, good_arg(ArgNs, SigArgs)])
            end;
        only_contract ->
            case (ArgNs =:= []) orelse IsOverloaded of
                true ->
                    %% We do not know which arguments caused the failure
                    format(?BW "breaks the contract"?R" ~s\n", [Contract]);
                false ->
                    format(?BW "breaks the contract"?R" ~s "?BW"in the"?R
                           " ~s "?BW"argument\n",
                           [good_arg(ArgNs, Contract), PositionString])
            end;
        both ->
            format(?BW "will never return since the success typing is "
                   ?R"~s "?BW"->"?R" ~s " ?BW"and the contract is "?R"~s\n",
                   [good_arg(ArgNs, SigArgs), SigRet,
                    good_arg(ArgNs, Contract)])
    end.

form_positions(ArgNs) ->
    case ArgNs of
        [_] -> "an opaque term as ";
        [_,_|_] -> "opaque terms as "
    end ++ form_position_string(ArgNs) ++
        case ArgNs of
            [_] -> " argument";
            [_,_|_] -> " arguments"
        end.

%% We know which positions N are to blame;
%% the list of triples will never be empty.
form_expected_without_opaque([{N, T, TStr}]) ->
    case erl_types:t_is_opaque(T) of
        true  ->
            format([?BW, "an opaque term of type", ?NG, " ~s ", ?BW, "as "], [TStr]);
        false ->
            format([?BW, "a term of type ", ?NG, "~s ", ?BW, "(with opaque subterms) as "], [TStr])
    end ++ form_position_string([N]) ++ ?BW ++ " argument" ++ ?R;
form_expected_without_opaque(ExpectedTriples) -> %% TODO: can do much better here
    {ArgNs, _Ts, _TStrs} = lists:unzip3(ExpectedTriples),
    "opaque terms as " ++ form_position_string(ArgNs) ++ " arguments".

form_expected(ExpectedArgs) ->
    case ExpectedArgs of
        [T] ->
            TS = erl_types:t_to_string(T),
            case erl_types:t_is_opaque(T) of
                true  -> format("an opaque term of type ~s is expected", [TS]);
                false -> format("a structured term of type ~s is expected", [TS])
            end;
        [_,_|_] -> "terms of different types are expected in these positions"
    end.

form_position_string(ArgNs) ->
    case ArgNs of
        [] -> "";
        [N1] -> ordinal(N1);
        [_,_|_] ->
            [Last|Prevs] = lists:reverse(ArgNs),
            ", " ++ Head = lists:flatten([format(", ~s",[ordinal(N)]) ||
                                             N <- lists:reverse(Prevs)]),
            Head ++ " and " ++ ordinal(Last)
    end.

ordinal(1) -> ?BB ++ "1" ++ ?R ++ "st";
ordinal(2) -> ?BB ++ "2" ++ ?R ++ "nd";
ordinal(3) -> ?BB ++ "3" ++ ?R ++ "rd";
ordinal(N) when is_integer(N) -> format(?BB ++ "~w" ++ ?R ++ "th", [N]).


bad_pat("pattern " ++ P) ->
    "pattern " ?NR ++ P ++ ?R;
bad_pat("variable " ++ P) ->
    "variable " ?NR ++ P ++ ?R;
bad_pat(P) ->
    "pattern " ?NR ++ P ++ ?R.


bad_arg(N, Args) ->
    color_arg(N, ?NR, Args).

good_arg(N, Args) ->
    color_arg(N, ?NG, Args).
color_arg(N, C, Args) when is_integer(N) ->
    color_arg([N], C, Args);
color_arg(Ns, C, Args) ->
    Args1 = seperate_args(Args),
    Args2 = highlight(Ns, 1, C, Args1),
    join_args(Args2).


highlight([], _N, _C, Rest) ->
    Rest;

highlight([N | Nr], N, C, [Arg | Rest]) ->
    [[C, Arg, ?R] | highlight(Nr, N+1, C, Rest)];

highlight(Ns, N, C, [Arg | Rest]) ->
    [Arg | highlight(Ns, N + 1, C, Rest)].

%% highlight([], _N, _C, Rest) ->
%%     [[?NG, A, ?R] || A <- Rest];

%% highlight([N | Nr], N, C, [Arg | Rest]) ->
%%     [[?NR, Arg, ?R] | highlight(Nr, N+1, C, Rest)];

%% highlight(Ns, N, C, [Arg | Rest]) ->
%%     [[?NG, Arg, ?R] | highlight(Ns, N + 1, C, Rest)].

seperate_args([$( | S]) ->
    seperate_args([], S, "", []).



%% We strip this space since dialyzer is inconsistant in adding or not adding 
%% it ....
seperate_args([], [$,, $\s | R], Arg, Args) ->
    seperate_args([], R, [], [lists:reverse(Arg) | Args]);

seperate_args([], [$, | R], Arg, Args) ->
    seperate_args([], R, [], [lists:reverse(Arg) | Args]);

seperate_args([], [$)], Arg, Args) ->
    lists:reverse([lists:reverse(Arg) | Args]);
seperate_args([C | D], [C | R], Arg, Args) ->
    seperate_args(D, R, [C | Arg], Args);
%% Brackets
seperate_args(D, [${ | R], Arg, Args) ->
    seperate_args([$}|D], R, [${ | Arg], Args);

seperate_args(D, [$( | R], Arg, Args) ->
    seperate_args([$)|D], R, [$( | Arg], Args);

seperate_args(D, [$[ | R], Arg, Args) ->
    seperate_args([$]|D], R, [$[ | Arg], Args);

seperate_args(D, [$< | R], Arg, Args) ->
    seperate_args([$>|D], R, [$< | Arg], Args);
%% 'strings'
seperate_args(D, [$' | R], Arg, Args) ->
    seperate_args([$'|D], R, [$' | Arg], Args);
seperate_args(D, [$" | R], Arg, Args) ->
    seperate_args([$"|D], R, [$" | Arg], Args);

seperate_args(D, [C | R], Arg, Args) ->
    seperate_args(D, R, [C | Arg], Args).

join_args(Args) ->
    [$(, string:join(Args, ", "), $)].


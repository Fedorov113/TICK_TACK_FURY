-module(server).

-define(SERVER, ?MODULE).
-define(LINK, {global, ?SERVER}).
%-behaviour(gen_server).
-export([start/0,
  who_plays/3,
  join/3,
  leave/3,
  get_field/3,
  make_turn/3,
  reset/3,
  who_won/3]).

-define(LOGIC, {global, logic}).
ct_string(json) -> "Content-type: application/json\r\n\r\n";
ct_string(text) -> "Content-type: text/plain\r\n\r\n".
%%% Некоторые функции-обработчики, которые доступны через веб-интерфейс по имени
join(SessionId, _, In) ->
  Name = http_uri:decode(In),
  Status = gen_server:call(?LOGIC, {join, Name}),
  mod_esi:deliver(SessionId,  ct_string(text) ++ atom_to_list(Status)).
%Отправка запросов на сервер осуществляется с помощью функции gen_server:call/2. При получении нового запроса будет вызвана функция handle_call:
leave(SessionId, _, In) ->
  Name = http_uri:decode(In),
  gen_server:cast(?LOGIC, {leave, Name}),
  mod_esi:deliver(SessionId, ct_string(text) ++ "ok").

get_field(SessionId, _, _) ->
  FieldItems = dict:to_list(gen_server:call(?LOGIC, {get_field})),
  ScreenedItems = lists:map(fun({{X,Y}, Value}) ->
    io_lib:format("{\"x\": ~p, \"y\": ~p, \"player\": \"~s\"}", [X, Y, Value])
  end, FieldItems),
  FieldJSON = "[" ++ string:join(ScreenedItems, ", ") ++ "]",
  mod_esi:deliver(SessionId, ct_string(json) ++ FieldJSON).

make_turn(SessionId, _, In) ->
  Request = http_uri:decode(In),
  WordsCount = string:words(Request, 47),  % 47 – это код символа «/»
  case WordsCount of
    3 ->
      Name = string:sub_word(Request, 1, 47),
      {X, _} = string:to_integer((string:sub_word(Request, 2, 47))),
      {Y, _} = string:to_integer(string:sub_word(Request, 3, 47)),
      Status = gen_server:call(?LOGIC, {make_turn, Name, X, Y}),
      mod_esi:deliver(SessionId, ct_string(text) ++ atom_to_list(Status));
    _ -> mod_esi:deliver(SessionId, ct_string(text) ++ "bad_request")
  end.

who_plays(SessionId, _,_) ->
  Players = gen_server:call(?LOGIC, {who_plays}),

  Answer = lists:map(fun(X) ->
    io_lib:format("\"~s\"", [X])
  end, Players),
  JSON = "[" ++ string:join(Answer, ",") ++ "]",
  AnswerLine = io_lib:format("{\"players\": ~s}",[JSON]),
  mod_esi:deliver(SessionId, ct_string(json) ++ AnswerLine).

who_won(SessionId,_,_) ->
  Winner = gen_server:call(?LOGIC,{who_won}),
  case Winner of
    nobody ->
      WinnerJSON = "{\"winner\":\"no\"}";
    _ -> WinnerJSON = io_lib:format("{\"winner\":\"~s\"}", [Winner])
  end,
  mod_esi:deliver(SessionId, ct_string(json) ++ WinnerJSON).

start_link() ->
  io:format("Starting logic server~n"),
  gen_server:start_link(?LINK, ?MODULE, [], []).

start() -> logic:start_link(),
  start_link().

reset(SessionID,_,_) ->
  gen_server:cast(?LOGIC,{reset}),
  mod_esi:deliver(SessionID, ct_string(text) ++ "ok").

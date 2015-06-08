-module(logic).
-behaviour(gen_server).
-export([terminate/2,
  init/1, 
  start_link/0, 
  handle_call/3, 
  handle_cast/2]).
-export([try_make_turn/4, 
  who_won/1, 
  join_game/2,
  who_plays/1, 
  check_cell/3,
  start_game/0,
  leave_game/2, 
  handle_info/2, 
  code_change/3 ]).
-record(game_state, {name_not_done=[], name_done=[], winner=no, field = dict:new()}).
%%% Реализация процесса игровой логики
%%%   start_link – запуск процесса
%%%   init – создание начального состояния
%%%   handle_call – обработка сообщений, которые требуют ответ
%%%   handle_cast – обработка сообщений, которые не требуют ответs

start_link() -> gen_server:start_link({global, logic}, ?MODULE, [], []).
init([]) ->{ ok, logic:start_game() }.
handle_call( {who_plays} , _, State) -> { reply, who_plays(State), State } ;
handle_call( {who_won} , _, State) -> {reply, who_won(State), State};
handle_call( {check_cell, X, Y}, _, State) -> {reply, check_cell(X, Y, State), State};
handle_call( {get_field}, _, State) -> {reply, State#game_state.field, State};
handle_call( {make_turn, PlayerName, X, Y}, _, State) ->
  {Status, NewState} = logic:try_make_turn(X, Y, PlayerName, State),
  {reply, Status, NewState};
handle_call( {join, Name}, _, State) ->
  {Status, NewState} = join_game(Name, State),
  {reply, Status, NewState}.
handle_cast( {reset}, _ ) -> {noreply, #game_state{}};
handle_cast( {leave, Name}, State) ->  {noreply, leave_game(Name, State)}.

who_plays(State) ->
  State#game_state.name_done ++ State#game_state.name_not_done.

who_won(State) -> State#game_state.winner.

join_game(Name, State) ->
  NameDone = State#game_state.name_done,
  Players = State#game_state.name_done ++ State#game_state.name_not_done,
  IsPlaying = lists:member(Name,Players),
  if IsPlaying == true -> {not_ok, State};
    IsPlaying /= true ->
      if NameDone == [] ->
        {ok, State#game_state{name_done = [Name]}};
        Players /= [] -> {ok, State#game_state{name_not_done = State#game_state.name_not_done ++ [Name]}}
      end
  end.

try_make_turn(X,Y,PlayerName,State) ->
  IsNameDone = lists:member(PlayerName,State#game_state.name_done),
  IsCellFree = check_cell(X,Y,State),
  if true == IsNameDone ->
    if IsCellFree == free ->
      if State#game_state.winner == no -> make_turn(X,Y,PlayerName,State);
        State#game_state.winner /= no -> {end_game,State}
      end;
      IsCellFree /= free -> {busy,State}
    end;
    true /= IsNameDone -> {not_your_turn, State}
  end.

check_cell(X, Y, State) ->
  Field = State#game_state.field,
  IsBusy = dict:find({X,Y},Field),
  if IsBusy == error -> free;
    IsBusy /= error -> ok
  end.

make_turn(X,Y,PlayerName,State) ->
  Name = PlayerName,
  Field = dict:append({X,Y},Name,State#game_state.field),
  Won = checkGame(X,Y,Name,Field),
  if Won == Name -> {end_game,State#game_state{winner = Name}};
    Won /= Name ->
      New_name_done = firstElement(State#game_state.name_not_done),
      New_name_not_done = deleteFirst(State#game_state.name_not_done),
      New = New_name_not_done++[Name],
      {no_winner,State#game_state{name_not_done = New, name_done = [New_name_done], field = Field}}
  end.

checkGame(X,Y,Name,Field) ->
  N = 5, %количество элементов в строке для выигрыша
  IsWon = check_line(X,Y,Name,Field,N),
  if IsWon == true -> Name;
    IsWon /= true -> no_winner
  end.

check_line(X,Y,Name,Field,N) ->
  Row = check_line(X,Y,Name,Field,right,N) - check_line(X,Y,Name,Field,left,N) - 1,
  Coloumn = check_line(X,Y,Name,Field,up,N) - check_line(X,Y,Name,Field,down,N) - 1,
  UpDiagon = check_line(X,Y,Name,Field,right_up,N) - check_line(X,Y,Name,Field,left_down,N) - 1,
  DownDiagon =  check_line(X,Y,Name,Field,right_down,N) - check_line(X,Y,Name,Field,left_up,N) - 1,
  if ((Row >= N) or (Coloumn >= N) or (UpDiagon >= N) or (DownDiagon >= N)) -> true;
    true -> false
  end.

check_line(X,Y,Name,Field,Direction,N) ->
  case Direction of
    right ->
      case dict:find({X,Y},Field) of {ok, [Name]} -> check_line(X+1,Y,Name,Field,Direction,N);
        _ ->  X
      end;
    left ->
      case dict:find({X,Y},Field) of {ok, [Name]} -> check_line(X-1,Y,Name,Field,Direction,N);
        _Else -> X
      end;
    up ->
      case dict:find({X,Y},Field) of {ok, [Name]} -> check_line(X,Y+1,Name,Field,Direction,N);
        _Else -> Y
      end;
    down ->
      case dict:find({X,Y},Field) of {ok, [Name]} -> check_line(X,Y-1,Name,Field,Direction,N);
        _Else -> Y
      end;
    right_up ->
      case dict:find({X,Y},Field) of {ok, [Name]} -> check_line(X+1,Y+1,Name,Field,Direction,N);
        _Else -> X
      end;
    left_up ->
      case dict:find({X,Y},Field) of {ok, [Name]} -> check_line(X-1,Y+1,Name,Field,Direction,N);
        _Else -> X
      end;
    right_down ->
      case dict:find({X,Y},Field) of {ok, [Name]} -> check_line(X+1,Y-1,Name,Field,Direction,N);
        _Else -> X
      end;
    left_down ->
      case dict:find({X,Y},Field) of {ok, [Name]} -> check_line(X-1,Y-1,Name,Field,Direction,N);
        _Else -> X
      end
  end.

leave_game(Name,State) ->
  NameNotDone = State#game_state.name_not_done,
  NameDone = State#game_state.name_done,
  IsMember = lists:member(Name,NameDone),
  if IsMember == true ->
    State#game_state {name_done = [lists:append(firstElement(NameNotDone),lists:delete(Name,NameDone))], name_not_done = deleteFirst(NameNotDone)};
    IsMember == false -> State#game_state {name_not_done = lists:delete(Name,NameNotDone)}
  end.

start_game() -> #game_state{}.

firstElement([X|_]) ->
  X;
firstElement([]) ->
  [].
deleteFirst([_|T]) ->
  T;
deleteFirst([])->[].

terminate(_Reason, _State) -> ok.
handle_info(_Info, State) -> {noreply, State}.
code_change(_OldVsn, State, _Extra) -> {ok, State}.

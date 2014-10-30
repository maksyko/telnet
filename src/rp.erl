-module(rp).
-behaviour(gen_server).
-behaviour(ranch_protocol).

%% @doc telnet chat-server
%% What can you do
%% crete/new room
%% show/
%% join/1
%% send/1 text
%% send/text
%% @end

-include("../include/config.hrl").
-export([start_link/4]).

-export([init/1]).
-export([init/4]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([terminate/2]).
-export([code_change/3]).


-define(TIMEOUT, 60000).
-record(state, {socket, transport}).

start_link(Ref, Socket, Transport, Opts) ->

  proc_lib:start_link(?MODULE, init, [Ref, Socket, Transport, Opts]).

init([]) -> {ok, undefined}.
init(Ref, Socket, Transport, _Opts = []) ->

  ets:insert(chat_manager, {self(), Socket, 1}),

  ok = proc_lib:init_ack({ok, self()}),
  ok = ranch:accept_ack(Ref),
  ok = Transport:setopts(Socket, [{active, once}]),
  gen_server:enter_loop(?MODULE, [],
    #state{socket=Socket, transport=Transport},
    ?TIMEOUT).
handle_info({tcp, Socket, Data}, State=#state{socket = Socket, transport=Transport}) ->
  Transport:setopts(Socket, [{active, once}]),
  case Data of
    <<"create/",Create/binary>> ->
      rp_chat:create(Create),
      Transport:send(Socket, <<"create ",Create/binary>>);

    <<"show/",_/binary>> ->
      Object = rp_chat:show(),
      ShowOut = show_in(Object),
      Transport:send(Socket, list_to_binary(ShowOut));

    <<"join/",Id/binary>> ->
      rp_chat:join(self(), Id, Socket),
      Transport:send(Socket, <<"join to ",Id/binary>>);

    <<"send/",Msg/binary>> ->
      rp_chat:send(Msg);

    Data ->
      Transport:send(Socket, Data)
  end,

  {noreply, State, ?TIMEOUT};

handle_info({tcp_closed, _Socket}, State) ->
  {stop, normal, State};

handle_info({tcp_error, _, Reason}, State) ->
  {stop, Reason, State};

handle_info(timeout, State) ->
  {stop, normal, State};

handle_info(_Info, State) ->
  {stop, normal, State}.

handle_call(_Request, _From, State) ->
  {reply, ok, State}.

handle_cast(_Msg, State) ->
  {noreply, State}.

terminate(_Reason, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

show_in(Object) ->
  {ok,List} = Object,
  remove_key(List).


remove_key(List) -> remove_key(List, []).
remove_key([], Acc) -> Acc;
remove_key([H | T], Acc) ->
 {_, Id, Name} = H,
 remove_key(T, [ "id | " ++ integer_to_list(Id) ++ " | name | " ++ binary_to_list(Name) ++ "\r\n" | Acc]).
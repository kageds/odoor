%% @doc api web service for odoo >= 8
-module(odoor).

-record(odoo, {host :: string()
              , db :: string()
              , pass :: string()
              , uid :: integer()
         }).
-type odoo() :: #odoo{}.
-type model() :: string() | atom().
-type method() :: string() | atom().

%% @doc rpc method **authenticate**
-record(authenticate, {db, user, pass, extra = #{}}).

%% @doc rpc method **execute_kw**
-record(execute_kw, {db, uid, pass, model, method, args = [], keywords = #{}}).

%% API exports
-export([auth/4,version/1]).
-export([call/5, call/4, check_access_rights/3, search/3, read/3, create/3, write/4,unlink/3]).

%%====================================================================
%% API functions
%%====================================================================
-spec auth(string(), binary(), binary(), binary()) -> {ok, odoo()} | {error, any()}.
auth(Host, Db, User, Pass) ->
    case xerlrpc:call(common_url(Host), #authenticate{
                                    db = Db,
                                    user = User,
                                    pass = Pass}) of
        {ok, [Id]} ->
            {ok, #odoo{db=Db, host=Host, uid = Id, pass=Pass}};
        {error, Error} ->
            {error, Error}
    end.

-spec version(odoo()) -> {ok, #{}} | {fault, any()} | {error, any()}.
version(Odoo) ->
    case xerlrpc:call(odoo_common_url(Odoo), version, []) of
        {ok, [Server]} ->
            {ok, struct_to_map(Server)};
        {error, Error} ->
            {error, Error}
    end.

check_access_rights(#odoo{} = Odoo, Model, Perms) ->
    Exec = odoo_execute_kw(Odoo, Model, <<"check_access_rights">>, Perms, #{<<"raise_exception">> => false}),
    case xerlrpc:call(odoo_object_url(Odoo), Exec) of
        {ok, [Bool]} ->
            {ok, Bool};
        Err ->
            Err
    end.

%% @doc make a custom rpc call
-spec call(odoo(), model(), method(), [any()]) -> {ok, [any()]} | {fault, any()} | {error, any()}.
call(#odoo{} = Odoo, Model, Method, Args) ->
    call(Odoo, Model, Method, Args, #{}).

%% @doc make a custom rpc call
-spec call(odoo(), model(), method(), [any()], #{}) -> {ok, [any()]} | {fault, any()} | {error, any()}.
call(#odoo{} = Odoo, Model, Method, Args, Keywords) ->
    Exec = odoo_execute_kw(Odoo, Model, Method, Args, Keywords),
    xerlrpc:call(odoo_object_url(Odoo), Exec).

%% @doc List records
%% Records can be listed and filtered via search().
%% search() takes a mandatory domain filter (possibly empty), and returns the database identifiers of all records matching the filter. To list customer companies for instance:
%% <a href="http://www.odoo.com/documentation/9.0/api_integration.html#list-records">More info</a>
%% @end
-spec search(odoo(), model(), any()) ->  {ok, [integer()]} | {fault, any()} | {error, any()}.
search(#odoo{} = Odoo, Model, Filter) ->
    case call(Odoo, Model, 'search', Filter, #{}) of
        {ok, [Ids]} ->
            {ok, Ids};
        Err ->
            Err
    end.

%% @doc Read records
%% Record data is accessible via the read() method, which takes a list of ids (as returned by search()) and optionally a list of fields to fetch. By default, it will fetch all the fields the current user can read, which tends to be a huge amount.
%% <a href="http://www.odoo.com/documentation/9.0/api_integration.html#read-records">More info</a>
%% @end
-spec read(odoo(), model(), [integer()]) -> {ok, [#{}]} | {fault, any()} | {error, any()}.
read(#odoo{} = Odoo, Model, Ids) ->
    case call(Odoo, Model, 'read', [Ids], #{}) of
        {ok, [Recs]} ->
            {ok, [struct_to_map(Rec) || Rec <- Recs]};
        Err ->
            Err
    end.

%% @doc Create records
%%
%% Records of a model are created using create(). The method will create a single record and return its database identifier.
%%
%% create() takes a mapping of fields to values, used to initialize the record. For any field which has a default value and is not set through the mapping argument, the default value will be used.
%%
%% <a href="http://www.odoo.com/documentation/9.0/api_integration.html#create-records">More info</a>
%% @end
-spec create(odoo(), model(), #{}) -> {ok, boolean()} | {fault, any()} | {error, any()}.
create(#odoo{} = Odoo, Model, Fields) ->
    case call(Odoo, Model, 'create', [Fields], #{}) of
        {ok, [Id]} ->
            {ok, Id};
        Err ->
            Err
    end.

%% @doc Update records
%%
%% Records can be updated using write(), it takes a list of records to update and a mapping of updated fields to values similar to create().
%%
%% Multiple records can be updated simultanously, but they will all get the same values for the fields being set. It is not currently possible to perform "computed" updates (where the value being set depends on an existing value of a record).
%%
%% <a href="http://www.odoo.com/documentation/9.0/api_integration.html#update-records">More info</a>
%% @end
-spec write(odoo(), model(), [integer()], #{}) -> {ok, boolean()} | {fault, any()} | {error, any()}.
write(#odoo{} = Odoo, Model, Ids, Fields) ->
    case call(Odoo, Model, 'write', [Ids, Fields], #{}) of
        {ok, [Bool]} ->
            {ok, Bool};
        Err ->
            Err
    end.

%% @doc Delete records
%%
%% Records can be deleted in bulk by providing their ids to unlink().
%%
%% <a href="http://www.odoo.com/documentation/9.0/api_integration.html#delete-records">More info</a>
%% @end
-spec unlink(odoo(), model(), [integer()]) -> {ok, boolean()} | {fault, any()} | {error, any()}.
unlink(#odoo{} = Odoo, Model, Ids) ->
    case call(Odoo, Model, 'unlink', [Ids], #{}) of
        {ok, [Bool]} ->
            {ok, Bool};
        Err ->
            Err
    end.


%%====================================================================
%% Internal functions
%%====================================================================
common_url(Host) ->
    Host ++ "/xmlrpc/2/common".
object_url(Host) ->
    Host ++ "/xmlrpc/2/object".

odoo_common_url(#odoo{host=Host}) ->
    common_url(Host).

odoo_object_url(#odoo{host=Host}) ->
    object_url(Host).

-spec odoo_execute_kw(odoo(), model(), string() | atom(), [any()], #{}) -> #execute_kw{}.
odoo_execute_kw(#odoo{db=Db,uid=Uid,pass=Pass}, Model, Method, Args, Keywords) ->
    #execute_kw{db=Db, uid=Uid, pass=Pass, method=Method, model=Model, args=Args, keywords=Keywords}.

struct_to_map(L) ->
    lists:foldl(fun({K,V}, Acc) ->
                        maps:put(erlang:binary_to_atom(K, utf8), V, Acc)
                end, maps:new(), L).

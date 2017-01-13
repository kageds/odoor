odoor
=====

Odoo Erlang low-level client.

## Usage

Add it to your rebar.config deps:
~~~erlang
{"odoor", ".*", {git, "git@github.com:Neurotec/odoor.git", {tag, "0.1.0"}}}
~~~

## RPC

first authenticate :
~~~erlang
{ok, O} = odoor:auth("http://odoo.neurotec.co", 'test', 'admin', 'admin'),
~~~

**model** call **method**

~~~erlang
{ok, O} = odoor:auth("http://odoo.neurotec.co", 'test', 'admin', 'admin'),
{ok, [Ids]} = odoor:call(O, 'res.partner', 'search', [[['is_company', '=', true]]]),
{ok, [Count]} = odoor:call(O, 'res.partner', 'search_cound', [[['is_company', '=', true]]]).
~~~

### METHODS

~~~erlang
auth(string(), binary(), binary(), binary()) -> {ok, odoo()} | {error, any()}.

version(odoo()) -> {ok, #{}} | {fault, any()} | {error, any()}.

search(odoo(), model(), any()) ->  {ok, [integer()]} | {fault, any()} | {error, any()}. 

create(odoo(), model(), #{}) -> {ok, boolean()} | {fault, any()} | {error, any()}.

write(odoo(), model(), [integer()], #{}) -> {ok, boolean()} | {fault, any()} | {error, any()}.

unlink(odoo(), model(), [integer()]) -> {ok, boolean()} | {fault, any()} | {error, any()}.
~~~

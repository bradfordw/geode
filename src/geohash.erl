-module(geohash).
-export([encode/2, encode/3, decode/1, adjacent/2]).

-include_lib("eunit/include/eunit.hrl").

-define(BITS, [16,8,4,2,1]).
-define(BASE32, "0123456789bcdefghjkmnpqrstuvwxyz").
-define(DEFAULT_COORDS, [[-90.0, 90.0], [-180.0, 180.0]]).
-define(GV, fun(P, B, PL) -> proplists:get_value(B, proplists:get_value(P, PL)) end).
-define(TOGGLE, fun(P) ->
    case P of
      on -> off;
      off -> on
    end
  end).

-define(NEIGHBORS, [
                   {right, [{even, "bc01fg45238967deuvhjyznpkmstqrwx"}]},
                   {left, [{even, "238967debc01fg45kmstqrwxuvhjyznp"}]},
                   {top, [{even, "p0r21436x8zb9dcf5h7kjnmqesgutwvy"}]},
                   {bottom, [{even, "14365h7k9dcfesgujnmqp0r2twvyx8zb"}]}
                  ]).
-define(BORDERS, [
                  {right, [{even, "bcfguvyz"}]},
                  {left, [{even, "0145hjnp"}]},
                  {top, [{even, "prxz"}]},
                  {bottom, [{even, "028b"}]}
                 ]).

inverse_of(Position) ->
  case Position of
    bottom  ->  left;
    top     ->  right;
    left    ->  bottom;
    right   ->  top
  end.

get_property(Position, Branch, PropList) ->
  case Branch of
    even  ->  ?GV(Position, Branch, PropList);
    odd   ->  ?GV(inverse_of(Position), even, PropList)
  end.

neighbors(Position, Branch) ->
  get_property(Position, Branch, ?NEIGHBORS).

borders(Position, Branch) ->
  get_property(Position, Branch, ?BORDERS).

encode(Latitude, Longitude) ->
  encode(Latitude, Longitude, on, 12).

encode(Latitude, Longitude, Precision) ->
  encode(Latitude, Longitude, on, Precision).

encode(Latitude, Longitude, Proc, Precision) ->
  encode([], 0, 0, [Latitude, Longitude], ?DEFAULT_COORDS, Proc, Precision).

encode(GeoHash, _, _, _, _, _, Precision) when length(GeoHash) =:= Precision -> GeoHash;
encode(GeoHash, Bit, Chr, [Latitude, Longitude], [Lats, Lons], Proc, Precision) ->
  case Proc of
    on -> {NewLons, NewLats, NewChr} = compare(Lons, Longitude, Lats, Bit, Chr);
    off -> {NewLats, NewLons, NewChr} = compare(Lats, Latitude, Lons, Bit, Chr)
  end,
  {NewGeoHash, NewBit, NewChr1} = case Bit < 4 of
    true  -> {GeoHash, Bit + 1, NewChr};
    false -> 
    GeoHash1 = GeoHash ++ [lists:nth(NewChr + 1, ?BASE32)], {GeoHash1, 0, 0}
  end,
  encode(NewGeoHash, NewBit, NewChr1, [Latitude, Longitude], [NewLats, NewLons], ?TOGGLE(Proc), Precision).

compare([HCoord, TCoord], Coord, OtherCoords, Bit, Chr) ->
  Mid = (HCoord + TCoord) / 2,
  case Coord > Mid of
    true ->
      NChr = Chr + lists:nth(Bit+1, ?BITS),
      {[Mid, TCoord], OtherCoords, NChr};
    false ->
      {[HCoord, Mid], OtherCoords, Chr}
  end.

decode(GeoHash) ->
  decode(GeoHash, ?DEFAULT_COORDS, on).

decode([], [[NLaH, NLaT], [NLoH,NLoT]], _) ->
  Lats = lists:sum([NLaH, NLaT, (NLaH+NLaT) / 2]) / 3,
  Lons = lists:sum([NLoH,NLoT, (NLoH+NLoT) / 2]) / 3,
  [{lat, Lats}, {lon, Lons}];
decode([H|GeoHash], [Lats, Lons], Proc) ->
  ValidChr = string:str(?BASE32, [H]) - 1,
  {[NewLats, NewLons], NewProc} = refine(?BITS, [Lats, Lons], ValidChr, Proc),
  decode(GeoHash, [NewLats, NewLons], NewProc).

refine([], [Lats, Lons], _, Proc) ->
  {[Lats, Lons], Proc};
refine([Bit|Bits], [Lats, Lons], Chr, Proc) ->
  [NewLats, NewLons] = case Proc of
    on  -> [Lats, refine_interval(Lons, Chr, Bit)];
    off -> [refine_interval(Lats, Chr, Bit), Lons]
  end,
  refine(Bits, [NewLats, NewLons], Chr, ?TOGGLE(Proc)).

refine_interval([Head, Tail], C, Bit) when C band Bit =/= 0 -> [(Head + Tail) / 2.0, Tail];
refine_interval([Head, Tail], _, _)  -> [Head, (Head + Tail) / 2.0].

adjacent(GeoHash, Direction) ->
  GHLen = length(GeoHash),
  LastChr = lists:last(GeoHash),
  Branch = which_branch(GHLen rem 2),
  Base = string:substr(GeoHash,1,GHLen-1),
  case lists:member(LastChr, borders(Direction, Branch)) of
    true -> adjacent(Base, Direction);
    false -> Base ++ [lists:nth(string:str(neighbors(Direction, Branch), [LastChr]), ?BASE32)]
  end.

which_branch(0) -> even;
which_branch(_) -> odd.

%% TEST
-ifdef(TEST).

decode_test() ->
  Expected = [{lat,38.89699992723763},{lon,-77.0359998755157}],
  Expected = decode("dqcjr0bp7n74"),
  ok.

encode_test() ->
  Expected = "dqcjr0bp7n",
  Expected = encode(38.897, -77.036, 10),
  ok.

encode_low_precision_test() ->
  Expected = "dqcjr0bp7n74",
  Expected = encode(38.897, -77.036),
  ok.
  
fizz_buzz_test() ->
  off = ?TOGGLE(on),
  on = ?TOGGLE(off),
  ok.

inverse_of_test() ->
  Inversions = [[bottom,left], [top,right],
                [left,bottom], [right,top]],
  [L = inverse_of(R) || [L,R] <- Inversions],
  ok.

borders_test() ->
  Expected = "bcfguvyz",
  Expected = borders(right, even),
  ok.

neighbors_test() ->
  Expected = "bc01fg45238967deuvhjyznpkmstqrwx",
  Expected = neighbors(right, even),
  ok.

adjacency_test() ->
  GeoHash = "dqcjr0bp7n74",
  Expected = [
    {top, "dqcjr0bp7n75"},
    {right, "dqcjr0bp7n76"},
    {left, "dqcjr0bp7n6"},
    {bottom, "dqcjr0bp7n71"}],
  Dirs = [top, right, left, bottom],
  Eval = [true, true, true, true],
  Eval = [lists:member(V, Expected) || V <- [{D, adjacent(GeoHash, D)} || D <- Dirs]],
  ok.
-endif.

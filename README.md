# Geode
## [Geohash](https://en.wikipedia.org/wiki/Geohash) / proximity searches in pure, uncut Erlang


### Usage

#### Encoding
```erlang
%% to encode a lat/lon
geohash:encode(38.897, -77.036).
%% would yield "dqcjr0bp7n74"

%% or if you want to control the "precision"
geohash:encode(38.897, -77.036, 10).
%% would yield "dqcjr0bp7n"
```

#### Decoding
```erlang
%% to encode a lat/lon
geohash:decode("dqcjr0bp7n74").
%% would yield [{lat,38.89699992723763},{lon,-77.0359998755157}]
```

#### Calculating Adjacent hashes/lat,lons
```erlang
%% to get the surrounding area hashes to test proximity
geohash:adjacent("dqcjr0bp7n74", top).
%% would yield "dqcjr0bp7n75" (which you may now decode to a lat/lon as well)

```
Supported directions are top, left, right, bottom (may change in future to north, south, east, west)

### To Do

Still need to implement (probably via gb_tree) a manner to search for nearby hashes.

### Caveats

This does not lend itself towards global searches (see the wikipedia article as to why).
If you're doing "local" searches in the same country or really just the same hemisphere, you should be fine.


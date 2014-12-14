Configuration examples
===============================

## 2v2

I like playing 2v2's on more maps (we generally use the map veto option), so I create a new section like so:

```
"GameTypes"
{
    "2v2"
    {
        "config"        "sourcemod/pugsetup/standard.cfg"
        "maplist"       "2v2maps.txt"
        "teamsize"      "2"
        "maptype"      "veto"
        "teamtype"      "manual"
    }
}
```

And then I create a new maplist ``csgo/addons/sourcemod/configs/pugsetup/2v2maps.txt``:

```
de_aztec
de_cache
de_cbble
de_dust
de_dust2
de_inferno
de_mirage
de_nuke
de_overpass
de_train
workshop/125689191/de_season_rc1
workshop/144923022/de_contra_b3
workshop/201811336/de_toscan
workshop/239672577/de_crown
workshop/267340686/de_facade
```

## 10man / gather

```
"GameTypes"
{
    "10man"
    {
        "config"        "sourcemod/pugsetup/standard.cfg"
        "maplist"       "standard.txt"
        "teamsize"      "5"
        "maptype"      "vote"
        "teamtype"      "captains"
    }
}
```

## Match

```
"GameTypes"
{
    "Match"
    {
        "config"        "sourcemod/pugsetup/standard.cfg"
        "maplist"       "standard.txt"
        "teamsize"      "5"
        "maptype"      "current"
        "teamtype"      "manual"
    }
}
```

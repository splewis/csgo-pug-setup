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
        "collection"        "12345678"
        "teamsize"      "5"
        "maptype"      "vote"
        "teamtype"      "captains"
    }
}
```

This is how you can use a workshop collection instead of a maplist. Note that the maps won't be downloade for you by the pugsetup plugin, but if the maps are avaliable they will be put into the map list.

Generally, you would want to use the collection that the server was launched with to use.

If you use this, you must install the [System2](https://forums.alliedmods.net/showthread.php?t=146019) extension.


## Match

```
"GameTypes"
{
    "Match"
    {
        "config"        "sourcemod/pugsetup/standard.cfg"
        "teamsize"      "5"
        "maptype"      "current"
        "teamtype"      "manual"
        "maps"
        {
            "de_dust2"      ""
            "de_inferno"        ""
            "de_mirage"     ""
            "de_cache"      ""
            "de_nuke"       ""
        }
    }
}
```

This match example also shows how you can use the optional "maps" section instead of creating a file for a maplist.


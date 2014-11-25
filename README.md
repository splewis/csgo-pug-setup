csgo-pug-setup
===========================

[![Build Status](https://travis-ci.org/splewis/csgo-pug-setup.svg)](https://travis-ci.org/splewis/csgo-pug-setup)

This is a useful plugin for managing pug games, especially **10 mans**/gathers. It allows a player to type .setup into chat and select (from a menu):
- how to choose the teams (players do it manually, random teams, captains select teams)
- how to choose the map (use the current map, do a map vote, veto maps)

The goal is to allow a **lightweight, easy-to-use setup system** that automates as much as possible with as few dependencies as possible. However,
the goal isn't fully automated - it assumes the players know each other or there is an admin. There is no mechanism for kicking players or anything similar.

Part of being lightweight is doing nothing that can interfere with the server's performance. **When the game is actually live, the plugin is doing extremely little work** - the only thing it does is read chat commands (e.g. pausing when a captain types .pause). Otherwise, there is 0 effect on gameplay and the rounds progress the same as without sourcemod on the server. This is in contrast to the WarMod plugin or what ESEA servers use, where they are tracking the overall score, overriding the in-game warmup period, etc.

The goal is to make setup easier for people, not provide a comprehensive pug platform. Please keep this and the principle of **keep it simple, stupid** in mind when making any suggestions.


#### Some alternatives
- [Goonpug](https://github.com/goonpug/goonpug) (very similar to this plugin, but with more features - and more dependencies)
- [PUG Mod](https://forums.alliedmods.net/showthread.php?p=1742753) (relatively plain - but no captain selection)
- [WarMod](https://forums.alliedmods.net/showthread.php?t=225474) (does pretty much everything - can be difficult to configure, heavyweight)


## Download
You should be able to get the most recent download from https://github.com/splewis/csgo-pug-setup/releases.


#### Usage
There is a notion of the the pug/game "leader". This is the player that writes .setup first and goes through the setup menu. The leader has elevated permissions and can use some extra commands (e.g. pause). To prevent some abuse there is also an admin command sm_leader to manually change the leader.

Generally, here is what happens:
- A player joins and types .setup and goes through the menu to select how the teams and map will be chosen
- Other players join and all type ``!ready``
- If the leader setup for a map vote, the map vote will occur and the map will change, then all players will type ``!ready`` on the new map
- If the leader setup for a captain-style team selection, the game will wait for when 2 captains are selected, then the captains will be given menus to chose players
- Then, either by the leader typing ``!start`` or the game auto-living (which is configurable), the game will initiate a live-on-3 restart and go


## Installation
Since this is a sourcemod plugin, you must have sourcemod installed. You can download it at http://www.sourcemod.net/downloads.php.

Note that sourcemod also requires MetaMod:Source to be on the server. You can download it at http://www.sourcemm.net/downloads.

**As of 1.3.0, sourcemod 1.7 is required.**

Download pugsetup.zip and extract the files to the game server. From the download, you should have installed the following (to the ``csgo`` directory):
- ``addons/sourcemod/plugins/pugsetup.smx``
- ``addons/sourcemod/translations/`` (the entire directory)
- ``addons/sourcemod/configs/pugsetup/`` (the entire directory)
- ``cfg/sourcemod/pugsetup`` (the entire directory)

Sometimes it's easier to add features in a separate plugin than the core plugin. So, there are a few addon (**optional**) plugins included in the download:
- ``pugsetup_autokicker``: kicks players that join when the game is already live, and players not selected by captains when using captain-player selection
- ``pugsetup_teamnames``: sets team names/flag according to the players on the team, see more detail at the end of the readme
- ``pugsetup_teamlocker``: blocks players from joining full teams when a game is live
- ``pugsetup_autosetup``: automatically sets up a game when a player connects so nobody has to type .setup

Most of these create a cfg file in ``cfg/sourcemod/pugsetup``you can tweak.

**Once all of these are on the server, it should just work.** If you want to tweak the configs or maplists read on.

## Configuration
One of the files you should have downloaded was `csgo/addons/sourcemod/configs/pugsetup/gametypes.cfg`:
```
"GameTypes"
{
    // Configs are relative to the csgo/cfg directory
    // Maplists are relative to the csgo/addons/sourcemod/configs/pugsetup directory
    "Normal"
    {
        "config"        "sourcemod/pugsetup/standard.cfg"
        "maplist"       "standard.txt"
    }
}
```

This file specifies different "game types", which are just combonations of a cfg file and a map list. You can add more sections if you want,
and the .setup menu will contain a page to choose which option. Otherwise, if there is only 1 game type, that one will always be used.

To create a new game type, add a section to the gametypes.cfg file, create the .cfg file in ``csgo/cfg/sourcemod/pugsetup``, and create a maplist in ``csgo/addons/sourcemod/configs/pugsetup``.


#### Example Configuration

One use of this is to have different rule sets. For example, I like playing 2v2's on more maps (we generally use the map veto option), so I create a new section like so:
```
"GameTypes"
{
    "Normal"
    {
        "config"        "sourcemod/pugsetup/standard.cfg"
        "maplist"       "standard.txt"
    }
    "2v2"
    {
        "config"        "sourcemod/pugsetup/standard.cfg"
        "maplist"       "2v2maps.txt"
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

When creating configs, realize that CS:GO's standard competitive config (``csgo/cfg/gamemode_competitive.cfg``) will be executed first. Two example deathmatch-style configs (good for aim maps) are included as examples, ``csgo/cfg/sourcemod/pugsetup`` contains ``awp.cfg`` and ``ak.cfg``.


There are other key/values you can use inside a gametype. For example:
```
    "10man"
    {
        "config"        "sourcemod/pugsetup/standard.cfg"
        "maplist"       "standard.txt"
        "teamsize"      "5"
        "lo3"       "wait" // might want to move players in mumble/teamspeak (equivalent of auto-lo3 disabled)
    }
```

``teamsize`` will force a team size for that game type. If left blank, there will be an option in the setup menu for the leader to select the teamsize.

In addition, you can use the key ``lo3`` with allowed values "ask" (makes the lo3 option show up in the setup menu), "auto" (always auto-lo3 for that game type), or "wait" (never auto-lo3 for that game type).

There is also another field ``hidden``, which you can set to 1 to make the game type not appear in the setup menu. This may be useful for other plugin developers using the ``SetupGame`` native.




## For developers
There is some extension support in the form of some natives and forwards. See [pugsetup.inc](scripting/include/pugsetup.inc).

An example of these in use is in [pugsetup_teamnames.sp](scripting/pugsetup_teamnames.sp).

Some examples of custom things I have done/can do:
- plugin to freeze players in place when not ready and enough players are on the server
- plugin to compress/upload demo files when games are finished
- plugin to kick players if they don't ready after x seconds


## Enabling GOTV
You need to enable gotv to use the demo-recording feature. Adding the following to your ``server.cfg`` will work:

    tv_enable 1
    tv_delaymapchange 1
    tv_delay 45
    tv_deltacache 2
    tv_dispatchmode 1
    tv_maxclients 10
    tv_maxrate 0
    tv_overridemaster 0
    tv_relayvoice 1
    tv_snapshotrate 20
    tv_timeout 60
    tv_transmitall 1

Of course, you can tweak the values.


## Commands

Some commands that are important are:
- **!setup**, begins the setup phase and sets the pug leader
- **!start**, begins the game (note that the cvar sm_teamselect_autolo3 controls if this is needed
- **!ready**
- **!unready**
- **!pause**
- **!unpause**
- **!capt** gives the pug leader a menu to select captains
- **!rand** selects random captains
- **!leader** gives a menu to change the game leader
- **!endgame**, force ends the game safely (only the leader can do this, note that this **resets the leader** to nobody)

You can also type .start instead of !start, or .ready instead of !ready.

These are some helper commands for automation purposes the bypass requiring a player to press any menus:
- sm_10man (this just uses the first game type from ``gametypes.cfg``, with 5v5, captains, map vote, and auto-lo3 disabled)
- sm_forceend (force ends the game with no confirmation menu)
- sm_pugmaps (lists the maps in the current maplist, requires a game to be !setup already)

You may find this plugin useful: https://forums.alliedmods.net/showthread.php?t=250224

It will let you make custom commands: e.g., you could set .myreadycommand as a chat trigger for the sm_ready command (in particular, this might be useful for making commands for non-english speaking users).


## ConVars
These are put in an autogenerated file at ``cfg/sourcemod/pugsetup.cfg``, once you start the plugin go edit that file if you wish. These are just some important ones, check the file for more.
- **sm_pugsetup_warmup_cfg** should store where the warmup config goes, defaults to the included file ``sourcemod/pugsetup/warmup.cfg``)
- **sm_pugsetup_autorecord** controls if the plugin should autorecord a gotv demo (you may need to add some extra cvars to your cfgs, such as tv_enable 1)
- **sm_pugsetup_requireadmin** controls if an admin flag ("g" for change map permissions) is needed to use the setup command

You may also want to change ``sm_vote_progress_chat`` in ``cfg/sourcemod/sourcemod.cfg`` to print players' votes when map voting is being used.

## Fun with team names/flags
(Using the included ``pugsetup_teamnames.smx`` plugin)

Just for fun, I added support to automatically set mp_teamname_1 and mp_teamflag_1 (and 2). Here's how it works
- you run the **sm_name** command in console to associate a player with a team name and flag (example: ``sm_name splewis "splewises terrible team1" "US"``)
- when the game goes live, the plugin picks a name/flag randomly from the players on the team
- when running the sm_name command, the syntax is: ``sm_name <player> <teamname> <teamflag>``
- note that the team flags are the [2-letter country codes](http://countrycode.org/)
- the team names/flags are stored using the clientprefs API, so a database for clientprefs must be set (by default SQLite is used)


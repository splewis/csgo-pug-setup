## 2.0.5
- update default maplist configs
- update default warmup config to not set mp_maxrounds so high (freezes game on panorama UI)
- add new setting (sm_pugsetup_snake_captain_picks 2) to do ABBABABA picking

## 2.0.4
- make instant runoff voting as the default mode for map votes
- make knife round decisions reached as soon as a majority is reached

## 2.0.3
- update practicemode to 1.1.3
- update maplists to use better pagination settings
- add instant runoff voting cvar (sm_pugsetup_instant_runoff_voting)
- fix for long captain names in hint texts

## 2.0.2
- update autoupdate url

## 2.0.1
- update russian translations
- update default cvars to shorter knife round / replace deprecated sv_alltalk
- added exit button to .setup menu
- disable pausing when no game is setup

## 2.0.0
- knife rounds now take into account the number of players (then health in a tie) when roundtime runs out
- pugsetup_practicemode addon has been moved into a subproject and renamed simply practicemode
- natives and forwards have been renamed with a PugSetup_ prefix
- default live.cfg cvars match new ESL ruleset

## 1.4.3:
- add optional voting for stay/swap decisions after knife rounds (sm_pugsetup_vote_for_knife_round_decision)
- add optional user-set ready echo messages set with .readymessage command
- clean up setup menus to have an ExitBack option
- practice mode: noclip command will work correctly even with a "noclip; say .noclip" command
- practice mode: add commands to launch/exit practice mode: sm_launchpractice, sm_exitpractice
- rwsbalancer: fix bugs with accuracy of the stored rws values
- add Polish translations (thanks TheTolek14)
- add Brazilian Portuguese translations (thanks marcelotk)
- add Norwegian translations (thanks Bawls)

## 1.4.2:
- correct a bug where the pug leader was not being assigned correctly when a client finished the .setup menu

## 1.4.1:
- add "playout" setup option (default to off & not displayed) that wraps mp_match_can_clinch

## 1.4.0:

Major core plugin changes:
- complete rework on how the setup menu is configured, instead of 2 cvars per option (default/whether it is display), these options
  are now stored in ``addons/sourcemod/configs/pugsetup/setupoptions.cfg``, and can be changed ingame using .setdefault and .setdisplay commmands
- new cvars ``sm_pugsetup_use_aim_map_warmup``, ``sm_pugsetup_maplist_aim_maps`` to use aim_ maps during warmup periods when waiting for map votes/vetoes (off by default)
- new cvar ``sm_pugsetup_use_game_warmup`` to use the builtin warmup system (on by default)
- allow pugsetup commands to have their permissions changed in file ``addons/sourcemod/configs/pugsetup/permissions.cfg``, this means any cvar
  dealing with permissions (e.g. ``sm_pugsetup_requireadmin`` is removed)
- system2 support for using workshop collections is removed and replaced with [SteamWorks](https://forums.alliedmods.net/showthread.php?t=229556) for both correctness and reliability improvements
- when using a workshop collection id as a maplist, the maps no longer have to already be on the server - the ``host_workshop_map`` command is used and the map will be download automatically
- the core plugin is aware of an autobalancers (e.g. the pugsetup_rwsbalancer) now, if one is available the team type "autobalanced" will be on the setup menu

Minor core plugin changes:
- add generic console command ``pugstatus`` to print pug state information (setup options, current game state, etc.)
- new cvar ``sm_pugsetup_money_on_warmup_spawn`` to give 16,000 dollars on player spawn during warmup phases
- improvements to make the plugin force-end warmup when doing a lo3, regardless of what is in the live/warmup configs
- add ingame .addalias/.removealias admin commands for adding aliases to ``addons/sourcemod/configs/pugsetup/chataliases.cfg``
- add ingame .addmap/.removemap admin commands for modifying the current maplist
- make knife round cvars in ``cfg/sourcemod/pugsetup/knife.cfg`` not reliant on being reset by the live config (cvars are restored to their previous values automatically now)
- new cvar ``sm_pugsetup_pausing_enabled`` (default 1)
- new cvar ``sm_pugsetup_random_map_vote_option`` (default 1)
- new cvar ``sm_pugsetup_postgame_cfg`` (default sourcemod/pugsetup/warmup.cfg)
- new cvar ``sm_pugsetup_setup_enabled`` (default 1)

API changes:
- new fowards: ``OnGameStateChanged``, ``OnPlayerAddedToCaptainMenu``, ``OnPostGameCfgExecuted``, ``OnHelpCommand``
- new natives: ``IsTeamBalancerAvaliable``, ``IsTeamBalancerAvaliable``, ``ClearTeamBalancer``, ``GetGameState``, ``IsValidCommand``, ``GetPermissions``, ``SetPermissions``

Optional plugin changes:
- correct bugs with pugsetup_damageprint plugin and make ``sm_pugsetup_damageprint_format`` cvar configurable
- new rws balancers features (off by default): ``sm_pugsetup_rws_allow_rws_command``, ``sm_pugsetup_rws_display_on_menu``
- remove non-clientprefs storage mechanisms in the rwsbalancer
- various improvements to pugsetup_practicemode plugin: new cvars ``sm_infinite_money``, ``sm_grenade_trajectory_use_player_color``, ``sm_allow_noclip``,
  reimplement grenade trajectories using ``sv_grenade_trajectory`` value, ``sv_cheats`` is no longer required to be on
- practicemode will save the origin/angles a client is facing when throwing grenades and can be revisited using .back, .forward commands
- practicemode will let clients save persistent angles/locations per map for grenades using .save <name of grenade/position> and .nades [playername]
- autokicker has new cvars to kick players that don't ready up after a given time period, ``sm_pugsetup_autokicker_ready_time``, ``sm_pugsetup_autokicker_ready_time_kick_message`` (off by default)

### 1.3.3:
- fix the rwsbalancer being totally broken with team balancing
- bugfixes with the use of default setup options overriding the actual setup options used
- fix ``sm_pugsetup_any_can_pause`` not having the correct effect
- add pugsetup_damageprint plugin to replicate ESEA damage printing options (experimental)
- add commands sm_t, sm_ct for picking sides after winning a knife round in addition to sm_stay and sm_swap

### 1.3.2:
- the auto-live-on-3 (named autolive) setting can now be turned off again, cvars ``sm_pugsetup_default_autolive`` and ``sm_pugsetup_autolive_option`` control the default setting and whether the setting is avaliable in the setup menu
- captains can now be set by selecting a "select captains" option in the .setup menu after a game is setup
- the pugsetup_hostname addon now displays scores in the name (e.g. [LIVE 11-8])
- the pugsetup_rwsbalancer addon will not respect users that try to override the captains the plugin set (it sets captains as the 2 highest rated players)
- fix the PugSetupMessageToAll native not checking for clients being in game and causing errors

### 1.3.1:
- several bug fixes when using default setting cvars
- pausing now works during knife rounds
- new command: sm_forcestart to force a match to proceed forward even if everyone isn't ready
- add forward OnStartRecording
- the rwsbalancer plugin can store data in any of: clientprefs, a flat keyvalues file on disk, or a MySQL database now (set by the ``sm_pugsetup_rws_storage_method`` cvar)

## 1.3.0:
 - sourcemod 1.7 is now required
 - instead of a choice "auto-lo3", there is now a cvar for the length of a countdown timer (``sm_pugsetup_start_delay``)
 - the top .setup menu has be rewritten to be simpler and use toggle options rather than a series of pages
 - new cvar: ``sm_pugsetup_autosetup`` can be used to automatically do a game setup with the "default" options
 - default options can be set by the new cvars: ``sm_pugsetup_default_knife_rounds``, ``sm_pugsetup_default_maptype``, ``sm_pugsetup_autorecord``, ``sm_pugsetup_default_teamsize``, ``sm_pugsetup_default_teamtype``
 - knife rounds can now be used for choosing starting sides
 - new cvar: ``sm_pugsetup_exclude_spectators`` can be used to exclude spectators from the game (i.e. they don't have to ready up)
 - new cvar: ``sm_pugsetup_mutual_unpausing`` can be set to 1 to require both teams to type .unpause before an unpause takes effect
 - new cvar: ``sm_pugsetup_snake_captain_picks`` can be set to 1 to have captains pick players in a ABBAABBA format
 - add forwards/natives for other plugins to add custom behavior, see [pugsetup.inc](scripting/include/pugsetup.inc).
 - added optional plugin ``pugsetup_autokicker``, which kicks players that join when the game is already live, and players not selected by captains when using  captain-player selection
 - added optional plugin ``pugsetup_teamnames``, which sets team names/flag according to the players on the team, see more detail at the end of the readme
 - added optional plugin ``pugsetup_hostname``, which adds some tags to the server hostname depending on the pug status, examples: "[LIVE]" and "[NEED 3]"
 - added optional plugin ``pugsetup_rwsbalancer``, which implements a simple rws calculation (stored via clientprefs) and balances team accordingly when using manual /random teams
 - added optional plugin ``pugsetup_chatmoney``, which prints out the team members' money to chat on round starts
 - added optional plugin ``pugsetup_practicemode``, which adds an option to the .setup menu to launch a practice mode with cheats/infinite ammo/respawning/etc.
 - workshop collection ids can be used instead of a maplist file in ``sm_pugsetup_maplist`` if the [System2](https://forums.alliedmods.net/showthread.php?t=146019) extension is installed
 - new commands: sm_forceend, sm_forceready
 - custom chat aliases may be defined in ``addons/sourcemod/configs/pugsetup/chataliases.cfg``
 - translation support
 - re-add updater support

### 1.2.1:
 - bug fix for demo recording on a map inside another directory (e.g. workshop maps)

## 1.2.0:
 - bug fixes with team name handling and live-timer

## 1.1.0:
- add chat prefixes to plugin chat messages
- change the demo formatting name to use a time formatting string that is supported by Windows
- fix issues where ready-up checking timers were being created multiple teams (as a result some chat messages were printed multiple times)
- add an (optional) fun command ``sm_name`` that lets you pick a name/flag for a player, when the game goes live it selects a random team/flag from the players on the team to use

## 1.0.0:
- initial public release
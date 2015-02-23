1.3.3:
- fix the rwsbalancer being totally broken with team balancing
- bugfixes with the use of default setup options overriding the actual setup options used
- fix ``sm_pugsetup_any_can_pause`` not having the correct effect
- add pugsetup_damageprint plugin to replicate ESEA damage printing options (experimental)
- add commands sm_t, sm_ct for picking sides after winning a knife round in addition to sm_stay and sm_swap

1.3.2:
- the auto-live-on-3 (named autolive) setting can now be turned off again, cvars ``sm_pugsetup_default_autolive`` and ``sm_pugsetup_autolive_option`` control the default setting and whether the setting is avaliable in the setup menu
- captains can now be set by selecting a "select captains" option in the .setup menu after a game is setup
- the pugsetup_hostname addon now displays scores in the name (e.g. [LIVE 11-8])
- the pugsetup_rwsbalancer addon will not respect users that try to override the captains the plugin set (it sets captains as the 2 highest rated players)
- fix the PugSetupMessageToAll native not checking for clients being in game and causing errors

1.3.1:
- several bug fixes when using default setting cvars
- pausing now works during knife rounds
- new command: sm_forcestart to force a match to proceed forward even if everyone isn't ready
- add forward OnStartRecording
- the rwsbalancer plugin can store data in any of: clientprefs, a flat keyvalues file on disk, or a MySQL database now (set by the ``sm_pugsetup_rws_storage_method`` cvar)

1.3.0:
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

1.2.1:
 - bug fix for demo recording on a map inside another directory (e.g. workshop maps)

1.2.0:
 - bug fixes with team name handling and live-timer

1.1.0:
- add chat prefixes to plugin chat messages
- change the demo formatting name to use a time formatting string that is supported by Windows
- fix issues where ready-up checking timers were being created multiple teams (as a result some chat messages were printed multiple times)
- add an (optional) fun command ``sm_name`` that lets you pick a name/flag for a player, when the game goes live it selects a random team/flag from the players on the team to use

1.0.0:
- initial public release
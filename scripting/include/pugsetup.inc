#if defined _pugsetup_included
  #endinput
#endif
#define _pugsetup_included

// Different ways teams can be selected.
enum TeamType {
    TeamType_Manual = 0,
    TeamType_Random = 1,
    TeamType_Captains = 2,
    TeamType_Autobalanced = 3,                  // only allowed if IsTeamBalancerAvaliable() is true
};

// Different ways the map can be selected.
enum MapType {
    MapType_Current = 0,
    MapType_Vote = 1,
    MapType_Veto = 2,
};

// Permission checking values.
enum Permission {
    Permission_All = 0,
    Permission_Captains = 1,
    Permission_Leader = 2,
    Permission_Admin = 3,
};

// Pug game state
enum GameState {
    GameState_None = 0,                          // no setup has taken place
    GameState_Warmup = 1,                        // setup done, waiting for players to ready up
    GameState_PickingPlayers = 2,                // only used if TeamType_Captains is the teamtype
    GameState_WaitingForStart = 3,               // waiting for a .start if autolive is disabled
    GameState_Countdown = 4,                     // doing the countdown timer
    GameState_KnifeRound = 5,                    // in the knife round
    GameState_WaitingForKnifeRoundDecision = 6,  // waiting for a .stay/.swap command after the knife round
    GameState_GoingLive = 7,                     // in the lo3 process
    GameState_Live = 8,                          // the match is live
};

/**
 * Called when a setup menu is opened.
 *
 * @param client Client that did the setup menu (e.g. the leader).
 * @param menu The menu being given to the client.
 * @return Whether to display the menu to the client or not.
 */
forward bool OnSetupMenuOpen(int client, Menu menu, bool displayOnly);

/**
 * Called when a setup menu option is selected.
 * You should call GiveSetupMenu to the calling client at the end of this function.
 */
forward void OnSetupMenuSelect(Menu menu, MenuAction action, int param1, int param2);

/**
 * Called when a setup menu is finished.
 *
 * @param client Client that did the setup menu (e.g. the leader).
 * @param teamType The team type selected
 * @param mapType The map type selected
 * @param playersPerTeam The number of players per team
 */
forward void OnSetup(int client, TeamType teamType, MapType mapType, int playersPerTeam);

/**
 * Called when a client force-ends the match.
 *
 * @param client Client that force-ended the match.
 */
forward void OnForceEnd(int client);

/**
 * Called when a player marks themselves as ready.
 */
forward void OnReady(int client);

/**
 * Called when a player marks themselves as not ready.
 */
forward void OnUnready(int client);

/**
 * Called when the match is ready to begin, for example
 * when all players are ready and the captains are now picking players.
 */
forward void OnReadyToStart();

/**
 * Called when the going-live process begins, before the lo3.
 */
forward void OnGoingLive();

/**
 * Called after the last restart when the game is completely live.
 */
forward void OnLive();

/**
 * Called after the warmup config is executed.
 */
forward void OnWarmupCfgExecuted();

/**
 * Called after the live config is executed.
 */
forward void OnLiveCfgExecuted();

/**
 * Called when the match is over.
 * If you plan on using the result of the demo file,
 * I'd suggest adding a slight delay from when this is called
 * to accomodate the time spent flushing the demo to disk.
 *
 * @param hasDemo whether a demo was being recorded
 * @param demoFileName the filename of the demo (including the .dem extension)
 */
forward void OnMatchOver(bool hasDemo, const char[] demoFileName);

/**
 * Called when a client is not picked in a captain-selection game.
 */
forward void OnNotPicked(int client);

/**
 * Called every timer-check for whether the pug is ready to start or not.
 */
forward void OnReadyToStartCheck(int readyPlayers, int totalPlayers);

/**
 * Called when user permissions are being checked. You can change
 * the value of "allow" to change the result of the check and allow
 * or disallow an action.
 *
 * @param client Client that initiated the command
 * @param command The command that was issued
 * @param p Default permissions the plugin checked against
 * @param allow Result of the check
 * @note permissions-checking is only relevent for pugsetup commands.
 */
forward void OnPermissionCheck(int client, const char[] command, Permission p, bool& allow);

/**
 * Called when a tv_record command is about to be sent.
 *
 * @param demoName The name given when the tv_record command was used (no .dem file extension)
 */
forward void OnStartRecording(char[] demoName);

/**
 * Called after a maplist is read.
 *
 * @param maplist The maplist file or workshop collection id
 * @param maps The ArrayList of maps fetched
 * @param workshopCollection Whether the maplist was a workshop collection or a regular maplist file
 */
forward void OnMapListRead(const char[] maplist, ArrayList maps, bool workshopCollection);

/**
 * Called before a player gets added to a captain selection menu.
 *
 * @param menu The Menu players are being added to
 * @param client The client being added to the menu
 * @param menuString The menu display string being added for the client
 * @param length Length of the menuString
 */
forward void OnPlayerAddedToCaptainMenu(Menu menu, int client, char[] menuString, int length);

/**
 * Called during any game state change.
 */
forward void OnGameStateChanged(GameState before, GameState after);

typedef TeamBalancerFunction = function void (ArrayList players);

/**
 * Returns if a team balancer function has been set for pugsetup to use, if selected in the setup menu.
 */
native bool IsTeamBalancerAvaliable();

/**
 * Sets a team balancer function, returning if the balancer function was set.
 */
native bool SetTeamBalancer(TeamBalancerFunction balancerFunction, bool override=false);

/**
 * Clears any team balancer function set, returning if there was one before clearing.
 */
native bool ClearTeamBalancer();

// Sets a game up with the given settings.
native void SetupGame(TeamType teamType, MapType mapType=MapType_Vote, int playersPerTeam=5, bool recordDemo=false, bool knifeRound=false, bool autoLive=true);

// Sets the current game options. These can still be overwritten by a user with access to the .setup menu.
native void SetSetupOptions(TeamType teamType, MapType mapType, int playersPerTeam=5, bool recordDemo=false, bool knifeRound=false, bool autoLive=true);

// Fetches the current game options.
// @error If there is no game setup yet.
native void GetSetupOptions(TeamType& teamType, MapType& mapType, int& playersPerTeam, bool& recordDemo, bool& knifeRound, bool& autoLive);

// Readies up a player.
// Returns if they were successfully readied.
native bool ReadyPlayer(int client);

// Unreadies a player.
// Returns if they were successfully unreadied. (returns false if the client was already not-ready)
native bool UnreadyPlayer(int client);

// Returns whether a client is ready.
// This is only valid when the game is setup AND not live.
native bool IsReady(int client);

// Returns if the game settings have been setup.
native bool IsSetup();

// Returns the team type being used.
// Only valid if IsSetup is true.
native TeamType GetTeamType();

// Returns the map type being used.
// Only valid if IsSetup is true.
native MapType GetMapType();

// Returns the current pug gamestate.
native GameState GetGameState();

// Returns if there is currently a match setup.
native bool IsMatchLive();

// Returns if the match is pending start. (e.g. during the lo3)
native bool IsPendingStart();

// Sets the pug leader.
native void SetLeader(int client);

// Returns the pug leader, or -1 if not set.
native int GetLeader();

// Sets who is a captain.
// A captain number is either 1 or 2.
native void SetCaptain(int captainNumber, int client, bool printIfSame=false);

// Returns captain 1, or -1 if not set.
// A captain number is either 1 or 2.
native int GetCaptain(int captainNumber);

// Prints a plugin-formatted message to a client.
native void PugSetupMessage(int client, const char[] format, any:...);

// Prints a plugin-formatted message to all clients.
native void PugSetupMessageToAll(const char[] format, any:...);

// Returns the maximum number of players in the pug.
// Only valid if the game has already been setup.
native int GetPugMaxPlayers();

// Returns if a client was present when the game started.
// This doesn't include if the player disconnected and reconnected.
native bool PlayerAtStart(int client);

// Returns if the plugin has identified a player as having elevated permissions.
native bool IsPugAdmin(int client);

// Returns if a client satisfies a permission check.
native bool HasPermissions(int client, Permission p);

// Sets random captains.
native void SetRandomCaptains();

// Adds a chat alias for a command. For example: .setup as a chat trigger for sm_setup
native void AddChatAlias(const char[] alias, const char[] command);

// Give a client the root setup menu again.
// This is intended to be called in the OnSetupMenuSelect forward.
native void GiveSetupMenu(int client, bool displayOnly=false, int menuPosition=-1);

// Returns if a console command is a valid pugsetup command.
native bool IsValidCommand(const char[] command);

// Gets the permissions for a command, or throws an error on invalid command.
// Note: permissions-checking is only relevent for pugsetup commands.
native Permission GetPermissions(const char[] command);

// Sets the permissions for a command, returning whether the command already had permissions set.
// Note: permissions-checking is only relevent for pugsetup commands.
native bool SetPermissions(const char[] command, Permission p);

public SharedPlugin __pl_pugsetup = {
    name = "pugsetup",
    file = "pugsetup.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_pugsetup_SetNTVOptional() {
    MarkNativeAsOptional("SetupGame");
    MarkNativeAsOptional("GetSetupOptions");
    MarkNativeAsOptional("SetSetupOptions");
    MarkNativeAsOptional("ReadyPlayer");
    MarkNativeAsOptional("UnreadyPlayer");
    MarkNativeAsOptional("IsReady");
    MarkNativeAsOptional("IsSetup");
    MarkNativeAsOptional("GetTeamType");
    MarkNativeAsOptional("GetMapType");
    MarkNativeAsOptional("GetGameState");
    MarkNativeAsOptional("IsMatchLive");
    MarkNativeAsOptional("IsPendingStart");
    MarkNativeAsOptional("SetLeader");
    MarkNativeAsOptional("GetLeader");
    MarkNativeAsOptional("SetCaptain");
    MarkNativeAsOptional("GetCaptain");
    MarkNativeAsOptional("PugSetupMessage");
    MarkNativeAsOptional("PugSetupMessageToAll");
    MarkNativeAsOptional("GetPugMaxPlayers");
    MarkNativeAsOptional("PlayerAtStart");
    MarkNativeAsOptional("IsPugAdmin");
    MarkNativeAsOptional("HasPermissions");
    MarkNativeAsOptional("SetRandomCaptains");
    MarkNativeAsOptional("AddChatAlias");
    MarkNativeAsOptional("GiveSetupMenu");
    MarkNativeAsOptional("IsValidCommand");
    MarkNativeAsOptional("GetPermissions");
    MarkNativeAsOptional("SetPermissions");;
    MarkNativeAsOptional("SetTeamBalancer");
    MarkNativeAsOptional("IsTeamBalancerAvaliable")
    MarkNativeAsOptional("ClearTeamBalancer");
}
#endif

stock bool TeamTypeFromString(const char[] teamTypeString, TeamType& teamType, bool logError=false) {
    if (StrEqual(teamTypeString, "captains", false) || StrEqual(teamTypeString, "captain", false)) {
        teamType = TeamType_Captains;
    } else if (StrEqual(teamTypeString, "manual", false)) {
        teamType = TeamType_Manual;
    } else if (StrEqual(teamTypeString, "random", false)) {
        teamType = TeamType_Random;
    } else if (StrEqual(teamTypeString, "autobalanced", false) || StrEqual(teamTypeString, "balanced", false)) {
        teamType = TeamType_Autobalanced;
    } else {
        if (logError)
            LogError("Invalid team type: \"%s\", allowed values: \"captains\", \"manual\", \"random\", \"autobalanced\"", teamTypeString);
        return false;
    }

    return true;
}

stock bool MapTypeFromString(const char[] mapTypeString, MapType& mapType, bool logError=false) {
    if (StrEqual(mapTypeString, "current", false)) {
        mapType = MapType_Current;
    } else if (StrEqual(mapTypeString, "vote", false)) {
        mapType = MapType_Vote;
    } else if (StrEqual(mapTypeString, "veto", false)) {
        mapType = MapType_Veto;
    } else {
        if (logError)
            LogError("Invalid map type: \"%s\", allowed values: \"current\", \"vote\", \"veto\"", mapTypeString);
        return false;
    }

    return true;
}

stock bool PermissionFromString(const char[] permissionString, Permission& p, bool logError=false) {
    if (StrEqual(permissionString, "all", false) || StrEqual(permissionString, "any", false)) {
        p = Permission_All;
    } else if (StrEqual(permissionString, "captains", false) || StrEqual(permissionString, "captain", false)) {
        p = Permission_Captains;
    } else if (StrEqual(permissionString, "leader", false)) {
        p = Permission_Leader;
    } else if (StrEqual(permissionString, "admin", false)) {
        p = Permission_Admin;
    } else {
        if (logError)
            LogError("Invalid permission type: \"%s\", allowed values: \"all\", \"captain\", \"leader\", \"admin\"", permissionString);
        return false;
    }

    return true;
}

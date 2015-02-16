#if defined _pugsetup_included
  #endinput
#endif
#define _pugsetup_included

// Different ways teams can be selected.
enum TeamType {
    TeamType_Manual = 0,
    TeamType_Random = 1,
    TeamType_Captains = 2
};

// Different ways the map can be selected.
enum MapType {
    MapType_Current = 0,
    MapType_Vote = 1,
    MapType_Veto = 2
};

// Permissions checking values.
enum Permissions {
    Permission_All = 0,
    Permission_Captains = 1,
    Permission_Leader = 2,
    Permission_Admin = 3
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
 */
forward void OnPermissionCheck(int client, const char[] command, Permissions p, bool& allow);

// Called when a tv_record command is about to be sent.
forward void OnStartRecording(char[] demoName);

// Sets a game up with the given settings.
native void SetupGame(TeamType teamType, MapType mapType=MapType_Vote, int playersPerTeam=5, bool recordDemo=false, bool knifeRound=false, bool autoLive=true);

// Readies up a player.
native void ReadyPlayer(int client);

// Unreadies a player.
native void UnreadyPlayer(int client);

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
native bool HasPermissions(int client, Permissions p);

// Sets random captains.
native void SetRandomCaptains();

// Adds a chat alias for a command. For example: .setup as a chat trigger for sm_setup
native void AddChatAlias(const char[] alias, const char[] command);

// Give a client the root setup menu again.
// This is intended to be called in the OnSetupMenuSelect forward.
native void GiveSetupMenu(int client, bool displayOnly=false, int menuPosition=-1);

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
    MarkNativeAsOptional("ReadyPlayer");
    MarkNativeAsOptional("UnreadyPlayer");
    MarkNativeAsOptional("IsReady");
    MarkNativeAsOptional("IsSetup");
    MarkNativeAsOptional("GetTeamType");
    MarkNativeAsOptional("GetMapType");
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
}
#endif

stock TeamType TeamTypeFromString(const char[] teamTypeString,
                                  TeamType fallback=TeamType_Captains,
                                  bool logError=true) {
    if (StrEqual(teamTypeString, "captains") || StrEqual(teamTypeString, "captain"))
        return TeamType_Captains;
    else if (StrEqual(teamTypeString, "manual"))
        return TeamType_Manual;
    else if (StrEqual(teamTypeString, "random"))
        return TeamType_Random;
    else if (logError)
        LogError("Invalid team type: \"%s\", allowed values: \"captains\", \"manual\", \"random\"", teamTypeString);

    return fallback;
}

stock MapType MapTypeFromString(const char[] mapTypeString,
                                MapType fallback=MapType_Vote,
                                bool logError=true) {
    if (StrEqual(mapTypeString, "current"))
        return MapType_Current;
    else if (StrEqual(mapTypeString, "vote"))
        return MapType_Vote;
    else if (StrEqual(mapTypeString, "veto"))
        return MapType_Veto;
    else if (logError)
        LogError("Invalid map type: \"%s\", allowed values: \"current\", \"vote\", \"veto\"", mapTypeString);

    return fallback;
}

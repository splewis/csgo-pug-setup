#if defined _pugsetup_included
  #endinput
#endif
#define _pugsetup_included

// Different ways teams can be selected.
enum TeamType {
    TeamType_Manual,
    TeamType_Random,
    TeamType_Captains
};

// Different ways the map can be selected.
enum MapType {
    MapType_Current,
    MapType_Vote,
    MapType_Veto
};

// Called when a setup menu is finished.
forward OnSetup(int client, TeamType teamType, MapType mapType, int playersPerTeam);

// Called when a player marks themselves as ready.
forward OnReady(int client);

// Called when a player marks themselves as unready.
forward OnUnready(int client);

// Called when the going-live process begins, before the lo3.
forward OnGoingLive();

// Called after the last restart when the game is completely live.
forward OnLive();

// Called when the match is over.
// If you plan on using the result of the demo file,
// I'd suggest adding a slight delay from when this is called
// to accomodate the time spent flushing the demo to disk.
forward OnMatchOver(bool hasDemo, char demoFileName[]);

// Sets a game up with the given settings.
native void SetupGame(int gameTypeIndex, TeamType teamType, MapType mapType, int playersPerTeam, bool autolo3);

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

// Sets the pug leader.
native void SetLeader(int client);

// Returns the pug leader, or -1 if not set.
native int GetLeader();

// Sets who is captain 1.
native void SetCaptain1(int client);

// Returns captain 1, or -1 if not set.
native int GetCaptain1();

// Sets who is captain 2.
native void SetCaptain2(int client);

// Returns captain 2, or -1 if not set.
native int GetCaptain2();

// Prints a plugin-formatted message to a client.
native void PugSetupMessage(int client, const char format[], any:...);

// Prints a plugin-formatted message to all clients.
native void PugSetupMessageToAll(const char format[], any:...);

// Returns the maximum number of players in the pug.
// Only valid if the game has already been setup.
native int GetPugMaxPlayers();

public SharedPlugin:__pl_pugsetup = {
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
    MarkNativeAsOptional("IsReady");
    MarkNativeAsOptional("IsSetup");
    MarkNativeAsOptional("GetTeamType");
    MarkNativeAsOptional("GetMapType");
    MarkNativeAsOptional("IsMatchLive");
    MarkNativeAsOptional("SetLeader");
    MarkNativeAsOptional("GetLeader");
    MarkNativeAsOptional("SetCaptain1");
    MarkNativeAsOptional("GetCaptain1");
    MarkNativeAsOptional("SetCaptain2");
    MarkNativeAsOptional("GetCaptain2");
    MarkNativeAsOptional("PugSetupMessage");
    MarkNativeAsOptional("PugSetupMessageToAll");
    MarkNativeAsOptional("GetPugMaxPlayers");
    MarkNativeAsOptional("SetupGame");
}
#endif

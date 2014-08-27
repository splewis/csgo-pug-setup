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

// Called when the going-live process begins.
forward OnGoingLive();

// Called when the match is over.
forward OnMatchOver(bool hasDemo, char demoFileName[]);

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

// Sets a game up.
// Returns true if it was setup, or false if the game couldn't be setup. (i.e. if already live)
native bool SetupGame(TeamType teamType, MapType mapType, int playersPerTeam, bool autoLo3);

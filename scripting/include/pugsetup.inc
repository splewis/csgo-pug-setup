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
forward OnSetup(client, TeamType:teamType, MapType:mapType, playersPerTeam);

// Called when the going-live process begins.
forward OnGoingLive();

// Called when the match is over.
forward OnMatchOver(bool:hasDemo, String:demoFileName[]);

// Returns whether a client is ready.
// This is only valid when the game is setup AND not live.
native bool:IsReady(client);

// Returns if the game settings have been setup.
native bool:IsSetup();

// Returns if there is currently a match setup.
native bool:IsMatchLive();

// Returns the pug leader, or -1 if not set.
native any:GetLeader();

// Returns captain 1, or -1 if not set.
native any:GetCaptain1();

// Returns captain 2, or -1 if not set.
native any:GetCaptain2();

// Prints a plugin-formatted message to a client.
native PugSetupMessage(client, const String:fmt[], any:...);

// Prints a plugin-formatted message to all clients.
native PugSetupMessageToAll(const String:fmt[], any:...);

// Returns the maximum number of players in the pug.
// Only valid if the game has already been setup.
native GetPugMaxPlayers();

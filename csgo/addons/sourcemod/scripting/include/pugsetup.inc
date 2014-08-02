// Called when the going-live process begins.
forward OnGoingLive();

// Called when the match is over.
forward OnMatchOver(bool:hasDemo, String:demoFileName[]);

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

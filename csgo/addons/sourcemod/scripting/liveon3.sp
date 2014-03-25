#include <sourcemod>
#include <cstrike>

/** Begins the LO3 process. **/
public Action:BeginLO3(Handle:timer) {
	PrintToChatAll("*** Restart 1/3 ***");
	ServerCommand("mp_restartgame 1");
	CreateTimer(3.0, Restart2);
}

public Action:Restart2(Handle:timer) {
	PrintToChatAll("*** Restart 2/3 ***");
	ServerCommand("mp_restartgame 1");
	CreateTimer(4.0, Restart3);
}

public Action:Restart3(Handle:timer) {
	PrintToChatAll("*** Restart 3/3 ***");
	ServerCommand("mp_restartgame 5");
	CreateTimer(5.1, MatchLive);
}

public Action:MatchLive(Handle:timer) {
	for (new i = 0; i < 5; i++)
		PrintToChatAll("****** Match is LIVE ******");
}

/** Begins the LO3 process. **/
public Action:BeginLO3(Handle:timer) {
    if (!g_MatchLive)
        return;

    // reset player tags
    for (new i = 1; i <= MaxClients; i++)
        if (IsValidClient(i) && !IsFakeClient(i))
            CS_SetClientClanTag(i, "");

    PrintToChatAll("*** Restart 1/3 ***");
    ServerCommand("mp_restartgame 1");
    CreateTimer(3.0, Restart2);
}

public Action:Restart2(Handle:timer) {
    if (!g_MatchLive)
        return;

    PrintToChatAll("*** Restart 2/3 ***");
    ServerCommand("mp_restartgame 1");
    CreateTimer(4.0, Restart3);
}

public Action:Restart3(Handle:timer) {
    if (!g_MatchLive)
        return;

    PrintToChatAll("*** Restart 3/3 ***");
    ServerCommand("mp_restartgame 5");
    CreateTimer(5.1, MatchLive);
}

public Action:MatchLive(Handle:timer) {
    if (!g_MatchLive)
        return;

    for (new i = 0; i < 5; i++)
        PrintToChatAll("****** Match is LIVE ******");
}

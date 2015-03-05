/** Begins the LO3 process. **/
public Action BeginLO3(Handle timer) {
    if (!g_InStartPhase)
        return Plugin_Handled;

    Call_StartForward(g_hOnGoingLive);
    Call_Finish();

    // force kill the warmup if we need to
    if (InWarmup()) {
        EndWarmup();
    }

    // reset player tags
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i)) {
            UpdateClanTag(i, true); // force strip them
        }
    }

    if (GetConVarInt(g_hQuickRestarts) == 0) {
        // start lo3
        PugSetupMessageToAll("%t", "RestartCounter", 1);
        ServerCommand("mp_restartgame 1");
        CreateTimer(3.0, Restart2);
    } else {
        // single restart
        ServerCommand("mp_restartgame 5");
        CreateTimer(5.1, MatchLive);
    }

    return Plugin_Handled;
}

public Action Restart2(Handle timer) {
    if (!g_InStartPhase)
        return Plugin_Handled;

    PugSetupMessageToAll("%t", "RestartCounter", 2);
    ServerCommand("mp_restartgame 1");
    CreateTimer(4.0, Restart3);

    return Plugin_Handled;
}

public Action Restart3(Handle timer) {
    if (!g_InStartPhase)
        return;

    PugSetupMessageToAll("%t", "RestartCounter", 3);
    ServerCommand("mp_restartgame 5");
    CreateTimer(5.1, MatchLive);
}

public Action MatchLive(Handle timer) {
    if (!g_InStartPhase)
        return;

    g_MatchLive = true;
    g_InStartPhase = false;
    Call_StartForward(g_hOnLive);
    Call_Finish();

    for (int i = 0; i < 5; i++)
        PugSetupMessageToAll("%t", "Live");
}

public Action StartKnifeRound(Handle timer) {
    if (!g_InStartPhase)
        return Plugin_Handled;

    // reset player tags
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i)) {
            UpdateClanTag(i, true); // force strip them
        }
    }

    ServerCommand("exec sourcemod/pugsetup/knife");
    g_WaitingForKnifeWinner = true;
    g_WaitingForKnifeDecision = false;
    ServerCommand("mp_restartgame 1");

    // This is done on a delay since the cvar changes from
    // the knife cfg execute have their own delay of when they are printed
    // into global chat.
    CreateTimer(1.0, Timer_AnnounceKnife);
    return Plugin_Handled;
}

public Action Timer_AnnounceKnife(Handle timer) {
    if (!g_InStartPhase)
        return Plugin_Handled;

    for (int i = 0; i < 5; i++)
        PugSetupMessageToAll("%t", "KnifeRound");
    return Plugin_Handled;
}

public void EndKnifeRound() {
    ExecGameConfigs();
    g_WaitingForKnifeWinner = false;
    CreateTimer(3.0, BeginLO3, _, TIMER_FLAG_NO_MAPCHANGE);
}

static bool AwaitingDecision(int client) {
    if (!g_InStartPhase)
        return false;

    if (!g_WaitingForKnifeDecision)
        return false;

    // always lets console make the decision
    if (client == 0)
        return true;

    // check if they're on the winning team
    return IsPlayer(client) && GetClientTeam(client) == g_KnifeWinner;
}

public Action Command_Stay(int client, int args) {
    if (AwaitingDecision(client)) {
        g_WaitingForKnifeDecision = false;
        EndKnifeRound();
    }
}

public Action Command_Swap(int client, int args) {
    if (AwaitingDecision(client)) {
        g_WaitingForKnifeDecision = false;
        for (int i = 1; i <= MaxClients; i++) {
            if (IsPlayer(i)) {
                int team = GetClientTeam(i);
                if (team == CS_TEAM_T)
                    SwitchPlayerTeam(i, CS_TEAM_CT);
                else if (team == CS_TEAM_CT)
                    SwitchPlayerTeam(i, CS_TEAM_T);
            }
        }
        EndKnifeRound();
    }
}

public Action Command_Ct(int client, int args) {
    if (IsPlayer(client)) {
        if (GetClientTeam(client) == CS_TEAM_CT)
            FakeClientCommand(client, "sm_stay");
        else if (GetClientTeam(client) == CS_TEAM_T)
            FakeClientCommand(client, "sm_swap");
    }
    return Plugin_Handled;
}

public Action Command_T(int client, int args) {
    if (IsPlayer(client)) {
        if (GetClientTeam(client) == CS_TEAM_T)
            FakeClientCommand(client, "sm_stay");
        else if (GetClientTeam(client) == CS_TEAM_CT)
            FakeClientCommand(client, "sm_swap");
    }
    return Plugin_Handled;
}


// See include/pugsetup.inc for documentation.

public APLRes AskPluginLoad2(Handle myself, bool late, char error[], err_max) {
    CreateNative("IsReady", Native_IsReady);
    CreateNative("IsSetup", Native_IsSetup);
    CreateNative("GetTeamType", Native_GetTeamType);
    CreateNative("GetMapType", Native_GetMapType);
    CreateNative("IsMatchLive", Native_IsMatchLive);
    CreateNative("SetLeader", Native_SetLeader);
    CreateNative("GetLeader", Native_GetLeader);
    CreateNative("SetCaptain1", Native_SetCaptain1);
    CreateNative("GetCaptain1", Native_GetCaptain1);
    CreateNative("SetCaptain2", Native_SetCaptain2);
    CreateNative("GetCaptain2", Native_GetCaptain2);
    CreateNative("PugSetupMessage", Native_PugSetupMessage);
    CreateNative("PugSetupMessageToAll", Native_PugSetupMessageToAll);
    CreateNative("GetPugMaxPlayers", Native_GetPugMaxPlayers);
    CreateNative("SetupGame", Native_SetupGame);
    RegPluginLibrary("pugsetup");
    return APLRes_Success;
}

public Native_IsReady(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    return g_Ready[client];
}

public Native_IsSetup(Handle plugin, numParams) {
    return g_Setup;
}

public Native_GetMapType(Handle plugin, numParams) {
    return _:g_MapType;
}

public Native_GetTeamType(Handle plugin, numParams) {
    return _:g_TeamType;
}

public Native_IsMatchLive(Handle plugin, numParams) {
    return g_MatchLive;
}

public Native_SetLeader(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (IsPlayer(client)) {
        PugSetupMessageToAll("The new leader is {GREEN}%N", client);
        g_Leader = GetSteamAccountID(client);
    }
}

public Native_GetLeader(Handle plugin, numParams) {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientConnected(i) && !IsFakeClient(i) && GetSteamAccountID(i) == g_Leader)
            return i;
    }

    int r = RandomPlayer();
    if (IsPlayer(r))
        g_Leader = GetSteamAccountID(r);
    return r;
}

public Native_SetCaptain1(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (IsPlayer(client)) {
        g_capt1 = client;
        PugSetupMessageToAll("Captain 1 will be {PINK}%N", g_capt1);
    }

}

public Native_GetCaptain1(Handle plugin, numParams) {
    if (IsValidClient(g_capt1) && !IsFakeClient(g_capt1))
        return g_capt1;
    else
        return -1;
}

public Native_SetCaptain2(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    if (IsPlayer(client)) {
        g_capt2 = client;
        PugSetupMessageToAll("Captain 2 will be {LIGHT_GREEN}%N", g_capt2);
    }
}

public Native_GetCaptain2(Handle plugin, numParams) {
    if (IsValidClient(g_capt2) && !IsFakeClient(g_capt2))
        return g_capt2;
    else
        return -1;
}

public Native_PugSetupMessage(Handle plugin, numParams) {
    int client = GetNativeCell(1);
    char buffer[1024];
    int bytesWritten = 0;
    FormatNativeString(0, 2, 3, sizeof(buffer), bytesWritten, buffer);

    char finalMsg[1024];
    Format(finalMsg, sizeof(finalMsg), "%s%s", MESSAGE_PREFIX, buffer);

    Colorize(finalMsg, sizeof(finalMsg));
    PrintToChat(client, finalMsg);
}

public Native_PugSetupMessageToAll(Handle plugin, numParams) {
    char buffer[1024];
    int bytesWritten = 0;
    FormatNativeString(0, 1, 2, sizeof(buffer), bytesWritten, buffer);

    char finalMsg[1024];
    Format(finalMsg, sizeof(finalMsg), "%s%s", MESSAGE_PREFIX, buffer);

    Colorize(finalMsg, sizeof(finalMsg));
    PrintToChatAll(finalMsg);
}

public Native_GetPugMaxPlayers(Handle plugin, numParams) {
    return 2 * g_PlayersPerTeam;
}

public Native_SetupGame(Handle plugin, numParams) {
    if (g_MatchLive) {
        return false;
    }

    g_TeamType = TeamType:GetNativeCell(1);
    g_MapType = MapType:GetNativeCell(2);
    g_PlayersPerTeam = GetNativeCell(3);
    g_AutoLO3 = bool:GetNativeCell(4);
    g_PickingPlayers = false;
    g_capt1 = -1;
    g_capt2 = -1;
    g_Setup = true;
    g_PickingPlayers = false;
    for (int i = 1; i <= MaxClients; i++)
        g_Ready[i] = false;

    SetupFinished();
    return true;
}

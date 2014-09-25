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
    RegPluginLibrary("pugsetup");
    return APLRes_Success;
}

public Native_IsReady(Handle plugin, int numParams) {
    int client = GetNativeCell(1);
    return g_Ready[client];
}

public Native_IsSetup(Handle plugin, int numParams) {
    return g_Setup;
}

public Native_GetMapType(Handle plugin, int numParams) {
    return _:g_MapType;
}

public Native_GetTeamType(Handle plugin, int numParams) {
    return _:g_TeamType;
}

public Native_IsMatchLive(Handle plugin, int numParams) {
    return g_MatchLive;
}

public Native_SetLeader(Handle plugin, int numParams) {
    int client = GetNativeCell(1);
    if (IsPlayer(client)) {
        PugSetupMessageToAll("%t", "NewLeader", client);
        g_Leader = GetSteamAccountID(client);
    }
}

public Native_GetLeader(Handle plugin, int numParams) {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientConnected(i) && !IsFakeClient(i) && GetSteamAccountID(i) == g_Leader)
            return i;
    }

    int r = RandomPlayer();
    if (IsPlayer(r))
        g_Leader = GetSteamAccountID(r);
    return r;
}

public Native_SetCaptain1(Handle plugin, int numParams) {
    int client = GetNativeCell(1);
    if (IsPlayer(client)) {
        g_capt1 = client;
        PugSetupMessageToAll("%t", "Capt1Message", g_capt1);
    }

}

public Native_GetCaptain1(Handle plugin, int numParams) {
    if (IsValidClient(g_capt1) && !IsFakeClient(g_capt1))
        return g_capt1;
    else
        return -1;
}

public Native_SetCaptain2(Handle plugin, int numParams) {
    int client = GetNativeCell(1);
    if (IsPlayer(client)) {
        g_capt2 = client;
        PugSetupMessageToAll("%t", "Capt2Message", g_capt2);
    }
}

public Native_GetCaptain2(Handle plugin, int numParams) {
    if (IsValidClient(g_capt2) && !IsFakeClient(g_capt2))
        return g_capt2;
    else
        return -1;
}

public Native_PugSetupMessage(Handle plugin, int numParams) {
    int client = GetNativeCell(1);

    if (!IsPlayer(client))
        return;

    char buffer[1024];
    int bytesWritten = 0;
    FormatNativeString(0, 2, 3, sizeof(buffer), bytesWritten, buffer);

    char finalMsg[1024];
    if (GetConVarInt(g_hUseMessagePrefix) == 0)
        Format(finalMsg, sizeof(finalMsg), " %s", buffer);
    else
        Format(finalMsg, sizeof(finalMsg), "%s%s", MESSAGE_PREFIX, buffer);

    Colorize(finalMsg, sizeof(finalMsg));

    PrintToChat(client, finalMsg);
}

public Native_PugSetupMessageToAll(Handle plugin, int numParams) {
    char buffer[1024];
    int bytesWritten = 0;
    FormatNativeString(0, 1, 2, sizeof(buffer), bytesWritten, buffer);

    char finalMsg[1024];
    if (GetConVarInt(g_hUseMessagePrefix) == 0)
        Format(finalMsg, sizeof(finalMsg), " %s", buffer);
    else
        Format(finalMsg, sizeof(finalMsg), "%s%s", MESSAGE_PREFIX, buffer);

    Colorize(finalMsg, sizeof(finalMsg));

    PrintToChatAll(finalMsg);
}

public Native_GetPugMaxPlayers(Handle plugin, int numParams) {
    return 2 * g_PlayersPerTeam;
}

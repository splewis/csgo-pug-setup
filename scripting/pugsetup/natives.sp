// See include/pugsetup.inc for documentation.

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
    CreateNative("IsReady", Native_IsReady);
    CreateNative("IsSetup", Native_IsSetup);
    CreateNative("IsMatchLive", Native_IsMatchLive);
    CreateNative("GetLeader", Native_GetLeader);
    CreateNative("GetCaptain1", Native_GetCaptain1);
    CreateNative("GetCaptain2", Native_GetCaptain2);
    CreateNative("PugSetupMessage", Native_PugSetupMessage);
    CreateNative("PugSetupMessageToAll", Native_PugSetupMessageToAll);
    CreateNative("GetPugMaxPlayers", Native_GetPugMaxPlayers);
    RegPluginLibrary("pugsetup");
    return APLRes_Success;
}

public Native_IsReady(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    return g_Ready[client];
}

public Native_IsSetup(Handle:plugin, numParams) {
    return g_Setup;
}

public Native_IsMatchLive(Handle:plugin, numParams) {
    return g_MatchLive;
}

public Native_GetLeader(Handle:plugin, numParams) {
    for (new i = 1; i <= MaxClients; i++) {
        if (IsClientConnected(i) && !IsFakeClient(i) && GetSteamAccountID(i) == g_Leader)
            return i;
    }

    new r = RandomPlayer();
    if (IsPlayer(r))
        g_Leader = GetSteamAccountID(r);
    return r;
}

public Native_GetCaptain1(Handle:plugin, numParams) {
    if (IsValidClient(g_capt1) && !IsFakeClient(g_capt1))
        return g_capt1;
    else
        return -1;
}

public Native_GetCaptain2(Handle:plugin, numParams) {
    if (IsValidClient(g_capt2) && !IsFakeClient(g_capt2))
        return g_capt2;
    else
        return -1;
}

public Native_PugSetupMessage(Handle:plugin, numParams) {
    new client = GetNativeCell(1);
    decl String:buffer[1024];
    new bytesWritten = 0;
    FormatNativeString(0, 2, 3, sizeof(buffer), bytesWritten, buffer);

    decl String:finalMsg[1024];
    Format(finalMsg, sizeof(finalMsg), "%s%s", MESSAGE_PREFIX, buffer);

    Colorize(finalMsg, sizeof(finalMsg));
    PrintToChat(client, finalMsg);
}

public Native_PugSetupMessageToAll(Handle:plugin, numParams) {
    decl String:buffer[1024];
    new bytesWritten = 0;
    FormatNativeString(0, 1, 2, sizeof(buffer), bytesWritten, buffer);

    decl String:finalMsg[1024];
    Format(finalMsg, sizeof(finalMsg), "%s%s", MESSAGE_PREFIX, buffer);

    Colorize(finalMsg, sizeof(finalMsg));
    PrintToChatAll(finalMsg);
}

public Native_GetPugMaxPlayers(Handle:plugin, numParams) {
    return 2 * g_PlayersPerTeam;
}

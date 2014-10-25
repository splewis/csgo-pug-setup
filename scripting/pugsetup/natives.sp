// See include/pugsetup.inc for documentation.

public APLRes AskPluginLoad2(Handle myself, bool late, char error[], err_max) {
    CreateNative("SetupGame", Native_SetupGame);
    CreateNative("ClearGameTypes", Native_ClearGameTypes);
    CreateNative("FindGameType", Native_FindGameType);
    CreateNative("AddGameType", Native_AddGameType);
    CreateNative("ReadyPlayer", Native_ReadyPlayer);
    CreateNative("UnreadyPlayer", Native_UnreadyPlayer);
    CreateNative("IsReady", Native_IsReady);
    CreateNative("IsSetup", Native_IsSetup);
    CreateNative("GetTeamType", Native_GetTeamType);
    CreateNative("GetMapType", Native_GetMapType);
    CreateNative("IsMatchLive", Native_IsMatchLive);
    CreateNative("SetLeader", Native_SetLeader);
    CreateNative("GetLeader", Native_GetLeader);
    CreateNative("GetCaptain", Native_GetCaptain);
    CreateNative("SetCaptain", Native_SetCaptain);
    CreateNative("PugSetupMessage", Native_PugSetupMessage);
    CreateNative("PugSetupMessageToAll", Native_PugSetupMessageToAll);
    CreateNative("GetPugMaxPlayers", Native_GetPugMaxPlayers);
    CreateNative("PlayerAtStart", Native_PlayerAtStart);
    CreateNative("IsPugAdmin", Native_IsPugAdmin);
    CreateNative("HasPermissions", Native_HasPermissions);
    CreateNative("SetRandomCaptains", Native_SetRandomCaptains);
    RegPluginLibrary("pugsetup");
    return APLRes_Success;
}

public Native_SetupGame(Handle plugin, int numParams) {
    g_GameTypeIndex = GetNativeCell(1);
    g_TeamType = TeamType:GetNativeCell(2);
    g_MapType = MapType:GetNativeCell(3);
    g_PlayersPerTeam = GetNativeCell(4);
    g_AutoLO3 = GetNativeCell(5);
    SetupFinished();
}

public Native_ClearGameTypes(Handle plugin, int numParams) {
    ClearArray(g_GameTypes);
    ClearArray(g_GameConfigFiles);
    ClearArray(g_GameMapFiles);
}

public Native_FindGameType(Handle plugin, int numParams) {
    char name[CONFIG_STRING_LENGTH];
    GetNativeString(1, name, sizeof(name));
    for (int i = 0; i < GetArraySize(g_GameTypes); i++) {
        char buffer[CONFIG_STRING_LENGTH];
        GetArrayString(g_GameTypes, i, buffer, sizeof(buffer));
        if (StrEqual(name, buffer, false)) {
            return i;
        }
    }
    return -1;
}

public Native_AddGameType(Handle plugin, int numParams) {
    char name[CONFIG_STRING_LENGTH];
    char liveCfg[CONFIG_STRING_LENGTH];
    char mapList[CONFIG_STRING_LENGTH];

    GetNativeString(1, name, sizeof(name));
    GetNativeString(2, liveCfg, sizeof(liveCfg));
    GetNativeString(3, mapList, sizeof(mapList));
    bool showInMenu = GetNativeCell(4);
    int teamSize = GetNativeCell(5);

    // Check for existence of live cfg
    char path[PLATFORM_MAX_PATH];
    Format("cfg/%s", sizeof(path), liveCfg);
    if (!FileExists(path)) {
        LogError("Gametype \"%s\" uses non-existent live cfg: \"%s\"", name, liveCfg);
    }

    // Check for existence of map file
    BuildPath(Path_SM, path, sizeof(path), "configs/pugsetup/%s", mapList);
    if (!FileExists(path)) {
        LogError("Gametype \"%s\" uses non-existent map list: \"%s\"", name, mapList);
    }

    PushArrayString(g_GameTypes, name);
    PushArrayString(g_GameConfigFiles, liveCfg);
    PushArrayString(g_GameMapFiles, mapList);
    PushArrayCell(g_GameTypeHidden, !showInMenu);
    PushArrayCell(g_GameTypeTeamSize, teamSize);
    return GetArraySize(g_GameTypes) - 1;
}

public Native_ReadyPlayer(Handle plugin, int numParams) {
    int client = GetNativeCell(1);

    if (!g_Setup || g_MatchLive || !IsPlayer(client))
        return;

    if (GetConVarInt(g_hExcludeSpectators) != 0 && GetClientTeam(client) == CS_TEAM_SPECTATOR) {
        PugSetupMessage(client, "%t", "SpecCantReady");
        return;
    }

    Call_StartForward(g_hOnReady);
    Call_PushCell(client);
    Call_Finish();

    g_Ready[client] = true;
    CS_SetClientClanTag(client, "[Ready]");
}

public Native_UnreadyPlayer(Handle plugin, int numParams) {
    int client = GetNativeCell(1);

    if (!g_Setup || g_MatchLive || !IsPlayer(client))
        return;

    Call_StartForward(g_hOnUnready);
    Call_PushCell(client);
    Call_Finish();

    g_Ready[client] = false;
    CS_SetClientClanTag(client, "[Not ready]");
}

public Native_IsReady(Handle plugin, int numParams) {
    int client = GetNativeCell(1);
    if (!IsPlayer(client))
        ThrowNativeError(SP_ERROR_PARAM, "Client %d is not a player", client);
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

public Native_SetCaptain(Handle plugin, int numParams) {
    int captainNumber = GetNativeCell(1);
    int client = GetNativeCell(2);
    if (IsPlayer(client)) {
        if (captainNumber == 1)
            g_capt1 = client;
        else
            g_capt2 = client;

        char buffer[64];
        FormatPlayerName(client, client, buffer);
        PugSetupMessageToAll("%t", "CaptMessage", captainNumber, buffer);
    }

}

public Native_GetCaptain(Handle plugin, int numParams) {
    int captainNumber = GetNativeCell(1);
    int capt = (captainNumber == 1) ? g_capt1 : g_capt2;

    if (IsValidClient(capt) && !IsFakeClient(capt))
        return capt;
    else
        return -1;
}

public Native_PugSetupMessage(Handle plugin, int numParams) {
    int client = GetNativeCell(1);

    if (!IsPlayer(client))
        return;

    char buffer[1024];
    int bytesWritten = 0;
    SetGlobalTransTarget(client);
    FormatNativeString(0, 2, 3, sizeof(buffer), bytesWritten, buffer);

    char prefix[64];
    GetConVarString(g_hMessagePrefix, prefix, sizeof(prefix));

    char finalMsg[1024];
    if (StrEqual(prefix, ""))
        Format(finalMsg, sizeof(finalMsg), " %s", buffer);
    else
        Format(finalMsg, sizeof(finalMsg), "%s %s", prefix, buffer);

    Colorize(finalMsg, sizeof(finalMsg));
    PrintToChat(client, finalMsg);
    SetGlobalTransTarget(LANG_SERVER);
}

public Native_PugSetupMessageToAll(Handle plugin, int numParams) {
    char prefix[64];
    GetConVarString(g_hMessagePrefix, prefix, sizeof(prefix));
    char buffer[1024];
    int bytesWritten = 0;

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsPlayer(i))
            continue;

        SetGlobalTransTarget(i);
        FormatNativeString(0, 1, 2, sizeof(buffer), bytesWritten, buffer);

        char finalMsg[1024];
        if (StrEqual(prefix, ""))
            Format(finalMsg, sizeof(finalMsg), " %s", buffer);
        else
            Format(finalMsg, sizeof(finalMsg), "%s %s", prefix, buffer);

        Colorize(finalMsg, sizeof(finalMsg));
        PrintToChat(i, finalMsg);
    }

    SetGlobalTransTarget(LANG_SERVER);
}

public Native_GetPugMaxPlayers(Handle plugin, int numParams) {
    return 2 * g_PlayersPerTeam;
}

public Native_PlayerAtStart(Handle plugin, int numParams) {
    int client = GetNativeCell(1);
    return IsPlayer(client) && g_PlayerAtStart[client];
}

public Native_IsPugAdmin(Handle plugin, int numParams) {
    int client = GetNativeCell(1);
    AdminId admin = GetUserAdmin(client);
    if (admin != INVALID_ADMIN_ID) {
        char flags[8];
        AdminFlag flag;
        GetConVarString(g_hAdminFlag, flags, sizeof(flags));
        if (!FindFlagByChar(flags[0], flag)) {
            LogError("Invalid immunity flag: %s", flags[0]);
            return false;
        } else {
            return GetAdminFlag(admin, flag);
        }
    }

    return false;
}

public Native_HasPermissions(Handle plugin, int numParams) {
    int client = GetNativeCell(1);
    Permissions p = Permissions:GetNativeCell(2);

    if (client == 0)
        return true;

    if (!IsPlayer(client))
        return false;

    bool isAdmin = IsPugAdmin(client);
    bool isLeader = (GetLeader() == client) || isAdmin;
    bool isCapt = (isLeader) || (client == g_capt1) || (client == g_capt2);

    if (p == Permission_Leader)
        return isLeader;
    else if (p == Permission_Captains)
        return isCapt;
    else
        ThrowNativeError(SP_ERROR_PARAM, "Unknown permission value: %d", p);

    return false;
}

public Native_SetRandomCaptains(Handle plugin, int numParams) {
    int c1 = -1;
    int c2 = -1;

    c1 = RandomPlayer();
    while (!IsPlayer(c2) || c1 == c2) {
        if (GetRealClientCount() < 2)
            break;

        c2 = RandomPlayer();
    }

    SetCaptain(1, c1);
    SetCaptain(2, c2);
}

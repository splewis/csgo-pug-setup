// See include/pugsetup.inc for documentation.

#define CHECK_CLIENT(%1) if (!IsValidClient(%1)) ThrowNativeError(SP_ERROR_PARAM, "Client %d is not connected", %1)
#define CHECK_CAPTAIN(%1) if (%1 != 1 && %1 != 2) ThrowNativeError(SP_ERROR_PARAM, "Captain number %d is not valid", %1)
#define CHECK_COMMAND(%1) if (!IsValidCommand(%1)) ThrowNativeError(SP_ERROR_PARAM, "Pugsetup command %s is not valid", %1)


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    g_ChatAliases = new ArrayList(ALIAS_LENGTH);
    g_ChatAliasesCommands = new ArrayList(COMMAND_LENGTH);
    g_MapList = new ArrayList(PLATFORM_MAX_PATH);
    g_PermissionsMap = new StringMap();

    CreateNative("SetupGame", Native_SetupGame);
    CreateNative("SetSetupOptions", Native_SetSetupOptions);
    CreateNative("GetSetupOptions", Native_GetSetupOptions);
    CreateNative("ReadyPlayer", Native_ReadyPlayer);
    CreateNative("UnreadyPlayer", Native_UnreadyPlayer);
    CreateNative("IsReady", Native_IsReady);
    CreateNative("IsSetup", Native_IsSetup);
    CreateNative("GetTeamType", Native_GetTeamType);
    CreateNative("GetMapType", Native_GetMapType);
    CreateNative("GetGameState", Native_GetGameState);
    CreateNative("IsMatchLive", Native_IsMatchLive);
    CreateNative("IsPendingStart", Native_IsPendingStart);
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
    CreateNative("AddChatAlias", Native_AddChatAlias);
    CreateNative("GiveSetupMenu", Native_GiveSetupMenu);
    CreateNative("IsValidCommand", Native_IsValidCommand);
    CreateNative("GetPermissions", Native_GetPermissions);
    CreateNative("SetPermissions", Native_SetPermissions);
    RegPluginLibrary("pugsetup");
    return APLRes_Success;
}

public int Native_SetupGame(Handle plugin, int numParams) {
    g_TeamType = view_as<TeamType>(GetNativeCell(1));
    g_MapType = view_as<MapType>(GetNativeCell(2));
    g_PlayersPerTeam = GetNativeCell(3);

    // optional parameters added, checking is they were
    // passed for backwards compatibility
    if (numParams >= 4) {
        g_RecordGameOption = GetNativeCell(4);
    }

    if (numParams >= 5) {
        g_DoKnifeRound = GetNativeCell(5);
    }

    if (numParams >= 6) {
        g_AutoLive = GetNativeCell(6);
    }

    SetupFinished();
}

public int Native_GetSetupOptions(Handle plugin, int numParams) {
    if (!IsSetup()) {
        ThrowNativeError(SP_ERROR_ABORTED, "Cannot get setup options when a match is not setup.");
    }

    SetNativeCellRef(1, g_TeamType);
    SetNativeCellRef(2, g_MapType);
    SetNativeCellRef(3, g_PlayersPerTeam);
    SetNativeCellRef(4, g_RecordGameOption);
    SetNativeCellRef(5, g_DoKnifeRound);
    SetNativeCellRef(6, g_AutoLive);
}

public int Native_SetSetupOptions(Handle plugin, int numParams) {
    g_TeamType = view_as<TeamType>(GetNativeCell(1));
    g_MapType = view_as<MapType>(GetNativeCell(2));
    g_PlayersPerTeam = GetNativeCell(3);
    g_RecordGameOption = GetNativeCell(4);
    g_DoKnifeRound = GetNativeCell(5);
    g_AutoLive = GetNativeCell(6);
}

public int Native_ReadyPlayer(Handle plugin, int numParams) {
    int client = GetNativeCell(1);
    CHECK_CLIENT(client);

    if (g_GameState != GameState_Warmup || !IsPlayer(client))
        return;

    if (g_hExcludeSpectators.IntValue != 0 && GetClientTeam(client) == CS_TEAM_SPECTATOR) {
        PugSetupMessage(client, "%t", "SpecCantReady");
        return;
    }

    Call_StartForward(g_hOnReady);
    Call_PushCell(client);
    Call_Finish();

    g_Ready[client] = true;
    UpdateClanTag(client);
}

public int Native_UnreadyPlayer(Handle plugin, int numParams) {
    int client = GetNativeCell(1);
    CHECK_CLIENT(client);

    if (g_GameState != GameState_Warmup || !IsPlayer(client))
        return;

    Call_StartForward(g_hOnUnready);
    Call_PushCell(client);
    Call_Finish();

    g_Ready[client] = false;
    UpdateClanTag(client);
}

public int Native_IsReady(Handle plugin, int numParams) {
    int client = GetNativeCell(1);
    CHECK_CLIENT(client);

    return g_Ready[client];
}

public int Native_IsSetup(Handle plugin, int numParams) {
    return view_as<int>(g_GameState >= GameState_Warmup);
}

public int Native_GetMapType(Handle plugin, int numParams) {
    return view_as<int>(g_MapType);
}

public int Native_GetTeamType(Handle plugin, int numParams) {
    return view_as<int>(g_TeamType);
}

public int Native_GetGameState(Handle plugin, int numParams) {
    return view_as<int>(g_GameState);
}

public int Native_IsMatchLive(Handle plugin, int numParams) {
    return g_GameState == GameState_Live;
}

public int Native_IsPendingStart(Handle plugin, int numParams) {
    return g_GameState >= GameState_PickingPlayers && g_GameState <= GameState_GoingLive;
}

public int Native_SetLeader(Handle plugin, int numParams) {
    int client = GetNativeCell(1);
    CHECK_CLIENT(client);

    if (IsPlayer(client)) {
        PugSetupMessageToAll("%t", "NewLeader", client);
        g_Leader = GetSteamAccountID(client);
    }
}

public int Native_GetLeader(Handle plugin, int numParams) {
    // first check if our "leader" is still connected
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientConnected(i) && !IsFakeClient(i) && GetSteamAccountID(i) == g_Leader)
            return i;
    }

    // then check if we have someone with admin permissions
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i) && IsPugAdmin(i)) {
            g_Leader = GetSteamAccountID(i);
            return i;
        }
    }

    // otherwise fall back to a random player
    int r = RandomPlayer();
    if (IsPlayer(r))
        g_Leader = GetSteamAccountID(r);

    return r;
}

public int Native_SetCaptain(Handle plugin, int numParams) {
    int captainNumber = GetNativeCell(1);
    CHECK_CAPTAIN(captainNumber);

    int client = GetNativeCell(2);
    CHECK_CLIENT(client);

    bool printIfSame = false;
    // backwards compatability
    if (numParams >= 3) {
        printIfSame = GetNativeCell(3);
    }

    if (IsPlayer(client)) {
        int originalCaptain = -1;
        if (captainNumber == 1) {
            originalCaptain = g_capt1;
            g_capt1 = client;
        }  else {
            originalCaptain = g_capt2;
            g_capt2 = client;
        }

        // Only printout if it's a different captain
        if (printIfSame || client != originalCaptain) {
            char buffer[64];
            FormatPlayerName(client, client, buffer);
            PugSetupMessageToAll("%t", "CaptMessage", captainNumber, buffer);
        }

    }
}

public int Native_GetCaptain(Handle plugin, int numParams) {
    int captainNumber = GetNativeCell(1);
    CHECK_CAPTAIN(captainNumber);

    int capt = (captainNumber == 1) ? g_capt1 : g_capt2;

    if (IsValidClient(capt) && !IsFakeClient(capt))
        return capt;
    else
        return -1;
}

public int Native_PugSetupMessage(Handle plugin, int numParams) {
    int client = GetNativeCell(1);
    if (client != 0 && (!IsClientConnected(client) || !IsClientInGame(client)))
        return;

    char buffer[1024];
    int bytesWritten = 0;
    SetGlobalTransTarget(client);
    FormatNativeString(0, 2, 3, sizeof(buffer), bytesWritten, buffer);

    char prefix[64];
    g_hMessagePrefix.GetString(prefix, sizeof(prefix));

    char finalMsg[1024];
    if (StrEqual(prefix, ""))
        Format(finalMsg, sizeof(finalMsg), " %s", buffer);
    else
        Format(finalMsg, sizeof(finalMsg), "%s %s", prefix, buffer);

    if (client == 0) {
        Colorize(finalMsg, sizeof(finalMsg), false);
        PrintToConsole(client, finalMsg);
    } else if (IsClientInGame(client)) {
        Colorize(finalMsg, sizeof(finalMsg));
        PrintToChat(client, finalMsg);
    }

}

public int Native_PugSetupMessageToAll(Handle plugin, int numParams) {
    char prefix[64];
    g_hMessagePrefix.GetString(prefix, sizeof(prefix));
    char buffer[1024];
    int bytesWritten = 0;

    for (int i = 0; i <= MaxClients; i++) {
        if (i != 0 && (!IsClientConnected(i) || !IsClientInGame(i)))
            continue;

        SetGlobalTransTarget(i);
        FormatNativeString(0, 1, 2, sizeof(buffer), bytesWritten, buffer);

        char finalMsg[1024];
        if (StrEqual(prefix, ""))
            Format(finalMsg, sizeof(finalMsg), " %s", buffer);
        else
            Format(finalMsg, sizeof(finalMsg), "%s %s", prefix, buffer);

        if (i != 0) {
            Colorize(finalMsg, sizeof(finalMsg));
            PrintToChat(i, finalMsg);
        } else {
            Colorize(finalMsg, sizeof(finalMsg), false);
            PrintToConsole(i, finalMsg);
        }
    }
}

public int Native_GetPugMaxPlayers(Handle plugin, int numParams) {
    return 2 * g_PlayersPerTeam;
}

public int Native_PlayerAtStart(Handle plugin, int numParams) {
    int client = GetNativeCell(1);
    return IsPlayer(client) && g_PlayerAtStart[client];
}

public int Native_IsPugAdmin(Handle plugin, int numParams) {
    int client = GetNativeCell(1);
    CHECK_CLIENT(client);

    AdminId admin = GetUserAdmin(client);
    if (admin != INVALID_ADMIN_ID) {
        char flags[8];
        AdminFlag flag;
        g_hAdminFlag.GetString(flags, sizeof(flags));
        if (!FindFlagByChar(flags[0], flag)) {
            LogError("Invalid immunity flag: %s", flags[0]);
            return false;
        } else {
            return GetAdminFlag(admin, flag);
        }
    }

    return false;
}

public int Native_HasPermissions(Handle plugin, int numParams) {
    int client = GetNativeCell(1);
    if (client == 0)
        return true;

    CHECK_CLIENT(client);

    Permissions p = view_as<Permissions>(GetNativeCell(2));
    bool isAdmin = IsPugAdmin(client);
    bool isLeader = GetLeader() == client;
    bool isCapt = (client == g_capt1) || (client == g_capt2);

    if (p == Permission_Admin)
        return isAdmin;
    else if (p == Permission_Leader)
        return isLeader || isAdmin;
    else if (p == Permission_Captains)
        return isCapt || isLeader || isAdmin;
    else if (p == Permission_All)
        return true;
    else
        ThrowNativeError(SP_ERROR_PARAM, "Unknown permission value: %d", p);

    return false;
}

public int Native_SetRandomCaptains(Handle plugin, int numParams) {
    int c1 = -1;
    int c2 = -1;

    c1 = RandomPlayer();
    while (!IsPlayer(c2) || c1 == c2) {
        if (GetRealClientCount() < 2)
            break;

        c2 = RandomPlayer();
    }

    if (IsPlayer(c1))
        SetCaptain(1, c1, true);

    if (IsPlayer(c2))
        SetCaptain(2, c2, true);
}

public int Native_AddChatAlias(Handle plugin, int numParams) {
    char alias[ALIAS_LENGTH];
    char command[COMMAND_LENGTH];
    GetNativeString(1, alias, sizeof(alias));
    GetNativeString(2, command, sizeof(command));

    // don't allow duplicate aliases to be added
    if (g_ChatAliases.FindString(alias) == -1) {
        LogDebug("AddChatAlias(%s, %s)", alias, command);
        g_ChatAliases.PushString(alias);
        g_ChatAliasesCommands.PushString(command);
    }
}

public int Native_GiveSetupMenu(Handle plugin, int numParams) {
    int client = GetNativeCell(1);
    CHECK_CLIENT(client);
    bool displayOnly = GetNativeCell(2);

    // backwards compatability
    int menuPosition = -1;
    if (numParams >= 3) {
        menuPosition = GetNativeCell(3);
    }

    SetupMenu(client, displayOnly, menuPosition);
}

public int Native_IsValidCommand(Handle plugin, int numParams) {
    char command[COMMAND_LENGTH];
    GetNativeString(1, command, sizeof(command));
    return g_Commands.FindString(command) != -1;
}

public int Native_GetPermissions(Handle plugin, int numParams) {
    char command[COMMAND_LENGTH];
    GetNativeString(1, command, sizeof(command));
    CHECK_COMMAND(command);

    Permissions p;
    g_PermissionsMap.GetValue(command, p);
    return view_as<int>(p);
}

public int Native_SetPermissions(Handle plugin, int numParams) {
    char command[COMMAND_LENGTH];
    GetNativeString(1, command, sizeof(command));
    CHECK_COMMAND(command);

    Permissions p = GetNativeCell(2);
    return view_as<int>(g_PermissionsMap.SetValue(command, p));
}

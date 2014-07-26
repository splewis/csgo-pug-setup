public Action:Command_ListNames(client, args) {
    new count = 0;
    for (new i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i) && !IsFakeClient(i) && AreClientCookiesCached(i)) {
            decl String:name[TEAM_NAME_LENGTH];
            decl String:flag[TEAM_FLAG_LENGTH];
            GetClientCookie(i, g_teamNameCookie, name, sizeof(name));
            GetClientCookie(i, g_teamFlagCookie, flag, sizeof(flag));
            ReplyToCommand(client, "%N: %s (%s)", i, name, flag);
            count++;
        }
    }
    if (count == 0)
        ReplyToCommand(client, "Nobody has a team name/flag set.");
}

public Action:Command_Name(client, args) {
    new String:arg1[128];
    new String:arg2[128];
    new String:arg3[128];
    if (args >= 3 && GetCmdArg(1, arg1, sizeof(arg1)) && GetCmdArg(2, arg2, sizeof(arg2)) && GetCmdArg(3, arg3, sizeof(arg3))) {
        new target = FindTarget(client, arg1, true, false);
        if (IsValidClient(target)) {
            SetClientCookie(target, g_teamNameCookie, arg2);
            SetClientCookie(target, g_teamFlagCookie, arg3);
        }
    } else {
        ReplyToCommand(client, "Usage: sm_name <player> <team name> <team flag>");
    }

    return Plugin_Handled;
}

public FillPotentialNames(team, Handle:names, Handle:flags) {
    for (new i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i) && !IsFakeClient(i) && GetClientTeam(i) == team &&!AreClientCookiesCached(i)) {
            decl String:name[TEAM_NAME_LENGTH];
            decl String:flag[TEAM_FLAG_LENGTH];
            GetClientCookie(i, g_teamNameCookie, name, sizeof(name));
            GetClientCookie(i, g_teamFlagCookie, flag, sizeof(flag));
            PushArrayString(names, name);
            PushArrayString(flags, flag);
        }
    }
}

public SetTeamNames() {
    new Handle:ctNames = CreateArray(TEAM_NAME_LENGTH);
    new Handle:ctFlags = CreateArray(TEAM_FLAG_LENGTH);
    new Handle:tNames = CreateArray(TEAM_NAME_LENGTH);
    new Handle:tFlags = CreateArray(TEAM_FLAG_LENGTH);

    FillPotentialNames(CS_TEAM_CT, ctNames, ctFlags);
    FillPotentialNames(CS_TEAM_T, tNames, tFlags);

    new choice = -1;
    decl String:name[TEAM_NAME_LENGTH];
    decl String:flag[TEAM_FLAG_LENGTH];

    if (GetArraySize(ctNames) > 0) {
        choice = GetArrayRandomIndex(ctNames);
        GetArrayString(ctNames, choice, name, sizeof(name));
        GetArrayString(ctFlags, choice, flag, sizeof(flag));
        SetTeamInfo(CS_TEAM_CT, name, flag);
    }

    if (GetArraySize(tNames) > 0) {
        choice = GetArrayRandomIndex(tNames);
        GetArrayString(tNames, choice, name, sizeof(name));
        GetArrayString(tFlags, choice, flag, sizeof(flag));
        SetTeamInfo(CS_TEAM_T, name, flag);
    }

    CloseHandle(ctNames);
    CloseHandle(ctFlags);
    CloseHandle(tNames);
    CloseHandle(tFlags);
}

public SetTeamInfo(team, String:name[], String:flag[]) {
    new team_int = (team == CS_TEAM_CT) ? 1 : 2;
    ServerCommand("mp_teamname_%d %s", team_int, name);
    ServerCommand("mp_teamflag_%d %s", team_int, flag);
}

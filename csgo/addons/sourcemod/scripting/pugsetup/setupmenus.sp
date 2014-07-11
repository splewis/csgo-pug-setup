/**
 * Main .setup menu
 */
public SetupMenu(client) {
    new Handle:menu = CreateMenu(SetupMenuHandler);
    SetMenuTitle(menu, "How will teams be setup?");
    SetMenuExitButton(menu, false);
    AddMenuInt(menu, _:TeamType_Captains, "Assigned captains pick their teams");
    AddMenuInt(menu, _:TeamType_Random, "Random teams");
    AddMenuInt(menu, _:TeamType_Manual, "Players manually switch teams");
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public SetupMenuHandler(Handle:menu, MenuAction:action, param1, param2) {
    if (action == MenuAction_Select) {
        new client = param1;
        g_TeamType = TeamType:GetMenuInt(menu, param2);
        GivePlayerCountMenu(client);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public GivePlayerCountMenu(client) {
    new Handle:menu = CreateMenu(PlayerCountHandler);
    SetMenuTitle(menu, "How many players per team?");
    SetMenuExitButton(menu, false);
    new any:choices[] = {1, 2, 3, 4, 5, 6};
    for (new i = 0; i < sizeof(choices); i++)
        AddMenuInt(menu, choices[i], "");

    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public PlayerCountHandler(Handle:menu, MenuAction:action, param1, param2) {
    if (action == MenuAction_Select) {
        new client = param1;
        g_PlayersPerTeam = GetMenuInt(menu, param2);
        MapMenu(client);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

/**
 * Generic map choice-type menu.
 */
public MapMenu(client) {
    new Handle:menu = CreateMenu(MapMenuHandler);
    SetMenuTitle(menu, "How will the map be chosen?");
    SetMenuExitButton(menu, false);
    AddMenuInt(menu, MapType_Current, "Use the current map");
    AddMenuInt(menu, MapType_Vote, "Vote for a map");
    AddMenuInt(menu, MapType_Veto, "Captains veto maps until 1 left");
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MapMenuHandler(Handle:menu, MenuAction:action, param1, param2) {
    if (action == MenuAction_Select) {
        new client = param1;
        g_MapType = MapType:GetMenuInt(menu, param2);
        switch (g_MapType) {
            case MapType_Current: g_mapSet = true;
            case MapType_Vote: g_mapSet = false;
            case MapType_Veto: g_mapSet = false;
            default: ERROR_FUNC("unknown maptype=%d", g_MapType);
        }
        AutoLO3Menu(client);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}


/**
 * Generic map choice-type menu.
 */
public AutoLO3Menu(client) {
    new Handle:menu = CreateMenu(AutoLO3MenuHandler);
    SetMenuTitle(menu, "Automatically start the game when ready?");
    SetMenuExitButton(menu, false);
    AddMenuBool(menu, true, "Yes");
    AddMenuBool(menu, false, "No");
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public AutoLO3MenuHandler(Handle:menu, MenuAction:action, param1, param2) {
    if (action == MenuAction_Select) {
        g_AutoLO3 = GetMenuBool(menu, param2);
        SetupFinished();
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}



/**
 * Called when the setup phase is over and the ready-up period should begin.
 */
public SetupFinished() {
    g_capt1 = -1;
    g_capt2 = -1;
    ExecCfg(g_hWarmupCfg);
    for (new i = 1; i < MaxClients; i++)
        if (IsValidClient(i) && !IsFakeClient(i))
            PrintSetupInfo(i);
    g_Setup = true;
    CreateTimer(1.0, Timer_CheckReady, _, TIMER_REPEAT);
}

/**
 * Converts enum choice types to strings to show to players.
 */
public GetTeamString(String:buffer[], length, TeamType:type) {
    switch (type) {
        case TeamType_Manual: return strcopy(buffer, length, "manual teams");
        case TeamType_Random: return strcopy(buffer, length, "random teams");
        case TeamType_Captains: return strcopy(buffer, length, "captains pick players");
        default: ERROR_FUNC("unknown teamtype=%d", type);
    }
    return 0;
}

public GetMapString(String:buffer[], length, MapType:type) {
    switch (type) {
        case MapType_Current: return strcopy(buffer, length, "use the current map");
        case MapType_Vote: return strcopy(buffer, length, "vote for a map");
        case MapType_Veto: return strcopy(buffer, length, "captains veto maps");
        default: ERROR_FUNC("unknown maptype=%d", type);
    }
    return 0;
}

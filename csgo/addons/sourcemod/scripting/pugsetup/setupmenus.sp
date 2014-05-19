/**
 * Main .setup menu
 */
public SetupMenu(client) {
    g_mapSet = false;
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

        if (g_TeamType == TeamType_Manual) {
            PrintToChatAll("The game will be using \x03manual team placement.");
        } else if (g_TeamType == TeamType_Random) {
            PrintToChatAll("The game will be using \x03random teams.");
        } else if (g_TeamType == TeamType_Captains){
            PrintToChatAll("The game will be using \x03team captains.");
        } else {
            ThrowError("Unknown team type choice: %d", g_TeamType);
        }

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
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MapMenuHandler(Handle:menu, MenuAction:action, param1, param2) {
    if (action == MenuAction_Select) {
        g_MapType = MapType:GetMenuInt(menu, param2);
        if (g_MapType == MapType_Current) {
            PrintToChatAll("The game will be using the \x03current map.");
            g_mapSet = true;
        } else if (g_MapType == MapType_Vote) {
            PrintToChatAll("The game will be using a \x03map vote.");
        } else {
            ThrowError("Unknown map choice: %d", g_MapType);
        }

        SetupFinished();
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

/**
 * Called when the setup phase is over and the ready-up period should begin.
 */
public SetupFinished() {
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
    if (type == TeamType_Manual)
        return strcopy(buffer, length, "manual teams");
    else if (type == TeamType_Random)
        return strcopy(buffer, length, "random teams");
    else if (type == TeamType_Captains)
        return strcopy(buffer, length, "captains pick players");
    else
        return strcopy(buffer, length, "unknown");
}

public GetMapString(String:buffer[], length, MapType:type) {
    if (type == MapType_Current)
        return strcopy(buffer, length, "use the current map");
    else if (type == MapType_Vote)
        return strcopy(buffer, length, "vote for a map");
    else
        return strcopy(buffer, length, "unknown");
}

/**
 * Main .setup menu
 */
public void SetupMenu(int client) {
    int numGameTypes = g_GameTypes.Length;

    if (numGameTypes == 0) {
        PugSetupMessage(client, "The server has no game types specified.");
        LogError("There are no game types specified.");
    } else if (numGameTypes == 1) {
        g_GameTypeIndex = 0;
        TeamTypeMenu(client);
    } else {
        Menu menu = new Menu(SetupMenuHandler);
        SetMenuTitle(menu, "%t", "GameTypeTitle");
        SetMenuExitButton(menu, false);
        char buffer[256];
        int count = 0;
        for (int i = 0; i < numGameTypes; i++) {
            if (!GetArrayCell(g_GameTypeHidden, i)) {
                count++;
                GetArrayString(g_GameTypes, i, buffer, sizeof(buffer));
                AddMenuInt(menu, i, buffer);
            }
        }
        if (count <= 0) {
            LogError("All game types were marked as hidden.");
        } else {
            DisplayMenu(menu, client, MENU_TIME_FOREVER);
        }
    }
}

public int SetupMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        g_GameTypeIndex = GetMenuInt(menu, param2);
        TeamTypeMenu(client);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public void TeamTypeMenu(int client) {
    TeamType teamType = GetArrayCell(g_GameTypeTeamTypes, g_GameTypeIndex);
    if (teamType == TeamType_Unspecified) {
        Menu menu = new Menu(TeamTypeMenuHandler);
        SetMenuTitle(menu, "%t", "TeamSetupMenuTitle");
        SetMenuExitButton(menu, false);
        AddMenuInt(menu, _:TeamType_Captains, "%t", "TeamSetupMenuCaptains");
        AddMenuInt(menu, _:TeamType_Random, "%t", "TeamSetupMenuRandom");
        AddMenuInt(menu, _:TeamType_Manual, "%t", "TeamSetupMenuManual");
        DisplayMenu(menu, client, MENU_TIME_FOREVER);
    } else {
        g_TeamType = teamType;
        GivePlayerCountMenu(client);
    }
}

public int TeamTypeMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        g_TeamType = TeamType:GetMenuInt(menu, param2);
        GivePlayerCountMenu(client);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public void GivePlayerCountMenu(int client) {
    int teamsize = GetArrayCell(g_GameTypeTeamSize, g_GameTypeIndex);

    if (teamsize <= 0) { // not specified by the game type
        Menu menu = new Menu(PlayerCountHandler);
        SetMenuTitle(menu, "%t", "HowManyPlayers");
        SetMenuExitButton(menu, false);
        int choices[] = {1, 2, 3, 4, 5, 6};
        for (int i = 0; i < sizeof(choices); i++)
            AddMenuInt(menu, choices[i], "");

        DisplayMenu(menu, client, MENU_TIME_FOREVER);
    } else {
        g_PlayersPerTeam = teamsize;
        MapMenu(client);
    }
}

public int PlayerCountHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        g_PlayersPerTeam = GetMenuInt(menu, param2);
        MapMenu(client);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

/**
 * Generic map choice-type menu.
 */
public void MapMenu(int client) {
    MapType mapType = GetArrayCell(g_GameTypeMapTypes, g_GameTypeIndex);
    LogMessage("got map type = %d", mapType);
    if (mapType == MapType_Unspecified) {
        Menu menu = new Menu(MapMenuHandler);
        SetMenuTitle(menu, "%t", "MapChoiceMenuTitle");
        SetMenuExitButton(menu, false);
        AddMenuInt(menu, _:MapType_Current, "%t", "MapChoiceCurrent");
        AddMenuInt(menu, _:MapType_Vote, "%t", "MapChoiceVote");
        AddMenuInt(menu, _:MapType_Veto, "%t", "MapChoiceVeto");
        DisplayMenu(menu, client, MENU_TIME_FOREVER);
    } else {
        g_MapType = mapType;
        SetupFinished();
    }
}

public int MapMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        g_MapType = MapType:GetMenuInt(menu, param2);
        switch (g_MapType) {
            case MapType_Current: g_mapSet = true;
            case MapType_Vote: g_mapSet = false;
            case MapType_Veto: g_mapSet = false;
            default: LogError("unknown maptype=%d", g_MapType);
        }

        SetupFinished();
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

/**
 * Called when the setup phase is over and the ready-up period should begin.
 */
public void SetupFinished() {
    g_capt1 = -1;
    g_capt2 = -1;
    ExecCfg(g_hWarmupCfg);

    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i)) {
            UnreadyPlayer(i);
            PrintSetupInfo(i);
        }
    }

    g_Setup = true;
    g_WaitingForKnifeWinner = false;
    g_WaitingForKnifeDecision = false;

    if (!g_LiveTimerRunning)
        CreateTimer(1.0, Timer_CheckReady, _, TIMER_REPEAT);
    g_LiveTimerRunning = true;

    if (GetConVarInt(g_hAutoRandomizeCaptains) != 0) {
        SetRandomCaptains();
    }

    Call_StartForward(g_hOnSetup);
    Call_PushCell(GetLeader());
    Call_PushCell(g_TeamType);
    Call_PushCell(g_MapType);
    Call_PushCell(g_PlayersPerTeam);
    Call_Finish();
}

/**
 * Converts enum choice types to strings to show to players.
 */
public void GetTeamString(char[] buffer, int length, TeamType type) {
    switch (type) {
        case TeamType_Manual: Format(buffer, length, "%t", "TeamSetupManualShort");
        case TeamType_Random: Format(buffer, length, "%t", "TeamSetupRandomShort");
        case TeamType_Captains: Format(buffer, length, "%t", "TeamSetupCaptainsShort");
        default: LogError("unknown teamtype=%d", type);
    }
}

public void GetMapString(char[] buffer, int length, MapType type) {
    switch (type) {
        case MapType_Current: Format(buffer, length, "%t", "MapChoiceCurrentShort");
        case MapType_Vote: Format(buffer, length, "%t", "MapChoiceVoteShort");
        case MapType_Veto: Format(buffer, length, "%t", "MapChoiceVetoShort");
        default: LogError("unknown maptype=%d", type);
    }
}

public void GetEnabledString(char[] buffer, int length, bool variable) {
    if (variable)
        Format(buffer, length, "%t", "Enabled");
    else
        Format(buffer, length, "%t", "Disabled");
}

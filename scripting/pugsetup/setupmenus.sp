/**
 * Main .setup menu
 */
 public void SetupMenu(int client, bool displayOnly) {
        Menu menu = new Menu(SetupMenuHandler);
        SetMenuTitle(menu, "%t", "SetupMenuTitle");
        SetMenuExitButton(menu, true);

        int style = ITEMDRAW_DEFAULT;
        if ((g_hForceDefaults.IntValue != 0 && !IsPugAdmin(client)) || displayOnly) {
            style = ITEMDRAW_DISABLED;
        }

        char buffer[256];

        // 1. team type
        if (g_hOptionTeamType.IntValue != 0) {
            char teamType[128];
            GetTeamString(teamType, sizeof(teamType), g_TeamType, client);
            Format(buffer, sizeof(buffer), "%T: %s", "TeamTypeOption", client, teamType);
            AddMenuItem(menu, "teamtype", buffer, style);
        }

        // 2. team size
        if (g_hOptionTeamSize.IntValue != 0) {
            Format(buffer, sizeof(buffer), "%T: %d", "TeamSizeOption", client, g_PlayersPerTeam);
            AddMenuItem(menu, "teamsize", buffer, style);
        }

        // 3. map type
        if (g_hOptionMapType.IntValue != 0) {
            char mapType[128];
            GetMapString(mapType, sizeof(mapType), g_MapType, client);
            Format(buffer, sizeof(buffer), "%T: %s", "MapTypeOption", client, mapType);
            AddMenuItem(menu, "maptype", buffer, style);
        }

        // 4. demo option
        if (g_hOptionRecord.IntValue != 0) {
            char demoString[128];
            GetEnabledString(demoString, sizeof(demoString), g_RecordGameOption, client);
            Format(buffer, sizeof(buffer), "%T: %s", "DemoOption", client, demoString);
            AddMenuItem(menu, "demo", buffer, style);
        }

        // 5. knife round option
        if (g_hOptionKnifeRounds.IntValue != 0) {
            char knifeString[128];
            GetEnabledString(knifeString, sizeof(knifeString), g_DoKnifeRound, client);
            Format(buffer, sizeof(buffer), "%T: %s", "KnifeRoundOption", client, knifeString);
            AddMenuItem(menu, "knife", buffer, style);
        }

        if (!g_Setup) {
            char finishSetupStr[128];
            Format(finishSetupStr, sizeof(finishSetupStr), "%T", "FinishSetup", client);
            AddMenuItem(menu, "finish_setup", finishSetupStr, style);
        } else  {
            char finishSetupStr[128];
            Format(finishSetupStr, sizeof(finishSetupStr), "%T", "CancelSetup", client);
            AddMenuItem(menu, "cancel_setup", finishSetupStr, style);
        }

        bool showMenu = true;
        Call_StartForward(g_hOnSetupMenuOpen);
        Call_PushCell(client);
        Call_PushCell(menu);
        Call_PushCell(displayOnly);
        Call_Finish(showMenu);

        if (showMenu) {
            DisplayMenu(menu, client, MENU_TIME_FOREVER);
        } else {
            CloseHandle(menu);
        }
}

public int SetupMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        char buffer[64];
        menu.GetItem(param2, buffer, sizeof(buffer));

        if (StrEqual(buffer, "maptype")) {
            MapTypeMenu(client);

        } else if (StrEqual(buffer, "teamtype")) {
            TeamTypeMenu(client);

        } else if (StrEqual(buffer, "teamsize")) {
            TeamSizeMenu(client);

        } else if (StrEqual(buffer, "demo")) {
            DemoHandler(client);

        } else if (StrEqual(buffer, "knife")) {
            g_DoKnifeRound = !g_DoKnifeRound;
            GiveSetupMenu(client);

        } else if (StrEqual(buffer, "finish_setup")) {
            SetupFinished();

        } else if (StrEqual(buffer, "cancel_setup")) {
            EndMatch(true);
        }

        Call_StartForward(g_hOnSetupMenuSelect);
        Call_PushCell(menu);
        Call_PushCell(action);
        Call_PushCell(param1);
        Call_PushCell(param2);
        Call_Finish();

    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public void TeamTypeMenu(int client) {
    Menu menu = new Menu(TeamTypeMenuHandler);
    SetMenuTitle(menu, "%T", "TeamSetupMenuTitle", client);
    SetMenuExitButton(menu, false);
    AddMenuInt(menu, _:TeamType_Captains, "%T", "TeamSetupMenuCaptains", client);
    AddMenuInt(menu, _:TeamType_Random, "%T", "TeamSetupMenuRandom", client);
    AddMenuInt(menu, _:TeamType_Manual, "%T", "TeamSetupMenuManual", client);
    AddMenuInt(menu, -1, "%T", "Back", client);
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int TeamTypeMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        int choice = GetMenuInt(menu, param2);
        if (choice != -1) {
            g_TeamType = TeamType:GetMenuInt(menu, param2);
        }
        GiveSetupMenu(client);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public void TeamSizeMenu(int client) {
    Menu menu = new Menu(TeamSizeHandler);
    SetMenuTitle(menu, "%T", "HowManyPlayers", client);
    SetMenuExitButton(menu, false);

    for (int i = 1; i <= g_hMaxTeamSize.IntValue; i++)
        AddMenuInt(menu, i, "");

    AddMenuInt(menu, -1, "%T", "Back", client);
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int TeamSizeHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        int choice = GetMenuInt(menu, param2);
        if (choice > 0) {
            g_PlayersPerTeam = choice;
        }
        GiveSetupMenu(client);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

/**
 * Generic map choice-type menu.
 */
public void MapTypeMenu(int client) {
    Menu menu = new Menu(MapTypeHandler);
    SetMenuTitle(menu, "%T", "MapChoiceMenuTitle", client);
    SetMenuExitButton(menu, false);
    AddMenuInt(menu, _:MapType_Current, "%T", "MapChoiceCurrent", client);
    AddMenuInt(menu, _:MapType_Vote, "%T", "MapChoiceVote", client);
    AddMenuInt(menu, _:MapType_Veto, "%T", "MapChoiceVeto", client);
    AddMenuInt(menu, -1, "%T", "Back", client);
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MapTypeHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        int choice = GetMenuInt(menu, param2);
        if (choice != -1) {
            g_MapType = MapType:choice;
            UpdateMapStatus();
        }
        GiveSetupMenu(client);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public int DemoHandler(int client) {
    g_RecordGameOption = !g_RecordGameOption;
    if (!IsTVEnabled() && g_RecordGameOption) {
        PugSetupMessage(client, "%t", "TVDisabled");
        g_RecordGameOption = false;
    }
    GiveSetupMenu(client);
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
            PrintSetupInfo(i);
            UnreadyPlayer(i);
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

    UpdateMapStatus();

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
stock void GetTeamString(char[] buffer, int length, TeamType type, int client=0) {
    if (client == 0)
        client = LANG_SERVER;

    switch (type) {
        case TeamType_Manual: Format(buffer, length, "%T", "TeamSetupManualShort", client);
        case TeamType_Random: Format(buffer, length, "%T", "TeamSetupRandomShort", client);
        case TeamType_Captains: Format(buffer, length, "%T", "TeamSetupCaptainsShort", client);
        default: LogError("unknown teamtype=%d", type);
    }
}

stock void GetMapString(char[] buffer, int length, MapType type, int client=0) {
    if (client == 0)
        client = LANG_SERVER;

    switch (type) {
        case MapType_Current: Format(buffer, length, "%T", "MapChoiceCurrentShort", client);
        case MapType_Vote: Format(buffer, length, "%T", "MapChoiceVoteShort", client);
        case MapType_Veto: Format(buffer, length, "%T", "MapChoiceVetoShort", client);
        default: LogError("unknown maptype=%d", type);
    }
}

static void UpdateMapStatus() {
    switch (g_MapType) {
        case MapType_Current: g_mapSet = true;
        case MapType_Vote: g_mapSet = false;
        case MapType_Veto: g_mapSet = false;
        default: LogError("unknown maptype=%d", g_MapType);
    }
}

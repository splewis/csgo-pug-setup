/**
 * Main .setup menu
 */
 public void SetupMenu(int client, bool displayOnly, int menuPosition) {
        Menu menu = new Menu(SetupMenuHandler);
        SetMenuTitle(menu, "%T", "SetupMenuTitle", client);
        SetMenuExitButton(menu, true);

        int style = ITEMDRAW_DEFAULT;
        if ((g_ForceDefaultsCvar.IntValue != 0 && !IsPugAdmin(client)) || displayOnly) {
            style = ITEMDRAW_DISABLED;
        }

        char buffer[256];

        if (g_GameState == GameState_None) {
            char finishSetupStr[128];
            Format(finishSetupStr, sizeof(finishSetupStr), "%T", "FinishSetup", client);
            AddMenuItem(menu, "finish_setup", finishSetupStr, style);
        } else  {
            char finishSetupStr[128];
            Format(finishSetupStr, sizeof(finishSetupStr), "%T", "CancelSetup", client);
            AddMenuItem(menu, "cancel_setup", finishSetupStr, style);
        }

        if (g_GameState == GameState_WaitingForStart) {
            Format(buffer, sizeof(buffer), "%T", "StartMatchMenuOption", client);
            AddMenuItem(menu, "start_match", buffer, style);
        }

        // first do a sanity check if an autobalancer is avaliable
        if (g_TeamType == TeamType_Autobalanced && !IsTeamBalancerAvaliable()) {
            g_TeamType = TeamType_Random;
        }

        // 1. team type
        if (g_DisplayTeamType) {
            char teamType[128];
            GetTeamString(teamType, sizeof(teamType), g_TeamType, client);
            Format(buffer, sizeof(buffer), "%T: %s", "TeamTypeOption", client, teamType);
            AddMenuItem(menu, "teamtype", buffer, style);
        }

        // 2. team size
        if (g_DisplayTeamSize) {
            Format(buffer, sizeof(buffer), "%T: %d", "TeamSizeOption", client, g_PlayersPerTeam);
            AddMenuItem(menu, "teamsize", buffer, style);
        }

        // 3. map type
        if (g_DisplayMapType) {
            char mapType[128];
            GetMapString(mapType, sizeof(mapType), g_MapType, client);
            Format(buffer, sizeof(buffer), "%T: %s", "MapTypeOption", client, mapType);
            AddMenuItem(menu, "maptype", buffer, style);
        }

        // 4. demo option
        if (g_DisplayRecordDemo) {
            char demoString[128];
            GetEnabledString(demoString, sizeof(demoString), g_RecordGameOption, client);
            Format(buffer, sizeof(buffer), "%T: %s", "DemoOption", client, demoString);
            AddMenuItem(menu, "demo", buffer, style);
        }

        // 5. knife round option
        if (g_DisplayKnifeRound) {
            char knifeString[128];
            GetEnabledString(knifeString, sizeof(knifeString), g_DoKnifeRound, client);
            Format(buffer, sizeof(buffer), "%T: %s", "KnifeRoundOption", client, knifeString);
            AddMenuItem(menu, "knife", buffer, style);
        }

        // 6. autolive option
        if (g_DisplayAutoLive) {
            char liveString[128];
            GetEnabledString(liveString, sizeof(liveString), g_AutoLive, client);
            Format(buffer, sizeof(buffer), "%T: %s", "AutoLiveOption", client, liveString);
            AddMenuItem(menu, "autolive", buffer, style);
        }

        // 7. set captains
        if (g_GameState ==  GameState_Warmup && UsingCaptains()) {
            Format(buffer, sizeof(buffer), "%T", "SetCaptainsMenuOption", client);
            AddMenuItem(menu, "set_captains", buffer, style);
        }

        // 8. change map
        if (g_DisplayMapChange) {
            Format(buffer, sizeof(buffer), "%T", "ChangeMapMenuOption", client);
            AddMenuItem(menu, "change_map", buffer, style);
        }

        bool showMenu = true;
        Call_StartForward(g_hOnSetupMenuOpen);
        Call_PushCell(client);
        Call_PushCell(menu);
        Call_PushCell(displayOnly);
        Call_Finish(showMenu);

        if (showMenu) {
            if (menuPosition == -1) {
                DisplayMenu(menu, client, MENU_TIME_FOREVER);
            } else {
                DisplayMenuAtItem(menu, client, menuPosition, MENU_TIME_FOREVER);
            }

        } else {
            CloseHandle(menu);
        }
}

public int SetupMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        char buffer[64];
        menu.GetItem(param2, buffer, sizeof(buffer));

        if (StrEqual(buffer, "start_match")) {
            FakeClientCommand(client, "sm_start");

        } else if (StrEqual(buffer, "maptype")) {
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

        } else if (StrEqual(buffer, "autolive")) {
            g_AutoLive = !g_AutoLive;
            GiveSetupMenu(client);

        } else if (StrEqual(buffer, "set_captains")) {
            FakeClientCommand(client, "sm_capt");

        } else if (StrEqual(buffer, "change_map")) {
            ChangeMapMenu(client);

        } else if (StrEqual(buffer, "finish_setup")) {
            SetupFinished();

        } else if (StrEqual(buffer, "cancel_setup")) {
            FakeClientCommand(client, "sm_endgame");
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
    AddMenuInt(menu, view_as<int>(TeamType_Captains), "%T", "TeamSetupMenuCaptains", client);
    AddMenuInt(menu, view_as<int>(TeamType_Random), "%T", "TeamSetupMenuRandom", client);
    AddMenuInt(menu, view_as<int>(TeamType_Manual), "%T", "TeamSetupMenuManual", client);
    if (IsTeamBalancerAvaliable())
        AddMenuInt(menu, view_as<int>(TeamType_Autobalanced), "%T", "Autobalanced", client);

    AddMenuInt(menu, -1, "%T", "Back", client);
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int TeamTypeMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        int choice = GetMenuInt(menu, param2);
        if (choice != -1) {
            g_TeamType = view_as<TeamType>(GetMenuInt(menu, param2));
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

    for (int i = 1; i <= g_MaxTeamSizeCvar.IntValue; i++)
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
    AddMenuInt(menu, view_as<int>(MapType_Current), "%T", "MapChoiceCurrent", client);
    AddMenuInt(menu, view_as<int>(MapType_Vote), "%T", "MapChoiceVote", client);
    AddMenuInt(menu, view_as<int>(MapType_Veto), "%T", "MapChoiceVeto", client);
    AddMenuInt(menu, -1, "%T", "Back", client);
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MapTypeHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        int choice = GetMenuInt(menu, param2);
        if (choice != -1) {
            g_MapType = view_as<MapType>(choice);
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
    ExecWarmupConfigs();

    if (g_UseGameWarmupCvar.IntValue != 0 && !InWarmup())
        StartWarmup();
    else
        RestartGame(1);

    for (int i = 1; i <= MaxClients; i++) {
        g_Ready[i] = false;
        if (IsPlayer(i)) {
            PrintSetupInfo(i);
        }
    }

    // reset match state variables
    g_capt1 = -1;
    g_capt2 = -1;
    ChangeState(GameState_Warmup);
    StartLiveTimer();

    if (GetConVarInt(g_AutoRandomizeCaptainsCvar) != 0) {
        SetRandomCaptains();
    }

    UpdateMapStatus();

    Call_StartForward(g_hOnSetup);
    Call_Finish();

    if (!g_OnDecidedMap && g_UseAimMapWarmupCvar.IntValue != 0 && !OnAimMap()) {
        ChangeToAimMap();
    }
}

public void StartLiveTimer() {
    if (!g_LiveTimerRunning)
        CreateTimer(LIVE_TIMER_INTERVAL, Timer_CheckReady, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    g_LiveTimerRunning = true;
}

/**
 * Converts enum choice types to strings to show to players.
 */
stock void GetTeamString(char[] buffer, int length, TeamType type, int client=LANG_SERVER) {
    switch (type) {
        case TeamType_Manual: Format(buffer, length, "%T", "TeamSetupManualShort", client);
        case TeamType_Random: Format(buffer, length, "%T", "TeamSetupRandomShort", client);
        case TeamType_Captains: Format(buffer, length, "%T", "TeamSetupCaptainsShort", client);
        case TeamType_Autobalanced: Format(buffer, length, "%T", "Autobalanced", client);
        default: LogError("unknown teamtype=%d", type);
    }
}

stock void GetMapString(char[] buffer, int length, MapType type, int client=LANG_SERVER) {
    switch (type) {
        case MapType_Current: Format(buffer, length, "%T", "MapChoiceCurrentShort", client);
        case MapType_Vote: Format(buffer, length, "%T", "MapChoiceVoteShort", client);
        case MapType_Veto: Format(buffer, length, "%T", "MapChoiceVetoShort", client);
        default: LogError("unknown maptype=%d", type);
    }
}

static void UpdateMapStatus() {
    switch (g_MapType) {
        case MapType_Current: g_OnDecidedMap = true;
        case MapType_Vote: g_OnDecidedMap = false;
        case MapType_Veto: g_OnDecidedMap = false;
        default: LogError("unknown maptype=%d", g_MapType);
    }
}

public void ChangeMapMenu(int client) {
    ArrayList mapList = GetCurrentMapList();

    Menu menu = new Menu(ChangeMapHandler);
    menu.ExitButton = true;
    menu.SetTitle("%T", "ChangeMapMenuTitle", client);

    for (int i = 0; i < mapList.Length; i++) {
        AddMapIndexToMenu(menu, mapList, i);
    }

    AddMenuInt(menu, -1, "%T", "Back", client);
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int ChangeMapHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        int choice = GetMenuInt(menu, param2);

        if (choice == -1) {
            GiveSetupMenu(client);
        } else {
            ChangeMap(g_MapList, GetMenuInt(menu, param2));
        }
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}
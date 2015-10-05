#define MAX_CONFIG_NAME 128 // Max length for a name in config files.
#define MAX_CONFIG_PATH 128 // Max length for a path value in config files.

/**
 * Main .setup menu
 */
 public void SetupMenu(int client, bool displayOnly, int menuPosition) {
        Menu menu = new Menu(SetupMenuHandler);
        menu.SetTitle("%T", "SetupMenuTitle", client);
        menu.ExitButton = true;

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
        if (g_DisplayRecordDemo && IsTVEnabled()) {
            char enabledString[128];
            GetEnabledString(enabledString, sizeof(enabledString), g_RecordGameOption, client);
            Format(buffer, sizeof(buffer), "%T: %s", "DemoOption", client, enabledString);
            AddMenuItem(menu, "demo", buffer, style);
        }

        // 5. knife round option
        if (g_DisplayKnifeRound) {
            char enabledString[128];
            GetEnabledString(enabledString, sizeof(enabledString), g_DoKnifeRound, client);
            Format(buffer, sizeof(buffer), "%T: %s", "KnifeRoundOption", client, enabledString);
            AddMenuItem(menu, "knife", buffer, style);
        }

        // 6. autolive option
        if (g_DisplayAutoLive) {
            char liveString[128];
            GetEnabledString(liveString, sizeof(liveString), g_AutoLive, client);
            Format(buffer, sizeof(buffer), "%T: %s", "AutoLiveOption", client, liveString);
            AddMenuItem(menu, "autolive", buffer, style);
        }

        // 7. use aim_ map warmup
        if (g_DisplayAimWarmup && g_AimMapList.Length >= 1) {
            char enabledString[128];
            GetEnabledString(enabledString, sizeof(enabledString), g_DoAimWarmup, client);
            Format(buffer, sizeof(buffer), "%T: %s", "AimWarmupMenuOption", client, enabledString);
            AddMenuItem(menu, "aim_warmup", buffer, style);
        }

        // 8. set captains
        if (g_GameState ==  GameState_Warmup && UsingCaptains()) {
            Format(buffer, sizeof(buffer), "%T", "SetCaptainsMenuOption", client);
            AddMenuItem(menu, "set_captains", buffer, style);
        }

        // 9. play out maxrounds
        if (g_DisplayPlayout) {
            char playOutString[128];
            GetEnabledString(playOutString, sizeof(playOutString), g_DoPlayout, client);
            Format(buffer, sizeof(buffer), "%T: %s", "PlayoutOption", client, playOutString);
            AddMenuItem(menu, "playout", buffer, style);
        }

        // 10. change map
        if (g_DisplayMapChange) {
            Format(buffer, sizeof(buffer), "%T", "ChangeMapMenuOption", client);
            AddMenuItem(menu, "change_map", buffer, style);
        }

        // 11. Change live cfg
        if (CountKvEntires(g_LiveConfigsKv) >= 2) {
            char currentLiveCfg[MAX_CONFIG_PATH];
            g_LiveCfgCvar.GetString(currentLiveCfg, sizeof(currentLiveCfg));
            char currentLiveCfgName[MAX_CONFIG_NAME];

            if (FindValueInKv(g_LiveConfigsKv, currentLiveCfg, currentLiveCfgName, sizeof(currentLiveCfgName))) {
                // If lookup of the config name succeeds, use that as the name displayed on the menu.
                Format(buffer, sizeof(buffer), "%T", "LiveConfigOption", client, currentLiveCfgName);
                AddMenuItem(menu, "livecfg", buffer, style);
            } else {
                // Otherwise, use the actual file path as the name displayed on the menu.
                Format(buffer, sizeof(buffer), "%T", "LiveConfigOption", client, currentLiveCfg);
                AddMenuItem(menu, "livecfg", buffer, style);
            }
        }

        // 12. Change maplist
        if (CountKvEntires(g_MapListsKv) >= 2) {
            char currentMaplist[MAX_CONFIG_PATH];
            g_MapListCvar.GetString(currentMaplist, sizeof(currentMaplist));
            char currentMaplistName[MAX_CONFIG_NAME];

            if (FindValueInKv(g_MapListsKv, currentMaplist, currentMaplistName, sizeof(currentMaplistName))) {
                // If lookup of the maplist name succeeds, use that as the name displayed on the menu.
                Format(buffer, sizeof(buffer), "%T", "MapListOption", client, currentMaplistName);
                AddMenuItem(menu, "maplist", buffer, style);
            } else {
                // Otherwise, use the actual file path as the name displayed on the menu.
                Format(buffer, sizeof(buffer), "%T", "MapListOption", client, currentMaplist);
                AddMenuItem(menu, "maplist", buffer, style);
            }
        }

        bool showMenu = true;
        Call_StartForward(g_hOnSetupMenuOpen);
        Call_PushCell(client);
        Call_PushCell(menu);
        Call_PushCell(displayOnly);
        Call_Finish(showMenu);

        if (showMenu) {
            if (menuPosition == -1) {
                menu.Display(client, MENU_TIME_FOREVER);
            } else {
                DisplayMenuAtItem(menu, client, menuPosition, MENU_TIME_FOREVER);
            }

        } else {
            delete menu;
        }
}

public int SetupMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        char buffer[64];
        menu.GetItem(param2, buffer, sizeof(buffer));
        int pos = GetMenuSelectionPosition();

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

        } else if (StrEqual(buffer, "playout")) {
            g_DoPlayout = !g_DoPlayout;
            GiveSetupMenu(client, false, pos);

        } else if (StrEqual(buffer, "finish_setup")) {
            SetupFinished();

        } else if (StrEqual(buffer, "cancel_setup")) {
            FakeClientCommand(client, "sm_endgame");

        } else if (StrEqual(buffer, "aim_warmup")) {
            g_DoAimWarmup = !g_DoAimWarmup;
            GiveSetupMenu(client, false, pos);

        } else if (StrEqual(buffer, "livecfg")) {
            LiveConfigMenu(client);

        } else if (StrEqual(buffer, "maplist")) {
            MapListMenu(client);
        }

        Call_StartForward(g_hOnSetupMenuSelect);
        Call_PushCell(menu);
        Call_PushCell(action);
        Call_PushCell(param1);
        Call_PushCell(param2);
        Call_Finish();

    } else if (action == MenuAction_End) {
        delete menu;
    }
}

public void TeamTypeMenu(int client) {
    Menu menu = new Menu(TeamTypeMenuHandler);
    menu.SetTitle("%T", "TeamSetupMenuTitle", client);
    menu.ExitButton = false;
    menu.ExitBackButton = true;
    AddMenuInt(menu, view_as<int>(TeamType_Captains), "%T", "TeamSetupMenuCaptains", client);
    AddMenuInt(menu, view_as<int>(TeamType_Random), "%T", "TeamSetupMenuRandom", client);
    AddMenuInt(menu, view_as<int>(TeamType_Manual), "%T", "TeamSetupMenuManual", client);
    if (IsTeamBalancerAvaliable())
        AddMenuInt(menu, view_as<int>(TeamType_Autobalanced), "%T", "Autobalanced", client);

    menu.Display(client, MENU_TIME_FOREVER);
}

public int TeamTypeMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        g_TeamType = view_as<TeamType>(GetMenuInt(menu, param2));
        GiveSetupMenu(client);
    }  else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        int client = param1;
        GiveSetupMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
}

public void TeamSizeMenu(int client) {
    Menu menu = new Menu(TeamSizeHandler);
    menu.SetTitle("%T", "HowManyPlayers", client);
    menu.ExitButton = false;
    menu.ExitBackButton = true;

    for (int i = 1; i <= g_MaxTeamSizeCvar.IntValue; i++)
        AddMenuInt(menu, i, "");

    menu.Display(client, MENU_TIME_FOREVER);
}

public int TeamSizeHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        g_PlayersPerTeam = GetMenuInt(menu, param2);
        GiveSetupMenu(client);
    } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        int client = param1;
        GiveSetupMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
}

/**
 * Generic map choice-type menu.
 */
public void MapTypeMenu(int client) {
    Menu menu = new Menu(MapTypeHandler);
    menu.SetTitle("%T", "MapChoiceMenuTitle", client);
    menu.ExitButton = false;
    menu.ExitBackButton = true;
    AddMenuInt(menu, view_as<int>(MapType_Current), "%T", "MapChoiceCurrent", client);
    AddMenuInt(menu, view_as<int>(MapType_Vote), "%T", "MapChoiceVote", client);
    AddMenuInt(menu, view_as<int>(MapType_Veto), "%T", "MapChoiceVeto", client);
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MapTypeHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        g_MapType = view_as<MapType>(GetMenuInt(menu, param2));
        UpdateMapStatus();
        GiveSetupMenu(client);
    } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        int client = param1;
        GiveSetupMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
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

    if (g_UseGameWarmupCvar.IntValue != 0)
        EnsurePausedWarmup();
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

    ServerCommand("exec sourcemod/pugsetup/on_setup.cfg");
    Call_StartForward(g_hOnSetup);
    Call_Finish();

    if (!g_OnDecidedMap && g_DoAimWarmup && !OnAimMap()) {
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
    menu.ExitButton = false;
    menu.ExitBackButton = true;
    menu.SetTitle("%T", "ChangeMapMenuTitle", client);

    for (int i = 0; i < mapList.Length; i++) {
        AddMapIndexToMenu(menu, mapList, i);
    }

    menu.Display(client, MENU_TIME_FOREVER);
}

public int ChangeMapHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int choice = GetMenuInt(menu, param2);
        ChangeMap(g_MapList, choice);
    } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        int client = param1;
        GiveSetupMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
}

public void LiveConfigMenu(int client) {
    Menu menu = new Menu(LiveConfigMenuHandler);
    menu.ExitButton = false;
    menu.ExitBackButton = true;
    menu.SetTitle("%T", "LiveConfigMenuTitle", client);
    AddKvEntriesToMenu(g_LiveConfigsKv, menu, MAX_CONFIG_NAME, MAX_CONFIG_PATH);
    menu.Display(client, MENU_TIME_FOREVER);
}

public int LiveConfigMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        char value[MAX_CONFIG_PATH];
        menu.GetItem(param2, value, sizeof(value));
        g_LiveCfgCvar.SetString(value);
        GiveSetupMenu(client);

    } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        int client = param1;
        GiveSetupMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
}

public void MapListMenu(int client) {
    Menu menu = new Menu(MapListMenuHandler);
    menu.ExitButton = false;
    menu.ExitBackButton = true;
    menu.SetTitle("%T", "MapListMenuTitle", client);
    AddKvEntriesToMenu(g_LiveConfigsKv, menu, MAX_CONFIG_NAME, MAX_CONFIG_PATH);
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MapListMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        char value[MAX_CONFIG_PATH];
        menu.GetItem(param2, value, sizeof(value));
        g_MapListCvar.SetString(value);
        GiveSetupMenu(client);

    } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        int client = param1;
        GiveSetupMenu(client);
    } else if (action == MenuAction_End) {
        delete menu;
    }
}

stock int CountKvEntires(KeyValues kv) {
    int count = 0;
    if (kv.GotoFirstSubKey(false)) {
        do {
            count++;
        } while (kv.GotoNextKey(false));
        kv.GoBack();
    }
    return count;
}

stock void AddKvEntriesToMenu(KeyValues kv, Menu menu, int keylen, int valuelen) {
    char[] key = new char[keylen];
    char[] value = new char[valuelen];
    if (kv.GotoFirstSubKey(false)) {
        do {
            kv.GetSectionName(key, keylen);
            kv.GetString(NULL_STRING, value, valuelen);
            if (StrEqual(value, "")) {
                menu.AddItem(key, key);
            } else {
                menu.AddItem(value, key);
            }
        } while (kv.GotoNextKey(false));
        kv.GoBack();
    }
}

stock bool FindValueInKv(KeyValues kv, const char[] value, char[] key, int keylen) {
    int valuelen = strlen(value) + 1;
    char[] tmpValue = new char[valuelen];
    if (kv.GotoFirstSubKey(false)) {
        do {
            kv.GetString(NULL_STRING, tmpValue, valuelen);
            if (StrEqual(tmpValue, value, false)) {
                kv.GetSectionName(key, keylen);
                kv.GoBack();
                return true;
            }
        } while (kv.GotoNextKey(false));
        kv.GoBack();
    }
    return false;
}

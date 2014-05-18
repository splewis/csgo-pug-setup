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
 * Map voting functions
 */
public CreateMapVote() {
    GetMapList();
    ShowMapVote();
}

public ShowMapVote() {
    g_VotesCasted = 0;
    for (new client = 1; client <= MaxClients; client++) {
        if (IsValidClient(client) && !IsFakeClient(client)) {
            new Handle:menu = CreateMenu(MapVoteHandler);
            SetMenuTitle(menu, "Vote for a map");
            SetMenuExitButton(menu, false);

            for (new i = 0; i < GetArraySize(g_MapNames); i++) {
                new String:mapName[MAP_NAME_LENGTH];
                GetArrayString(g_MapNames, i, mapName, sizeof(mapName));
                AddMenuInt(menu, i, mapName);
            }

            DisplayMenu(menu, client, 20);
        }
    }
    CreateTimer(20.0, MapVoteFinished);
}

public MapVoteHandler(Handle:menu, MenuAction:action, param1, param2) {
    if (action == MenuAction_Select) {
        new client = param1;
        new index = GetMenuInt(menu, param2);
        decl String:mapName[MAP_NAME_LENGTH];
        GetArrayString(g_MapNames, index, mapName, sizeof(mapName));
        new count = GetArrayCell(g_MapVotes, index);
        count++;
        g_VotesCasted++;
        PrintToChatAll(" \x01\x0B\x04%N \x01voted for \x03%s \x01(%d/%d)", client, mapName, count, g_VotesCasted);
        SetArrayCell(g_MapVotes, index, count);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public Action:MapVoteFinished(Handle:timer) {
    new bestIndex = -1;
    new bestVotes = 0;
    for (new i = 0; i < GetArraySize(g_MapVotes); i++) {
        new votes = GetArrayCell(g_MapVotes, i);
        if (bestIndex == -1 || votes > bestVotes) {
            bestIndex = i;
            bestVotes = votes;
        }
    }

    decl String:map[MAP_NAME_LENGTH];
    GetArrayString(g_MapNames, bestIndex, map, sizeof(map));
    g_mapSet = true;
    ServerCommand("changelevel %s", map);
    return Plugin_Handled;
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



/**
 * Helper functions for the setup menus.
 */
static CreateDefaultMapFile() {
    PrintToChatAll("No map list was found, autogenerating one now.");
    LogMessage("No map list was found, autogenerating one.");

    decl String:dirName[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, dirName, sizeof(dirName), "configs/pugsetup", dirName);
    if (!DirExists(dirName))
        CreateDirectory(dirName, 511);

    decl String:mapFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, mapFile, sizeof(mapFile), "configs/pugsetup/maps.txt", mapFile);
    new Handle:file = OpenFile(mapFile, "w");
    WriteFileLine(file, "de_cache");
    WriteFileLine(file, "de_dust2");
    WriteFileLine(file, "de_inferno");
    WriteFileLine(file, "de_mirage");
    WriteFileLine(file, "de_nuke");
    WriteFileLine(file, "de_train");
    CloseHandle(file);
}

static AddMap(const String:mapName[]) {
    PushArrayString(g_MapNames, mapName);
    PushArrayCell(g_MapVotes, 0);
}

static GetMapList() {
    g_MapNames = CreateArray(64);
    ClearArray(g_MapNames);
    g_MapVotes = CreateArray();
    ClearArray(g_MapVotes);

    // full file path
    decl String:mapFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, mapFile, sizeof(mapFile), "configs/pugsetup/maps.txt", mapFile);

    if (!FileExists(mapFile)) {
        CreateDefaultMapFile();
    }

    new Handle:file = OpenFile(mapFile, "r");
    decl String:mapName[MAP_NAME_LENGTH];
    while (!IsEndOfFile(file) && ReadFileLine(file, mapName, sizeof(mapName))) {
        TrimString(mapName);
        if (strlen(mapName) < 3)
            LogError("Map name too short: %s", mapName);
        else
            AddMap(mapName);
    }
    CloseHandle(file);


    if (GetArraySize(g_MapNames) < 1) {
        LogError("The map file was empty: %s", mapFile);
        PrintToChatAll(" \x01\x0B\x04The map file was empty - adding some default maps.");
        AddMap("de_dust2");
        AddMap("de_inferno");
        AddMap("de_mirage");
    }

}

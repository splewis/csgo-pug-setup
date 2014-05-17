new Handle:g_MapNames = INVALID_HANDLE;
new Handle:g_MapVotes = INVALID_HANDLE;

#define MAP_NAME_LENGTH 256

enum TeamType {
    TeamType_Manual,
    TeamType_Random,
    TeamType_Captains
};

enum MapType {
    MapType_Current,
    MapType_Vote,
    MapType_Manual
};

public SetupMenu(client) {
    g_mapSet = false;
    new Handle:menu = CreateMenu(SetupMenuHandler);
    SetMenuTitle(menu, "How will teams be setup?");
    SetMenuExitButton(menu, false);
    AddMenuItem(menu, "manual" , "Players manually switch");
    AddMenuItem(menu, "random", "Random Teams");
    AddMenuItem(menu, "captains", "Assigned captains pick their teams");
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public SetupMenuHandler(Handle:menu, MenuAction:action, param1, param2) {
    if (action == MenuAction_Select) {
        new client = param1;
        decl String:choice[32];
        GetMenuItem(menu, param2, choice, sizeof(choice));
        if (StrEqual(choice, "manual")) {
            PrintToChatAll("The game will be using the \x03manual team placement.");
            g_TeamType = TeamType_Manual;
        } else if (StrEqual(choice, "random")) {
            PrintToChatAll("The game will be using the \x04random teams.");
            g_TeamType = TeamType_Random;
        } else if (StrEqual(choice, "captains")){
            PrintToChatAll("The game will be using the \x04team captains.");
            g_TeamType = TeamType_Captains;
        } else {
            LogError("Unknown team type choice: %s", choice);
            g_TeamType = TeamType_Captains;
        }
        MapMenu(client);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public MapMenu(client) {
    new Handle:menu = CreateMenu(MapMenuHandler);
    SetMenuTitle(menu, "How will the map be chosen?");
    SetMenuExitButton(menu, false);
    AddMenuItem(menu, "current" , "Use the current map");
    AddMenuItem(menu, "vote", "Vote for a map");
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MapMenuHandler(Handle:menu, MenuAction:action, param1, param2) {
    if (action == MenuAction_Select) {
        decl String:choice[32];
        GetMenuItem(menu, param2, choice, sizeof(choice));
        if (StrEqual(choice, "current")) {
            PrintToChatAll("The game will be using the \x03current map.");
            g_mapSet = true;
            g_MapType = MapType_Current;
        } else if (StrEqual(choice, "vote")) {
            PrintToChatAll("The game will be a the \x03map vote.");
            g_MapType = MapType_Vote;
        } else {
            LogError("Unknown map choice: %s", choice);
            g_MapType = MapType_Current;
        }

        SetupFinished();

    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public SetupFinished() {
    ExecCfg(g_hWarmupCfg);
    g_Setup = true;
    CreateTimer(1.0, Timer_CheckReady, _, TIMER_REPEAT);
}

public CreateMapVote() {
    GetMapList();
    ShowMapVote();
}

static GetMapList() {
    g_MapNames = CreateArray(64);
    ClearArray(g_MapNames);
    g_MapVotes = CreateArray();
    ClearArray(g_MapVotes);

    decl String:mapFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, mapFile, sizeof(mapFile), "configs/pugsetup/maps.txt", mapFile);

    if (!FileExists(mapFile)) {
        CreateMapFile();
    }

    new Handle:file = OpenFile(mapFile, "r");
    decl String:mapName[MAP_NAME_LENGTH];
    while (!IsEndOfFile(file) && ReadFileLine(file, mapName, sizeof(mapName))) {
        TrimString(mapName);
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

static CreateMapFile() {
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

static ShowMapVote() {
    for (new client = 1; client <= MaxClients; client++) {
        if (IsValidClient(client) && !IsFakeClient(client)) {
            new Handle:menu = CreateMenu(MapVoteHandler);
            SetMenuTitle(menu, "Vote for a map");
            SetMenuExitButton(menu, false);

            for (new i = 0; i < GetArraySize(g_MapNames); i++) {
                new String:stringIndex[16];
                IntToString(i, stringIndex, sizeof(stringIndex));
                new String:mapName[MAP_NAME_LENGTH];
                GetArrayString(g_MapNames, i, mapName, sizeof(mapName));
                AddMenuItem(menu, stringIndex, mapName);
            }

            DisplayMenu(menu, client, 20);

        }
    }
    CreateTimer(20.0, MapVoteFinished);

}

public MapVoteHandler(Handle:menu, MenuAction:action, param1, param2) {
    if (action == MenuAction_Select) {
        new client = param1;
        decl String:choice[16];
        GetMenuItem(menu, param2, choice, sizeof(choice));
        new index = StringToInt(choice);
        decl String:mapName[MAP_NAME_LENGTH];
        GetArrayString(g_MapNames, index, mapName, sizeof(mapName));
        new count = GetArrayCell(g_MapVotes, index);
        count++;
        PrintToChatAll(" \x01\x0B\x04%N \x01voted for \x03%s \x01(x%d)", client, mapName, count);
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

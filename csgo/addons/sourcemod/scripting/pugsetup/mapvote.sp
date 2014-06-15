/**
 * Map voting functions
 */
public CreateMapVote() {
    GetMapList();
    ShowMapVote();
}

static ShowMapVote() {
    g_VotesCasted = 0;
    for (new client = 1; client <= MaxClients; client++) {
        if (IsValidClient(client) && !IsFakeClient(client)) {
            new Handle:menu = CreateMenu(MapVoteHandler);
            SetMenuTitle(menu, "Vote for a map");
            SetMenuExitButton(menu, false);

            for (new i = 0; i < GetArraySize(g_MapNames); i++) {
                new String:mapName[PLATFORM_MAX_PATH];
                GetArrayString(g_MapNames, i, mapName, sizeof(mapName));
                AddMenuInt(menu, i, mapName);
            }

            DisplayMenu(menu, client, 20);
        }
    }
    CreateTimer(GetConVarFloat(g_hMapVoteTime), MapVoteFinished);
}

public MapVoteHandler(Handle:menu, MenuAction:action, param1, param2) {
    if (action == MenuAction_Select) {
        new client = param1;
        new index = GetMenuInt(menu, param2);
        decl String:mapName[PLATFORM_MAX_PATH];
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
    g_ChosenMap = bestIndex;

    decl String:map[PLATFORM_MAX_PATH];
    GetArrayString(g_MapNames, bestIndex, map, sizeof(map));
    PrintToChatAll("Changing map to \x03%s\x01...", map);

    CreateTimer(3.0, ChangeMap);
    return Plugin_Handled;
}

public Action:ChangeMap(Handle:timer) {
    decl String:map[PLATFORM_MAX_PATH];
    GetArrayString(g_MapNames, g_ChosenMap, map, sizeof(map));
    g_mapSet = true;
    CloseHandle(g_MapNames);
    CloseHandle(g_MapVotes);
    ServerCommand("changelevel %s", map);
    return Plugin_Handled;
}

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
    WriteFileString(file, "de_train", false); // no newline at the end
    CloseHandle(file);
}

static AddMap(const String:mapName[]) {
    if (IsMapValid(mapName)) {
        PushArrayString(g_MapNames, mapName);
        PushArrayCell(g_MapVotes, 0);
    } else {
        LogError("Invalid map name in mapfile: %s", mapName);
    }
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
    decl String:mapName[PLATFORM_MAX_PATH];
    while (!IsEndOfFile(file) && ReadFileLine(file, mapName, sizeof(mapName))) {
        TrimString(mapName);
        AddMap(mapName);
    }
    CloseHandle(file);

    if (GetArraySize(g_MapNames) < 1) {
        LogError("The map file was empty: %s", mapFile);
        PrintToChatAll(" \x01\x0B\x04The map file was empty - adding some default maps.");
        AddMap("de_cache");
        AddMap("de_dust2");
        AddMap("de_inferno");
        AddMap("de_mirage");
        AddMap("de_nuke");
        AddMap("de_train");
    }

}

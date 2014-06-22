public ChangeMap() {
    decl String:map[PLATFORM_MAX_PATH];
    GetArrayString(g_MapNames, g_ChosenMap, map, sizeof(map));
    PrintToChatAll("Changing map to \x03%s\x01...", map);
    CreateTimer(3.0, Timer_DelayedChangeMap);
}

public Action:Timer_DelayedChangeMap(Handle:timer) {
    decl String:map[PLATFORM_MAX_PATH];
    GetArrayString(g_MapNames, g_ChosenMap, map, sizeof(map));
    g_mapSet = true;
    CloseHandle(g_MapNames);
    CloseHandle(g_MapVotes);
    ServerCommand("changelevel %s", map);
    return Plugin_Handled;
}

public GetMapList() {
    g_MapNames = CreateArray(PLATFORM_MAX_PATH);
    ClearArray(g_MapNames);
    g_MapVotes = CreateArray();
    ClearArray(g_MapVotes);
    g_MapVetoed = CreateArray();
    ClearArray(g_MapVetoed);

    // full file path
    decl String:mapFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, mapFile, sizeof(mapFile), "configs/pugsetup/%s", g_MapFile);

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
        AddMap("de_dust2");
        AddMap("de_inferno");
        AddMap("de_mirage");
        AddMap("de_nuke");
        AddMap("de_train");
    }
}

static AddMap(const String:mapName[]) {
    if (IsMapValid(mapName)) {
        PushArrayString(g_MapNames, mapName);
        PushArrayCell(g_MapVotes, 0);
        PushArrayCell(g_MapVetoed, false);
    } else {
        LogError("Invalid map name in mapfile: %s", mapName);
    }
}

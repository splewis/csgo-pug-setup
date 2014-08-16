public ChangeMap() {
    decl String:map[PLATFORM_MAX_PATH];
    GetArrayString(g_MapNames, g_ChosenMap, map, sizeof(map));
    PugSetupMessageToAll("Changing map to {GREEN}%s{NORMAL}...", map);
    CreateTimer(3.0, Timer_DelayedChangeMap);
}

public Action:Timer_DelayedChangeMap(Handle:timer) {
    decl String:map[PLATFORM_MAX_PATH];
    GetArrayString(g_MapNames, g_ChosenMap, map, sizeof(map));
    g_mapSet = true;
    ServerCommand("changelevel %s", map);
    return Plugin_Handled;
}

public GetMapList() {
    ClearArray(g_MapNames);
    ClearArray(g_MapVetoed);

    // full file path
    decl String:mapCvar[PLATFORM_MAX_PATH];
    GetConVarString(g_hMapListFile, mapCvar, sizeof(mapCvar));

    decl String:mapFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, mapFile, sizeof(mapFile), mapCvar);

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
        AddMap("de_dust2");
        AddMap("de_inferno");
        AddMap("de_mirage");
        AddMap("de_nuke");
        AddMap("de_train");
    }

    if (GetConVarInt(g_hRandomizeMapOrder) != 0) {
        RandomizeMaps();
    }
}

static AddMap(const String:mapName[]) {
    if (IsMapValid(mapName)) {
        PushArrayString(g_MapNames, mapName);
        PushArrayCell(g_MapVetoed, false);
    } else if (strlen(mapName) >= 1) {  // don't print errors on empty
        LogMessage("Invalid map name in mapfile: %s", mapName);
    }
}

static CreateDefaultMapFile() {
    LogError("No map list was found, autogenerating one.");

    decl String:dirName[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, dirName, sizeof(dirName), "configs/pugsetup", dirName);
    if (!DirExists(dirName))
        CreateDirectory(dirName, 751);

    decl String:mapFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, mapFile, sizeof(mapFile), "configs/pugsetup/maps.txt", mapFile);
    new Handle:file = OpenFile(mapFile, "w");
    WriteFileLine(file, "de_dust2");
    WriteFileLine(file, "de_inferno");
    WriteFileLine(file, "de_mirage");
    WriteFileLine(file, "de_nuke");
    WriteFileString(file, "de_train", false); // no newline at the end
    CloseHandle(file);
}

static RandomizeMaps() {
    new n = GetArraySize(g_MapNames);
    for (new i = 0; i < n; i++) {
        new choice = GetRandomInt(0, n - 1);
        SwapArrayItems(g_MapNames, i, choice);
    }
}

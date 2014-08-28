public void ChangeMap() {
    char map[PLATFORM_MAX_PATH];
    GetArrayString(g_MapNames, g_ChosenMap, map, sizeof(map));
    PugSetupMessageToAll("Changing map to {GREEN}%s{NORMAL}...", map);
    CreateTimer(3.0, Timer_DelayedChangeMap);
}

public Action Timer_DelayedChangeMap(Handle timer) {
    char map[PLATFORM_MAX_PATH];
    GetArrayString(g_MapNames, g_ChosenMap, map, sizeof(map));
    g_mapSet = true;
    ServerCommand("changelevel %s", map);
    return Plugin_Handled;
}

public void GetMapList() {
    char fileName[256];
    GetArrayString(g_GameMapFiles, g_GameTypeIndex, fileName, sizeof(fileName));

    ClearArray(g_MapNames);
    ClearArray(g_MapVetoed);

    char mapFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, mapFile, sizeof(mapFile), "configs/pugsetup/%s", fileName);

    if (!FileExists(mapFile)) {
        LogError("Missing map file: %s", mapFile);
    } else {
        Handle file = OpenFile(mapFile, "r");
        char mapName[PLATFORM_MAX_PATH];
        while (!IsEndOfFile(file) && ReadFileLine(file, mapName, sizeof(mapName))) {
            TrimString(mapName);
            AddMap(mapName);
        }
        CloseHandle(file);
    }

    if (GetArraySize(g_MapNames) < 1) {
        LogError("The map file was empty: %s", mapFile);
        AddMap("de_cache");
        AddMap("de_dust2");
        AddMap("de_inferno");
        AddMap("de_mirage");
        AddMap("de_nuke");
        AddMap("de_train");
    }

    if (GetConVarInt(g_hRandomizeMapOrder) != 0) {
        RandomizeArray(g_MapNames);
    }
}

static void AddMap(const char mapName[]) {
    if (IsMapValid(mapName)) {
        PushArrayString(g_MapNames, mapName);
        PushArrayCell(g_MapVetoed, false);
    } else if (strlen(mapName) >= 1) {  // don't print errors on empty
        LogError("Invalid map name in mapfile: %s", mapName);
    }
}

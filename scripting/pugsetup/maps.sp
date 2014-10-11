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
    bool isComment = strlen(mapName) >= 2 && mapName[0] == '/' && mapName[1] == '/';
    if (strlen(mapName) <= 2 || isComment) {
        return;
    }

    if (IsMapValid(mapName)) {
        PushArrayString(g_MapNames, mapName);
        PushArrayCell(g_MapVetoed, false);
    } else if (strlen(mapName) >= 2) {  // don't print errors on empty
        LogError("Invalid map name in mapfile: %s", mapName);
    }
}

public Action Command_ListPugMaps(int client, args) {
    if (!IsSetup()) {
        ReplyToCommand(client, "The game is not setup yet, so there is no map list specified.");
    } else {
        GetMapList();
        int n = GetArraySize(g_MapNames);
        if (n == 0) {
            ReplyToCommand(client, "This map list is empty");
        }

        for (int i = 0; i < n; i++) {
            char mapName[PLATFORM_MAX_PATH];
            GetArrayString(g_MapNames, i, mapName, sizeof(mapName));
            ReplyToCommand(client, mapName);
        }
    }
}

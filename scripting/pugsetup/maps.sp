public void ChangeMap() {
    char map[PLATFORM_MAX_PATH];
    GetArrayString(GetCurrentMapList(), g_ChosenMap, map, sizeof(map));
    PugSetupMessageToAll("Changing map to {GREEN}%s{NORMAL}...", map);
    CreateTimer(3.0, Timer_DelayedChangeMap);
}

public Action Timer_DelayedChangeMap(Handle timer) {
    char map[PLATFORM_MAX_PATH];
    GetArrayString(GetCurrentMapList(), g_ChosenMap, map, sizeof(map));
    g_mapSet = true;
    ServerCommand("changelevel %s", map);
    return Plugin_Handled;
}

public void AddBackupMaps(ArrayList array) {
    AddMap("de_cache", array);
    AddMap("de_dust2", array);
    AddMap("de_inferno", array);
    AddMap("de_mirage", array);
    AddMap("de_nuke", array);
    AddMap("de_overpass", array);
    AddMap("de_season", array);
    AddMap("de_train", array);
}

public void GetMapList(const char[] fileName, ArrayList array) {
    char mapFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, mapFile, sizeof(mapFile), "configs/pugsetup/%s", fileName);

    if (!FileExists(mapFile)) {
        LogError("Missing map file: %s", mapFile);
    } else {
        File file = OpenFile(mapFile, "r");
        char mapName[PLATFORM_MAX_PATH];
        while (!file.EndOfFile() && file.ReadLine(mapName, sizeof(mapName))) {
            TrimString(mapName);
            AddMap(mapName, array);
        }
        delete file;
    }

    if (array.Length < 1) {
        LogError("The map file was empty: %s", mapFile);
        AddBackupMaps(array);
    }
}

public void AddMap(const char[] mapName, ArrayList array) {
    bool isComment = strlen(mapName) >= 2 && mapName[0] == '/' && mapName[1] == '/';
    if (strlen(mapName) <= 2 || isComment) {
        return;
    }

    // only add valid maps and non-duplicate maps
    if (IsMapValid(mapName) && FindStringInArray(array, mapName) == -1) {
        array.PushString(mapName);
    }
}

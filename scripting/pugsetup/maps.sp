public void ChangeMap() {
    char map[PLATFORM_MAX_PATH];
    GetArrayString(g_MapList, g_ChosenMap, map, sizeof(map));
    PugSetupMessageToAll("Changing map to {GREEN}%s{NORMAL}...", map);
    CreateTimer(3.0, Timer_DelayedChangeMap);
}

public Action Timer_DelayedChangeMap(Handle timer) {
    char map[PLATFORM_MAX_PATH];
    GetArrayString(g_MapList, g_ChosenMap, map, sizeof(map));
    g_MapSet = true;
    g_SwitchingMaps = true;
    ServerCommand("changelevel %s", map);
    return Plugin_Handled;
}

public void AddBackupMaps() {
    AddMap("de_cache");
    AddMap("de_dust2");
    AddMap("de_inferno");
    AddMap("de_mirage");
    AddMap("de_nuke");
    AddMap("de_overpass");
    AddMap("de_season");
    AddMap("de_train");
}

public void GetMapList(const char[] fileName) {
    g_MapList.Clear();
    char mapFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, mapFile, sizeof(mapFile), "configs/pugsetup/%s", fileName);

    if (!FileExists(mapFile)) {
        LogError("Missing map file: %s", mapFile);
    } else {
        File file = OpenFile(mapFile, "r");
        char mapName[PLATFORM_MAX_PATH];
        while (!file.EndOfFile() && file.ReadLine(mapName, sizeof(mapName))) {
            TrimString(mapName);
            AddMap(mapName);
        }
        delete file;
    }

    Call_StartForward(g_hOnMapListRead);
    Call_PushString(fileName);
    Call_PushCell(g_MapList);
    Call_PushCell(false);
    Call_Finish();
}

public void AddMap(const char[] mapName) {
    bool isComment = strlen(mapName) >= 2 && mapName[0] == '/' && mapName[1] == '/';
    if (strlen(mapName) <= 2 || isComment) {
        return;
    }

    // only add valid maps and non-duplicate maps
    if (IsMapValid(mapName) && g_MapList.FindString(mapName) == -1) {
        g_MapList.PushString(mapName);
    }
}

public void AddMapIndexToMenu(Menu menu, ArrayList mapList, int mapIndex) {
    char map[PLATFORM_MAX_PATH];
    mapList.GetString(mapIndex, map, sizeof(map));

    // explode map by '/' so we can remove any directory prefixes (e.g. workshop stuff)
    char buffers[4][PLATFORM_MAX_PATH];
    int numSplits = ExplodeString(map, "/", buffers, sizeof(buffers), PLATFORM_MAX_PATH);
    int mapStringIndex = (numSplits > 0) ? (numSplits - 1) : (0);

    AddMenuInt(menu, mapIndex, buffers[mapStringIndex]);
}

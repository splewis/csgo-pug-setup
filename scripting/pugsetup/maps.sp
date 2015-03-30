static char g_BackupMaps[][] = {
    "de_cache",
    "de_cbble",
    "de_dust2",
    "de_inferno",
    "de_mirage",
    "de_nuke",
    "de_overpass",
    "de_season",
    "de_train",
};

stock void ChangeMap(ArrayList mapList, int mapIndex=-1, float delay=3.0, bool toFinalMap=true) {
    char map[PLATFORM_MAX_PATH];

    if (mapIndex == -1) {
        mapIndex = GetArrayRandomIndex(mapList);
    }

    // print the formatted name
    FormatMapName(mapList, mapIndex, map, sizeof(map));
    PugSetupMessageToAll("Changing map to {GREEN}%s{NORMAL}...", map);

    // pass the "true" name to a timer to changelevel
    mapList.GetString(mapIndex, map, sizeof(map));
    Handle data = CreateDataPack();
    WritePackString(data, map);
    WritePackCell(data, toFinalMap);

    CreateTimer(delay, Timer_DelayedChangeMap, data);
}

public Action Timer_DelayedChangeMap(Handle timer, Handle pack) {
    char map[PLATFORM_MAX_PATH];
    ResetPack(pack);
    ReadPackString(pack, map, sizeof(map));
    bool toFinalMap = ReadPackCell(pack);

    if (toFinalMap) {
        g_OnDecidedMap = true;
    }

    g_SwitchingMaps = true;
    ServerCommand("changelevel %s", map);
    return Plugin_Handled;
}

public void AddBackupMaps() {
    for (int i = 0; i < sizeof(g_BackupMaps); i++)
        AddMap(g_BackupMaps[i], g_MapList);
}

public bool GetMapList(const char[] fileName, ArrayList mapList) {
    mapList.Clear();
    char mapFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, mapFile, sizeof(mapFile), "configs/pugsetup/%s", fileName);

    if (!FileExists(mapFile)) {
        LogError("Missing map file: %s", mapFile);
        return false;
    } else {
        File file = OpenFile(mapFile, "r");
        if (file != null) {
            char mapName[PLATFORM_MAX_PATH];
            while (!file.EndOfFile() && file.ReadLine(mapName, sizeof(mapName))) {
                TrimString(mapName);
                AddMap(mapName, mapList);
            }
            delete file;
        } else {
            LogError("Failed to open maplist for reading: %s", mapFile);
            return false;
        }
    }

    Call_StartForward(g_hOnMapListRead);
    Call_PushString(fileName);
    Call_PushCell(mapList);
    Call_PushCell(false);
    Call_Finish();
    return true;
}

public bool WriteMapList(const char[] fileName, ArrayList mapList) {
    char mapFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, mapFile, sizeof(mapFile), "configs/pugsetup/%s", fileName);

    if (!FileExists(mapFile)) {
        LogError("Missing map file: %s", mapFile);
    } else {
        File file = OpenFile(mapFile, "w");
        if (file != null) {
            char mapName[PLATFORM_MAX_PATH];
            for (int i = 0; i < mapList.Length; i++) {
                mapList.GetString(i, mapName, sizeof(mapName));
                file.WriteLine(mapName);
            }
            delete file;
            return true;
        } else {
            LogError("Failed to open maplist for reading: %s", mapFile);
            return false;
        }
    }

    return false;
}

public bool AddToMapList(const char[] mapName) {
    if (UsingWorkshopCollection())
        return false;

    char maplist[PLATFORM_MAX_PATH];
    g_MapListCvar.GetString(maplist, sizeof(maplist));

    char mapFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, mapFile, sizeof(mapFile), "configs/pugsetup/%s", maplist);

    File file = OpenFile(mapFile, "a");
    if (file != null) {
        file.WriteLine(mapName);
        delete file;
        return true;
    } else {
        LogError("Failed to open maplist for writing: %s", mapFile);
    }
    return false;
}

public bool RemoveMapFromList(const char[] mapName) {
    if (UsingWorkshopCollection())
        return false;

    char maplist[PLATFORM_MAX_PATH];
    g_MapListCvar.GetString(maplist, sizeof(maplist));

    ArrayList tmpList = new ArrayList(PLATFORM_MAX_PATH);
    GetMapList(maplist, tmpList);

    if (!RemoveMap(mapName, tmpList))
        return false;

    if (!WriteMapList(maplist, tmpList))
        return false;

    return true;
}

public bool AddMap(const char[] mapName, ArrayList mapList) {
    bool isComment = strlen(mapName) >= 2 && mapName[0] == '/' && mapName[1] == '/';
    if (strlen(mapName) <= 2 || isComment) {
        return false;
    }

    // only add valid maps and non-duplicate maps
    if (IsMapValid(mapName) && mapList.FindString(mapName) == -1) {
        LogDebug("succesfully added map %s to maplist", mapName);
        mapList.PushString(mapName);
        return true;
    }

    return false;
}

public bool RemoveMap(const char[] mapName, ArrayList mapList) {
    int index = mapList.FindString(mapName);

    if (index == -1) {
        return false;
    } else {
        mapList.Erase(index);
        return true;
    }
}

public void FormatMapName(ArrayList mapList, int mapIndex, char[] buffer, int len) {
    char map[PLATFORM_MAX_PATH];
    mapList.GetString(mapIndex, map, sizeof(map));

    // explode map by '/' so we can remove any directory prefixes (e.g. workshop stuff)
    char buffers[4][PLATFORM_MAX_PATH];
    int numSplits = ExplodeString(map, "/", buffers, sizeof(buffers), PLATFORM_MAX_PATH);
    int mapStringIndex = (numSplits > 0) ? (numSplits - 1) : (0);
    strcopy(buffer, len, buffers[mapStringIndex]);
}

public void AddMapIndexToMenu(Menu menu, ArrayList mapList, int mapIndex) {
    char mapName[128];
    FormatMapName(mapList, mapIndex, mapName, sizeof(mapName));
    AddMenuInt(menu, mapIndex, mapName);
}

public bool OnAimMap() {
    ArrayList maps = new ArrayList(PLATFORM_MAX_PATH);
    GetMapList("aim_maps.txt", maps);

    char currentMap[PLATFORM_MAX_PATH];
    GetCurrentMap(currentMap, sizeof(currentMap));

    // if the map starts with 'aim' or exists in the aim map list
    bool ret = StrContains(currentMap, "aim") == 0 || maps.FindString(currentMap) >= 0;

    delete maps;
    return ret;
}

public void ChangeToAimMap() {
    ArrayList maps = new ArrayList(PLATFORM_MAX_PATH);
    GetMapList("aim_maps.txt", maps);
    if (maps.Length > 0) {
        ChangeMap(maps, GetArrayRandomIndex(maps), 5.0, false);
    }
    delete maps;
}

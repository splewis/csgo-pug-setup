public void Config_MapStart() {
    char maplist[PLATFORM_MAX_PATH];
    g_hMapList.GetString(maplist, sizeof(maplist));

    int collectionID = StringToInt(maplist);

    if (collectionID == 0) {
        // it's a regular map list
        GetMapList(maplist);
    } else {
        // it's a workshop collection id, setup the workshop cache
        BuildPath(Path_SM, g_DataDir, sizeof(g_DataDir), "data/pugsetup");

        if (!DirExists(g_DataDir)) {
            CreateDirectory(g_DataDir, 511);
        }

        Format(g_CacheFile, sizeof(g_CacheFile), "%s/cache.cfg", g_DataDir);
        g_WorkshopCache = new KeyValues("Workshop");
        g_WorkshopCache.ImportFromFile(g_CacheFile);
        UpdateWorkshopCache(collectionID);
    }
}

public void SetConfigDefaults() {
    char buffer[128];

    g_hDefaultMapType.GetString(buffer, sizeof(buffer));
    g_MapType = MapTypeFromString(buffer);

    g_hDefaultTeamType.GetString(buffer, sizeof(buffer));
    g_TeamType = TeamTypeFromString(buffer);

    g_RecordGameOption = (g_hDefaultRecord.IntValue != 0);
    if (!IsTVEnabled())
        g_RecordGameOption = false;

    g_PlayersPerTeam = g_hDefaultTeamSize.IntValue;

    g_DoKnifeRound = (g_hDefaultKnifeRounds.IntValue != 0);
}

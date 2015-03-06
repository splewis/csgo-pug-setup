/**
 * Update maplist info and fetch any workshop info needed.
 */
stock void InitMapSettings() {
    ClearArray(g_MapList);

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

stock void ReadChatConfig() {
    char configFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configFile, sizeof(configFile), "configs/pugsetup/chataliases.cfg");
    KeyValues kv = new KeyValues("ChatAliases");
    if (kv.ImportFromFile(configFile) && kv.GotoFirstSubKey(false)) {
        do {
            char alias[ALIAS_LENGTH];
            char command[COMMAND_LENGTH];
            kv.GetSectionName(alias, sizeof(alias));
            kv.GetString(NULL_STRING, command, sizeof(command));
            AddChatAlias(alias, command);
        } while (kv.GotoNextKey(false));
    }
    delete kv;
}

stock void ReadSetupOptions() {
    char configFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configFile, sizeof(configFile), "configs/pugsetup/setupsettings.cfg");
    KeyValues kv = new KeyValues("SetupSettings");
    if (kv.ImportFromFile(configFile) && kv.GotoFirstSubKey()) {
        do {
            char setting[128];
            char buffer[128];
            kv.GetSectionName(setting, sizeof(setting));
            bool display = !!kv.GetNum("display_setting", 1);

            if (StrEqual(setting, "map_type", false)) {
                kv.GetString("default", buffer, sizeof(buffer), "vote");
                g_MapType = MapTypeFromString(buffer);
                g_DisplayMapType = display;

            } else if (StrEqual(setting, "team_type", false)) {
                kv.GetString("default", buffer, sizeof(buffer), "captains");
                g_TeamType = TeamTypeFromString(buffer);
                g_DisplayTeamType = display;

            } else if (StrEqual(setting, "auto_live", false)) {
                g_AutoLive = !!kv.GetNum("default", 0);
                g_DisplayAutoLive = display;

            } else if (StrEqual(setting, "knife_round", false)) {
                g_DoKnifeRound = !!kv.GetNum("default", 0);
                g_DisplayKnifeRound = display;

            } else if (StrEqual(setting, "team_size", false)) {
                g_PlayersPerTeam = kv.GetNum("default", 5);
                g_DisplayTeamSize = display;

            } else if (StrEqual(setting, "record_demo", false)) {
                g_RecordGameOption = !!kv.GetNum("default", 0);
                g_DisplayRecordDemo = display;

            } else if (StrEqual(setting, "allow_map_change", false)) {
                g_DisplayMapChange = display;

            } else {
                LogError("Unknown section name in %s: \"%s\"", configFile, setting);
            }

        } while (kv.GotoNextKey());
    }
    delete kv;
}

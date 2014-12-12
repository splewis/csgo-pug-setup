/**
 * Parses the pugsetup config file, populating the
 * gametype / map files / config files
 * arrays that specify options for each game type.
 */
public Config_MapStart() {
    g_GameTypes = CreateArray(CONFIG_STRING_LENGTH);
    g_GameConfigFiles = CreateArray(CONFIG_STRING_LENGTH);
    g_GameMapFiles = CreateArray(CONFIG_STRING_LENGTH);

    g_GameTypeHidden = CreateArray();
    g_GameTypeTeamSize = CreateArray();
    g_GameTypeMapTypes = CreateArray();
    g_GameTypeTeamTypes = CreateArray();

    char configFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configFile, sizeof(configFile), "configs/pugsetup/gametypes.cfg");

    if (!FileExists(configFile)) {
        LogError("The pugsetup config file does not exist");
        LoadBackupConfig();
        GameTypeForward();
        return;
    }

    Handle kv = CreateKeyValues("GameTypes");
    FileToKeyValues(kv, configFile);
    if (!KvGotoFirstSubKey(kv)) {
        LogError("The pugsetup config file was empty");
        CloseHandle(kv);
        LoadBackupConfig();
        GameTypeForward();
        return;
    }

    char name[CONFIG_STRING_LENGTH];
    char config[CONFIG_STRING_LENGTH];
    char maplist[CONFIG_STRING_LENGTH];
    char teamTypeString[CONFIG_STRING_LENGTH];
    char mapTypeString[CONFIG_STRING_LENGTH];

    do {
        KvGetSectionName(kv, name, sizeof(name));
        KvGetString(kv, "config", config, sizeof(config), "gamemode_competitive.cfg");
        KvGetString(kv, "maplist", maplist, sizeof(maplist), "standard.txt");
        bool visible = !KvGetNum(kv, "hidden", 0);
        int teamsize = KvGetNum(kv, "teamsize", -1);

        KvGetString(kv, "teamtype", teamTypeString, sizeof(teamTypeString), "unspecified");
        KvGetString(kv, "maptype", mapTypeString, sizeof(mapTypeString), "unspecified");
        TeamType teamType = TeamTypeFromString(teamTypeString, TeamType_Unspecified, true, true);
        MapType mapType = MapTypeFromString(mapTypeString, MapType_Unspecified, true, true);

        AddGameType(name, config, maplist, visible, teamsize, teamType, mapType);
    } while (KvGotoNextKey(kv));

    CloseHandle(kv);
    GameTypeForward();
}

static void GameTypeForward() {
    Call_StartForward(g_OnGameTypesAdded);
    Call_Finish();
}

static LoadBackupConfig() {
    LogError("Falling back to builtin backup config");
    AddGameType("Normal", "gamemode_competitive.cfg", "standard.txt");
}

public Config_MapEnd() {
    CloseHandle(g_GameTypes);
    CloseHandle(g_GameConfigFiles);
    CloseHandle(g_GameMapFiles);

    CloseHandle(g_GameTypeHidden);
    CloseHandle(g_GameTypeTeamSize);
    CloseHandle(g_GameTypeMapTypes);
    CloseHandle(g_GameTypeTeamTypes);
}

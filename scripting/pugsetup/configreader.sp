/**
 * Parses the pugsetup config file, populating the
 * gametype / map files / config files
 * arrays that specify options for each game type.
 */
public Config_MapStart() {
    g_GameTypes = CreateArray(CONFIG_STRING_LENGTH);
    g_GameMapFiles = CreateArray(CONFIG_STRING_LENGTH);
    g_GameConfigFiles = CreateArray(CONFIG_STRING_LENGTH);

    decl String:configFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configFile, sizeof(configFile), "configs/pugsetup/gametypes.cfg");

    if (!FileExists(configFile)) {
        LogError("The pugsetup config file does not exist");
        LoadBackupConfig();
        return;
    }

    new Handle:kv = CreateKeyValues("GameTypes");
    FileToKeyValues(kv, configFile);
    if (!KvGotoFirstSubKey(kv)) {
        LogError("The pugsetup config file was empty");
        CloseHandle(kv);
        LoadBackupConfig();
        return;
    }

    do {
        char buffer[CONFIG_STRING_LENGTH];
        KvGetSectionName(kv, buffer, sizeof(buffer));
        PushArrayString(g_GameTypes, buffer);

        KvGetString(kv, "config", buffer, sizeof(buffer));
        PushArrayString(g_GameConfigFiles, buffer);

        KvGetString(kv, "maplist", buffer, sizeof(buffer), "standard.txt");
        PushArrayString(g_GameMapFiles, buffer);

    } while (KvGotoNextKey(kv));

    CloseHandle(kv);
}

static LoadBackupConfig() {
    PushArrayString(g_GameTypes, "Normal");
    PushArrayString(g_GameMapFiles, "standard.txt");
    PushArrayString(g_GameConfigFiles, "standard.cfg");
}

public Config_MapEnd() {
    CloseHandle(g_GameTypes);
    CloseHandle(g_GameMapFiles);
    CloseHandle(g_GameConfigFiles);
}

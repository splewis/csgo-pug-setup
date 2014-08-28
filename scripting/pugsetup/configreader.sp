/**
 * Parses the pugsetup config file, populating the
 * gametype / map files / config files
 * arrays that specify options for each game type.
 */
public Config_MapStart() {
    g_GameTypes = CreateArray(256);
    g_GameMapFiles = CreateArray(256);
    g_GameConfigFiles = CreateArray(256);

    decl String:configFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configFile, sizeof(configFile), "configs/pugsetup/gametypes.cfg");

    if (!FileExists(configFile)) {
        LogMessage("The pugsetup config file does not exist");
        return;
    }

    new Handle:kv = CreateKeyValues("GameTypes");
    FileToKeyValues(kv, configFile);
    if (!KvGotoFirstSubKey(kv)) {
        LogMessage("The pugsetup config file was empty");
        CloseHandle(kv);
        return;
    }

    do {
        char buffer[256];
        KvGetSectionName(kv, buffer, sizeof(buffer));
        PushArrayString(g_GameTypes, buffer);
        LogMessage("%s", buffer);

        KvGetString(kv, "config", buffer, sizeof(buffer));
        PushArrayString(g_GameConfigFiles, buffer);
        LogMessage("%s", buffer);

        KvGetString(kv, "maplist", buffer, sizeof(buffer), "standard.txt");
        PushArrayString(g_GameMapFiles, buffer);
        LogMessage("%s\n", buffer);

    } while (KvGotoNextKey(kv));

    CloseHandle(kv);
}

public Config_MapEnd() {
    CloseHandle(g_GameTypes);
    CloseHandle(g_GameMapFiles);
    CloseHandle(g_GameConfigFiles);
}

#define CHAT_ALIAS_FILE "configs/pugsetup/chataliases.cfg"
#define SETUP_OPTIONS_FILE "configs/pugsetup/setupoptions.cfg"

/**
 * Update maplist info and fetch any workshop info needed.
 */
stock bool UsingWorkshopCollection() {
    char maplist[PLATFORM_MAX_PATH];
    g_hMapList.GetString(maplist, sizeof(maplist));
    int collectionID = StringToInt(maplist);
    return collectionID != 0;
}

stock void InitMapSettings() {
    ClearArray(g_MapList);

    char maplist[PLATFORM_MAX_PATH];
    g_hMapList.GetString(maplist, sizeof(maplist));

    int collectionID = StringToInt(maplist);

    if (collectionID == 0) {
        // it's a regular map list
        GetMapList(maplist, g_MapList);
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

public Action Command_AddMap(int client, int args) {
    char mapName[PLATFORM_MAX_PATH];
    char durationString[32];
    bool perm = true;

    if (args >= 1 && GetCmdArg(1, mapName, sizeof(mapName))) {
        if (args >= 2 && GetCmdArg(2, durationString, sizeof(durationString))) {
            perm = StrEqual(durationString, "perm", false);
        }

        if (AddMap(mapName, g_MapList)) {
            PugSetupMessage(client, "Succesfully added map %s", mapName);
            if (perm && !AddToMapList(mapName)) {
                PugSetupMessage(client, "Failed to add map to maplist file.");
            }
        } else {
            PugSetupMessage(client, "Map could not be found: %s", mapName);
        }
    } else {
        PugSetupMessage(client, "Usage: sm_addmap <map> [temp|perm] (default perm)");
    }

    return Plugin_Handled;
}

public Action Command_RemoveMap(int client, int args) {
    char mapName[PLATFORM_MAX_PATH];
    char durationString[32];
    bool perm = true;

    if (args >= 1 && GetCmdArg(1, mapName, sizeof(mapName))) {
        if (args >= 2 && GetCmdArg(2, durationString, sizeof(durationString))) {
            perm = StrEqual(durationString, "perm", false);
        }

        if (RemoveMap(mapName, g_MapList)) {
            PugSetupMessage(client, "Succesfully removed map %s", mapName);
            if (perm && !RemoveMapFromList(mapName)) {
                PugSetupMessage(client, "Failed to remove map from maplist file.");
            }
        } else {
            PugSetupMessage(client, "Map %s was not found", mapName);
        }
    } else {
        PugSetupMessage(client, "Usage: sm_removemap <map> [temp|perm] (default perm)");
    }

    return Plugin_Handled;
}

/**
 * Dealing with the chat alias config file.
 */
stock void ReadChatConfig() {
    char configFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configFile, sizeof(configFile), CHAT_ALIAS_FILE);
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

public Action Command_AddAlias(int client, int args) {
    char alias[ALIAS_LENGTH];
    char command[COMMAND_LENGTH];

    if (args >= 2 && GetCmdArg(1, alias, sizeof(alias)) && GetCmdArg(2, command, sizeof(command))) {
        if (!IsValidCommand(command)) {
            PugSetupMessage(client, "%s is not a valid pugsetup command.", command);
            PugSetupMessage(client, "Usage: sm_addalias <alias> <command>");
        } else {
            AddChatAlias(alias, command);
            if (AddChatAliasToFile(alias, command))
                PugSetupMessage(client, "Succesfully added %s as an alias of commmand %s", alias, command);
            else
                PugSetupMessage(client, "Failed to add chat alias");
        }
    } else {
        PugSetupMessage(client, "Usage: sm_addalias <alias> <command>");
    }

    return Plugin_Handled;
}

stock bool AddChatAliasToFile(const char[] alias, const char[] command) {
    char configFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configFile, sizeof(configFile), CHAT_ALIAS_FILE);
    KeyValues kv = new KeyValues("ChatAliases");
    kv.ImportFromFile(configFile);
    kv.SetString(alias, command);
    kv.Rewind();
    bool success = kv.ExportToFile(configFile);
    delete kv;
    return success;
}


/**
 * Dealing with the setup options config file.
 */
static char g_SetupKeys[][] = {"maptype", "teamtype", "autolive", "kniferound", "teamsize", "record", "mapchange"};

stock bool CheckEnabledFromString(const char[] value) {
    char strs[][] = { "true", "enabled", "1", "yes", "on" , "y" };
    for (int i = 0; i < sizeof(strs); i++) {
        if (StrEqual(value, strs[i], false)) {
            return true;
        }
    }
    return false;
}

stock bool CheckSetupOptionValidity(int client, const char[] setting, const char[] value, bool setDefault=true, bool setDisplay=false) {
    if (StrEqual(setting, "maptype", false)) {
        if (setDefault && !StrEqual(value, "vote") && !StrEqual(value, "veto") && !StrEqual(value, "manual")) {
            PugSetupMessage(client, "%s is not a valid option for setting %s, valid options are vote, veto, manual", value, setting);
            return false;
        } else if (setDefault) {
            g_MapType = MapTypeFromString(value);
        }

        if (setDisplay)
            g_DisplayMapType = CheckEnabledFromString(value);
        return true;

    } else if (StrEqual(setting, "teamtype", false)) {
        if (setDefault && !StrEqual(value, "captains") && !StrEqual(value, "manual") && !StrEqual(value, "random")) {
            PugSetupMessage(client, "%s is not a valid option for setting %s, valid options are captains, manual, random", value, setting);
            return false;
        } else if (setDefault) {
            g_TeamType = TeamTypeFromString(value);
        }

        if (setDisplay)
            g_DisplayTeamType = CheckEnabledFromString(value);
        return true;

    } else if (StrEqual(setting, "autolive", false)) {
        if (setDisplay)
            g_DisplayAutoLive = CheckEnabledFromString(value);
        if (setDefault)
            g_AutoLive = CheckEnabledFromString(value);

        return true;

    } else if (StrEqual(setting, "kniferound", false)) {
        if (setDisplay)
            g_DisplayKnifeRound = CheckEnabledFromString(value);
        if (setDefault)
            g_DoKnifeRound = CheckEnabledFromString(value);

        return true;

    } else if (StrEqual(setting, "teamsize", false)) {
        int teamsize = StringToInt(value);
        bool valid = teamsize >= 1;
        if (setDefault && !valid) {
            PugSetupMessage(client, "Teamsize %s is not valid", teamsize);
            return false;
        }

        if (setDisplay)
            g_DisplayTeamSize = CheckEnabledFromString(value);
        if (setDefault)
            g_PlayersPerTeam = teamsize;
        return true;

    } else if (StrEqual(setting, "record", false)) {
        if (setDisplay)
            g_DisplayRecordDemo = CheckEnabledFromString(value);
        if (setDefault)
            g_RecordGameOption = CheckEnabledFromString(value);
        return true;

    } else if (StrEqual(setting, "mapchange", false)) {
        if (setDisplay)
            g_DisplayMapChange = CheckEnabledFromString(value);
        return true;

    } else {
        char allSettings[128] = "\0";
        for (int i = 0; i < sizeof(g_SetupKeys); i++) {
            StrCat(allSettings, sizeof(allSettings), g_SetupKeys[i]);
            if (i < sizeof(g_SetupKeys) - 1)
                StrCat(allSettings, sizeof(allSettings), ", ");
        }

        PugSetupMessage(client, "%s is not a valid option", setting);
        PugSetupMessage(client, "Valid options are: %s", allSettings);
        return false;
    }
}

stock void ReadSetupOptions() {
    char configFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configFile, sizeof(configFile), SETUP_OPTIONS_FILE);
    KeyValues kv = new KeyValues("SetupOptions");
    if (kv.ImportFromFile(configFile) && kv.GotoFirstSubKey()) {
        do {
            char setting[128];
            char buffer[128];
            kv.GetSectionName(setting, sizeof(setting));
            bool display = !!kv.GetNum("display_setting", 1);

            if (StrEqual(setting, "maptype", false)) {
                kv.GetString("default", buffer, sizeof(buffer), "vote");
                g_MapType = MapTypeFromString(buffer);
                g_DisplayMapType = display;

            } else if (StrEqual(setting, "teamtype", false)) {
                kv.GetString("default", buffer, sizeof(buffer), "captains");
                g_TeamType = TeamTypeFromString(buffer);
                g_DisplayTeamType = display;

            } else if (StrEqual(setting, "autolive", false)) {
                kv.GetString("default", buffer, sizeof(buffer), "0");
                g_AutoLive = CheckEnabledFromString(buffer);
                g_DisplayAutoLive = display;

            } else if (StrEqual(setting, "kniferound", false)) {
                kv.GetString("default", buffer, sizeof(buffer), "0");
                g_DoKnifeRound = CheckEnabledFromString(buffer);
                g_DisplayKnifeRound = display;

            } else if (StrEqual(setting, "teamsize", false)) {
                g_PlayersPerTeam = kv.GetNum("default", 5);
                g_DisplayTeamSize = display;

            } else if (StrEqual(setting, "record", false)) {
                kv.GetString("default", buffer, sizeof(buffer), "0");
                g_RecordGameOption = CheckEnabledFromString(buffer);
                g_DisplayRecordDemo = display;

            } else if (StrEqual(setting, "mapchange", false)) {
                g_DisplayMapChange = display;

            } else {
                LogError("Unknown section name in %s: \"%s\"", configFile, setting);
            }

        } while (kv.GotoNextKey());
    }
    delete kv;
}

public Action Command_SetDefault(int client, int args) {
    char setting[32];
    char value[32];

    if (args >= 2 && GetCmdArg(1, setting, sizeof(setting)) && GetCmdArg(2, value, sizeof(value))) {
        if (CheckSetupOptionValidity(client, setting, value, true, false)) {
            if (SetDefaultInFile(setting, value))
                PugSetupMessage(client, "Succesfully set default option %s as %s", setting, value);
            else
                PugSetupMessage(client, "Failed to write default setting to file");
        }
    } else {
        PugSetupMessage(client, "Usage: sm_setdefault <setting> <default>");
    }

    return Plugin_Handled;
}

public Action Command_SetDisplay(int client, int args) {
    char setting[32];
    char value[32];

    if (args >= 2 && GetCmdArg(1, setting, sizeof(setting)) && GetCmdArg(2, value, sizeof(value))) {
        if (CheckSetupOptionValidity(client, setting, value, false, true)) {
            if (SetDisplayInFile(setting, CheckEnabledFromString(value)))
                PugSetupMessage(client, "Succesfully set display for setting %s as %s", setting, value);
            else
                PugSetupMessage(client, "Failed to write display setting to file");
        }
    } else {
        PugSetupMessage(client, "Usage: sm_setdefault <setting> <0/1>");
    }

    return Plugin_Handled;
}

stock bool SetDefaultInFile(const char[] setting, const char[] newValue) {
    char configFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configFile, sizeof(configFile), SETUP_OPTIONS_FILE);
    KeyValues kv = new KeyValues("SetupOptions");
    kv.ImportFromFile(configFile);
    kv.JumpToKey(setting, true);
    kv.SetString("default", newValue);
    kv.Rewind();
    bool success = kv.ExportToFile(configFile);
    delete kv;
    return success;
}

stock bool SetDisplayInFile(const char[] setting, bool display) {
    char configFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configFile, sizeof(configFile), SETUP_OPTIONS_FILE);
    KeyValues kv = new KeyValues("SetupOptions");
    kv.ImportFromFile(configFile);
    kv.JumpToKey(setting, true);
    kv.SetNum("display_setting", display);
    kv.Rewind();
    bool success = kv.ExportToFile(configFile);
    delete kv;
    return success;
}

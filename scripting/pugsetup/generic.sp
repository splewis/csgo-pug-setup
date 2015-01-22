#include <cstrike>
#include <sdktools>

#tryinclude "../include/pugsetup_version.inc"
#if !defined PLUGIN_VERSION
#define PLUGIN_VERSION "1.3.0-dev"
#endif

char g_ColorNames[][] = {"{NORMAL}", "{DARK_RED}", "{PINK}", "{GREEN}", "{YELLOW}", "{LIGHT_GREEN}", "{LIGHT_RED}", "{GRAY}", "{ORANGE}", "{LIGHT_BLUE}", "{DARK_BLUE}", "{PURPLE}", "{CARRIAGE_RETURN}"};
char g_ColorCodes[][] = {"\x01",     "\x02",      "\x03",   "\x04",         "\x05",     "\x06",          "\x07",        "\x08",   "\x09",     "\x0B",         "\x0C",        "\x0E",     "\n"};

/**
 * Executes a config file named by a convar.
 */
stock void ExecCfg(ConVar ConVarName) {
    char cfg[PLATFORM_MAX_PATH];
    ConVarName.GetString(cfg, sizeof(cfg));
    ServerCommand("exec \"%s\"", cfg);
}

/**
 * Adds an integer to a menu as a string choice.
 */
stock void AddMenuInt(Menu menu, int value, const char[] display, any:...) {
    char formattedDisplay[128];
    VFormat(formattedDisplay, sizeof(formattedDisplay), display, 4);
    char buffer[8];
    IntToString(value, buffer, sizeof(buffer));
    menu.AddItem(buffer, formattedDisplay);
}

/**
 * Adds an integer to a menu, named by the integer itself.
 */
stock void AddMenuInt2(Menu menu, int value) {
    char buffer[8];
    IntToString(value, buffer, sizeof(buffer));
    menu.AddItem(buffer, buffer);
}

/**
 * Gets an integer to a menu from a string choice.
 */
stock int GetMenuInt(Menu menu, int param2) {
    char buffer[8];
    menu.GetItem(param2, buffer, sizeof(buffer));
    return StringToInt(buffer);
}

/**
 * Adds a boolean to a menu as a string choice.
 */
stock void AddMenuBool(Menu menu, bool value, const char[] display, any:...) {
    char formattedDisplay[128];
    VFormat(formattedDisplay, sizeof(formattedDisplay), display, 4);
    int convertedInt = value ? 1 : 0;
    AddMenuInt(menu, convertedInt, formattedDisplay);
}

/**
 * Gets a boolean to a menu from a string choice.
 */
stock bool GetMenuBool(Menu menu, int param2) {
    return GetMenuInt(menu, param2) != 0;
}

/**
 * Returns the number of human clients on a team.
 */
stock int GetNumHumansOnTeam(int team) {
    int count = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i) && !IsFakeClient(i))
            count++;
    }
    return count;
}

/**
 * Returns a random player client on the server.
 */
stock int RandomPlayer() {
    int client = -1;
    while (!IsValidClient(client) || IsFakeClient(client)) {
        if (GetRealClientCount() < 1)
            return -1;

        client = GetRandomInt(1, MaxClients);
    }
    return client;
}

/**
 * Switches and respawns a player onto a new team.
 */
stock void SwitchPlayerTeam(int client, int team) {
    if (GetClientTeam(client) == team)
        return;

    ForcePlayerSuicide(client);
    if (team > CS_TEAM_SPECTATOR) {
        CS_SwitchTeam(client, team);
        CS_UpdateClientModel(client);
        CS_RespawnPlayer(client);
    } else {
        ChangeClientTeam(client, team);
    }
}

/**
 * Returns if a client is valid.
 */
stock bool IsValidClient(int client) {
    if (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client))
        return true;
    return false;
}

stock bool IsPlayer(int client) {
    return IsValidClient(client) && !IsFakeClient(client);
}

/**
 * Returns the number of clients that are actual players in the game.
 */
stock int GetRealClientCount() {
    int clients = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) {
            clients++;
        }
    }
    return clients;
}

/**
 * Returns a random index from an array.
 */
stock int GetArrayRandomIndex(ArrayList array) {
    int len = array.Length;
    if (len == 0)
        ThrowError("Can't get random index from empty array");
    return GetRandomInt(0, len - 1);
}

/**
 * Returns a random element from an array.
 */
stock int GetArrayCellRandom(ArrayList array) {
    int index = GetArrayRandomIndex(array);
    return array.Get(index);
}

stock void Colorize(char[] msg, int size) {
    for (int i = 0; i < sizeof(g_ColorNames); i ++) {
        ReplaceString(msg, size, g_ColorNames[i], g_ColorCodes[i]);
    }
}

stock void RandomizeArray(ArrayList array) {
    int n = array.Length;
    for (int i = 0; i < n; i++) {
        int choice = GetRandomInt(0, n - 1);
        array.SwapAt(i, choice);
    }
}

// Thanks to KissLick https://forums.alliedmods.net/member.php?u=210752
stock bool SplitStringRight(const char[] source, const char[] split, char[] part, int partLen) {
    int index = StrContains(source, split);
    if (index == -1)
        return false;

    index += strlen(split);
    strcopy(part, partLen, source[index]);
    return true;
}

stock bool IsPrefix(const char[] str, const char[] prefix) {
    return StrContains(str, prefix, false) == 0;
}

stock bool IsTVEnabled() {
    Handle tvEnabledCvar = FindConVar("tv_enable");
    if (tvEnabledCvar == INVALID_HANDLE) {
        LogError("Failed to get tv_enable cvar");
        return false;
    }
    return GetConVarInt(tvEnabledCvar) != 0;
}

stock void Record(const char[] demoName) {
    char szDemoName[256];
    strcopy(szDemoName, sizeof(szDemoName), demoName);
    ReplaceString(szDemoName, sizeof(szDemoName), "\"", "\\\"");
    ServerCommand("tv_record \"%s\"", szDemoName);

    Handle tvEnabledCvar = FindConVar("tv_enable");
    if (tvEnabledCvar == INVALID_HANDLE) {
        LogError("Failed to get tv_enable cvar");
    } else if (GetConVarInt(tvEnabledCvar) == 0) {
        LogError("Autorecording will not work with current cvar \"tv_enable\"=0. Set \"tv_enable 1\" in server.cfg (or another config file) to fix this.");
    }
}

stock bool IsPaused() {
    return bool:GameRules_GetProp("m_bMatchWaitingForResume");
}

stock int GetCookieInt(int client, Handle cookie) {
    char buffer[32];
    GetClientCookie(client, cookie, buffer, sizeof(buffer));
    return StringToInt(buffer);
}

stock float GetCookieFloat(int client, Handle cookie) {
    char buffer[32];
    GetClientCookie(client, cookie, buffer, sizeof(buffer));
    return StringToFloat(buffer);
}

stock void SetCookieInt(int client, Handle cookie, int value) {
    char buffer[32];
    IntToString(value, buffer, sizeof(buffer));
    SetClientCookie(client, cookie, buffer);
}

stock void SetCookieFloat(int client, Handle cookie, float value) {
    char buffer[32];
    FloatToString(value, buffer, sizeof(buffer));
    SetClientCookie(client, cookie, buffer);
}

stock void SetConVarStringSafe(const char[] name, const char[] value) {
    Handle cvar = FindConVar(name);
    if (cvar == INVALID_HANDLE) {
        LogError("Failed to find cvar: \"%s\"", name);
    } else {
        SetConVarString(cvar, value);
    }
}

stock void SetTeamInfo(int team, const char[] name, const char[] flag) {
    int team_int = (team == CS_TEAM_CT) ? 1 : 2;

    char teamCvarName[32];
    char flagCvarName[32];
    Format(teamCvarName, sizeof(teamCvarName), "mp_teamname_%d", team_int);
    Format(flagCvarName, sizeof(flagCvarName), "mp_teamflag_%d", team_int);

    SetConVarStringSafe(teamCvarName, name);
    SetConVarStringSafe(flagCvarName, flag);
}

stock void UpdateClanTag(int client, bool strip=false) {
    if (IsPlayer(client)) {

        // don't bother with crazy things when the plugin isn't active
        if (g_MatchLive || !g_Setup || strip) {
            CS_SetClientClanTag(client, "");
            return;
        }

        int team = GetClientTeam(client);
        if (g_hExcludeSpectators.IntValue == 0 || team == CS_TEAM_CT || team == CS_TEAM_T) {
            char tag[32];
            if (g_Ready[client]) {
                Format(tag, sizeof(tag), "%T", "Ready", LANG_SERVER);
            } else {
                Format(tag, sizeof(tag), "%T", "NotReady", LANG_SERVER);
            }
            CS_SetClientClanTag(client, tag);
        } else {
            CS_SetClientClanTag(client, "");
        }
    }
}

stock bool OnActiveTeam(int client) {
    if (!IsPlayer(client))
        return false;

    int team = GetClientTeam(client);
    return team == CS_TEAM_CT || team == CS_TEAM_T;
}

/**
 * Closes a nested adt-array.
 */
stock void CloseNestedArray(Handle array, bool clearOuterArray=true) {
    int n = GetArraySize(array);
    for (int i = 0; i < n; i++) {
        Handle h = GetArrayCell(array, i);
        CloseHandle(h);
    }

    if (clearOuterArray)
        CloseHandle(array);
}

stock void GetEnabledString(char[] buffer, int length, bool variable, int lang=LANG_SERVER) {
    if (variable)
        Format(buffer, length, "%T", "Enabled", lang);
    else
        Format(buffer, length, "%T", "Disabled", lang);
}

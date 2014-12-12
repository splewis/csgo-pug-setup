#pragma semicolon 1
#include <cstrike>
#include <sourcemod>

#include "include/pugsetup.inc"
#include "pugsetup/generic.sp"

Handle g_hEnabled = INVALID_HANDLE;
Handle g_hGameType = INVALID_HANDLE;
Handle g_hMapType = INVALID_HANDLE;
Handle g_hTeamSize = INVALID_HANDLE;
Handle g_hTeamType = INVALID_HANDLE;

// To prevent multiple setups if the game is aborted (!endmatch, !forceend),
// this tracks if this plugin has done a setup - so at most 1
// call to SetupGame happens per map.
bool g_ForceEnded = false;

public Plugin:myinfo = {
    name = "CS:GO PugSetup: auto setup",
    author = "splewis",
    description = "Sets up a game without a player needing to type .setup",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-pug-setup"
};

public void OnPluginStart() {
    LoadTranslations("pugsetup.phrases");
    g_hEnabled = CreateConVar("sm_pugsetup_autosetup_teamsize", "5", "Number of players per team.");
    g_hGameType = CreateConVar("sm_pugsetup_autosetup_gametype", "Normal", "Game type from addons/sourcemod/configs/pugsetup/gametypes.cfg to use.");
    g_hMapType = CreateConVar("sm_pugsetup_autosetup_maptype", "vote", "Vote type to use. Allowed values: \"vote\", \"veto\", \"current\".");
    g_hTeamSize = CreateConVar("sm_pugsetup_autosetup_enabled", "1", "Whether the plugin is enabled or not.");
    g_hTeamType = CreateConVar("sm_pugsetup_autosetup_teamtype", "captains", "What team type to use. Allowed values: \"captains\", \"manual\", and \"random\".");
    AutoExecConfig(true, "pugsetup_autosetup", "sourcemod/pugsetup");
}

public void OnMapStart() {
    g_ForceEnded = false;
}

public void OnClientConnected() {
    Setup();
}

public void OnForceEnd(int client) {
    g_ForceEnded = true;
}

public void OnMatchOver() {
    g_ForceEnded = false;
    Setup();
}

public void Setup() {
    if (GetConVarInt(g_hEnabled) != 0 && !IsSetup() && !g_ForceEnded) {
        int teamsize = GetConVarInt(g_hTeamSize);

        char mapTypeStr[32];
        GetConVarString(g_hMapType, mapTypeStr, sizeof(mapTypeStr));
        MapType mapType = MapTypeFromString(mapTypeStr);

        char teamTypeStr[32];
        GetConVarString(g_hTeamType, teamTypeStr, sizeof(teamTypeStr));
        TeamType teamType = TeamTypeFromString(teamTypeStr);

        char gameType[256];
        GetConVarString(g_hGameType, gameType, sizeof(gameType));
        int gameTypeIndex = FindGameType(gameType);
        if (gameTypeIndex < 0) {
            LogError("There is no gametype matching \"%s\" in addons/sourcemod/configs/pugsetup/gametypes.cfg", gameType);
        } else {
            SetupGame(gameTypeIndex, teamType, mapType, teamsize);
        }
    }
}

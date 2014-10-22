#pragma semicolon 1
#include <cstrike>
#include <sourcemod>

#include "include/pugsetup.inc"
#include "pugsetup/generic.sp"

Handle g_hAutolo3 = INVALID_HANDLE;
Handle g_hEnabled = INVALID_HANDLE;
Handle g_hGameType = INVALID_HANDLE;
Handle g_hMapType = INVALID_HANDLE;
Handle g_hTeamSize = INVALID_HANDLE;
Handle g_hTeamType = INVALID_HANDLE;

// To prevent multiple setups if the game is aborted (!endmatch, !forceend),
// this tracks if this plugin has done a setup - so at most 1
// call to SetupGame happens per map.
bool g_Setup = false;

public Plugin:myinfo = {
    name = "CS:GO PugSetup: auto setup",
    author = "splewis",
    description = "Sets up a game without a player needing to type .setup",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-pug-setup"
};

public OnPluginStart() {
    LoadTranslations("pugsetup.phrases");
    g_hAutolo3 = CreateConVar("sm_pugsetup_autosetup_autolo3", "1", "Whether auto-live on 3 should be used.");
    g_hEnabled = CreateConVar("sm_pugsetup_autosetup_teamsize", "5", "Number of players per team.");
    g_hGameType = CreateConVar("sm_pugsetup_autosetup_gametype", "Normal", "Game type from addons/sourcemod/configs/pugsetup/gametypes.cfg to use.");
    g_hMapType = CreateConVar("sm_pugsetup_autosetup_maptype", "vote", "Vote type to use. Allowed values: \"vote\", \"veto\", \"current\".");
    g_hTeamSize = CreateConVar("sm_pugsetup_autosetup_enabled", "1", "Whether the plugin is enabled or not.");
    g_hTeamType = CreateConVar("sm_pugsetup_autosetup_teamtype", "captains", "What team type to use. Allowed values: \"captains\", \"manual\", and \"random\".");
    AutoExecConfig(true, "pugsetup_auto10man", "sourcemod/pugsetup");
}

public OnMapStart() {
    g_Setup = false;
}

public OnClientConnected() {
    if (GetConVarInt(g_hEnabled) != 0 && !IsSetup() && !g_Setup) {
        bool autolo3 = GetConVarInt(g_hAutolo3) != 0;
        int teamsize = GetConVarInt(g_hTeamSize);

        char mapTypeStr[32];
        GetConVarString(g_hMapType, mapTypeStr, sizeof(mapTypeStr));
        MapType mapType = MapType_Vote;

        if (StrEqual(mapTypeStr, "current")) {
            mapType = MapType_Current;
        } else if (StrEqual(mapTypeStr, "vote")) {
            mapType = MapType_Vote;
        } else if (StrEqual(mapTypeStr, "veto")) {
            mapType = MapType_Veto;
        } else {
            LogError("Invalid map type: %s", mapTypeStr);
        }

        char teamTypeStr[32];
        GetConVarString(g_hTeamType, teamTypeStr, sizeof(teamTypeStr));
        TeamType teamType = TeamType_Captains;

        if (StrEqual(teamTypeStr, "captains")) {
            teamType = TeamType_Captains;
        } else if (StrEqual(teamTypeStr, "manual")) {
            teamType = TeamType_Manual;
        } else if (StrEqual(teamTypeStr, "random")) {
            teamType = TeamType_Random;
        } else {
            LogError("Invalid team type: %s", teamTypeStr);
        }

        char gameType[256];
        GetConVarString(g_hGameType, gameType, sizeof(gameType));
        int gameTypeIndex = FindGameType(gameType);
        if (gameTypeIndex < 0) {
            LogError("There is no gametype matching \"%s\" in addons/sourcemod/configs/pugsetup/gametypes.cfg", gameType);
        } else {
            SetupGame(gameTypeIndex, teamType, mapType, teamsize, autolo3);
            g_Setup = true;
        }
    }
}

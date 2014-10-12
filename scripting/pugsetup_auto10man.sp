#pragma semicolon 1
#include <cstrike>
#include <sourcemod>

#include "include/pugsetup.inc"
#include "pugsetup/generic.sp"

Handle g_hAutolo3 = INVALID_HANDLE;
Handle g_hEnabled = INVALID_HANDLE;
Handle g_hGameType = INVALID_HANDLE;

public Plugin:myinfo = {
    name = "CS:GO PugSetup: auto 10 man setup",
    author = "splewis",
    description = "Sets up a game with 10-man settings without a player needing to type .setup",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-pug-setup"
};

public OnPluginStart() {
    LoadTranslations("pugsetup.phrases");
    g_hAutolo3 = CreateConVar("sm_pugsetup_auto10man_autol03", "1", "Whether auto-live on 3 should be used");
    g_hEnabled = CreateConVar("sm_pugsetup_auto10man_enabled", "1", "Whether the plugin is enabled or not");
    g_hGameType = CreateConVar("sm_pugsetup_auto10man_gametype", "Normal", "Game type from addons/sourcemod/configs/pugsetup/gametypes.cfg to use");
    AutoExecConfig(true, "pugsetup_auto10man", "sourcemod/pugsetup");
}

public OnClientConnected() {
    if (GetConVarInt(g_hEnabled) != 0 && !IsSetup()) {
        bool autolo3 = GetConVarInt(g_hAutolo3) != 0;
        char gameType[256];
        GetConVarString(g_hGameType, gameType, sizeof(gameType));
        int gameTypeIndex = FindGameType(gameType);
        if (gameTypeIndex < 0) {
            LogError("There is no gametype matching \"%s\" in addons/sourcemod/configs/pugsetup/gametypes.cfg", gameType);
        } else {
            SetupGame(gameTypeIndex, TeamType_Captains, MapType_Vote, 5, autolo3);
        }
    }
}

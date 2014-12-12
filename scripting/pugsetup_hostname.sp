#pragma semicolon 1
#include <cstrike>
#include <sourcemod>

#include "include/pugsetup.inc"
#include "pugsetup/generic.sp"

#define MAX_HOST_LENGTH 256

Handle g_hEnabled = INVALID_HANDLE;
char g_HostName[MAX_HOST_LENGTH];
Handle g_HostnameCvar = INVALID_HANDLE;

public Plugin:myinfo = {
    name = "CS:GO PugSetup: hostname setter",
    author = "splewis",
    description = "Tweaks the server hostname according to the pug status",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-pug-setup"
};

public void OnPluginStart() {
    LoadTranslations("pugsetup.phrases");
    g_hEnabled = CreateConVar("sm_pugsetup_hostname_enabled", "1", "Whether the plugin is enabled");
    AutoExecConfig(true, "pugsetup_hostname", "sourcemod/pugsetup");
    g_HostnameCvar = FindConVar("hostname");
}

public void OnConfigsExecuted() {
    GetConVarString(g_HostnameCvar, g_HostName, sizeof(g_HostName));
}

public void OnReadyToStartCheck(int readyPlayers, int totalPlayers) {
    if (GetConVarInt(g_hEnabled) == 0)
        return;

    char hostname[MAX_HOST_LENGTH];
    int need = GetPugMaxPlayers() - totalPlayers;

    if (need >= 1) {
        Format(hostname, sizeof(hostname), "%s [NEED %d]", g_HostName, need);
    } else {
        Format(hostname, sizeof(hostname), "%s", g_HostName);
    }

    SetConVarString(g_HostnameCvar, hostname);
}

public void OnGoingLive() {
    if (GetConVarInt(g_hEnabled) == 0)
        return;

    char hostname[MAX_HOST_LENGTH];
    Format(hostname, sizeof(hostname), "%s [LIVE]", g_HostName);
    SetConVarString(g_HostnameCvar, g_HostName);
}

public void OnMatchOver() {
    if (GetConVarInt(g_hEnabled) == 0)
        return;

    SetConVarString(g_HostnameCvar, g_HostName);
}

#pragma semicolon 1
#include <cstrike>
#include <sourcemod>
#include "include/pugsetup.inc"
#include "pugsetup/generic.sp"

Handle g_hLockTeamsEnabled = INVALID_HANDLE;

public Plugin:myinfo = {
    name = "CS:GO PugSetup: team locker",
    author = "splewis",
    description = "Blocks team join events to full teams",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-pug-setup"
};

public OnPluginStart() {
    g_hLockTeamsEnabled = CreateConVar("sm_pugsetup_teamlocker_enabled", "1", "Whether teams are locked when matches are live.");
    AutoExecConfig(true, "pugsetup_teamlocker", "sourcemod/pugsetup");
    AddCommandListener(Command_TeamJoin, "jointeam");
}

public Action Command_TeamJoin(int client, const char command[], argc) {
    if (!IsValidClient(client))
        return Plugin_Handled;

    if (GetConVarInt(g_hLockTeamsEnabled) == 0 || !IsMatchLive())
        return Plugin_Continue;

    char arg[4];
    GetCmdArg(1, arg, sizeof(arg));
    int team_to = StringToInt(arg);

    int playerCount = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i) && GetClientTeam(i) == team_to) {
            playerCount++;
        }
    }

    if (playerCount >= GetPugMaxPlayers() / 2) {
        return Plugin_Handled;
    } else {
        return Plugin_Continue;
    }
}

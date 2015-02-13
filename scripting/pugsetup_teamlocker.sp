#include <cstrike>
#include <sourcemod>
#include "include/pugsetup.inc"
#include "pugsetup/generic.sp"

#pragma semicolon 1
#pragma newdecls required

ConVar g_hLockTeamsEnabled;

public Plugin myinfo = {
    name = "CS:GO PugSetup: team locker",
    author = "splewis",
    description = "Blocks team join events to full teams",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-pug-setup"
};

public void OnPluginStart() {
    g_hLockTeamsEnabled = CreateConVar("sm_pugsetup_teamlocker_enabled", "1", "Whether teams are locked when matches are live.");
    AutoExecConfig(true, "pugsetup_teamlocker", "sourcemod/pugsetup");
    AddCommandListener(Command_TeamJoin, "jointeam");
    HookEvent("player_team", Event_OnPlayerTeam, EventHookMode_Pre);
}

public Action Event_OnPlayerTeam(Handle event, const char[] name, bool dontBroadcast) {
    return Plugin_Continue;
}

public Action Command_TeamJoin(int client, const char[] command, int argc) {
    if (!IsValidClient(client))
        return Plugin_Handled;

    if (g_hLockTeamsEnabled.IntValue == 0)
        return Plugin_Continue;

    // blocks changes during team-selection/lo3-process
    if (IsPendingStart())
        return Plugin_Handled;

    // don't do anything if not live/not in startup phase
    if (!IsMatchLive())
        return Plugin_Continue;

    char arg[4];
    GetCmdArg(1, arg, sizeof(arg));
    int team_to = StringToInt(arg);

    // don't let someone change to a "none" team (e.g. using auto-select)
    if (team_to == CS_TEAM_NONE)
        return Plugin_Handled;

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

#pragma semicolon 1
#include <cstrike>
#include <sourcemod>
#include "include/pugsetup.inc"
#include "pugsetup/generic.sp"

ConVar g_hAutoKickerEnabled;
ConVar g_hKickMessage;
ConVar g_hKickNotPicked;
ConVar g_hKickWhenLive;
ConVar g_hUseAdminImmunity;

public Plugin:myinfo = {
    name = "CS:GO PugSetup: autokicker",
    author = "splewis",
    description = "Adds cvars to automatically kick players when they aren't part of the current pug",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-pug-setup"
};

public void OnPluginStart() {
    LoadTranslations("pugsetup.phrases");
    g_hAutoKickerEnabled = CreateConVar("sm_pugsetup_autokicker_enabled", "1", "Whether the autokicker is enabled or not");
    g_hKickMessage = CreateConVar("sm_pugsetup_autokicker_message", "Sorry, this pug is full.", "Message to show to clients when they are kicked");
    g_hKickNotPicked = CreateConVar("sm_pugsetup_autokicker_kick_not_picked", "1", "Whether to kick players not selected by captains in a captain-style game");
    g_hKickWhenLive = CreateConVar("sm_pugsetup_autokicker_kick_when_live", "1", "Whether the autokicker kicks newly connecting clients during live matches when there are already full teams");
    g_hUseAdminImmunity = CreateConVar("sm_pugsetup_autokicker_admin_immunity", "1", "Whether admins (defined by pugsetup's admin flag cvar) are immune to kicks");
    AutoExecConfig(true, "pugsetup_autokicker", "sourcemod/pugsetup");
}

public void OnClientPostAdminCheck(int client) {
    bool enabled = g_hAutoKickerEnabled.IntValue != 0 && g_hKickWhenLive.IntValue != 0;
    bool live = IsMatchLive() || IsPendingStart();

    if (enabled && live && !PlayerAtStart(client)) {
        int count = 0;
        for (int i = 1; i <= MaxClients; i++) {
            if (IsPlayer(i)) {
                int team = GetClientTeam(i);
                if (team != CS_TEAM_NONE && team != CS_TEAM_SPECTATOR) {
                    count++;
                }
            }
        }

        if (count >= GetPugMaxPlayers()) {
            Kick(client);
        }
    }
}

public void OnNotPicked(int client) {
    if (g_hAutoKickerEnabled.IntValue != 0 && g_hKickNotPicked.IntValue != 0) {
        Kick(client);
    }
}

static void Kick(int client) {
    if (g_hUseAdminImmunity.IntValue != 0 && IsPugAdmin(client)) {
        return;
    }

    char msg[1024];
    GetConVarString(g_hKickMessage, msg, sizeof(msg));
    KickClient(client, msg);
}

#include <cstrike>
#include <sourcemod>
#include "include/pugsetup.inc"
#include "pugsetup/generic.sp"

#pragma semicolon 1
#pragma newdecls required

ConVar g_hEnabled;
ConVar g_hAllowDmgCommand;

int g_DamageDone[MAXPLAYERS+1][MAXPLAYERS+1];
int g_DamageDoneHits[MAXPLAYERS+1][MAXPLAYERS+1];

public Plugin myinfo = {
    name = "CS:GO PugSetup: damage printer",
    author = "splewis",
    description = "Writes out player damage on round end or when .dmg is used",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-pug-setup"
};

public void OnPluginStart() {
    LoadTranslations("pugsetup.phrases");
    g_hEnabled = CreateConVar("sm_pugsetup_damageprint_enabled", "1", "Whether the plugin is enabled");
    g_hAllowDmgCommand = CreateConVar("sm_pugsetup_damageprint_allow_dmg_command", "1", "Whether players can type .dmg to see damage done");
    AutoExecConfig(true, "pugsetup_damageprint", "sourcemod/pugsetup");

    RegConsoleCmd("sm_dmg", Command_Damage, "Displays damage done");
    AddChatAlias(".dmg", "sm_dmg");

    HookEvent("round_start", Event_RoundStart);
    HookEvent("player_hurt", Event_DamageDealt, EventHookMode_Pre);
    HookEvent("round_end", Event_RoundEnd);
}

static void PrintDamageInfo(int client) {
    if (!IsValidClient(client))
        return;

    int team = GetClientTeam(client);
    if (team != CS_TEAM_T && team != CS_TEAM_CT)
        return;

    int otherTeam = (team == CS_TEAM_T) ? CS_TEAM_CT : CS_TEAM_T;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i) && GetClientTeam(i) == otherTeam) {
            int health = IsPlayerAlive(i) ? GetClientHealth(i) : 0;
            PrintToChat(client, "--> (%d dmg / %d hits) to (%d dmg / %d hits) from %N (%d HP)",
                        g_DamageDone[client][i], g_DamageDoneHits[client][i],
                        g_DamageDone[i][client], g_DamageDoneHits[i][client],
                        i, health);
        }
    }
}

public Action Command_Damage(int client, int args) {
    if (!IsMatchLive() || g_hEnabled.IntValue == 0 || g_hAllowDmgCommand.IntValue == 0)
        return Plugin_Handled;

    if (IsPlayerAlive(client)) {
        PugSetupMessage(client, "You cannot use that command when alive.");
        return Plugin_Handled;
    }

    PrintDamageInfo(client);
    return Plugin_Handled;
}

public Action Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast) {
    if (!IsMatchLive() || g_hEnabled.IntValue == 0)
        return;

    for (int i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i)) {
            PrintDamageInfo(i);
        }
    }
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast) {
    for (int i = 1; i <= MaxClients; i++) {
        for (int j = 1; j <= MaxClients; j++) {
            g_DamageDone[i][j] = 0;
            g_DamageDoneHits[i][j] = 0;
        }
    }
}

public Action Event_DamageDealt(Handle event, const char[] name, bool dontBroadcast) {
    int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    int victim = GetClientOfUserId(GetEventInt(event, "userid"));
    bool validAttacker = IsValidClient(attacker);
    bool validVictim = IsValidClient(victim);

    if (validAttacker && validVictim) {
        int preDamageHealth = GetClientHealth(victim);
        int damage = GetEventInt(event, "dmg_health");
        int postDamageHealth = GetEventInt(event, "health");

        // this maxes the damage variables at 100,
        // so doing 50 damage when the player had 2 health
        // only counts as 2 damage.
        if (postDamageHealth == 0) {
            damage += preDamageHealth;
        }

        g_DamageDone[attacker][victim] += damage;
        g_DamageDoneHits[attacker][victim]++;
    }
}

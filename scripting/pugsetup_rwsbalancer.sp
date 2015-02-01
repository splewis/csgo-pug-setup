#pragma semicolon 1
#include <clientprefs>
#include <cstrike>
#include <sourcemod>

#include "include/priorityqueue.inc"
#include "include/pugsetup.inc"
#include "pugsetup/generic.sp"

/*
 * This isn't meant to be a comprehensive stats system, it's meant to be a simple
 * way to balance teams to replace manual stuff.
 * The update takes place every round, following this equation
 *
 * R' = (1-a) * R_prev + alpha * R
 * Where
 *    R' is the new rating
 *    a is the alpha factor (how much a new round counts into the new rating)
 *    R is the round-rating
 *
 * Alpha is made to be variable, where it decreases linearly to allow
 * ratings to change more quickly early on when a player has few rounds played.
 */
#define ALPHA_INIT 0.1
#define ALPHA_FINAL 0.003
#define ROUNDS_FINAL 250.0

/** Client cookie handles **/
Handle g_RWSCookie = INVALID_HANDLE;
Handle g_RoundsPlayedCookie = INVALID_HANDLE;

/** Client stats **/
float g_PlayerRWS[MAXPLAYERS+1];
int g_PlayerRounds[MAXPLAYERS+1];

/** Rounds stats **/
int g_RoundPoints[MAXPLAYERS+1];

/** Cvars **/
ConVar g_MoveTeams;
ConVar g_RecordRWS;
ConVar g_SetCaptainsByRWS;


public Plugin:myinfo = {
    name = "CS:GO PugSetup: RWS balancer",
    author = "splewis",
    description = "Sets player teams based on historical RWS ratings stored via clientprefs cookies",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-pug-setup"
};

public OnPluginStart() {
    LoadTranslations("common.phrases");

    HookEvent("bomb_defused", Event_Bomb);
    HookEvent("bomb_planted", Event_Bomb);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_hurt", Event_DamageDealt);
    HookEvent("round_end", Event_RoundEnd);

    RegAdminCmd("sm_showrws", Command_ShowRWS, ADMFLAG_KICK, "");

    g_RWSCookie = RegClientCookie("pugsetup_rws", "Pugsetup RWS rating", CookieAccess_Protected);
    g_RoundsPlayedCookie = RegClientCookie("pugsetup_roundsplayed", "Pugsetup rounds played", CookieAccess_Protected);

    g_MoveTeams = CreateConVar("sm_pugsetup_rws_move_teams", "1", "Whether to balance teams in non-captains pugs. Set to 0 to disable team moves by this plugin");
    g_RecordRWS = CreateConVar("sm_pugsetup_rws_record_stats", "1", "Whether rws should be recorded during live matches (set to 0 to disable changing players rws stats)");
    g_SetCaptainsByRWS = CreateConVar("sm_pugsetup_rws_set_captains", "1", "Whether to set captains to the highest-rws players in a game using captains. Note: this behavior cannot be overwritten by the pug-leader or admins.");

    AutoExecConfig(true, "pugsetup_rwsbalancer", "sourcemod/pugsetup");
}

public OnClientCookiesCached(int client) {
    if (IsFakeClient(client))
        return;

    g_PlayerRWS[client] = GetCookieFloat(client, g_RWSCookie);
    g_PlayerRounds[client] = GetCookieInt(client, g_RoundsPlayedCookie);
}

public OnClientConnected(int client) {
    g_PlayerRWS[client] = 0.0;
    g_PlayerRounds[client] = 0;
    g_RoundPoints[client] = 0;
}

/**
 * Here the teams are actually set to use the rws stuff.
 */
public void OnReadyToStart() {
    // only do balancing if we didn' do captains
    if (GetTeamType() == TeamType_Captains || g_MoveTeams.IntValue == 0)
        return;

    Handle pq = PQ_Init();

    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i) && PlayerAtStart(i)) {
            PQ_Enqueue(pq, i, g_PlayerRWS[i]);
        }
    }

    int count = 0;

    while (!PQ_IsEmpty(pq) && count < GetPugMaxPlayers()) {
        int p1 = PQ_Dequeue(pq);
        int p2 = PQ_Dequeue(pq);

        if (IsPlayer(p1))
            SwitchPlayerTeam(p1, CS_TEAM_CT);
        if (IsPlayer(p2))
            SwitchPlayerTeam(p2, CS_TEAM_T);

        count += 2;
    }

    while (!PQ_IsEmpty(pq)) {
        int client = PQ_Dequeue(pq);
        if (IsPlayer(client))
            SwitchPlayerTeam(client, CS_TEAM_SPECTATOR);
    }

    CloseHandle(pq);
}

/**
 * These events update player "rounds points" for computing rws at the end of each round.
 */
public Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast) {
    if (!IsMatchLive())
        return;

    int victim = GetClientOfUserId(GetEventInt(event, "userid"));
    int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

    bool validAttacker = IsValidClient(attacker);
    bool validVictim = IsValidClient(victim);

    if (validAttacker && validVictim && HelpfulAttack(attacker, victim)) {
        g_RoundPoints[attacker] += 100;
    }
}

public Event_Bomb(Handle event, const char[] name, bool dontBroadcast) {
    if (!IsMatchLive())
        return;

    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    g_RoundPoints[client] += 50;
}

public Action Event_DamageDealt(Handle event, const char[] name, bool dontBroadcast) {
    if (!IsMatchLive())
        return;

    int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    int victim = GetClientOfUserId(GetEventInt(event, "userid"));
    bool validAttacker = IsValidClient(attacker);
    bool validVictim = IsValidClient(victim);

    if (validAttacker && validVictim && HelpfulAttack(attacker, victim) ) {
        int damage = GetEventInt(event, "dmg_PlayerHealth");
        g_RoundPoints[attacker] += damage;
    }
}

public bool HelpfulAttack(int attacker, int victim) {
    if (!IsValidClient(attacker) || !IsValidClient(victim)) {
        return false;
    }
    int ateam = GetClientTeam(attacker);
    int vteam = GetClientTeam(victim);
    return ateam != vteam && attacker != victim;
}

/**
 * Round end event, updates rws values for everyone.
 */
public Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast) {
    if (!IsMatchLive() || g_RecordRWS.IntValue == 0)
        return;

    int winner = GetEventInt(event, "winner");
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i) && AreClientCookiesCached(i)) {
            int team = GetClientTeam(i);
            if (team == CS_TEAM_CT || team == CS_TEAM_T)
                RWSUpdate(i, team == winner);
        }
    }
}

/**
 * Here we apply magic updates to a player's rws based on the previous round.
 */
static void RWSUpdate(int client, bool winner) {
    float rws = 0.0;
    if (winner) {
        int playerCount = 0;
        int sum = 0;
        for (new i = 1; i <= MaxClients; i++) {
            if (IsPlayer(i)) {
                if (GetClientTeam(i) == GetClientTeam(client)) {
                    sum += g_RoundPoints[i];
                    playerCount++;
                }
            }
        }

        if (sum != 0) {
            // scaled so it's always considered "out of 5 players" so different team sizes
            // don't give inflated rws
            rws = 100.0 * float(playerCount) / 5.0 * float(g_RoundPoints[client]) / float(sum);
        } else {
            return;
        }

    } else {
        rws = 0.0;
    }

    float alpha = GetAlphaFactor(client);
    g_PlayerRWS[client] = (1.0 - alpha) * g_PlayerRWS[client] + alpha * rws;
    g_PlayerRounds[client]++;

    SetCookieInt(client, g_RoundsPlayedCookie, g_PlayerRounds[client]);
    SetCookieFloat(client, g_RWSCookie, g_PlayerRWS[client]);
}

static float GetAlphaFactor(int client) {
    float rounds = float(g_PlayerRounds[client]);
    if (rounds < ROUNDS_FINAL) {
        return ALPHA_INIT + (ALPHA_INIT - ALPHA_FINAL) / (-ROUNDS_FINAL) * rounds;
    } else {
        return ALPHA_FINAL;
    }
}

public int rwsSortFunction(index1, index2, Handle array, Handle hndl) {
    int client1 = GetArrayCell(array, index1);
    int client2 = GetArrayCell(array, index2);
    return g_PlayerRWS[client1] < g_PlayerRWS[client2];
}

public void OnReadyToStartCheck(int readyPlayers, int totalPlayers) {
    if (g_SetCaptainsByRWS.IntValue != 0 && totalPlayers >= GetPugMaxPlayers() && GetTeamType() == TeamType_Captains) {

        // The idea is to set the captains to the 2 highest rws players,
        // so they are thrown into an array and sorted by rws,
        // then the captains are set to the first 2 elements of the array.

        ArrayList players = new ArrayList();

        for (int i = 1; i <= MaxClients; i++) {
            if (IsPlayer(i))
                PushArrayCell(players, i);
        }

        SortADTArrayCustom(players, rwsSortFunction);

        if (players.Length >= 1)
            SetCaptain(1, GetArrayCell(players, 0));

        if (players.Length >= 2)
            SetCaptain(2, GetArrayCell(players, 1));

        delete players;
    }
}

public Action Command_ShowRWS(int client, int args) {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i) && AreClientCookiesCached(i)) {
            ReplyToCommand(client, "%L has RWS=%f, roundsplayed=%d", i, g_PlayerRWS[i], g_PlayerRounds[i]);
        }
    }

    return Plugin_Handled;
}

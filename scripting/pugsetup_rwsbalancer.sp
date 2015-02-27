#include <clientprefs>
#include <cstrike>
#include <sourcemod>
#include "include/priorityqueue.inc"
#include "include/pugsetup.inc"
#include "pugsetup/generic.sp"

#pragma semicolon 1
#pragma newdecls required

#define KV_DATA_LOCATION "data/pugsetup/rws.cfg"
KeyValues g_RwsKV;

/*
 * This isn't meant to be a comprehensive stats system, it's meant to be a simple
 * way to balance teams to replace manual stuff using a (exponentially) weighted moving average.
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

#define TABLE_NAME "pugsetup_rwsbalancer"
char g_TableFormat[][] = {
    "auth varchar(72) NOT NULL default ''",
    "roundsplayed INT NOT NULL default 0",
    "rws FLOAT NOT NULL default 0.0",
    "PRIMARY KEY (auth)",
};

enum StorageMethod {
    Storage_ClientPrefs = 0,
    Storage_KeyValues = 1,
    Storage_MySQL = 2,
};

/** Client cookie handles **/
Handle g_RWSCookie = INVALID_HANDLE;
Handle g_RoundsPlayedCookie = INVALID_HANDLE;

/** Client stats **/
float g_PlayerRWS[MAXPLAYERS+1];
int g_PlayerRounds[MAXPLAYERS+1];
bool g_PlayerHasStats[MAXPLAYERS+1];

/** Rounds stats **/
int g_RoundPoints[MAXPLAYERS+1];

/** Cvars **/
ConVar g_MoveTeams;
ConVar g_RecordRWS;
ConVar g_SetCaptainsByRWS;
ConVar g_StorageMethod;
ConVar g_ShowRWSOnMenu;

Handle g_Database = INVALID_HANDLE;
bool g_ManuallySetCaptains = false;


public Plugin myinfo = {
    name = "CS:GO PugSetup: RWS balancer",
    author = "splewis",
    description = "Sets player teams based on historical RWS ratings stored via clientprefs cookies",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-pug-setup"
};

public void OnPluginStart() {
    LoadTranslations("pugsetup.phrases");
    LoadTranslations("common.phrases");

    HookEvent("bomb_defused", Event_Bomb);
    HookEvent("bomb_planted", Event_Bomb);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_hurt", Event_DamageDealt);
    HookEvent("round_end", Event_RoundEnd);

    RegAdminCmd("sm_showrws", Command_ShowRWS, ADMFLAG_KICK, "Show player historical rws and rounds played");

    g_MoveTeams = CreateConVar("sm_pugsetup_rws_move_teams", "1", "Whether to balance teams in non-captains pugs. Set to 0 to disable team moves by this plugin");
    g_RecordRWS = CreateConVar("sm_pugsetup_rws_record_stats", "1", "Whether rws should be recorded during live matches (set to 0 to disable changing players rws stats)");
    g_SetCaptainsByRWS = CreateConVar("sm_pugsetup_rws_set_captains", "1", "Whether to set captains to the highest-rws players in a game using captains. Note: this behavior can be overwritten by the pug-leader or admins.");
    g_StorageMethod = CreateConVar("sm_pugsetup_rws_storage_method", "0", "Which storage method to use: 0=clientprefs database, 1=flat keyvalue file on disk, 2=MySQL table using the \"pugsetup\" database");
    g_ShowRWSOnMenu = CreateConVar("sm_pugsetup_rws_display_on_menu", "1", "Whether rws stats are to be displayed on captain-player selection menus");

    HookConVarChange(g_StorageMethod, OnCvarChanged);

    AutoExecConfig(true, "pugsetup_rwsbalancer", "sourcemod/pugsetup");

    // for clientprefs storage
    g_RWSCookie = RegClientCookie("pugsetup_rws", "Pugsetup RWS rating", CookieAccess_Protected);
    g_RoundsPlayedCookie = RegClientCookie("pugsetup_roundsplayed", "Pugsetup rounds played", CookieAccess_Protected);

}

public int OnCvarChanged(Handle cvar, const char[] oldValue, const char[] newValue) {
    if (cvar == g_StorageMethod) {
        StorageMethod m = view_as<StorageMethod>(StringToInt(newValue));
        if (m == Storage_MySQL) {
            InitSqlConnection();
        }
    }
}

public StorageMethod GetStorageMethod() {
    return view_as<StorageMethod>(g_StorageMethod.IntValue);
}

public void OnMapStart() {
    g_ManuallySetCaptains = false;
    StorageMethod m = GetStorageMethod();
    g_RwsKV = new KeyValues("RWSBalancerStats");

    if (m == Storage_KeyValues) {
        char path[PLATFORM_MAX_PATH];
        BuildPath(Path_SM, path, sizeof(path), KV_DATA_LOCATION);
        g_RwsKV.ImportFromFile(path);
    } else if (m == Storage_MySQL && g_Database == INVALID_HANDLE) {
        InitSqlConnection();
    }
}

public void InitSqlConnection() {
    // check if already connected
    if (g_Database != INVALID_HANDLE) {
        return;
    }

    char error[255];
    g_Database = SQL_Connect("pugsetup", true, error, sizeof(error));
    if (g_Database == INVALID_HANDLE) {
        LogError("Could not connect: %s", error);
    } else {
        SQL_LockDatabase(g_Database);
        SQL_CreateTable(g_Database, TABLE_NAME, g_TableFormat, sizeof(g_TableFormat));
        SQL_UnlockDatabase(g_Database);
    }
}

public void OnMapEnd() {
    StorageMethod m = GetStorageMethod();

    if (m == Storage_KeyValues) {
        char path[PLATFORM_MAX_PATH];
        BuildPath(Path_SM, path, sizeof(path), KV_DATA_LOCATION);
        g_RwsKV.ExportToFile(path);
    }

    delete g_RwsKV;
}

public void OnPermissionCheck(int client, const char[] command, Permissions p, bool& allow) {
    if (StrEqual(command, "sm_capt", false) || StrEqual(command, "sm_captain", false)) {
        g_ManuallySetCaptains = true;
    }
}

public int OnClientCookiesCached(int client) {
    if (IsFakeClient(client) || GetStorageMethod() != Storage_ClientPrefs)
        return;

    g_PlayerRWS[client] = GetCookieFloat(client, g_RWSCookie);
    g_PlayerRounds[client] = GetCookieInt(client, g_RoundsPlayedCookie);
    g_PlayerHasStats[client] = true;
}

public void OnClientConnected(int client) {
    g_PlayerRWS[client] = 0.0;
    g_PlayerRounds[client] = 0;
    g_RoundPoints[client] = 0;
    g_PlayerHasStats[client] = false;
}

public void OnClientDisconnect(int client) {
    WriteStats(client);
}

public void OnClientAuthorized(int client, const char[] auth) {
    if (StrEqual(auth, "bot", false))
        return;

    StorageMethod m = GetStorageMethod();
    if (m == Storage_KeyValues) {
        g_RwsKV.JumpToKey(auth, true);
        g_PlayerRWS[client] = g_RwsKV.GetFloat("rws", 0.0);
        g_PlayerRounds[client] = g_RwsKV.GetNum("roundsplayed", 0);
        g_RwsKV.GoBack();
        g_PlayerHasStats[client] = true;

    } else if (m == Storage_MySQL && g_Database != INVALID_HANDLE) {
        char query[2048];
        Format(query, sizeof(query),
               "INSERT IGNORE INTO %s (auth,rws,roundsplayed) VALUES ('%s', 0.0, 0)",
               TABLE_NAME, auth);
        SQL_TQuery(g_Database, Callback_Insert, query, GetClientSerial(client));
    }
}

public void Callback_Insert(Handle owner, Handle hndl, const char[] error, int serial) {
    int client = GetClientFromSerial(serial);
    if (client < 0 || IsFakeClient(client) || g_PlayerHasStats[client])
        return;

    char auth[64];
    GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));

    char query[2048];
    Format(query, sizeof(query),
            "SELECT rws, roundsplayed FROM %s WHERE auth = '%s'",
            TABLE_NAME, auth);
    SQL_TQuery(g_Database, Callback_FetchStats, query, GetClientSerial(client));
}

public void Callback_FetchStats(Handle owner, Handle hndl, const char[] error, int serial) {
    int client = GetClientFromSerial(serial);
    if (client < 0 || IsFakeClient(client) || g_PlayerHasStats[client])
        return;

    g_PlayerHasStats[client] = false;
    if (hndl == INVALID_HANDLE) {
        LogError("Query failed: (error: %s)", error);
    } else if (SQL_FetchRow(hndl)) {
        g_PlayerRWS[client] = SQL_FetchFloat(hndl, 0);
        g_PlayerRounds[client] = SQL_FetchInt(hndl, 1);
        g_PlayerHasStats[client] = true;
    }
}

public void Callback_CheckError(Handle owner, Handle hndl, const char[] error, int data) {
    if (!StrEqual("", error)) {
        LogError("Last SQL Error: %s", error);
    }
}

public bool HasStats(int client) {
    return g_PlayerHasStats[client];
}

public void WriteStats(int client) {
    if (!IsValidClient(client) || IsFakeClient(client))
        return;

    StorageMethod method = GetStorageMethod();
    if (method == Storage_ClientPrefs) {
        SetCookieInt(client, g_RoundsPlayedCookie, g_PlayerRounds[client]);
        SetCookieFloat(client, g_RWSCookie, g_PlayerRWS[client]);

    } else if (method == Storage_KeyValues) {
        char auth[64];
        GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));

        g_RwsKV.DeleteKey(auth);
        g_RwsKV.JumpToKey(auth, true);
        g_RwsKV.SetFloat("rws", g_PlayerRWS[client]);
        g_RwsKV.SetNum("roundsplayed", g_PlayerRounds[client]);
        g_RwsKV.GoBack();

    } else if (method == Storage_MySQL && g_Database != INVALID_HANDLE) {
        char auth[64];
        GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
        char query[1024];
        Format(query, sizeof(query), "UPDATE %s SET roundsplayed = %d, rws = %f where auth = '%s'",
               TABLE_NAME, g_PlayerRounds[client], g_PlayerRWS[client], auth);
        SQL_TQuery(g_Database, Callback_CheckError, query);

    } else {
        LogError("[WriteStats(%L)] unknown storage method or invalid database connection, m=%d", g_StorageMethod.IntValue);
    }

}

/**
 * Here the teams are actually set to use the rws stuff.
 */
public void OnReadyToStart() {
    // only do balancing if we didn't do captains
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
public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast) {
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

public Action Event_Bomb(Handle event, const char[] name, bool dontBroadcast) {
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
public Action Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast) {
    if (!IsMatchLive() || g_RecordRWS.IntValue == 0)
        return;

    int winner = GetEventInt(event, "winner");
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i) && HasStats(i)) {
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
        for (int i = 1; i <= MaxClients; i++) {
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
}

static float GetAlphaFactor(int client) {
    float rounds = float(g_PlayerRounds[client]);
    if (rounds < ROUNDS_FINAL) {
        return ALPHA_INIT + (ALPHA_INIT - ALPHA_FINAL) / (-ROUNDS_FINAL) * rounds;
    } else {
        return ALPHA_FINAL;
    }
}

public int rwsSortFunction(int index1, int index2, Handle array, Handle hndl) {
    int client1 = GetArrayCell(array, index1);
    int client2 = GetArrayCell(array, index2);
    return g_PlayerRWS[client1] < g_PlayerRWS[client2];
}

public void OnReadyToStartCheck(int readyPlayers, int totalPlayers) {
    if (!g_ManuallySetCaptains && g_SetCaptainsByRWS.IntValue != 0 &&
        totalPlayers >= GetPugMaxPlayers() && GetTeamType() == TeamType_Captains) {

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
        if (IsPlayer(i) && HasStats(i)) {
            ReplyToCommand(client, "%L has RWS=%f, roundsplayed=%d", i, g_PlayerRWS[i], g_PlayerRounds[i]);
        }
    }

    return Plugin_Handled;
}

public void OnPlayerAddedToCaptainMenu(Menu menu, int client, char[] menuString, int length) {
    if (g_ShowRWSOnMenu.IntValue != 0 && HasStats(client)) {
        Format(menuString, length, "%N [%.1f RWS]", client, g_PlayerRWS[client]);
    }
}

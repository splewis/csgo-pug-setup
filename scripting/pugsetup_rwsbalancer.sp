#include <clientprefs>
#include <cstrike>
#include <sourcemod>
#include "include/logdebug.inc"
#include "include/priorityqueue.inc"
#include "include/pugsetup.inc"
#include "pugsetup/generic.sp"

#pragma semicolon 1
#pragma newdecls required

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
#define AUTH_METHOD AuthId_Steam2

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
ConVar g_AllowRWSCommandCvar;
ConVar g_RecordRWSCvar;
ConVar g_SetCaptainsByRWSCvar;
ConVar g_ShowRWSOnMenuCvar;

bool g_ManuallySetCaptains = false;
bool g_SetTeamBalancer = false;


public Plugin myinfo = {
    name = "CS:GO PugSetup: RWS balancer",
    author = "splewis",
    description = "Sets player teams based on historical RWS ratings stored via clientprefs cookies",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-pug-setup"
};

public void OnPluginStart() {
    InitDebugLog(DEBUG_CVAR, "rwsbalance");
    LoadTranslations("pugsetup.phrases");
    LoadTranslations("common.phrases");

    HookEvent("bomb_defused", Event_Bomb);
    HookEvent("bomb_planted", Event_Bomb);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("player_hurt", Event_DamageDealt);
    HookEvent("round_end", Event_RoundEnd);

    RegAdminCmd("sm_showrws", Command_DumpRWS, ADMFLAG_KICK, "Dumps all player historical rws and rounds played");
    RegConsoleCmd("sm_rws", Command_RWS, "Show player's historical rws");
    AddChatAlias(".rws", "sm_rws");

    g_AllowRWSCommandCvar = CreateConVar("sm_pugsetup_rws_allow_rws_command", "0", "Whether players can use the .rws or !rws command on other players");
    g_RecordRWSCvar = CreateConVar("sm_pugsetup_rws_record_stats", "1", "Whether rws should be recorded during live matches (set to 0 to disable changing players rws stats)");
    g_SetCaptainsByRWSCvar = CreateConVar("sm_pugsetup_rws_set_captains", "1", "Whether to set captains to the highest-rws players in a game using captains. Note: this behavior can be overwritten by the pug-leader or admins.");
    g_ShowRWSOnMenuCvar = CreateConVar("sm_pugsetup_rws_display_on_menu", "0", "Whether rws stats are to be displayed on captain-player selection menus");

    AutoExecConfig(true, "pugsetup_rwsbalancer", "sourcemod/pugsetup");

    g_RWSCookie = RegClientCookie("pugsetup_rws", "Pugsetup RWS rating", CookieAccess_Protected);
    g_RoundsPlayedCookie = RegClientCookie("pugsetup_roundsplayed", "Pugsetup rounds played", CookieAccess_Protected);
}

public void OnAllPluginsLoaded() {
    g_SetTeamBalancer = SetTeamBalancer(BalancerFunction);
}

public void OnPluginEnd() {
    if (g_SetTeamBalancer)
        ClearTeamBalancer();
}

public void OnMapStart() {
    g_ManuallySetCaptains = false;
}

public void OnPermissionCheck(int client, const char[] command, Permission p, bool& allow) {
    if (StrEqual(command, "sm_capt", false)) {
        g_ManuallySetCaptains = true;
    }
}

public void OnClientCookiesCached(int client) {
    if (IsFakeClient(client))
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

public bool HasStats(int client) {
    return g_PlayerHasStats[client];
}

public void WriteStats(int client) {
    if (!IsValidClient(client) || IsFakeClient(client) || !g_PlayerHasStats[client])
        return;

    SetCookieInt(client, g_RoundsPlayedCookie, g_PlayerRounds[client]);
    SetCookieFloat(client, g_RWSCookie, g_PlayerRWS[client]);
}

public void FindSecondTeam(ArrayList buffer, ArrayList remainingPlayers, int done, int begin, int end, ArrayList &seconds ) {

    for (int i = begin; i < end; i++)
    {
        buffer.Set(done, remainingPlayers.Get(i));

        if (done == buffer.Length - 1) {
            ArrayList bufferClone = CloneArray( buffer );
            seconds.Push(bufferClone);
        }

        else {
            FindSecondTeam(buffer, remainingPlayers, done+1, i+1, end, seconds);
        }
    }
}

 public void FindFirstTeam(ArrayList buffer, ArrayList players, int done, int begin, int end, ArrayList &final_team_one, ArrayList &final_team_two, float &minRwsDifference)
  {
    for (int i = begin; i < end; i++)
    {
        buffer.Set(done, players.Get(i));

        if (done == buffer.Length - 1) {
            // We have a possible team one ("buffer"), now find a team two

            ArrayList remainingPlayers = new ArrayList();

            // Add the people that aren't in the first team to the 2nd team
            for (int j = 0; j < players.Length; j++) {
                if ( FindValueInArray(buffer, players.Get(j)) == -1 ) {
                    remainingPlayers.Push(players.Get(j));
                } 
            }


            ArrayList possibleSecondTeams = new ArrayList();
            ArrayList secondTeamBuffer = new ArrayList(1, buffer.Length);
            FindSecondTeam(secondTeamBuffer, remainingPlayers, 0, 0, remainingPlayers.Length, possibleSecondTeams);
            float team_one_rws = 0.0;

            for (int j = 0; j < buffer.Length; j++) {
                int client = buffer.Get(j);
                    
                float player_rws = g_PlayerRWS[client];
                if (player_rws < 1) {
                    // Set new players RWS to a slightly below average value (8)
                    player_rws = 8.0;
                }
                team_one_rws += player_rws;
            }

            for (int j = 0; j < possibleSecondTeams.Length; j++) {

                ArrayList secondteam = possibleSecondTeams.Get(j);
                float team_two_rws = 0.0;

                for (int k = 0; k < secondteam.Length; k++ ) {
                    int client = secondteam.Get(k);
                    
                    float player_rws = g_PlayerRWS[client];
                    if (player_rws < 1) {
                        // Set new players RWS to a slightly below average value (8)
                        player_rws = 8.0;
                    }
                    team_two_rws += player_rws;
                }

                // Compare the RWS for team one and team two and if ti's less than the min then make them the new mins 
                float localDifference = FloatAbs(team_one_rws - team_two_rws);

                if (localDifference < minRwsDifference) {
                    final_team_one = CloneArray(buffer);
                    final_team_two = CloneArray(secondteam);
                    minRwsDifference = localDifference;
                }
                delete secondteam;

            }
            delete possibleSecondTeams;
            delete secondTeamBuffer;
            delete remainingPlayers;
        }

        else {
            FindFirstTeam(buffer, players, done+1, i+1, end, final_team_one, final_team_two, minRwsDifference);
      }
    }
  }


public void FindCombinations(int m, ArrayList players, ArrayList &final_team_one, ArrayList &final_team_two, float &minRwsDifference){
    ArrayList buffer = new ArrayList(1, m);
    FindFirstTeam(buffer, players, 0, 0, players.Length, final_team_one, final_team_two, minRwsDifference);
    delete buffer;
}


/**
 * Here the teams are actually set to use the rws stuff.
 */
public void BalancerFunction(ArrayList players) {

    ArrayList team_one = new ArrayList();
    ArrayList team_two = new ArrayList();
    float minRwsDifference = 9999.0;

    // Assign all players to spec fix same-color bug
    for(int i = 0; i < GetPugMaxPlayers(); i++) {
        SwitchPlayerTeam(players.Get(i), CS_TEAM_SPECTATOR);
    }

    FindCombinations( (GetPugMaxPlayers() / 2), players, team_one, team_two, minRwsDifference);

    // Assign team one to CT
    LogDebug("[TEAM ONE]");
    LogDebug("----------");
    for(int i = 0; i < team_one.Length; i++) {
        int t1player = team_one.Get(i);
        float t1playerRWS = g_PlayerRWS[t1player];
        if (t1playerRWS < 1 ) {
            t1playerRWS = 8.0;
        }
        LogDebug("%L [%.2f RWS]", t1player, t1playerRWS);
        SwitchPlayerTeam(t1player, CS_TEAM_CT);
    }

    // Assign team two to T
    LogDebug("");
    LogDebug("[TEAM TWO]");
    LogDebug("----------");
    for(int i = 0; i < team_two.Length; i++) {
        int t2player = team_two.Get(i);
        float t2playerRWS = g_PlayerRWS[t2player];
        if (t2playerRWS < 1) {
            t2playerRWS = 8.0;
        }
        LogDebug("%L [%.2f RWS]", t2player, t2playerRWS);
        SwitchPlayerTeam(t2player, CS_TEAM_T);
    }
    LogDebug("");
    LogDebug("[Final Team Status]");
    LogDebug("[The RWS difference is: %.2f]", minRwsDifference);

    // Sort out spectators

    LogDebug("");
    LogDebug("[SPECTATORS]");
    LogDebug("----------");
    for (int i = 0; i < players.Length; i++) {
        if ( FindValueInArray( team_one, players.Get(i) ) == -1 && FindValueInArray( team_two, players.Get(i) ) == -1 ) {
            int spectator = players.Get(i);
            if (IsPlayer(spectator)) {
                LogDebug("-- %L", spectator);
                SwitchPlayerTeam(spectator, CS_TEAM_SPECTATOR);
            }
        } 
    }

    delete team_one;
    delete team_two;
}

/**
 * These events update player "rounds points" for computing rws at the end of each round.
 */
public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
    if (!IsMatchLive())
        return;

    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    bool validAttacker = IsValidClient(attacker);
    bool validVictim = IsValidClient(victim);

    if (validAttacker && validVictim && HelpfulAttack(attacker, victim)) {
        g_RoundPoints[attacker] += 100;
    }
}

public Action Event_Bomb(Event event, const char[] name, bool dontBroadcast) {
    if (!IsMatchLive())
        return;

    int client = GetClientOfUserId(event.GetInt("userid"));
    g_RoundPoints[client] += 50;
}

public Action Event_DamageDealt(Event event, const char[] name, bool dontBroadcast) {
    if (!IsMatchLive())
        return;

    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim = GetClientOfUserId(event.GetInt("userid"));
    bool validAttacker = IsValidClient(attacker);
    bool validVictim = IsValidClient(victim);

    if (validAttacker && validVictim && HelpfulAttack(attacker, victim) ) {
        int damage = event.GetInt("dmg_health");
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
public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
    if (!IsMatchLive() || g_RecordRWSCvar.IntValue == 0)
        return;

    int winner = event.GetInt("winner");
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i) && HasStats(i)) {
            int team = GetClientTeam(i);
            if (team == CS_TEAM_CT || team == CS_TEAM_T)
                RWSUpdate(i, team == winner);
        }
    }
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i) && HasStats(i)) {
            g_RoundPoints[i] = 0;
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
    LogDebug("RoundUpdate(%L), alpha=%f, round_rws=%f, new_rws=%f", client, alpha, rws, g_PlayerRWS[client]);
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
    if (!g_ManuallySetCaptains &&
        g_SetCaptainsByRWSCvar.IntValue != 0 &&
        totalPlayers >= GetPugMaxPlayers() &&
        GetTeamType() == TeamType_Captains) {

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

public Action Command_DumpRWS(int client, int args) {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i) && HasStats(i)) {
            ReplyToCommand(client, "%L has RWS=%f, roundsplayed=%d", i, g_PlayerRWS[i], g_PlayerRounds[i]);
        }
    }

    return Plugin_Handled;
}

public Action Command_RWS(int client, int args) {
    if (g_AllowRWSCommandCvar.IntValue == 0) {
        return Plugin_Handled;
    }

    char arg1[32];
    if (args >= 1 && GetCmdArg(1, arg1, sizeof(arg1))) {
        int target = FindTarget(client, arg1, true, false);
        if (target != -1) {
            if (HasStats(target))
                PugSetupMessage(client, "%N has a RWS of %.1f with %d rounds played",
                              target, g_PlayerRWS[target], g_PlayerRounds[target]);
            else
                PugSetupMessage(client, "%N does not currently have stats stored", target);
        }
    } else {
        PugSetupMessage(client, "Usage: .rws <player>");
    }

    return Plugin_Handled;
}

public void OnPlayerAddedToCaptainMenu(Menu menu, int client, char[] menuString, int length) {
    if (g_ShowRWSOnMenuCvar.IntValue != 0 && HasStats(client)) {
        Format(menuString, length, "%N [%.1f RWS]", client, g_PlayerRWS[client]);
    }
}

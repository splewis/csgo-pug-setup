#define PLUGIN_VERSION  "0.4.0"
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <adminmenu>



/***********************
 *                     *
 *   Global variables  *
 *                     *
 ***********************/

/** ConVar handles **/
new Handle:g_hCvarVersion = INVALID_HANDLE;
new Handle:g_hAutoLO3 = INVALID_HANDLE;
new Handle:g_hWarmupCfg = INVALID_HANDLE;
new Handle:g_hLiveCfg = INVALID_HANDLE;

/** Setup info **/
new bool:g_Setup = false;
new bool:g_mapSet = false;
new TeamType:g_TeamType;
new MapType:g_MapType;

/** Data about team selections **/
new g_capt1 = -1;
new g_capt2 = -1;
new g_PlayersPicked = 0;
new g_Teams[MAXPLAYERS+1];
new bool:g_Ready[MAXPLAYERS+1];
new bool:g_MatchLive = false;

#include "pugsetup/liveon3.sp"
#include "pugsetup/setupmenus.sp"
#include "pugsetup/playermenus.sp"



/***********************
 *                     *
 * Sourcemod overrides *
 *                     *
 ***********************/

public Plugin:myinfo = {
    name = "CS:GO PugSetup",
    author = "splewis",
    description = "Tools for setting up pugs/10mans",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/pugsetup"
};

public OnPluginStart() {
    LoadTranslations("common.phrases");

    /** ConVars **/
    g_hWarmupCfg = CreateConVar("sm_pugsetup_warmup_cfg", "sourcemod/pugsetup/warmup.cfg", "Config file to run before/after games");
    g_hLiveCfg = CreateConVar("sm_pugsetup_live_cfg", "sourcemod/pugsetup/standard.cfg", "Config file to run when a game goes live");
    g_hAutoLO3 = CreateConVar("sm_pugsetup_autolo3", "1", "If the game starts immediately after teams are picked");
    g_hCvarVersion = CreateConVar("sm_pugsetup_version", PLUGIN_VERSION, "Current pugsetup version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
    SetConVarString(g_hCvarVersion, PLUGIN_VERSION);

    // Create and exec plugin's configuration file
    AutoExecConfig(true, "pugsetup");

    /** Commands **/
    AddCommandListener(Command_Say, "say");
    AddCommandListener(Command_Say, "say2");
    AddCommandListener(Command_Say, "say_team");

    RegConsoleCmd("sm_ready", Command_Ready, "Marks the client as ready");
    RegConsoleCmd("sm_unready", Command_Unready, "Marks the client as not ready");

    RegAdminCmd("sm_setup", Command_Setup, ADMFLAG_CUSTOM1, "Starts 10man setup (!ready, !capt commands become avaliable)");
    RegAdminCmd("sm_start", Command_Start, ADMFLAG_CUSTOM1, "Starts the game if auto-lo3 is disabled");
    RegAdminCmd("sm_capt1", Command_Capt1, ADMFLAG_CUSTOM1, "Sets captain 1 (picks first, T)");
    RegAdminCmd("sm_capt2", Command_Capt2, ADMFLAG_CUSTOM1, "Sets captain 2 (picks second, CT)");
    RegAdminCmd("sm_pause", Command_Pause, ADMFLAG_CUSTOM1, "Pauses the game");
    RegAdminCmd("sm_unpause", Command_Unpause, ADMFLAG_CUSTOM1, "Unpauses the game");
    RegAdminCmd("sm_endgame", Command_EndMatch, ADMFLAG_CUSTOM1, "Pre-emptively ends the match");

    /** Event hooks **/
    HookEvent("cs_win_panel_match", Event_MatchOver);
}

public OnClientPostAdminCheck(client) {
    g_Teams[client] = CS_TEAM_SPECTATOR;
    g_Ready[client] = false;
}

public OnMapStart() {
    g_capt1 = -1;
    g_capt2 = -1;
    g_PlayersPicked = 0;

    for (new i = 1; i <= MaxClients; i++) {
        g_Ready[i] = false;
        g_Teams[i] = -1;
    }

    if (g_mapSet) {
        g_Setup = true;
        g_MatchLive = true;
        CreateTimer(1.0, Timer_CheckReady, _, TIMER_REPEAT);
    }
}

public OnMapEnd() {
}

public Action:Timer_CheckReady(Handle:timer) {
    new rdy = 0;
    new count = 0;
    for (new i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i) && IsClientInGame(i) && !IsFakeClient(i)) {
            count++;
            if (g_Ready[i]) {
                CS_SetClientClanTag(i, "[Ready]");
                rdy++;
            } else {
                CS_SetClientClanTag(i, "[Not ready]");
            }
        }
    }

    if (rdy == count && rdy >= 1) {
        if (g_mapSet) {
            g_MatchLive = true;
            if (GetConVarInt(g_hAutoLO3) != 0) {
                Command_Start(0, 0);
                return Plugin_Stop;
            }
        } else {
            PrintToChatAll(" \x01\x0B\x04Setup will begin in a few seconds!");
            CreateTimer(2.0, MapSetup);
            return Plugin_Stop;
        }

    } else {
        PrintHintTextToAll("%i out of %i players are ready", rdy, count);
    }

    return Plugin_Continue;
}

public Action:Timer_CheckCaptains(Handle:timer) {
    if (IsValidClient(g_capt1) && IsValidClient(g_capt2) && g_capt1 != g_capt2 ) {
        PrintToChatAll(" \x01\x0B\x04Team selection will begin in a few seconds!");
        CreateTimer(2.0, StartPicking);
        return Plugin_Stop;
    }

    return Plugin_Continue;
}



/***********************
 *                     *
 *     Commands        *
 *                     *
 ***********************/

public Action:Command_Setup(client, args) {
    if (g_Setup) {
        ReplyToCommand(client, "The game has already been setup. Use !endgame to force end it.");
        return Plugin_Handled;
    }

    g_Setup = true;
    for (new i = 1; i <= MaxClients; i++)
        g_Ready[i] = false;

    SetupMenu(client);

    return Plugin_Handled;
}

public Action:Command_Capt1(client, args) {
    if (!g_Setup || g_MatchLive)
        return Plugin_Handled;

    new String:arg1[32];
    GetCmdArg(1, arg1, sizeof(arg1));
    new target = FindTarget(client, arg1);
    if (target == -1)
        return Plugin_Handled;

    if (target == g_capt2) {
        ReplyToCommand(client, "%N is already captain 1!", target);
        return Plugin_Handled;
    }

    SetCapt1(target);
    return Plugin_Handled;
}

public Action:Command_Capt2(client, args) {
    if (!g_Setup || g_MatchLive)
        return Plugin_Handled;

    new String:arg1[32];
    GetCmdArg(1, arg1, sizeof(arg1));
    new target = FindTarget(client, arg1);
    if (target == -1)
        return Plugin_Handled;

    if (target == g_capt1) {
        ReplyToCommand(client, "%N is already captain 2!", target);
        return Plugin_Handled;
    }

    SetCapt2(target);
    return Plugin_Handled;
}

public Action:Command_Start(client, args) {
    if (!g_Setup || g_MatchLive)
        return;

    new String:liveCfg[256];
    GetConVarString(g_hLiveCfg, liveCfg, sizeof(liveCfg));
    ServerCommand("exec %s", liveCfg);
    g_MatchLive = true;

    for (new i = 0; i < 5; i++)
        PrintToChatAll("*** The match will begin shortly - live on 3! ***");
    CreateTimer(7.0, BeginLO3);
}

public Action:Command_Say(client, const String:command[], argc) {
    decl String:text[192];
    if (GetCmdArgString(text, sizeof(text)) < 1) {
        return Plugin_Continue;
    }

    StripQuotes(text);

    if (strcmp(text[0], ".ready", false) == 0) {
        Command_Ready(client, 0);
    }
    if (strcmp(text[0], ".unready", false) == 0) {
        Command_Unready(client, 0);
    }

    new bool:pausePermissions = (client == g_capt1) || (client == g_capt2);

    if (strcmp(text[0], ".pause", false) == 0) {
        if (pausePermissions) {
            Command_Pause(client, 0);
        } else {
            ReplyToCommand(client, " \x01\x0B\x04Only captains may pause");
        }
    }

    if (strcmp(text[0], ".unpause", false) == 0) {
        if (pausePermissions) {
            Command_Unpause(client, 0);
        } else {
            ReplyToCommand(client, " \x01\x0B\x04Only captains may unpause");
        }
    }

    // continue normally
    return Plugin_Continue;
}

public Action:Command_EndMatch(client, args) {
    if (!g_Setup)
        ReplyToCommand(client, "The match has not begun yet!");
    else
        EndMatch();
    return Plugin_Handled;
}

public Action:Command_Pause(client, args) {
    if (!g_Setup || !g_MatchLive)
        return Plugin_Handled;

    if (IsValidClient(client)) {
        ServerCommand("mp_pause_match");
        PrintToChatAll(" \x01\x0B\x03%N \x01has called for a pause", client);
    }
    return Plugin_Handled;
}

public Action:Command_Unpause(client, args) {
    if (!g_Setup || !g_MatchLive)
        return Plugin_Handled;

    if (IsValidClient(client)) {
        ServerCommand("mp_unpause_match");
        PrintToChatAll(" \x01\x0B\x03%N \x01has unpaused", client);
    }
    return Plugin_Handled;
}

public Action:Command_Ready(client, args) {
    if (!g_Setup || g_MatchLive)
        return Plugin_Handled;

    g_Ready[client] = true;
    CS_SetClientClanTag(client, "[Ready]");
    return Plugin_Handled;
}

public Action:Command_Unready(client, args) {
    if (!g_Setup || g_MatchLive)
        return Plugin_Handled;

    g_Ready[client] = false;
    CS_SetClientClanTag(client, "[Not ready]");
    return Plugin_Handled;
}



/***********************
 *                     *
 *       Events        *
 *                     *
 ***********************/

public Action:Event_MatchOver(Handle:event, const String:name[], bool:dontBroadcast) {
    EndMatch();
    return Plugin_Handled;
}



/***********************
 *                     *
 *  Teamselect logic   *
 *                     *
 ***********************/

public SetCapt1(client) {
    g_capt1 = client;
    PrintToChatAll("Captain 1 will be \x02%N", g_capt1);
}

public SetCapt2(client) {
    g_capt2 = client;
    PrintToChatAll("Captain 2 will be \x03%N", g_capt2);
}

public SetRandomCaptains() {
    new c1 = -1;
    new c2 = -1;

    c1 = RandomPlayer();
    while (!IsValidClient(c2) || c1 == c2) {
        if (GetClientCount() < 2)
            break;

        c2 = RandomPlayer();
    }

    SetCapt1(c1);
    SetCapt2(c2);
}

public EndMatch() {
    g_Setup = false;
    g_MatchLive = false;
    new String:warmupCfg[256];
    GetConVarString(g_hWarmupCfg, warmupCfg, sizeof(warmupCfg));
    ServerCommand("exec %s", warmupCfg);
}

public Action:MapSetup(Handle:timer) {
    if (g_MapType == MapType_Vote) {
        CreateMapVote();
    } else {
        CreateTimer(1.0, TeamSetup);
    }
    return Plugin_Handled;
}

public Action:TeamSetup(Handle:timer) {
    if (g_TeamType == TeamType_Random) {
        ServerCommand("mp_scrambleteams");
        g_MatchLive = true;
        if (GetConVarInt(g_hAutoLO3) != 0) {
            Command_Start(0, 0);
        }

    } else if (g_TeamType == TeamType_Captains) {
        CreateTimer(1.0, Timer_CheckCaptains, _, TIMER_REPEAT);

    } else if (g_TeamType == TeamType_Manual) {
        g_MatchLive = true;
        if (GetConVarInt(g_hAutoLO3) != 0) {
            Command_Start(0, 0);
        }
    }

    return Plugin_Handled;
}

public Action:StartPicking(Handle:timer) {
    ServerCommand("mp_pause_match");
    ServerCommand("mp_restartgame 1");

    for (new i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) {
            g_Teams[i] = CS_TEAM_SPECTATOR;
            SwitchPlayerTeam(i, CS_TEAM_SPECTATOR);
            CS_SetClientClanTag(i, "");
        }
    }

    // temporary teams
    SwitchPlayerTeam(g_capt2, CS_TEAM_CT);
    SwitchPlayerTeam(g_capt1, CS_TEAM_T);
    GiveSideMenu(g_capt2);
    return Plugin_Handled;
}

public Action:FinishPicking(Handle:timer) {
    for (new i = 1; i <= MaxClients; i++) {
        if (IsValidClient(i) && !IsFakeClient(i)) {
            g_Ready[i] = false;
            SwitchPlayerTeam(i, g_Teams[i]);
        }
    }

    ServerCommand("mp_unpause_match");
    g_MatchLive = true;
    if (GetConVarInt(g_hAutoLO3) != 0) {
        Command_Start(0, 0);
    }
}



/***********************
 *                     *
 *  Generic Functions  *
 *                     *
 ***********************/

/**
 * Returns if a client is valid.
 */
public bool:IsValidClient(client) {
    if (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client))
        return true;
    return false;
}

/**
 * Returns the number of clients that are actual players in the game.
 */
public GetRealClientCount() {
    new clients = 0;
    for (new i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) {
            clients++;
        }
    }
    return clients;
}

/**
 * Returns a random player client on the server.
 */
public RandomPlayer() {
    new client = -1;
    while (!IsValidClient(client) || IsFakeClient(client)) {
        if (GetRealClientCount() < 1)
            return -1;

        client = GetRandomInt(1, MaxClients);
    }
    return client;
}

/**
 * Switches and respawns a player onto a new team.
 */
SwitchPlayerTeam(client, team) {
    if (team > CS_TEAM_SPECTATOR) {
        CS_SwitchTeam(client, team);
        CS_UpdateClientModel(client);
        CS_RespawnPlayer(client);
    } else {
        ChangeClientTeam(client, team);
    }
}

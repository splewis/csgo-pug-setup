#define PLUGIN_VERSION  "0.3.0"
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
new Handle:g_hRequireCommand = INVALID_HANDLE;
new Handle:g_hCvarVersion = INVALID_HANDLE;
new Handle:g_hAutoLO3 = INVALID_HANDLE;
new Handle:g_hWarmupCfg = INVALID_HANDLE;
new Handle:g_hLiveCfg = INVALID_HANDLE;

/** Data about team selections **/
new g_capt1 = 0;
new g_capt2 = 0;
new g_PlayersPicked = 0;
new g_Ready[MAXPLAYERS+1];
new g_Teams[MAXPLAYERS+1];
new g_Active = false;
new g_MatchLive = false;

#include "teamselect/liveon3.sp"
#include "teamselect/menus.sp"



/***********************
 *                     *
 * Sourcemod overrides *
 *                     *
 ***********************/

public Plugin:myinfo = {
    name = "CS:GO TeamSelect",
    author = "splewis",
    description = "Lets captains pick their teams",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/teamselect"
};

public OnPluginStart() {
    LoadTranslations("common.phrases");

    /** ConVars **/
    g_hWarmupCfg = CreateConVar("sm_teamselect_warmup_cfg", "sourcemod/teamselect_warmup.cfg", "Config file to run before/after games");
    g_hLiveCfg = CreateConVar("sm_teamselect_live_cfg", "sourcemod/teamselect_live.cfg", "Config file to run when a game goes live");
    g_hRequireCommand = CreateConVar("sm_teamselect_require_load_command", "1", "Sets whether teamselect needs a command to run");
    g_hAutoLO3 = CreateConVar("sm_teamselect_autolo3", "1", "If the game starts immediately after teams are picked");
    g_hCvarVersion = CreateConVar("sm_teamselect_version", PLUGIN_VERSION, "Current brush version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
    SetConVarString(g_hCvarVersion, PLUGIN_VERSION);

    // Create and exec plugin's configuration file
    AutoExecConfig(true, "teamselect");

    /** Commands **/
    AddCommandListener(Command_Say, "say");
    AddCommandListener(Command_Say, "say2");
    AddCommandListener(Command_Say, "say_team");

    RegConsoleCmd("sm_ready", Command_Ready, "Marks the client as ready");
    RegConsoleCmd("sm_unready", Command_Unready, "Marks the client as not ready");

    RegAdminCmd("sm_10man", Command_10man, ADMFLAG_CUSTOM1, "Starts 10man setup (!ready, !capt commands become avaliable)");
    RegAdminCmd("sm_rand", Command_RandomCaptains, ADMFLAG_CUSTOM1, "Selects random captains");
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
    if (IsClientInGame(client) && !IsFakeClient(client) && !g_MatchLive)
        CS_SetClientClanTag(client, "[Not ready]");
}

public OnMapStart() {
    g_Active = false;
    g_capt1 = -1;
    g_capt2 = -1;
    g_PlayersPicked = 0;
    g_MatchLive = false;

    for (new i = 1; i <= MaxClients; i++) {
        g_Ready[i] = false;
        g_Teams[i] = -1;
    }

    if (GetConVarInt(g_hRequireCommand) == 0) {
        // fake a sm_10man command with fake args (they aren't used)
        Command_10man(0, 0);
    }
}

public OnMapEnd() {
}

public Action:Timer_CheckReady(Handle:timer) {
    if (!g_Active)
        return Plugin_Stop;

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

    if (rdy == count && rdy >= 10 && IsValidClient(g_capt1) && IsValidClient(g_capt2) && g_capt1 != g_capt2) {
        PrintToChatAll(" \x01\x0B\x04Team selection will begin in a few seconds!");
        CreateTimer(3.0, StartPicking);
        return Plugin_Stop;
    } else {
        decl String:cap1[60];
        decl String:cap2[60];

        if (IsValidClient(g_capt1) && !IsFakeClient(g_capt1) && IsClientInGame(g_capt1))
            Format(cap1, sizeof(cap1), "%N", g_capt1);
        else
            Format(cap1, sizeof(cap1), "not selected");

        if (IsValidClient(g_capt2) && !IsFakeClient(g_capt2) && IsClientInGame(g_capt2))
            Format(cap2, sizeof(cap2), "%N", g_capt2);
        else
            Format(cap2, sizeof(cap2), "not selected");


        PrintHintTextToAll("%i out of %i players are ready\nCaptain 1: %s\nCaptain 2: %s", rdy, count, cap1, cap2);
    }
    return Plugin_Continue;
}


/***********************
 *                     *
 *     Commands        *
 *                     *
 ***********************/

public Action:Command_10man(client, args) {
    if (g_MatchLive)
        return Plugin_Handled;

    for (new i = 1; i <= MaxClients; i++)
        g_Ready[i] = false;

    g_Active = true;

    new String:warmupCfg[256];
    GetConVarString(g_hWarmupCfg, warmupCfg, sizeof(warmupCfg));
    ServerCommand("exec %s", warmupCfg);

    ServerCommand("mp_restartgame 1");
    CreateTimer(1.0, Timer_CheckReady, _, TIMER_REPEAT);
    return Plugin_Handled;
}

public Action:Command_RandomCaptains(client, args) {
    if (g_MatchLive || !g_Active || GetRealClientCount() < 2)
        return Plugin_Handled;

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

    return Plugin_Handled;
}

public Action:Command_Capt1(client, args) {
    if (g_MatchLive || !g_Active)
        return Plugin_Handled;

    new String:arg1[32];
    GetCmdArg(1, arg1, sizeof(arg1));
    new target = FindTarget(client, arg1);
    if (target == -1)
        return Plugin_Handled;

    SetCapt1(target);
    return Plugin_Handled;
}

public Action:Command_Capt2(client, args) {
    if (g_MatchLive || !g_Active)
        return Plugin_Handled;

    new String:arg1[32];
    GetCmdArg(1, arg1, sizeof(arg1));
    new target = FindTarget(client, arg1);
    if (target == -1)
        return Plugin_Handled;

    SetCapt2(target);
    return Plugin_Handled;
}

public Action:Command_Start(client, args) {
    if (!g_Active)
        return;

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
    if (strcmp(text[0], ".ready", false) == 0 && g_Active) {
        Command_Ready(client, 0);
    }
    if (strcmp(text[0], ".unready", false) == 0 && g_Active) {
        Command_Unready(client, 0);
    }

    new bool:pausePermissions = client == g_capt1 || client == g_capt2;

    if (strcmp(text[0], ".pause", false) == 0) {
        if (pausePermissions) {
            Command_Pause(client, 0);
        } else {
            PrintToChat(client, " \x01\x0B\x04Only captains may pause");
        }
    }

    if (strcmp(text[0], ".unpause", false) == 0) {
        if (pausePermissions) {
            Command_Unpause(client, 0);
        } else {
            PrintToChat(client, " \x01\x0B\x04Only captains may unpause");
        }
    }

    // continue normally
    return Plugin_Continue;
}

public Action:Command_EndMatch(client, args) {
    if (!g_MatchLive || !g_Active)
        ReplyToCommand(client, "The match has not begun yet!");
    else
        EndMatch();
    return Plugin_Handled;
}

public Action:Command_Pause(client, args) {
    if (IsValidClient(client)) {
        ServerCommand("mp_pause_match");
        PrintToChatAll(" \x01\x0B\x03%N \x01has called for a pause", client);
    }
}

public Action:Command_Unpause(client, args) {
    if (IsValidClient(client)) {
        ServerCommand("mp_unpause_match");
        PrintToChatAll(" \x01\x0B\x03%N \x01has unpaused", client);
    }
}

public Action:Command_Ready(client, args) {
    if (g_Active && !g_MatchLive) {
        g_Ready[client] = true;
        CS_SetClientClanTag(client, "[Ready]");
    }
    return Plugin_Handled;
}

public Action:Command_Unready(client, args) {
    if (g_Active && !g_MatchLive) {
        g_Ready[client] = false;
        CS_SetClientClanTag(client, "[Not ready]");
    }
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

public EndMatch() {
    if (g_Active) {
        g_MatchLive = false;
        ServerCommand("exec sourcemod/postgame.cfg");
    }
}

public Action:StartPicking(Handle:timer) {
    if (g_MatchLive || !g_Active)
        return Plugin_Handled;

    g_MatchLive = true;
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

    new String:liveCfg[256];
    GetConVarString(g_hLiveCfg, liveCfg, sizeof(liveCfg));
    ServerCommand("exec %s", liveCfg);

    ServerCommand("mp_unpause_match");
    if (GetConVarInt(g_hAutoLO3) != 0) {
        Command_Start(0, 0); // fake a sm_start command
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

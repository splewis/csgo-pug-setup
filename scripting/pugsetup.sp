#define MESSAGE_PREFIX "[\x05PugSetup\x01] "
#pragma semicolon 1

#include <adminmenu>
#include <cstrike>
#include <sdkhooks>
#include <sdktools>
#include <sourcemod>

#include "include/pugsetup.inc"



/***********************
 *                     *
 *   Global variables  *
 *                     *
 ***********************/

/** Permissions for the chat commands **/
enum Permissions {
    Permission_All,
    Permission_Captains,
    Permission_Leader
}

/** Initial menu data (where captain 1 picks between side pick or 1st player pick) **/
enum InitialPick {
    InitialPick_Side,
    InitialPick_Player
};

/** ConVar handles **/
Handle g_hAlways5v5 = INVALID_HANDLE;
Handle g_hAutoKickerEnabled = INVALID_HANDLE;
Handle g_hAutoRandomizeCaptains = INVALID_HANDLE;
Handle g_hAutorecord = INVALID_HANDLE;
Handle g_hCvarVersion = INVALID_HANDLE;
Handle g_hDemoNameFormat = INVALID_HANDLE;
Handle g_hDemoTimeFormat = INVALID_HANDLE;
Handle g_hKickMessage = INVALID_HANDLE;
Handle g_hLockTeams = INVALID_HANDLE;
Handle g_hMapVoteTime = INVALID_HANDLE;
Handle g_hRandomizeMapOrder = INVALID_HANDLE;
Handle g_hRequireAdminToSetup = INVALID_HANDLE;
Handle g_hWarmupCfg = INVALID_HANDLE;

/** Setup info **/
int g_Leader = -1;

bool g_Setup = false;
bool g_mapSet = false;
bool g_Recording = true;
char g_DemoFileName[256];
bool g_LiveTimerRunning = false;

// Specific choices made when setting up
int g_GameTypeIndex = 0;
int g_PlayersPerTeam = 5;
bool g_AutoLO3 = false;
TeamType g_TeamType;
MapType g_MapType;

Handle g_GameTypes = INVALID_HANDLE;
Handle g_GameMapFiles = INVALID_HANDLE;
Handle g_GameConfigFiles = INVALID_HANDLE;

/** Map-voting variables **/
Handle g_MapNames = INVALID_HANDLE;
Handle g_MapVetoed = INVALID_HANDLE;
int g_ChosenMap = -1;

/** Data about team selections **/
int g_capt1 = -1;
int g_capt2 = -1;
int g_Teams[MAXPLAYERS+1];
bool g_Ready[MAXPLAYERS+1];
bool g_PickingPlayers = false;
bool g_MatchLive = false;

/** Forwards **/
Handle g_hOnSetup = INVALID_HANDLE;
Handle g_hOnGoingLive = INVALID_HANDLE;
Handle g_hOnMatchOver = INVALID_HANDLE;
Handle g_hOnReady = INVALID_HANDLE;
Handle g_hOnUnready = INVALID_HANDLE;

#include "pugsetup/captainpickmenus.sp"
#include "pugsetup/configreader.sp"
#include "pugsetup/generic.sp"
#include "pugsetup/leadermenus.sp"
#include "pugsetup/liveon3.sp"
#include "pugsetup/maps.sp"
#include "pugsetup/mapveto.sp"
#include "pugsetup/mapvote.sp"
#include "pugsetup/natives.sp"
#include "pugsetup/setupmenus.sp"



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
    url = "https://github.com/splewis/csgo-pug-setup"
};

public OnPluginStart() {
    LoadTranslations("common.phrases");

    /** ConVars **/
    g_hAutoRandomizeCaptains = CreateConVar("sm_pugsetup_auto_randomize_captains", "0", "When games are using captains, should they be automatically randomzied once? Note you can still manually set them or use .rand/!rand to redo the randomization.");
    g_hAlways5v5 = CreateConVar("sm_pugsetup_always_5v5", "0", "Set to 1 to make the team sizes always 5v5 and not give a .setup option to set team sizes.");
    g_hAutoKickerEnabled = CreateConVar("sm_pugsetup_autokicker_enabled", "0", "Whether the autokicker is enabled or not");
    g_hAutorecord = CreateConVar("sm_pugsetup_autorecord", "0", "Should the plugin attempt to record a gotv demo each game, requries tv_enable 1 to work");
    g_hDemoNameFormat = CreateConVar("sm_pugsetup_demo_name_format", "pug_{MAP}_{TIME}", "Naming scheme for demos. You may use {MAP}, {TIME}, and {TEAMSIZE}. Make sure there are no spaces in this.");
    g_hDemoTimeFormat = CreateConVar("sm_pugsetup_time_format", "%Y-%m-%d_%H", "Time format to use when creating demo file names. Don't tweak this unless you know what you're doing!");
    g_hKickMessage = CreateConVar("sm_pugsetup_autokicker_message", "Sorry, this pug is full.", "Message to show to clients when they are kicked");
    g_hLockTeams = CreateConVar("sm_pugsetup_lock_teams", "0", "Whether the plugin should lock teams once the game stats. Note if a player leaves someone can still join to replace them, however.");
    g_hMapVoteTime = CreateConVar("sm_pugsetup_mapvote_time", "20", "How long the map vote should last if using map-votes", _, true, 10.0);
    g_hRandomizeMapOrder = CreateConVar("sm_pugsetup_randomize_maps", "1", "When maps are shown in the map vote/veto, should their order be randomized?");
    g_hRequireAdminToSetup = CreateConVar("sm_pugsetup_requireadmin", "0", "If a client needs the map-change admin flag to use the .setup command");
    g_hWarmupCfg = CreateConVar("sm_pugsetup_warmup_cfg", "sourcemod/pugsetup/warmup.cfg", "Config file to run before/after games; should be in the csgo/cfg directory.");

    /** Create and exec plugin's configuration file **/
    AutoExecConfig(true, "pugsetup", "sourcemod/pugsetup");

    g_hCvarVersion = CreateConVar("sm_pugsetup_version", PLUGIN_VERSION, "Current pugsetup version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
    SetConVarString(g_hCvarVersion, PLUGIN_VERSION);

    /** Commands **/
    AddCommandListener(Command_Say, "say");
    AddCommandListener(Command_Say, "say2");
    AddCommandListener(Command_Say, "say_team");

    RegConsoleCmd("sm_ready", Command_Ready, "Marks the client as ready");
    RegConsoleCmd("sm_unready", Command_Unready, "Marks the client as not ready");

    RegAdminCmd("sm_setup", Command_Setup, ADMFLAG_CHANGEMAP, "Starts pug setup (.ready, .capt commands become avaliable)");
    RegAdminCmd("sm_10man", Command_10man, ADMFLAG_CHANGEMAP, "Starts 10man setup (alias for .setup with 10 man/gather settings)");
    RegAdminCmd("sm_lo3", Command_LO3, ADMFLAG_CHANGEMAP, "Restarts the game with a lo3 (generally this command is not neeeded!)");
    RegAdminCmd("sm_start", Command_Start, ADMFLAG_CHANGEMAP, "Starts the game if auto-lo3 is disabled");
    RegAdminCmd("sm_rand", Command_Rand, ADMFLAG_CHANGEMAP, "Sets random captains");
    RegAdminCmd("sm_pause", Command_Pause, ADMFLAG_GENERIC, "Pauses the game");
    RegAdminCmd("sm_unpause", Command_Unpause, ADMFLAG_GENERIC, "Unpauses the game");
    RegAdminCmd("sm_endgame", Command_EndGame, ADMFLAG_CHANGEMAP, "Pre-emptively ends the match");
    RegAdminCmd("sm_endmatch", Command_EndGame, ADMFLAG_CHANGEMAP, "Pre-emptively ends the match");
    RegAdminCmd("sm_forceend", Command_ForceEnd, ADMFLAG_CHANGEMAP, "Pre-emptively ends the match, without any confirmation menu");
    RegAdminCmd("sm_leader", Command_Leader, ADMFLAG_CHANGEMAP, "Sets the pug leader");
    RegAdminCmd("sm_capt", Command_Capt, ADMFLAG_CHANGEMAP, "Gives the client a menu to pick captains");

    /** Hooks **/
    HookEvent("cs_win_panel_match", Event_MatchOver);
    HookEvent("player_connect_full", Event_PlayerConnectFull);
    HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
    AddCommandListener(Command_TeamJoin, "jointeam");

    g_hOnSetup = CreateGlobalForward("OnSetup", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    g_hOnGoingLive = CreateGlobalForward("OnGoingLive", ET_Ignore);
    g_hOnMatchOver = CreateGlobalForward("OnMatchOver", ET_Ignore, Param_Cell, Param_String);
    g_hOnReady = CreateGlobalForward("OnReady", ET_Ignore, Param_Cell);
    g_hOnUnready = CreateGlobalForward("OnUnready", ET_Ignore, Param_Cell);

    g_LiveTimerRunning = false;
}

public OnClientConnected(client) {
    g_Teams[client] = CS_TEAM_NONE;
    g_Ready[client] = false;
}

public OnClientDisconnect(client) {
    g_Teams[client] = CS_TEAM_SPECTATOR;
    g_Ready[client] = false;
    int numPlayers = 0;
    for (int i = 1; i <= MaxClients; i++)
        if (IsPlayer(i))
            numPlayers++;

    if (numPlayers == 0 && (g_MapType != MapType_Vote || g_MapType != MapType_Veto || !g_mapSet || g_MatchLive))
        EndMatch(true);
}

public OnMapStart() {
    Config_MapStart();
    g_MapNames = CreateArray(PLATFORM_MAX_PATH);
    g_MapVetoed = CreateArray();
    g_Recording = false;

    for (int i = 1; i <= MaxClients; i++) {
        g_Ready[i] = false;
        g_Teams[i] = -1;
    }

    if (g_mapSet) {
        ExecCfg(g_hWarmupCfg);
        g_Setup = true;
        if (!g_LiveTimerRunning) {
            CreateTimer(1.0, Timer_CheckReady, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
            g_LiveTimerRunning = true;
        }
    } else {
        g_capt1 = -1;
        g_capt2 = -1;
        g_Leader = -1;
    }
}

public OnMapEnd() {
    Config_MapEnd();
    CloseHandle(g_MapNames);
    CloseHandle(g_MapVetoed);
}

public Action:Timer_CheckReady(Handle timer) {
    if (!g_Setup || g_MatchLive || !g_LiveTimerRunning) {
        g_LiveTimerRunning = false;
        return Plugin_Stop;
    }

    int readyPlayers = 0;
    int totalPlayers = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i)) {
            totalPlayers++;
            if (g_Ready[i]) {
                CS_SetClientClanTag(i, "[Ready]");
                readyPlayers++;
            } else {
                CS_SetClientClanTag(i, "[Not ready]");
            }
        }
    }

    // beware: scary spaghetti code ahead
    if (readyPlayers == totalPlayers && readyPlayers >= 2 * g_PlayersPerTeam) {
        if (g_mapSet) {
            if (g_TeamType == TeamType_Captains) {
                if (IsPlayer(g_capt1) && IsPlayer(g_capt2) && g_capt1 != g_capt2) {
                    CreateTimer(1.0, StartPicking, _, TIMER_FLAG_NO_MAPCHANGE);
                    g_LiveTimerRunning = false;
                    return Plugin_Stop;
                } else {
                    StatusHint(readyPlayers, totalPlayers);
                }
            } else {
                g_LiveTimerRunning = false;
                ReadyToStart();
                return Plugin_Stop;
            }

        } else {
            if (g_MapType == MapType_Veto) {
                if (IsPlayer(g_capt1) && IsPlayer(g_capt2) && g_capt1 != g_capt2) {
                    PugSetupMessageToAll("The map veto process will begin in a few seconds.");
                    CreateTimer(2.0, MapSetup, _, TIMER_FLAG_NO_MAPCHANGE);
                    g_LiveTimerRunning = false;
                    return Plugin_Stop;
                } else {
                    StatusHint(readyPlayers, totalPlayers);
                }

            } else {
                PugSetupMessageToAll("The map voting will begin in a few seconds.");
                CreateTimer(2.0, MapSetup, _, TIMER_FLAG_NO_MAPCHANGE);
                g_LiveTimerRunning = false;
                return Plugin_Stop;
            }
        }

    } else {
        StatusHint(readyPlayers, totalPlayers);
    }

    return Plugin_Continue;
}

public StatusHint(readyPlayers, totalPlayers) {
    if (!g_mapSet && g_MapType != MapType_Veto) {
        PrintHintTextToAll("%i out of %i players are ready\nType .ready to ready up", readyPlayers, totalPlayers);
    } else {
        if (g_TeamType == TeamType_Captains || g_MapType == MapType_Veto) {
            char cap1[64];
            char cap2[64];
            if (IsPlayer(g_capt1))
                Format(cap1, sizeof(cap1), "%N", g_capt1);
            else
                Format(cap1, sizeof(cap1), "not selected");

            if (IsPlayer(g_capt2))
                Format(cap2, sizeof(cap2), "%N", g_capt2);
            else
                Format(cap2, sizeof(cap2), "not selected");

            PrintHintTextToAll("%i out of %i players are ready\nCaptain 1: %s\nCaptain 2: %s", readyPlayers, totalPlayers, cap1, cap2);

        } else {
            PrintHintTextToAll("%i out of %i players are ready\nType .ready to ready up", readyPlayers, totalPlayers);
        }

    }
}



/***********************
 *                     *
 *     Commands        *
 *                     *
 ***********************/

public Action Command_Setup(client, args) {
    if (g_MatchLive) {
        PugSetupMessage(client, "The game is already live!");
        return Plugin_Handled;
    }

    if (g_Setup && client != GetLeader()) {
        PrintSetupInfo(client);
        return Plugin_Handled;
    }

    if (GetConVarInt(g_hRequireAdminToSetup) != 0 && !CheckCommandAccess(client, "sm_map", ADMFLAG_CHANGEMAP)) {
        PugSetupMessage(client, "You don't have permission to do that.");
        return Plugin_Handled;
    }

    g_PickingPlayers = false;
    g_capt1 = -1;
    g_capt2 = -1;
    g_Setup = true;
    g_Leader = GetSteamAccountID(client);
    for (int i = 1; i <= MaxClients; i++)
        g_Ready[i] = false;

    SetupMenu(client);
    return Plugin_Handled;
}

public Action Command_10man(client, args) {
    if (g_MatchLive) {
        PugSetupMessage(client, "The game is already live!");
        return Plugin_Handled;
    }

    if (g_Setup && client != GetLeader()) {
        PrintSetupInfo(client);
        return Plugin_Handled;
    }

    if (GetConVarInt(g_hRequireAdminToSetup) != 0 && !CheckCommandAccess(client, "sm_map", ADMFLAG_CHANGEMAP)) {
        PugSetupMessage(client, "You don't have permission to do that.");
        return Plugin_Handled;
    }

    g_PickingPlayers = false;
    g_capt1 = -1;
    g_capt2 = -1;
    g_Setup = true;
    g_Leader = GetSteamAccountID(client);
    for (int i = 1; i <= MaxClients; i++)
        g_Ready[i] = false;

    g_GameTypeIndex = 0;
    g_TeamType = TeamType_Captains;
    g_MapType = MapType_Vote;
    g_PlayersPerTeam = 5;
    g_AutoLO3 = false;
    SetupFinished();

    return Plugin_Handled;
}

public Action Command_Rand(client, args) {
    if (!g_Setup || g_MatchLive)
        return Plugin_Handled;

    if (g_TeamType != TeamType_Captains && g_MapType != MapType_Veto) {
        PugSetupMessage(client, "This game isn't using team captains");
        return Plugin_Handled;
    }

    SetRandomCaptains();
    return Plugin_Handled;
}

public Action Command_Capt(client, args) {
    if (!g_Setup || g_MatchLive || g_PickingPlayers)
        return Plugin_Handled;

    if (g_TeamType != TeamType_Captains && g_MapType != MapType_Veto) {
        PugSetupMessage(client, "This game isn't using team captains");
        return Plugin_Handled;
    }

    char buffer[64];
    if (GetCmdArgs() >= 1 && args != 0) {

        GetCmdArg(1, buffer, sizeof(buffer));
        int target = FindTarget(client, buffer, true, false);
        SetCaptain1(target);

        if (GetCmdArgs() >= 2) {
            GetCmdArg(2, buffer, sizeof(buffer));
            target = FindTarget(client, buffer, true, false);
            SetCaptain2(target);
        } else {
            Captain2Menu(client);
        }

    } else {
        Captain1Menu(client);
    }
    return Plugin_Handled;
}

public Action Command_LO3(client, args) {
    for (int i = 0; i < 5; i++)
        PugSetupMessageToAll("*** The match will begin shortly - live on 3! ***");
    CreateTimer(2.0, BeginLO3, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Command_Start(client, args) {
    if (!g_Setup || g_MatchLive || !g_mapSet || g_LiveTimerRunning)
        return;

    if (GetConVarInt(g_hAutorecord) != 0) {
        // get the map, with any workshop stuff before removed
        // this is {MAP} in the format string
        char mapName[128];
        GetCurrentMap(mapName, sizeof(mapName));
        int last_slash = 0;
        int len = strlen(mapName);
        for (int i = 0;  i < len; i++) {
            if (mapName[i] == '/')
                last_slash = i + 1;
        }

        // get the time, this is {TIME} in the format string
        char timeFormat[64];
        GetConVarString(g_hDemoTimeFormat, timeFormat, sizeof(timeFormat));
        int timeStamp = GetTime();
        char formattedTime[64];
        FormatTime(formattedTime, sizeof(formattedTime), timeFormat, timeStamp);

        // get the player count, this is {TEAMSIZE} in the format string
        char playerCount[8];
        IntToString(g_PlayersPerTeam, playerCount, sizeof(playerCount));

        // create the actual demo name to use
        char demoName[256];
        GetConVarString(g_hDemoNameFormat, demoName, sizeof(demoName));

        ReplaceString(demoName, sizeof(demoName), "{MAP}", mapName[last_slash], false);
        ReplaceString(demoName, sizeof(demoName), "{TEAMSIZE}", playerCount, false);
        ReplaceString(demoName, sizeof(demoName), "{TIME}", formattedTime, false);

        ServerCommand("tv_record %s", demoName);
        LogMessage("Recording to %s", demoName);
        Format(g_DemoFileName, sizeof(g_DemoFileName), "%s.dem", demoName);
        g_Recording = true;
    }

    ServerCommand("exec gamemode_competitive.cfg");
    char liveCfg[256];
    GetArrayString(g_GameConfigFiles, g_GameTypeIndex, liveCfg, sizeof(liveCfg));
    ServerCommand("exec sourcemod/pugsetup/%s", liveCfg);

    g_MatchLive = true;
    if (g_TeamType == TeamType_Random) {
        PugSetupMessageToAll("{GREEN}Scrambling the teams!");
        ServerCommand("mp_scrambleteams");
    }

    for (int i = 0; i < 5; i++)
        PugSetupMessageToAll("The match will begin shortly - live on 3!");
    CreateTimer(7.0, BeginLO3, _, TIMER_FLAG_NO_MAPCHANGE);
}

// ChatAlias(String:chatAlias, commandfunction, Permissions:permissions)
#define ChatAlias(%1,%2,%3) \
if (StrEqual(text[0], %1)) { \
    if (HasPermissions(client, %3)) { \
        %2 (client, 0); \
    } else { \
        PugSetupMessage(client, "You don't have permisson to do that."); \
    } \
}

public Action Command_Say(client, const String:command[], argc) {
    char text[256];
    if (GetCmdArgString(text, sizeof(text)) < 1) {
        return Plugin_Continue;
    }

    StripQuotes(text);

    ChatAlias(".setup", Command_Setup, Permission_All)
    ChatAlias(".10man", Command_10man, Permission_All)
    ChatAlias(".start", Command_Start, Permission_Leader)
    ChatAlias(".endgame", Command_EndGame, Permission_Leader)
    ChatAlias(".endmatch", Command_EndGame, Permission_Leader)
    ChatAlias(".cancel", Command_EndGame, Permission_Leader)
    ChatAlias(".capt", Command_Capt, Permission_Leader)
    ChatAlias(".leader", Command_Leader, Permission_Leader)
    ChatAlias(".rand", Command_Rand, Permission_Leader)
    ChatAlias(".gaben", Command_Ready, Permission_All)
    ChatAlias(".ready", Command_Ready, Permission_All)
    ChatAlias(".gs4lyfe", Command_Ready, Permission_All)
    ChatAlias(".splewis", Command_Ready, Permission_All)
    ChatAlias(".unready", Command_Unready, Permission_All)
    ChatAlias(".pause", Command_Pause, Permission_Captains)
    ChatAlias(".unpause", Command_Unpause, Permission_Captains)

    // there is no sm_help command since we don't want override the built-in sm_help command
    if (StrEqual(text[0], ".help")) {
        PugSetupMessage(client, "{GREEN}Useful commands:");
        PugSetupMessage(client, "  {LIGHT_GREEN}.setup {NORMAL}begins the setup phase");
        PugSetupMessage(client, "  {LIGHT_GREEN}.start {NORMAL}starts the match if needed");
        PugSetupMessage(client, "  {LIGHT_GREEN}.endgame {NORMAL}ends the match");
        PugSetupMessage(client, "  {LIGHT_GREEN}.leader {NORMAL}allows you to set the game leader");
        PugSetupMessage(client, "  {LIGHT_GREEN}.capt {NORMAL}allows you to set team captains");
        PugSetupMessage(client, "  {LIGHT_GREEN}.rand {NORMAL}selects random captains");
        PugSetupMessage(client, "  {LIGHT_GREEN}.ready/.unready {NORMAL}mark you as ready");
        PugSetupMessage(client, "  {LIGHT_GREEN}.pause/.unpause {NORMAL}pause the match");
    }

    // continue normally
    return Plugin_Continue;
}

public bool HasPermissions(int client, Permissions p) {
    if (!IsPlayer(client))
        return false;

    bool isLeader = GetLeader() == client;
    bool isCapt = isLeader || client == g_capt1 || client == g_capt2 || CheckCommandAccess(client, "sm_map", ADMFLAG_CHANGEMAP);

    if (p == Permission_Leader)
        return isLeader;
    else if (p == Permission_Captains)
        return isCapt;
    else if (p == Permission_All)
        return true;
    else
        LogError("Unknown permission: %d", p);

    return false;

}

public Action Command_EndGame(client, args) {
    if (!g_Setup) {
        PugSetupMessage(client, "The match has not begun yet!");
    } else {
        Handle menu = CreateMenu(MatchEndHandler);
        SetMenuTitle(menu, "Are you sure you want to end the match?");
        SetMenuExitButton(menu, true);
        AddMenuBool(menu, false, "No, continue the match");
        AddMenuBool(menu, true, "Yes, end the match");
        DisplayMenu(menu, client, 20);
    }
    return Plugin_Handled;
}

public MatchEndHandler(Handle menu, MenuAction action, param1, param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        bool choice = GetMenuBool(menu, param2);
        if (choice) {
            PugSetupMessageToAll("The match was force-ended by {GREEN}%N", client);
            EndMatch(true);
        }
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public Action Command_ForceEnd(client, args) {
    PugSetupMessageToAll("The match was force-ended by {GREEN}%N", client);
    EndMatch(true);
}

public Action Command_Pause(client, args) {
    if (!g_Setup || !g_MatchLive)
        return Plugin_Handled;

    if (IsPlayer(client)) {
        ServerCommand("mp_pause_match");
        PugSetupMessageToAll("{GREEN}%N {NORMAL}has called for a pause", client);
    }
    return Plugin_Handled;
}

public Action Command_Unpause(client, args) {
    if (!g_Setup || !g_MatchLive)
        return Plugin_Handled;

    if (IsPlayer(client)) {
        ServerCommand("mp_unpause_match");
        PugSetupMessageToAll("{GREEN}%N {NORMAL}has unpaused", client);
    }
    return Plugin_Handled;
}

public Action Command_Ready(client, args) {
    if (!g_Setup || g_MatchLive)
        return Plugin_Handled;

    Call_StartForward(g_hOnReady);
    Call_PushCell(client);
    Call_Finish();

    g_Ready[client] = true;
    CS_SetClientClanTag(client, "[Ready]");
    return Plugin_Handled;
}

public Action Command_Unready(client, args) {
    if (!g_Setup || g_MatchLive)
        return Plugin_Handled;

    Call_StartForward(g_hOnUnready);
    Call_PushCell(client);
    Call_Finish();

    g_Ready[client] = false;
    CS_SetClientClanTag(client, "[Not ready]");
    return Plugin_Handled;
}

public Action Command_Leader(client, args) {
    if (!g_Setup)
        return Plugin_Handled;

    LeaderMenu(client);
    return Plugin_Handled;
}



/***********************
 *                     *
 *       Events        *
 *                     *
 ***********************/

public Action Event_MatchOver(Handle event, const char name[], bool dontBroadcast) {
    if (g_MatchLive) {
        CreateTimer(15.0, Timer_EndMatch);
        ExecCfg(g_hWarmupCfg);
    }
    return Plugin_Continue;
}

public Event_PlayerConnectFull(Handle event, const char name[], bool dontBroadcast) {
    int client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (IsMatchLive() && GetConVarInt(g_hAutoKickerEnabled) != 0 &&
        !CheckCommandAccess(client, "sm_setup", ADMFLAG_CHANGEMAP) &&
        IsPlayer(client)) {

        // count number of active players
        int count = 0;
        for (int i = 1; i <= MaxClients; i++) {
            if (IsPlayer(i)) {
                int team = GetClientTeam(i);
                if (team != CS_TEAM_NONE) {
                    count++;
                }
            }
        }

        if (count >= GetPugMaxPlayers()) {
            char msg[1024];
            GetConVarString(g_hKickMessage, msg, sizeof(msg));
            KickClient(client, msg);
        }
    }
}

/** Helper timer to delay starting warmup period after match is over by a little bit **/
public Action Timer_EndMatch(Handle timer) {
    EndMatch(false);
}

/**
 * Called when a player joins a team, silences team join events during player selection.
 */
public Action Event_PlayerTeam(Handle event, const char name[], bool dontBroadcast)  {
    if (g_Setup && !g_MatchLive) {
        dontBroadcast = true;
        return Plugin_Changed;
    } else {
        return Plugin_Continue;
    }
}

public Action:Command_TeamJoin(client, const String:command[], argc) {
    if (!IsValidClient(client) || argc < 1)
        return Plugin_Handled;

    char arg[4];
    GetCmdArg(1, arg, sizeof(arg));
    int team_to = StringToInt(arg);
    int team_from = GetClientTeam(client);

    int numT = 0;
    int numCT = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i)) {
            int team = GetClientTeam(i);
            if (team == CS_TEAM_CT)
                numCT++;
            if (team == CS_TEAM_T)
                numT++;
        }
    }

    // if same team, teamswitch controlled by the plugin
    // note if a player hits autoselect their team_from=team_to=CS_TEAM_NONE
    if (!g_MatchLive || (team_from == team_to && team_from != CS_TEAM_NONE) || IsFakeClient(client) || GetConVarInt(g_hLockTeams) == 0) {
        return Plugin_Continue;
    } else if ((team_to == CS_TEAM_T && numT >= g_PlayersPerTeam) || (team_from == CS_TEAM_CT && numCT >= g_PlayersPerTeam)) {
        // disables joining a full team
        return Plugin_Handled;
    } else {
        return Plugin_Continue;
    }
}



/***********************
 *                     *
 *   Pugsetup logic    *
 *                     *
 ***********************/

public void PrintSetupInfo(int client) {
    if (IsPlayer(GetLeader()))
        PugSetupMessage(client, "The game has been setup by {GREEN}%N", GetLeader());

    char buffer[128];
    GetArrayString(g_GameTypes, g_GameTypeIndex, buffer, sizeof(buffer));
    PugSetupMessage(client, "Game type: {GREEN}%s", buffer);

    GetTeamString(buffer, sizeof(buffer), g_TeamType);
    PugSetupMessage(client, "Teams: ({GREEN}%d vs %d{NORMAL}) {GREEN}%s", g_PlayersPerTeam, g_PlayersPerTeam, buffer);

    GetMapString(buffer, sizeof(buffer), g_MapType);
    PugSetupMessage(client, "Map: {GREEN}%s", buffer);

    GetEnabledString(buffer, sizeof(buffer), g_AutoLO3);
    PugSetupMessage(client, "Auto live-on-3: {GREEN}%s", buffer);

    GetMapList();
}

public void SetRandomCaptains() {
    int c1 = -1;
    int c2 = -1;

    c1 = RandomPlayer();
    while (!IsPlayer(c2) || c1 == c2) {
        if (GetRealClientCount() < 2)
            break;

        c2 = RandomPlayer();
    }

    SetCaptain1(c1);
    SetCaptain2(c2);
}

public void ReadyToStart() {
    if (g_AutoLO3) {
        Command_Start(0, 0);
    } else {
        PugSetupMessageToAll("Everybody is ready! Waiting for {GREEN}%N {NORMAL}to type \x03.start", GetLeader());
    }
}

public void EndMatch(bool execConfigs) {
    if (g_Recording) {
        CreateTimer(3.0, StopDemoMsg, _, TIMER_FLAG_NO_MAPCHANGE);
        CreateTimer(4.0, StopDemo, _, TIMER_FLAG_NO_MAPCHANGE);
    } else {
        Call_StartForward(g_hOnMatchOver);
        Call_PushCell(false);
        Call_PushString("");
        Call_Finish();
    }

    for (new i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i))
            CS_SetClientClanTag(i, "");
    }

    ServerCommand("mp_unpause_match");
    if (g_MatchLive && execConfigs)
        ExecCfg(g_hWarmupCfg);

    g_LiveTimerRunning = false;
    g_Leader = -1;
    g_capt1 = -1;
    g_capt2 = -1;
    g_mapSet = false;
    g_Setup = false;
    g_MatchLive = false;


}

public Action MapSetup(Handle timer) {
    if (g_MapType == MapType_Vote) {
        CreateMapVote();
    } else if (g_MapType == MapType_Veto) {
        CreateMapVeto();
    } else {
        LogError("Unexpected map type in MapSetup=%d", g_MapType);
    }
    return Plugin_Handled;
}

public Action StartPicking(Handle timer) {
    ServerCommand("mp_pause_match");
    ServerCommand("mp_restartgame 1");

    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i)) {
            g_Teams[i] = CS_TEAM_SPECTATOR;
            SwitchPlayerTeam(i, CS_TEAM_SPECTATOR);
        }
    }

    // temporary teams
    SwitchPlayerTeam(g_capt2, CS_TEAM_CT);
    SwitchPlayerTeam(g_capt1, CS_TEAM_T);
    InitialChoiceMenu(g_capt1);
    return Plugin_Handled;
}

public Action FinishPicking(Handle timer) {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i)) {
            SwitchPlayerTeam(i, g_Teams[i]);
        }
    }

    if (GetConVarInt(g_hAutoKickerEnabled) != 0) {
        for (int i = 1; i <= MaxClients; i++) {
            if (IsPlayer(i) && !CheckCommandAccess(i, "sm_setup", ADMFLAG_CHANGEMAP)) {
                int team = GetClientTeam(i);
                if (team == CS_TEAM_NONE || team == CS_TEAM_SPECTATOR) {
                    char msg[1024];
                    GetConVarString(g_hKickMessage, msg, sizeof(msg));
                    KickClient(i, msg);
                }
            }
        }
    }

    ServerCommand("mp_unpause_match");
    ReadyToStart();
    return Plugin_Handled;
}

public Action StopDemoMsg(Handle timer) {
    PugSetupMessageToAll("Stopping the GOTV demo...");
    return Plugin_Handled;
}

public Action StopDemo(Handle timer) {
    ServerCommand("tv_stoprecord");
    g_Recording = false;
    Call_StartForward(g_hOnMatchOver);
    Call_PushCell(true);
    Call_PushString(g_DemoFileName);
    Call_Finish();
    return Plugin_Handled;
}

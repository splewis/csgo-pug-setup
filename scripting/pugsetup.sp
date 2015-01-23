#pragma semicolon 1
#include <cstrike>
#include <sourcemod>
#include <sdktools>
#include "include/pugsetup.inc"

#undef REQUIRE_EXTENSIONS
#include "include/system2.inc"

#undef REQUIRE_PLUGIN
#include "include/updater.inc"
#define UPDATE_URL "https://dl.dropboxusercontent.com/u/76035852/csgo-pug-setup/csgo-pug-setup.txt"


/***********************
 *                     *
 *   Global variables  *
 *                     *
 ***********************/

/** Initial menu data (where captain 1 picks between side pick or 1st player pick) **/
enum InitialPick {
    InitialPick_Side,
    InitialPick_Player
};

/** ConVar handles **/
ConVar g_hAdminFlag;
ConVar g_hAnnounceCountdown;
ConVar g_hAnyCanPause;
ConVar g_hAutoRandomizeCaptains;
ConVar g_hAutoSetup;
ConVar g_hAutoUpdate;
ConVar g_hCvarVersion;
ConVar g_hDefaultKnifeRounds;
ConVar g_hDefaultMapType;
ConVar g_hDefaultRecord;
ConVar g_hDefaultTeamSize;
ConVar g_hDefaultTeamType;
ConVar g_hDemoNameFormat;
ConVar g_hDemoTimeFormat;
ConVar g_hExcludeSpectators;
ConVar g_hExecDefaultConfig;
ConVar g_hForceDefaults;
ConVar g_hLiveCfg;
ConVar g_hMapList;
ConVar g_hMapVoteTime;
ConVar g_hMessagePrefix;
ConVar g_hMutualUnpause;
ConVar g_hOptionKnifeRounds;
ConVar g_hOptionMapType;
ConVar g_hOptionRecord;
ConVar g_hOptionTeamSize;
ConVar g_hOptionTeamType;
ConVar g_hQuickRestarts;
ConVar g_hRandomizeMapOrder;
ConVar g_hRequireAdminToSetup;
ConVar g_hSnakeCaptains;
ConVar g_hStartDelay;
ConVar g_hWarmupCfg;

/** Setup info **/
int g_Leader = -1;
ArrayList g_MapList;
bool g_ForceEnded = false;

// Specific choices made when setting up
int g_PlayersPerTeam = 5;
TeamType g_TeamType;
MapType g_MapType;
bool g_RecordGameOption;
bool g_DoKnifeRound;
bool g_SetDefaultConfig = false;

// Other important variables about the state of the game
bool g_Setup = false;
bool g_mapSet = false;
bool g_Recording = true;
char g_DemoFileName[PLATFORM_MAX_PATH];
bool g_LiveTimerRunning = false;
int g_CountDownTicks = 0;

// Pause information
bool g_ctUnpaused = false;
bool g_tUnpaused = false;

/** Stuff for workshop map/collection cache **/
char g_DataDir[PLATFORM_MAX_PATH]; // directory to leave cache files in
char g_CacheFile[PLATFORM_MAX_PATH]; // filename of the keyvalue cache file
KeyValues g_WorkshopCache; // keyvalue struct for the cache

/** Chat aliases loaded from the config file **/
ArrayList g_ChatAliases;
ArrayList g_ChatAliasesCommands;

/** Map-voting variables **/
ArrayList g_MapVetoed;
int g_ChosenMap = -1;

/** Data about team selections **/
int g_capt1 = -1;
int g_capt2 = -1;
int g_Teams[MAXPLAYERS+1];
bool g_Ready[MAXPLAYERS+1];
bool g_PlayerAtStart[MAXPLAYERS+1];
bool g_PickingPlayers = false;
bool g_MatchLive = false;
bool g_InStartPhase = false;

/** Knife round data **/
bool g_WaitingForKnifeWinner = false;
bool g_WaitingForKnifeDecision = false;
int g_KnifeWinner = -1;

/** Forwards **/
Handle g_hOnForceEnd = INVALID_HANDLE;
Handle g_hOnGoingLive = INVALID_HANDLE;
Handle g_hOnLive = INVALID_HANDLE;
Handle g_hOnLiveCheck = INVALID_HANDLE;
Handle g_hOnMatchOver = INVALID_HANDLE;
Handle g_hOnNotPicked = INVALID_HANDLE;
Handle g_hOnPermissionCheck = INVALID_HANDLE;
Handle g_hOnReady = INVALID_HANDLE;
Handle g_hOnReadyToStart = INVALID_HANDLE;
Handle g_hOnSetup = INVALID_HANDLE;
Handle g_hOnSetupMenuOpen = INVALID_HANDLE;
Handle g_hOnSetupMenuSelect = INVALID_HANDLE;
Handle g_hOnUnready = INVALID_HANDLE;

#include "pugsetup/captainpickmenus.sp"
#include "pugsetup/configreader.sp"
#include "pugsetup/generic.sp"
#include "pugsetup/kniferounds.sp"
#include "pugsetup/leadermenus.sp"
#include "pugsetup/liveon3.sp"
#include "pugsetup/maps.sp"
#include "pugsetup/mapveto.sp"
#include "pugsetup/mapvote.sp"
#include "pugsetup/natives.sp"
#include "pugsetup/setupmenus.sp"
#include "pugsetup/steamapi.sp"



/***********************
 *                     *
 * Sourcemod forwards  *
 *                     *
 ***********************/

public Plugin:myinfo = {
    name = "CS:GO PugSetup",
    author = "splewis",
    description = "Tools for setting up pugs/10mans",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-pug-setup"
};

public void OnPluginStart() {
    LoadTranslations("common.phrases");
    LoadTranslations("pugsetup.phrases");

    /** ConVars **/
    g_hAdminFlag = CreateConVar("sm_pugsetup_admin_flag", "b", "Admin flag to mark players as having elevated permissions - e.g. can always pause,setup,end the game, etc.");
    g_hAnnounceCountdown = CreateConVar("sm_pugsetup_announce_countdown_timer", "1", "Whether to announce how long the countdown has left before the lo3 begins");
    g_hAnyCanPause = CreateConVar("sm_pugsetup_any_can_pause", "1", "Whether everyone can pause, or just captains/leader. Note: if sm_pugsetup_mutual_unpausing is set to 1, this cvar is ignored");
    g_hAutoRandomizeCaptains = CreateConVar("sm_pugsetup_auto_randomize_captains", "0", "When games are using captains, should they be automatically randomized once? Note you can still manually set them or use .rand/!rand to redo the randomization.");
    g_hAutoSetup = CreateConVar("sm_pugsetup_autosetup", "0", "Whether a pug is automatically setup using the default setup options or not");
    g_hAutoUpdate = CreateConVar("sm_pugsetup_autoupdate", "1", "Whether the plugin may (if the \"Updater\" plugin is loaded) automatically update");

    // Setup options defaults
    g_hDefaultKnifeRounds = CreateConVar("sm_pugsetup_default_knife_rounds", "0", "Whether to use knife rounds to select starting sides");
    g_hDefaultMapType = CreateConVar("sm_pugsetup_default_maptype", "vote", "Default team type to use. Allowed values: \"vote\", \"veto\", \"current\"");
    g_hDefaultRecord = CreateConVar("sm_pugsetup_default_record", "0", "Default value for recording demoes each game, requries tv_enable 1 to work");
    g_hDefaultTeamSize = CreateConVar("sm_pugsetup_default_teamsize", "5", "Default number of players per team, can be changed in the .setup menu");
    g_hDefaultTeamType = CreateConVar("sm_pugsetup_default_teamtype", "captains", "What team type to use. Allowed values: \"captains\", \"manual\", and \"random\"");

    g_hDemoNameFormat = CreateConVar("sm_pugsetup_demo_name_format", "pug_{MAP}_{TIME}", "Naming scheme for demos. You may use {MAP}, {TIME}, and {TEAMSIZE}. Make sure there are no spaces or colons in this.");
    g_hDemoTimeFormat = CreateConVar("sm_pugsetup_time_format", "%Y-%m-%d_%H", "Time format to use when creating demo file names. Don't tweak this unless you know what you're doing! Avoid using spaces or colons.");
    g_hExcludeSpectators = CreateConVar("sm_pugsetup_exclude_spectators", "0", "Whether to exclude spectators in the ready-up counts. Setting this to 1 will exclude specators from being selected by captains, as well.");
    g_hExecDefaultConfig = CreateConVar("sm_pugsetup_exec_default_game_config", "1", "Whether gamemode_competitive (the matchmaking config) should be executed before the live config.");
    g_hForceDefaults = CreateConVar("sm_pugsetup_force_defaults", "0", "Whether the default setup options are forced as the setup options");
    g_hLiveCfg = CreateConVar("sm_pugsetup_live_cfg", "sourcemod/pugsetup/standard.cfg", "Config to execute when the game goes live");
    g_hMapList = CreateConVar("sm_pugsetup_maplist", "standard.txt", "Maplist file in addons/sourcemod/configs/pugsetup to use. You may also use a workshop collection ID instead of a maplist if you have the System2 extension installed.");
    g_hMapVoteTime = CreateConVar("sm_pugsetup_mapvote_time", "20", "How long the map vote should last if using map-votes", _, true, 10.0);
    g_hMessagePrefix = CreateConVar("sm_pugsetup_message_prefix", "[{YELLOW}PugSetup{NORMAL}]", "The tag applied before plugin messages. If you want no tag, you should use an single space \" \" to ensure colors work correctly");
    g_hMutualUnpause = CreateConVar("sm_pugsetup_mutual_unpausing", "1", "Whether an unpause command requires someone from both teams to fully unpause the match. Note that this cvar will let anybody use the !unpause command.");

    // Whether setup options are shown
    g_hOptionKnifeRounds = CreateConVar("sm_pugsetup_knife_rounds_option", "1", "Whether the knife round option is displayed in the setup menu or the default is always used");
    g_hOptionMapType = CreateConVar("sm_pugsetup_maptype_option", "1", "Whether the map type option is displayed in the setup menu or the default is always used");
    g_hOptionRecord = CreateConVar("sm_pugsetup_record_option", "1", "Whether the record demooption is displayed in the setup menu or the default is always used");
    g_hOptionTeamSize = CreateConVar("sm_pugsetup_teamsize_option", "1", "Whether the teamsize option is displayed in the setup menu or the default is always used");
    g_hOptionTeamType = CreateConVar("sm_pugsetup_teamtype_option", "1", "Whether the teamtype option is displayed in the setup menu or the default is always used");

    g_hQuickRestarts = CreateConVar("sm_pugsetup_quick_restarts", "0", "If set to 1, going live won't restart 3 times and will just do a single restart.");
    g_hRandomizeMapOrder = CreateConVar("sm_pugsetup_randomize_maps", "1", "When maps are shown in the map vote/veto, should their order be randomized?");
    g_hRequireAdminToSetup = CreateConVar("sm_pugsetup_requireadmin", "0", "If a client needs the sm_pugsetup_admin_flag flag to use the .setup command.");
    g_hSnakeCaptains = CreateConVar("sm_pugsetup_snake_captain_picks", "0", "Whether captains will pick players in a \"snaked\" fashion rather than alternating, e.g. ABBAABBA rather than ABABABAB.");
    g_hStartDelay = CreateConVar("sm_pugsetup_start_delay", "10", "How many seconds before the lo3 process should being. You might want to make this longer if you want to move people into teamspeak/mumble channels or similar.", _, true, 0.0, true, 60.0);
    g_hWarmupCfg = CreateConVar("sm_pugsetup_warmup_cfg", "sourcemod/pugsetup/warmup.cfg", "Config file to run before/after games; should be in the csgo/cfg directory.");

    /** Create and exec plugin's configuration file **/
    AutoExecConfig(true, "pugsetup", "sourcemod/pugsetup");

    g_hCvarVersion = CreateConVar("sm_pugsetup_version", PLUGIN_VERSION, "Current pugsetup version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
    SetConVarString(g_hCvarVersion, PLUGIN_VERSION);

    /** Commands **/
    RegConsoleCmd("sm_ready", Command_Ready, "Marks the client as ready");
    RegConsoleCmd("sm_notready", Command_Unready, "Marks the client as not ready");
    RegConsoleCmd("sm_unready", Command_Unready, "Marks the client as not ready");
    RegConsoleCmd("sm_setup", Command_Setup, "Starts pug setup (.ready, .capt commands become avaliable)");
    RegConsoleCmd("sm_10man", Command_10man, "Starts 10man setup (alias for .setup with 10 man/gather settings)");
    RegConsoleCmd("sm_rand", Command_Rand, "Sets random captains");
    RegConsoleCmd("sm_pause", Command_Pause, "Pauses the game");
    RegConsoleCmd("sm_unpause", Command_Unpause, "Unpauses the game");
    RegConsoleCmd("sm_endgame", Command_EndGame, "Pre-emptively ends the match");
    RegConsoleCmd("sm_endmatch", Command_EndGame, "Pre-emptively ends the match");
    RegConsoleCmd("sm_forceend", Command_ForceEnd, "Pre-emptively ends the match, without any confirmation menu");
    RegConsoleCmd("sm_forceready", Command_ForceReady, "Force-readies a player");
    RegConsoleCmd("sm_leader", Command_Leader, "Sets the pug leader");
    RegConsoleCmd("sm_capt", Command_Capt, "Gives the client a menu to pick captains");
    RegConsoleCmd("sm_captain", Command_Capt, "Gives the client a menu to pick captains");
    RegConsoleCmd("sm_stay", Command_Stay, "Elects to stay on the current team after winning a knife round");
    RegConsoleCmd("sm_swap", Command_Swap, "Elects to swap the current teams after winning a knife round");

    /** Hooks **/
    HookEvent("cs_win_panel_match", Event_MatchOver);
    HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
    HookEvent("round_end", Event_RoundEnd);

    g_hOnForceEnd = CreateGlobalForward("OnForceEnd", ET_Ignore, Param_Cell);
    g_hOnReadyToStart = CreateGlobalForward("OnReadyToStart", ET_Ignore);
    g_hOnGoingLive = CreateGlobalForward("OnGoingLive", ET_Ignore);
    g_hOnLive = CreateGlobalForward("OnLive", ET_Ignore);
    g_hOnLiveCheck = CreateGlobalForward("OnReadyToStartCheck", ET_Ignore, Param_Cell, Param_Cell);
    g_hOnMatchOver = CreateGlobalForward("OnMatchOver", ET_Ignore, Param_Cell, Param_String);
    g_hOnNotPicked = CreateGlobalForward("OnNotPicked", ET_Ignore, Param_Cell);
    g_hOnPermissionCheck = CreateGlobalForward("OnPermissionCheck", ET_Ignore, Param_Cell, Param_String, Param_Cell, Param_CellByRef);
    g_hOnReady = CreateGlobalForward("OnReady", ET_Ignore, Param_Cell);
    g_hOnSetup = CreateGlobalForward("OnSetup", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    g_hOnSetupMenuOpen = CreateGlobalForward("OnSetupMenuOpen", ET_Single, Param_Cell, Param_Cell, Param_Cell);
    g_hOnSetupMenuSelect = CreateGlobalForward("OnSetupMenuSelect", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    g_hOnUnready = CreateGlobalForward("OnUnready", ET_Ignore, Param_Cell);

    g_LiveTimerRunning = false;

    LoadChatAliases();

    /** Updater support **/
    if (GetConVarInt(g_hAutoUpdate) != 0) {
        AddUpdater();
    }

    g_SetDefaultConfig = false;
}

public void OnLibraryAdded(const char[] name) {
    if (GetConVarInt(g_hAutoUpdate) != 0) {
        AddUpdater();
    }
}

static void AddUpdater() {
    #if defined _updater_included
    if (LibraryExists("updater")) {
        Updater_AddPlugin(UPDATE_URL);
    }
    #endif
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlen) {
    g_Teams[client] = CS_TEAM_NONE;
    g_Ready[client] = false;
    g_PlayerAtStart[client] = false;
    CheckAutoSetup();
    return true;
}

public void OnClientDisconnect(int client) {
    g_Teams[client] = CS_TEAM_NONE;
    g_Ready[client] = false;
    g_PlayerAtStart[client] = false;
    int numPlayers = 0;
    for (int i = 1; i <= MaxClients; i++)
        if (IsPlayer(i))
            numPlayers++;

    if (numPlayers == 0 && (g_MapType != MapType_Vote || g_MapType != MapType_Veto || !g_mapSet || g_MatchLive)) {
        EndMatch(true);
    }
}

public void OnMapStart() {
    g_MapList = CreateArray(PLATFORM_MAX_PATH);
    g_ForceEnded = false;
    Config_MapStart();
    g_MapVetoed = new ArrayList();
    g_Recording = false;
    g_MatchLive = false;
    g_LiveTimerRunning = false;
    g_WaitingForKnifeWinner = false;
    g_WaitingForKnifeDecision = false;
    g_InStartPhase = false;

    for (int i = 1; i <= MaxClients; i++) {
        g_Ready[i] = false;
        g_Teams[i] = -1;
    }

    if (g_mapSet || g_Setup) {
        ExecCfg(g_hWarmupCfg);
        g_Setup = true;
        if (!g_LiveTimerRunning) {
            CreateTimer(0.3, Timer_CheckReady, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
            g_LiveTimerRunning = true;
        }
    } else {
        g_capt1 = -1;
        g_capt2 = -1;
        g_Leader = -1;
    }

    if (!g_Setup && !g_SetDefaultConfig) {
        SetConfigDefaults();
        g_SetDefaultConfig = true;
    }
}

public void OnMapEnd() {
    CloseHandle(g_MapVetoed);
    CloseHandle(g_MapList);
}

public Action Timer_CheckReady(Handle timer) {
    if (!g_Setup || g_MatchLive || !g_LiveTimerRunning) {
        g_LiveTimerRunning = false;
        return Plugin_Stop;
    }

    int readyPlayers = 0;
    int totalPlayers = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i)) {
            UpdateClanTag(i);
            int team = GetClientTeam(i);
            if (g_hExcludeSpectators.IntValue == 0 || team == CS_TEAM_CT || team == CS_TEAM_T) {
                totalPlayers++;
                if (g_Ready[i]) {
                    readyPlayers++;
                }
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
                    PugSetupMessageToAll("%t", "VetoMessage");
                    CreateTimer(2.0, MapSetup, _, TIMER_FLAG_NO_MAPCHANGE);
                    g_LiveTimerRunning = false;
                    return Plugin_Stop;
                } else {
                    StatusHint(readyPlayers, totalPlayers);
                }

            } else {
                PugSetupMessageToAll("%t", "VoteMessage");
                CreateTimer(2.0, MapSetup, _, TIMER_FLAG_NO_MAPCHANGE);
                g_LiveTimerRunning = false;
                return Plugin_Stop;
            }
        }

    } else {
        StatusHint(readyPlayers, totalPlayers);
    }

    if (g_TeamType == TeamType_Captains && g_hAutoRandomizeCaptains.IntValue != 0) {
        // re-randomize captains if they aren't set yet
        if (!IsPlayer(g_capt1)) {
            g_capt1 = RandomPlayer();
        }

        while (!IsPlayer(g_capt2) && g_capt1 != g_capt2) {
            if (GetRealClientCount() < 2)
                break;
            g_capt2 = RandomPlayer();
        }

    }

    Call_StartForward(g_hOnLiveCheck);
    Call_PushCell(readyPlayers);
    Call_PushCell(totalPlayers);
    Call_Finish();

    return Plugin_Continue;
}

public void StatusHint(int readyPlayers, int totalPlayers) {
    char rdyCommand[32];
    FindChatCommand("sm_ready", rdyCommand, sizeof(rdyCommand));
    if (!g_mapSet && g_MapType != MapType_Veto) {
        PrintHintTextToAll("%t", "ReadyStatus", readyPlayers, totalPlayers, rdyCommand);
    } else {
        if (g_TeamType == TeamType_Captains || g_MapType == MapType_Veto) {
            for (int i = 1; i <= MaxClients; i++) {
                if (IsPlayer(i))
                    GiveCaptainHint(i, readyPlayers, totalPlayers);
            }
        } else {
            PrintHintTextToAll("%t", "ReadyStatus", readyPlayers, totalPlayers, rdyCommand);
        }

    }
}

static void GiveCaptainHint(int client, int readyPlayers, int totalPlayers) {
        char cap1[64];
        char cap2[64];
        if (IsPlayer(g_capt1))
            Format(cap1, sizeof(cap1), "%N", g_capt1);
        else
            Format(cap1, sizeof(cap1), "%T", "CaptainNotSelected", client);

        if (IsPlayer(g_capt2))
            Format(cap2, sizeof(cap2), "%N", g_capt2);
        else
            Format(cap2, sizeof(cap2), "%T", "CaptainNotSelected", client);

        PrintHintTextToAll("%t", "ReadyStatusCaptains", readyPlayers, totalPlayers, cap1, cap2);
}


/***********************
 *                     *
 *     Commands        *
 *                     *
 ***********************/

// PermissionCheck(Permissions:permissions)
#define PermissionCheck(%1) { \
    bool _perm = HasPermissions(client, %1); \
    char _cmd[64]; \
    GetCmdArg(0, _cmd, sizeof(_cmd)); \
    Call_StartForward(g_hOnPermissionCheck); \
    Call_PushCell(client); \
    Call_PushString(_cmd); \
    Call_PushCell(%1); \
    Call_PushCellRef(_perm); \
    Call_Finish(); \
    if (!_perm) { \
        if (IsValidClient(client)) \
            PugSetupMessage(client, "%t", "NoPermission"); \
        return Plugin_Handled; \
    } \
}

public Action Command_Setup(int client, int args) {
    if (g_MatchLive) {
        PugSetupMessage(client, "%t", "AlreadyLive");
        return Plugin_Handled;
    }

    if (g_Setup && client != GetLeader()) {
        PrintSetupInfo(client);
        return Plugin_Handled;
    }

    if (g_hRequireAdminToSetup.IntValue != 0) {
        PermissionCheck(Permission_Admin)
    } else {
        PermissionCheck(Permission_All)
    }

    g_PickingPlayers = false;
    g_capt1 = -1;
    g_capt2 = -1;
    if (IsPlayer(client))
        g_Leader = GetSteamAccountID(client);

    for (int i = 1; i <= MaxClients; i++)
        g_Ready[i] = false;

    GiveSetupMenu(client);
    return Plugin_Handled;
}

public Action Command_10man(int client, int args) {
    if (g_MatchLive) {
        PugSetupMessage(client, "%t", "AlreadyLive");
        return Plugin_Handled;
    }

    if (g_Setup && client != GetLeader()) {
        PrintSetupInfo(client);
        return Plugin_Handled;
    }

    if (g_hRequireAdminToSetup.IntValue != 0) {
        PermissionCheck(Permission_Admin)
    } else {
        PermissionCheck(Permission_All)
    }

    g_PickingPlayers = false;
    g_capt1 = -1;
    g_capt2 = -1;
    if (IsPlayer(client))
        g_Leader = GetSteamAccountID(client);

    for (int i = 1; i <= MaxClients; i++)
        g_Ready[i] = false;

    SetupGame(TeamType_Captains, MapType_Vote, 5);
    return Plugin_Handled;
}

public Action Command_Rand(int client, int args) {
    if (!g_Setup || g_MatchLive)
        return Plugin_Handled;

    if (g_TeamType != TeamType_Captains && g_MapType != MapType_Veto) {
        PugSetupMessage(client, "%t", "NotUsingCaptains");
        return Plugin_Handled;
    }

    PermissionCheck(Permission_Captains)
    SetRandomCaptains();
    return Plugin_Handled;
}

public Action Command_Capt(int client, int args) {
    if (!g_Setup || g_MatchLive || g_PickingPlayers)
        return Plugin_Handled;

    if (g_TeamType != TeamType_Captains && g_MapType != MapType_Veto) {
        PugSetupMessage(client, "%t", "NotUsingCaptains");
        return Plugin_Handled;
    }

    PermissionCheck(Permission_Leader)

    char buffer[64];
    if (args != 0 && GetCmdArgs() >= 1) {

        GetCmdArg(1, buffer, sizeof(buffer));
        int target = FindTarget(client, buffer, true, false);
        if (IsPlayer(target))
            SetCaptain(1, target);

        if (GetCmdArgs() >= 2) {
            GetCmdArg(2, buffer, sizeof(buffer));
            target = FindTarget(client, buffer, true, false);

            if (IsPlayer(target))
                SetCaptain(2, target);

        } else {
            Captain2Menu(client);
        }

    } else {
        Captain1Menu(client);
    }
    return Plugin_Handled;
}

public void LoadChatAliases() {
    AddChatAlias(".setup", "sm_setup");
    AddChatAlias(".10man", "sm_10man");
    AddChatAlias(".endgame", "sm_endmatch");
    AddChatAlias(".endmatch", "sm_endmatch");
    AddChatAlias(".forceend", "sm_forceend");
    AddChatAlias(".cancel", "sm_endmatch");
    AddChatAlias(".capt", "sm_capt");
    AddChatAlias(".captain", "sm_capt");
    AddChatAlias(".leader", "sm_leader");
    AddChatAlias(".rand", "sm_rand");
    AddChatAlias(".gaben", "sm_ready");
    AddChatAlias(".gs4lyfe", "sm_ready");
    AddChatAlias(".splewis", "sm_ready");
    AddChatAlias(".ready", "sm_ready");
    AddChatAlias(".notready", "sm_unready");
    AddChatAlias(".unready", "sm_unready");
    AddChatAlias(".paws", "sm_pause");
    AddChatAlias(".unpaws", "sm_unpause");
    AddChatAlias(".pause", "sm_pause");
    AddChatAlias(".unpause", "sm_unpause");
    AddChatAlias(".stay", "sm_stay");
    AddChatAlias(".swap", "sm_swap");

    char configFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configFile, sizeof(configFile), "configs/pugsetup/chataliases.cfg");
    KeyValues kv = new KeyValues("ChatAliases");
    if (kv.ImportFromFile(configFile) && kv.GotoFirstSubKey()) {
        if (kv.JumpToKey("maps") && kv.GotoFirstSubKey(false)) {
            do {
                char alias[64];
                char command[64];
                kv.GetSectionName(alias, sizeof(alias));
                kv.GetString(alias, command, sizeof(command));
                AddChatAlias(alias, command);
            } while (kv.GotoNextKey(false));
        }
    }
    delete kv;
}

public void FindChatCommand(const char[] command, char[] buffer, int len) {
    int n = g_ChatAliases.Length;
    char tmpCommand[64];

    // This loop is done backwards since users are generally more likely
    // to add chat aliases to the end of the chataliases.cfg file, and
    // generally we'd want the user-created chat alias to be the one specified
    // to players on the server.
    for (int i = n - 1; i >= 0; i--) {
        g_ChatAliasesCommands.GetString(i, tmpCommand, sizeof(tmpCommand));

        if (StrEqual(command, tmpCommand)) {
            g_ChatAliases.GetString(i, buffer, len);
            return;
        }
    }

    // If we never found one, just use !<command> (without the sm_ prefix)
    // TODO: The use of "!" is actually a sourcemod option, so this should probably
    // detect that cvar's value instead of assuming it's always !
    Format(buffer, len, "!%s", command[2]);
}

static bool CheckChatAlias(const char[] alias, const char[] command, const char[] sArgs, int client) {
    if (IsPrefix(sArgs, alias)) {
        char text[255];
        SplitStringRight(sArgs, alias, text, sizeof(text));
        FakeClientCommand(client, "%s %s", command, text);
        return true;
    }
    return false;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs) {
    for (int i = 0; i < GetArraySize(g_ChatAliases); i++) {
        char alias[64];
        char cmd[64];
        GetArrayString(g_ChatAliases, i, alias, sizeof(alias));
        GetArrayString(g_ChatAliasesCommands, i, cmd, sizeof(cmd));

        if (CheckChatAlias(alias, cmd, sArgs, client)) {
            break;
        }
    }

    // there is no sm_help command since we don't want override the built-in sm_help command
    if (StrEqual(sArgs[0], ".help")) {
        PugSetupMessage(client, "{GREEN}Useful commands:");
        PugSetupMessage(client, "  {LIGHT_GREEN}!setup {NORMAL}begins the setup phase");
        PugSetupMessage(client, "  {LIGHT_GREEN}!endgame {NORMAL}ends the match");
        PugSetupMessage(client, "  {LIGHT_GREEN}!leader {NORMAL}allows you to set the game leader");
        PugSetupMessage(client, "  {LIGHT_GREEN}!capt {NORMAL}allows you to set team captains");
        PugSetupMessage(client, "  {LIGHT_GREEN}!rand {NORMAL}selects random captains");
        PugSetupMessage(client, "  {LIGHT_GREEN}!ready/!unready {NORMAL}mark you as ready");
        PugSetupMessage(client, "  {LIGHT_GREEN}!pause/!unpause {NORMAL}pause the match");
    }
}

public Action Command_EndGame(int client, int args) {
    if (!g_Setup) {
        PugSetupMessage(client, "%t", "NotLiveYet");
        PrintToChat(client, "%t", "NotLiveYet");
    } else {
        PermissionCheck(Permission_Leader)

        Menu menu = new Menu(MatchEndHandler);
        SetMenuTitle(menu, "%T", "EndMatchMenuTitle", client);
        SetMenuExitButton(menu, true);
        AddMenuBool(menu, false, "%T", "ContinueMatch", client);
        AddMenuBool(menu, true, "%T", "EndMatch", client);
        DisplayMenu(menu, client, 20);
    }
    return Plugin_Handled;
}

public int MatchEndHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        bool choice = GetMenuBool(menu, param2);
        if (choice) {
            Call_StartForward(g_hOnForceEnd);
            Call_PushCell(client);
            Call_Finish();

            PugSetupMessageToAll("%t", "ForceEnd", client);
            EndMatch(true);
            g_ForceEnded = true;
        }
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public Action Command_ForceEnd(int client, int args) {
    PermissionCheck(Permission_Admin)

    Call_StartForward(g_hOnForceEnd);
    Call_PushCell(client);
    Call_Finish();

    PugSetupMessageToAll("%t", "ForceEnd", client);
    EndMatch(true);
    g_ForceEnded = true;
    return Plugin_Handled;
}

public Action Command_ForceReady(int client, int args) {
    PermissionCheck(Permission_Admin)

    char buffer[64];
    if (args >= 1 && GetCmdArg(1, buffer, sizeof(buffer))) {
        int target = FindTarget(client, buffer, true, false);
        if (IsPlayer(target))
            ReadyPlayer(target);
    }

    return Plugin_Handled;
}

public Action Command_Pause(int client, int args) {
    if (!g_Setup || !g_MatchLive || IsPaused())
        return Plugin_Handled;

    if (g_hAnyCanPause.IntValue != 0)
        PermissionCheck(Permission_Captains)

    g_ctUnpaused = false;
    g_tUnpaused = false;
    ServerCommand("mp_pause_match");
    if (IsPlayer(client)) {
        PugSetupMessageToAll("%t", "Pause", client);
    }

    return Plugin_Handled;
}

public Action Command_Unpause(int client, int args) {
    if (!g_Setup || !g_MatchLive || !IsPaused())
        return Plugin_Handled;

    char unpauseCmd[32];
    FindChatCommand("sm_unpause", unpauseCmd, sizeof(unpauseCmd));

    if (g_hMutualUnpause.IntValue == 0) {
        if (g_hAnyCanPause.IntValue != 0)
            PermissionCheck(Permission_Captains)

        ServerCommand("mp_unpause_match");
        if (IsPlayer(client)) {
            PugSetupMessageToAll("%t", "Unpause", client);
        }
    } else {
        // Let console force unpause
        if (!IsPlayer(client)) {
            ServerCommand("mp_unpause_match");
        } else {
            int team = GetClientTeam(client);
            if (team == CS_TEAM_T)
                g_tUnpaused = true;
            else if (team == CS_TEAM_CT)
                g_ctUnpaused = true;

            if (g_tUnpaused && g_ctUnpaused)  {
                ServerCommand("mp_unpause_match");
                if (IsPlayer(client)) {
                    PugSetupMessageToAll("%t", "Unpause", client);
                }
            } else if (g_tUnpaused && !g_ctUnpaused) {
                PugSetupMessageToAll("%t", "MutualUnpauseMessage", "T", "CT", unpauseCmd);
            } else if (!g_tUnpaused && g_ctUnpaused) {
                PugSetupMessageToAll("%t", "MutualUnpauseMessage", "CT", "T", unpauseCmd);
            }
        }
    }

    return Plugin_Handled;
}

public Action Command_Ready(int client, int args) {
    ReadyPlayer(client);
    return Plugin_Handled;
}

public Action Command_Unready(int client, int args) {
    UnreadyPlayer(client);
    return Plugin_Handled;
}

public Action Command_Leader(int client, int args) {
    if (!g_Setup)
        return Plugin_Handled;

    PermissionCheck(Permission_Leader)

    char buffer[64];
    if (args != 0 && GetCmdArgs() >= 1) {
        GetCmdArg(1, buffer, sizeof(buffer));
        int target = FindTarget(client, buffer, true, false);
        if (IsPlayer(target))
            SetLeader(target);
    } else {
        LeaderMenu(client);
    }

    return Plugin_Handled;
}



/***********************
 *                     *
 *       Events        *
 *                     *
 ***********************/

public Action Event_MatchOver(Handle event, const char[] name, bool dontBroadcast) {
    if (g_MatchLive) {
        CreateTimer(15.0, Timer_EndMatch);
        ExecCfg(g_hWarmupCfg);
    }

    // Always make these false, in case the players didn't use the plugin's lo3/start functionality
    // and manually rcon'd the commands.
    g_mapSet = false;
    g_Setup = false;
    g_MatchLive = false;
    g_WaitingForKnifeDecision = false;
    g_WaitingForKnifeWinner = false;

    CreateTimer(15.0, Timer_CheckAutoSetup);
    return Plugin_Continue;
}

/** Helper timer to delay starting warmup period after match is over by a little bit **/
public Action Timer_EndMatch(Handle timer) {
    EndMatch(false);
}

/**
 * Called when a player joins a team, silences team join events during player selection.
 */
public Action Event_PlayerTeam(Handle event, const char[] name, bool dontBroadcast)  {
    if (g_Setup && !g_MatchLive) {
        dontBroadcast = true;
        return Plugin_Changed;
    } else {
        return Plugin_Continue;
    }
}

public Action Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast) {
    int winner = GetEventInt(event, "winner");
    if (g_WaitingForKnifeWinner) {
        g_WaitingForKnifeWinner = false;
        g_WaitingForKnifeDecision = true;
        g_KnifeWinner = winner;

        char teamString[4];
        if (g_KnifeWinner == CS_TEAM_CT)
            teamString = "CT";
        else
            teamString = "T";

        char stayCmd[32];
        char swapCmd[32];
        FindChatCommand("sm_stay", stayCmd, sizeof(stayCmd));
        FindChatCommand("sm_swap", swapCmd, sizeof(swapCmd));

        PugSetupMessageToAll("%t", "KnifeRoundWinner", teamString, stayCmd, swapCmd);
    }
}


/***********************
 *                     *
 *   Pugsetup logic    *
 *                     *
 ***********************/

public void PrintSetupInfo(int client) {
    if (IsPlayer(GetLeader()))
        PugSetupMessage(client, "%t", "SetupBy", GetLeader());

    GiveSetupMenu(client, true);
}

public void ReadyToStart() {
    g_InStartPhase = true;
    Call_StartForward(g_hOnReadyToStart);
    Call_Finish();

    g_CountDownTicks = g_hStartDelay.IntValue;
    CreateTimer(1.0, Timer_CountDown, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_CountDown(Handle timer)  {
    if (!g_Setup) {
        // match cancelled
        PugSetupMessageToAll("%t", "CancelCountdownMessage");
        return Plugin_Stop;
    }

    g_CountDownTicks--;

    if (g_CountDownTicks == 0) {
        StartGame();
        return Plugin_Stop;
    } else if (g_hAnnounceCountdown.IntValue != 0 && (g_CountDownTicks < 5 || g_CountDownTicks % 5 == 0)) {
        PugSetupMessageToAll("%t", "Countdown", g_CountDownTicks);
        return Plugin_Continue;
    }

    return Plugin_Continue;
}

public void StartGame() {
    if (g_RecordGameOption) {
        // get the map, with any workshop stuff before removed
        // this is {MAP} in the format string
        char mapName[128];
        GetCurrentMap(mapName, sizeof(mapName));
        int last_slash = 0;
        int len = strlen(mapName);
        for (int i = 0;  i < len; i++) {
            if (mapName[i] == '/' || mapName[i] == '\\')
                last_slash = i + 1;
        }

        // get the time, this is {TIME} in the format string
        char timeFormat[64];
        g_hDemoTimeFormat.GetString(timeFormat, sizeof(timeFormat));
        int timeStamp = GetTime();
        char formattedTime[64];
        FormatTime(formattedTime, sizeof(formattedTime), timeFormat, timeStamp);

        // get the player count, this is {TEAMSIZE} in the format string
        char playerCount[8];
        IntToString(g_PlayersPerTeam, playerCount, sizeof(playerCount));

        // create the actual demo name to use
        char demoName[256];
        g_hDemoNameFormat.GetString(demoName, sizeof(demoName));

        ReplaceString(demoName, sizeof(demoName), "{MAP}", mapName[last_slash], false);
        ReplaceString(demoName, sizeof(demoName), "{TEAMSIZE}", playerCount, false);
        ReplaceString(demoName, sizeof(demoName), "{TIME}", formattedTime, false);

        Record(demoName);

        LogMessage("Recording to %s", demoName);
        Format(g_DemoFileName, sizeof(g_DemoFileName), "%s.dem", demoName);
        g_Recording = true;
    }

    for (int i = 1; i <= MaxClients; i++) {
        g_PlayerAtStart[i] = IsPlayer(i);
    }

    if (g_TeamType == TeamType_Random) {
        PugSetupMessageToAll("%t", "Scrambling");
        ServerCommand("mp_scrambleteams");
    }

    if (g_DoKnifeRound) {
        ExecGameConfigs();
        CreateTimer(3.0, StartKnifeRound, _, TIMER_FLAG_NO_MAPCHANGE);
    } else {
        ExecGameConfigs();
        CreateTimer(3.0, BeginLO3, _, TIMER_FLAG_NO_MAPCHANGE);
    }

}

public void ExecGameConfigs() {
    if (g_hExecDefaultConfig.IntValue != 0)
        ServerCommand("exec gamemode_competitive");

    ExecCfg(g_hLiveCfg);
}

public void EndMatch(bool execConfigs) {
    if (g_Recording) {
        CreateTimer(4.0, StopDemo, _, TIMER_FLAG_NO_MAPCHANGE);
    } else {
        Call_StartForward(g_hOnMatchOver);
        Call_PushCell(false);
        Call_PushString("");
        Call_Finish();
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
    g_WaitingForKnifeWinner = false;
    g_InStartPhase = false;

    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i))
            UpdateClanTag(i);
    }
}

public ArrayList GetCurrentMapList() {
    if (g_MapList.Length == 0) {
        AddBackupMaps();
    }
    return g_MapList;
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
    g_InStartPhase = true;

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
    g_Teams[g_capt2] = CS_TEAM_CT;

    SwitchPlayerTeam(g_capt1, CS_TEAM_T);
    g_Teams[g_capt1] = CS_TEAM_T;

    InitialChoiceMenu(g_capt1);
    return Plugin_Handled;
}

public Action FinishPicking(Handle timer) {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i)) {
            if (g_Teams[i] == CS_TEAM_NONE) {
                SwitchPlayerTeam(i, CS_TEAM_SPECTATOR);
                Call_StartForward(g_hOnNotPicked);
                Call_PushCell(i);
                Call_Finish();
            } else {
                SwitchPlayerTeam(i, g_Teams[i]);
            }
        }
    }

    ServerCommand("mp_unpause_match");
    ReadyToStart();
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

public Action Timer_CheckAutoSetup(Handle timer) {
    CheckAutoSetup();
    return Plugin_Handled;
}

public void CheckAutoSetup() {
    if (g_hAutoSetup.IntValue != 0 && !g_Setup && !g_ForceEnded && !g_InStartPhase && !g_MatchLive) {
        SetupFinished();
    }
}

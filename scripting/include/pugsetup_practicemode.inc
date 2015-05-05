#if defined _pugsetup_practicemode_included
  #endinput
#endif
#define _pugsetup_practicemode_included

#include "pugsetup.inc"

#define OPTION_NAME_LENGTH 128 // max length of a setting name/id
#define CVAR_NAME_LENGTH 64 // max length of a cvar
#define CVAR_VALUE_LENGTH 128 // max length of a cvar value

/**
 * Called when practice mode is enabled.
 */
forward void OnPracticeModeEnabled();

/**
 * Called when practice mode is disabled.
 */
forward void OnPracticeModeDisabled();

/**
 * Called after practice mode reads its setting config file.
 */
forward void OnPracticeModeSettingsRead();

/**
 * Called when a client saves a grenade position.
 *
 * @return Plugin_Handled or a higher action to block the save.
 */
forward Action OnGrenadeSaved(int client, const float origin[3], const float angle[3], const char[] name);

/**
 * Called when a practice mode setting is changed.
 */
forward void OnPracticeModeSettingChanged(int settingNumber, const char[] settingId, const char[] displayName, bool enabled);

/**
 * Adds a new setting to practice mode.
 * @note The practicemode plugin will take over ownership of the enabledCvars and enabledValues arrays.
 * @return the settingNumber value for the new setting.
 */
native int AddPracticeModeSetting(const char[] settingId, const char[] name,
                                  ArrayList enabledCvars, ArrayList enabledValues,
                                  bool defaultEnabled=false, bool changeable=true);

/**
 * Returns if practice mode is enabled.
 */
native bool IsPracticeModeEnabled();

/**
 * Returns if a practice mode setting is currently enabled.
 */
native bool IsPracticeModeSettingEnabled(int settingNumber);

public SharedPlugin __pl_pugsetup_practicemode = {
    name = "pugsetup_practicemode",
    file = "pugsetup_practicemode.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_pugsetup_SetNTVOptional() {
    MarkNativeAsOptional("AddPracticeModeSetting");
    MarkNativeAsOptional("IsPracticeModeEnabled");
    MarkNativeAsOptional("IsPracticeModeSettingEnabled");
}
#endif

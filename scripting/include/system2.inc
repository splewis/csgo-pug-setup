#if defined _system2_included
	#endinput
#endif

#define _system2_included






// Max Size of the Command Output.
#define CMD_MAX_RETURN 4096







/**
 * A list of operating systems.
 */
enum OS
{
	OS_UNKNOWN,		// Shouldn't happen
	OS_WINDOWS,		// Windows
	OS_UNIX,		// Linux/Unix
	OS_MAC 			// MAC
}




/**
 * A list of possible cmd return statuses
 */
enum CMDReturn
{
	CMD_SUCCESS,		// Fully finished
	CMD_EMPTY,		// Result is empty (only System2_RunThreadCommand)
	CMD_ERROR,		// An error appeared
	CMD_PROGRESS		// Not finished yet
}




/**
 * A list of possible archives
 */
enum CompressArchive
{
	ARCHIVE_ZIP,		// Zip
	ARCHIVE_7Z,		// 7 Zip
	ARCHIVE_GZIP,
	ARCHIVE_BZIP2,
	ARCHIVE_TAR
}




/**
 * A list of possible compress levels
 */
enum CompressLevel
{
	LEVEL_1,		// Weekest
	LEVEL_3,
	LEVEL_5,
	LEVEL_7,
	LEVEL_9			// Strongest
}









/**
 * Called when finished with a command.
 * Maybe called more than once, if output > 4096.
 * Use status to check if last call or not.
 *
 * @param output				Output of the command/page.
 * @param size					Size of output string.
 * @param status				CMDReturn status
 * @param data					Data passed
 */
funcenum CmdCallback
{
	public(const String:output[], const size, CMDReturn:status, any:data),

	public(const String:output[], const size, CMDReturn:status)
};







/**
 * Called on every update when downloading/uploading a file.
 *
 * @param finished				Is downloading / uploading finished?
 * @param error					Error when finished. If no error string is empty.
 * @param dltotal				Download size total in bytes.
 * @param dlnow					Current download size in bytes.
 * @param ultotal				Upload size total in bytes.
 * @param ulnow					Current upload size in bytes.
 * @param data					Data passed
 */
funcenum TransferUpdated
{
	public(bool:finished, const String:error[], Float:dltotal, Float:dlnow, Float:ultotal, Float:ulnow, any:data),

	public(bool:finished, const String:error[], Float:dltotal, Float:dlnow, Float:ultotal, Float:ulnow)
};








/**
 * Called when finished with System2_CopyFile.
 *
 * @param success				Was copying successfull? (Or couldn't open current or new file)
 * @param from					File which was copied
 * @param to					New file
 * @param data					Data passed
 */
funcenum CopyCallback 
{
	public(bool:success, String:from[], String:to[], any:data),

	public(bool:success, String:from[], String:to[])
};










/**
 * Gets the content of a page
 *
 * @param callback				Callback function.
 * @param URL					Page URL.
 * @param POST					POST parameters (use like this: "name=test&pw=test2")
 * @param useragent				Useragent to use. Leave empty for default one.
 */
native System2_GetPage(CmdCallback:callback, const String:URL[], const String:POST[] = "", const String:useragent[] = "", any:data = INVALID_HANDLE);







/**
 * Downloads a file from a site.
 *
 * @param updateFunction			Function to call on update.
 * @param URL					Download URL.
 * @param localFile				Local file to save to.
 */
native System2_DownloadFile(TransferUpdated:updateFunction, const String:URL[], const String:localFile[], any:data = INVALID_HANDLE);







/**
 * Downloads a file from a FTP server.
 *
 * @param updateFunction			Function to call on update.
 * @param remoteFile				Path to the file on the FTP server.
 * @param localFile				Local file to save to.
 * @param host					The FTP host.
 * @param user					The FTP username.
 * @param pass					The FTP password.
 * @param port					The FTP port (Default: 21).
 */
native System2_DownloadFTPFile(TransferUpdated:updateFunction, const String:remoteFile[], const String:localFile[], const String:host[], const String:user[] = "", const String:pass[] = "", port = 21, any:data = INVALID_HANDLE);







/**
 * Uploads a file to a FTP server.
 *
 * @param updateFunction			Function to call on update.
 * @param localFile				Local file to upload.
 * @param remoteFile				Path to the file on the FTP server.
 * @param host					The FTP host.
 * @param user					The FTP username.
 * @param pass					The FTP password.
 * @param port					The FTP port (Default: 21).
 */
native System2_UploadFTPFile(TransferUpdated:updateFunction, const String:localFile[], const String:remoteFile[], const String:host[], const String:user[] = "", const String:pass[] = "", port = 21, any:data = INVALID_HANDLE);







/**
 * Copies a file
 *
 * @param callback				Callback function.
 * @param pathToFile				Path to the file
 * @param pathToCopy				Path to copy to (including filename).
 *
 * @noreturn
 */
native System2_CopyFile(CopyCallback:callback, const String:pathToFile[], const String:pathToCopy[], any:data = INVALID_HANDLE);







/**
 * Compresses a file to a archive
 *
 * @param callback				Callback function.
 * @param pathToFile				Path to the file/folder to compress.
 * @param pathToCompress			Path to archive file.
 * @param archive				Archive typ
 * @param level					Archive compress level
 *
 * @noreturn
 */
native System2_CompressFile(CmdCallback:callback, const String:pathToFile[], const String:pathToArchive[], CompressArchive:archive = ARCHIVE_ZIP, CompressLevel:level = LEVEL_9, any:data = INVALID_HANDLE);






/**
 * Extracts a lot of archives with 7zip
 *
 * @param callback				Callback function.
 * @param pathToArchive				Path to the archive file.
 * @param pathToExtract				Path to extract to.
 *
 * @noreturn
 */
native System2_ExtractArchive(CmdCallback:callback, const String:pathToArchive[], const String:pathToExtract[], any:data = INVALID_HANDLE);







/**
 * Executes a threaded system command
 *
 * @param callback				Callback function.
 * @param command				Command string format
 * @param ...					Command string arguments.
 *
 * @noreturn
 */
native System2_RunThreadCommand(CmdCallback:callback, const String:command[], any:...);

// Backwards Compatiblity
native RunThreadCommand(CmdCallback:callback, const String:command[], any:...);







/**
 * Executes a non threaded system command
 *
 * @param output				Output variable
 * @param size					Size of the output variable
 * @param command				Command string format
 * @param ...					Command string arguments.
 *
 * @return					CMDReturn var
 */
native CMDReturn:System2_RunCommand(String:output[], size, const String:command[], any:...);

// Backwards Compatiblity
native CMDReturn:RunCommand(String:output[], size, const String:command[], any:...);







/**
 * Gets the absolute gamedir (e.g. /home/.../.../cstrike)
 *
 * @param gamedir				String to save gamedir in.
 * @param maxlength				Size of the string.
 *
 * @noreturn
 */
native System2_GetGameDir(String:gamedir[], maxlength);

// Backwards Compatiblity
native GetGameDir(String:gamedir[], maxlength);







/**
 * Gets the servers operating system
 *
 * @return					OS_UNKNOWN, OS_WINDOWS, OS_UNIX, OS_MAC
 */
native OS:System2_GetOS();

// Backwards Compatiblity
native OS:GetOS();









public Extension:__ext_system2 =
{
	name = "System2",
	file = "system2.ext",

	#if defined AUTOLOAD_EXTENSIONS
		autoload = 1,
	#else
		autoload = 0,
	#endif

	#if defined REQUIRE_EXTENSIONS
		required = 1,
	#else
		required = 0,
	#endif
};



#if !defined REQUIRE_EXTENSIONS

	public __ext_system2_SetNTVOptional()
	{
		MarkNativeAsOptional("System2_GetPage");
		MarkNativeAsOptional("System2_CompressFile");
		MarkNativeAsOptional("System2_ExtractArchive");
		MarkNativeAsOptional("System2_DownloadFile");
		MarkNativeAsOptional("System2_DownloadFTPFile");
		MarkNativeAsOptional("System2_UploadFTPFile");
		MarkNativeAsOptional("System2_RunThreadCommand");
		MarkNativeAsOptional("System2_RunCommand");
		MarkNativeAsOptional("System2_GetGameDir");
		MarkNativeAsOptional("System2_GetOS");

		// Backwarts Compatiblity
		MarkNativeAsOptional("RunThreadCommand");
		MarkNativeAsOptional("RunCommand");
		MarkNativeAsOptional("GetGameDir");
		MarkNativeAsOptional("GetOS");
	}

#endif
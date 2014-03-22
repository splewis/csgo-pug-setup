brush
=====

BRush (or B Rush) is a custom mod for Counter Strike: Global Offensive in which players
try to attack the B bombsite only, typically with 5 attackers and 3 defenders that rotate sides
depending on who wins the round. It is often used for practice or warmup.

This is a work in progress for help maintaining a CS:GO Brush server, it includes both:
  - the BRush plugin and config files
  - config files for other useful plugins for my own Brush server(s)


### Building
The build process is managed by the Makefile.

		make          # builds the .smx file
		make clean    # clears .smx files, .zip files
		make package  # packages the essential plugin things into brush-plugin and all server files to brush-all

Note: any .zip files in GitHub's "downloads" section may also include other plugin binaries that are not built when running the makefile commands.


### Installation
If you only want the plugin, either download brush-plugin.zip or build it yourself.
It should contain the plugin binary, the translation files, and the default config file.
Extract all 3 to the appropriate folders.

Recommended plugins to also use:
  - Weapon-restrict http://forums.alliedmods.net/showthread.php?p=950174
  - Anti-rush https://forums.alliedmods.net/showthread.php?p=1433894
  - Very Basic High Ping Kicker https://forums.alliedmods.net/showthread.php?p=769939
  - AFK Manager https://forums.alliedmods.net/showthread.php?p=708265
  - Advertisements https://forums.alliedmods.net/showthread.php?t=155705
  - Player report https://forums.alliedmods.net/showthread.php?t=189586
  - SourceMod Anti-Cheat (SMAC)

Config files are included for many of these plugins in this repo. Of course, you're free to use your own.
I'd strongly suggest starting from my anti-rush config files if you are setting up a BRush server, however!


### Thanks to
This plugin is only possible thanks to TnTSCS from alliedmods.net's forums.
His CS:S version of the plugin is at https://forums.alliedmods.net/showthread.php?t=175331.
This plugin is heavily based upon it.

#include <sourcemod>
#include <Helper-amuBans-->

#pragma newdecls required
#pragma semicolon 1

ConVar g_cvServerIP
		 , g_cvServerPort;

char g_szServerIP[24]
	 , g_szServerPort[7];
	 , g_szLogPath[256];

// we compare these to steamid later...
bool g_bIsMuted[MAXPLAYERS+1]
	 , g_bIsGaged[MAXPLAYERS+1]
	 , g_bIsBanned[MAXPLAYERS+1];

int g_iAdmin[MAXPLAYERS+1]
	, g_iVictim[MAXPLAYERS+1]
	, g_iPunishTime[MAXPLAYERS+1];

Handle g_hPunishedDatabase = INVALID_HANDLE;

char sql_createPunishmentDB[] = "CREATE TABLE IF NOT EXISTS punishedlist (steamid VARCHAR(32), name VARCHAR(32), )"):


public Plugin myinfo = {
	name = "amuBans-- Main module",
	author = "hiiamu",
	description = "sum bitch ass niga shit",
	version = "0.1.0",
	url = "/id/hiiamu/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	CreateNative("AB_IsBanned", Native_IsBanned);
	CreateNative("AB_BanClient", Native_BanClient);
	CreateNative("AB_UnBanClient", Native_UnBanClient);
	CreateNative("AB_GetBanType", Native_GetBanType);
	CreateNative("AB_IsMuted", Native_IsMuted);
	CreateNative("AB_MuteClient", Native_MuteClient);
	CreateNative("AB_UnMuteClient", Native_UnMuteClient);
	CreateNative("AB_GetMuteType", Native_GetMuteType);
	CreateNative("AB_IsGaged", Native_IsGaged);
	CreateNative("AB_GagClient", Native_GagClient);
	CreateNative("AB_UnGagClient", Native_UnGagClient);
	CreateNative("AB_GetGagType", Native_GetGagType);

	RegPluginLibrary("amuBans--");
	return APLRes_Success;
}

public void OnPluginStart() {
	g_cvServerIP = FindConVar("hostip");
	g_cvServerPort = FindConVar("hostport");

	RegAdminCmd("sm_ban", Admin_Ban, ADMFLAG_BAN, "thing", "amuBans--");
	RegAdminCmd("sm_addban", Admin_Ban, ADMFLAG_BAN, "thing", "amuBans--");
	RegAdminCmd("sm_unban", Admin_Ban, ADMFLAG_BAN, "thing", "amuBans--");
	RegAdminCmd("sm_checkbans", Admin_Ban, ADMFLAG_GENERIC, "thing", "amuBans--");


	BuildPath(Path_SM, g_szLogPath, PLATFORM_MAX_PATH, "logs/amuBans--.log");
}

public void OnConfigsExecuted() {
	char filename[200];
	BuildPath(Path_SM, filename, sizeof(filename), "plugins/basebans.smx");
	if(FileExists(filename)) {
		char newfilename[200];
		BuildPath(Path_SM, newfilename, sizeof(newfilename), "plugins/disabled/basebans.smx");
		ServerCommand("sm plugins unload basebans");
		if(FileExists(newfilename))
			DeleteFile(newfilename);
		RenameFile(newfilename, filename);
	}
}





public int Native_IsBanned(Handle plugin, int numParams) {
	int client = GetNativeCell(1);

	char szSteamID[128];
	// get steamid from client index
	//szSteamID =


}

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

char sql_createPunishmentDB[] = "CREATE TABLE IF NOT EXISTS punishedlist (steamid VARCHAR(64), userip VARCHAR(64), name VARCHAR(32), banreason VARCHAR(128), bantime INT(64), banlength INT(16), mutereason VARCHAR(128), mutetime INT(64), mutelength INT(16), gagreason VARCHAR(128), gagtime INT(64), gaglength INT(16), PRIMARY KEY(steamid));"
	// bans
	 , sql_insertPlayerBan[] = "INSERT INTO punishedlist (steamid, userip, name, banreason, bantime, banlength) VALUES('%s', '%s', '%s', '%s', '%i', '%i');"
	 , sql_updatePlayerBan[] = "UPDATE punishedlist SET userip='%s', name='%s', banreason='%s', bantime='%i', banlength='%i' WHERE steamid = '%s';"
	 , sql_checkPlayerBan[] = "SELECT steamid, userip, name, banreason, bantime, banlength, FROM punishedlist WHERE steamid='%s';"
	 , sql_removePlayerBan[] = "UPDATE punishedlist SET banlength='-1' WHERE steamid='%s';"
	// mutes
	 , sql_insertPlayerMute[] = "INSERT INTO punishedlist (steamid, userip, name, mutereason, mutetime, mutelength) VALUES('%s', '%s', '%s', '%s', '%i', '%i');"
	 , sql_updatePlayerMute[] = "UPDATE punishedlist SET userip='%s', name='%s', mutereason='%s', mutetime='%i', mutelength='%i' WHERE steamid = '%s';"
	 , sql_checkPlayerMute[] = "SELECT steamid, userip, name, mutereason, mutetime, mutelength, FROM punishedlist WHERE steamid='%s';"
	 , sql_removePlayerMute[] = "UPDATE punishedlist SET mutelength='-1' WHERE steamid='%s';"
	// gags
	 , sql_insertPlayerGag[] = "INSERT INTO punishedlist (steamid, userip, name, gagreason, gagtime, gaglength) VALUES('%s', '%s', '%s', '%s', '%i', '%i');"
	 , sql_updatePlayerGag[] = "UPDATE punishedlist SET userip='%s', name='%s', gagreason='%s', gagtime='%i', gaglength='%i' WHERE steamid = '%s';"
	 , sql_checkPlayerGag[] = "SELECT steamid, userip, name, gagreason, gagtime, gaglength, FROM punishedlist WHERE steamid='%s';"
	 , sql_removePlayerGag[] = "UPDATE punishedlist SET gaglength='-1' WHERE steamid='%s';";


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
	SetupDatabase();

	g_cvServerIP = FindConVar("hostip");
	g_cvServerPort = FindConVar("hostport");

	RegAdminCmd("sm_ban", Admin_BAN, ADMFLAG_BAN, "add ban to sql");
	RegAdminCmd("sm_addban", Admin_AddBan, ADMFLAG_BAN, "add ban to sql with steamid");
	RegAdminCmd("sm_unban", Admin_UnBan, ADMFLAG_BAN, "remove ban from sql");
	RegAdminCmd("sm_checkbans", Admin_CheckBan, ADMFLAG_GENERIC, "check previous bans from sql");

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

public void OnClientPostAdminCheck(int client) {
	if(!IsValidClient(client))
		return;
	if(AC_IsBanned(client)) {
		char szReason[256];
		// Get reason from SQL check and log to global
		Format(szReason, 256, "");
		KickClient(client, szReason);
	}
	return;
}

public SetupDatabase() {
	char szError[256];
	g_hPunishedDatabase = SQL_Connect("amuBans--", false, szError, 256);
	if(g_hPunishedDatabase == INVALID_HANDLE) {
		SetFailState("[amuBans--] Unable to connect to database - %s", szError);
		return;
	}
	SQL_LockDatabase(g_hPunishedDatabase);
	SQL_FastQuery(g_hPunishedDatabase, sql_createPunishmentDB);
	SQL_UnlockDatabase(g_hPunishedDatabase);
}

void CheckArgs(int client, ) {
	
}

public Action Admin_BAN(int client int args) {
	szTarget[32];
	szBanDur[32];
	szReason[32];

	GetCmdArg(1, szTarget, 32);
	GetCmdArg(2, szBanDur, 32);
	GetCmdArg(3, szReason, 32);

	if(szTarget == '\0') {
		ReplyToCommand(client, "You must specify target. Command example: sm_ban hiiamu 3d \"Heh gey\"");
		return Plugin_Handled;
	}
	if(szBanDur == '\0') {
		ReplyToCommand(client, "You must specify duration. Command example: sm_ban hiiamu 3d \"Heh gey\"");
		return Plugin_Handled;
	}
	if(szReason == '\0') {
		ReplyToCommand(client, "You must specify reason. Command example: sm_ban hiiamu 3d \"Heh gey\"");
		return Plugin_Handled;
	}

	int iTemp;
	for(int i = 0; i <= 32; i++) {
		if(szBanDur[i] == '\0') {
			iTemp = i;
			i = 33;
		}
	}

	char szTimeType[8] = szBanDur[iTemp];
	szBanDur[iTemp] = '\0';
	int iBanDur = -1;
	if(szTimeType[0] == "d")
		// change time to minutes
		iBanDur = (StringToInt(szTimeType) * 1440);
	else if(szTimeType[0] == "m")
		// change time to minutes
		iBanDur = (StringToInt(szTimeType) * 43800);
	else if(szTimeType[0] == "y")
		// change time to minutes
		iBanDur = (StringToInt(szTimeType) * 525600);
	else
		// time is already minutes
		iBanDur = StringToInt(szTimeType);

	int iTarget = FindTarget(client, szTarget);
	char szTargetID[128];
	GetClientAuthId(iTarget, AuthId_SteamID64, szTargetID, 128);
	int iTargetIP = GetClientIP(iTarget);
	int iCurrentTime = GetTime();

	AB_BanClient(szTargetID, iTargetIP, iCurrentTime, iBanDur, szReason);
}

public Action Admin_AddBan(int client, int args) {
	szTargetID[32];
	szBanDur[32];
	szReason[32];

	GetCmdArg(1, szTargetID, 32);
	GetCmdArg(2, szBanDur, 32);
	GetCmdArg(3, szReason, 32);

	if(szTargetID == '\0') {
		ReplyToCommand(client, "You must specify target. Command example: sm_ban 76561198383391535 3d \"Heh gey\"");
		return Plugin_Handled;
	}
	if(szBanDur == '\0') {
		ReplyToCommand(client, "You must specify duration. Command example: sm_ban 76561198383391535 3d \"Heh gey\"");
		return Plugin_Handled;
	}
	if(szReason == '\0') {
		ReplyToCommand(client, "You must specify reason. Command example: sm_ban 76561198383391535 3d \"Heh gey\"");
		return Plugin_Handled;
	}

	int iTemp;
	for(int i = 0; i <= 32; i++) {
		if(szBanDur[i] == '\0') {
			iTemp = i--; // might not sub 1 from i first?
			i = 33;
		}
	}

	char szTimeType[8] = szBanDur[iTemp];
	szBanDur[iTemp] = '\0';
	int iBanDur = -1;
	if(szTimeType[0] == "d") // Days
		// change time to minutes
		iBanDur = (StringToInt(szBanDur) * 1440);
	else if(szTimeType[0] == "m") // Months
		// change time to minutes
		iBanDur = (StringToInt(szBanDur) * 43800);
	else if(szTimeType[0] == "y") // Years
		// change time to minutes
		iBanDur = (StringToInt(szBanDur) * 525600);
	else if(szTimeType[0] == "p")
		// set time to 100 years (perm)
		iBanDur = 52560000;
	else if(szTimeType[0] == "0" || "1" || "2" || "3" || "4" ||
													 "5" || "6" || "7" || "8" || "9")
		// time is already minutes
		iBanDur = StringToInt(szTimeType);
	else if(szTimeType[0] != "d" && szTimeType[0] != "m" &&
					szTimeType[0] != "y" && szTimeType[0] != "p") {
		ReplyToCommand(client, "Incorrect formatting on time, ex \"30\" for 30 minutes, \"3d\" for 3 days, \"3m\" for 3 months, \"p\" for perm");
		return Plugin_Handled;
	}

	// check the string wasnt bad
	// if there were multiple chars bandur is 0
	if(iBanDur == 0) {
		ReplyToCommand(client, "Time must be valid, ex \"30\" for 30 minutes, \"3d\" for 3 days, \"3m\" for 3 months, \"p\" for perm");
		return Plugin_Handled;
	}

	// get client ip from steamid stored in sql tabel
	// TODO erik
	int iCurrentTime = GetTime();

	AB_BanClient(szTargetID, iTargetIP, iCurrentTime, iBanDur, szReason);
}

public Action Admin_UnBan(int client, int args) {

}

public Action Admin_CheckBan(int client, int args) {

}

// TODO update this to steamid instead of client id idk why stupid me
// maybe idk i cant think now it seems right but kinda maybe not?
public int Native_IsBanned(Handle plugin, int numParams) {
	int client = GetNativeCell(1);

	char szQuery[256];
	Format(szQuery, 256, sql_checkPlayerBan, szSteamID);
	SQL_TQuery(g_hPunishedDatabase, SQL_ViewPlayerBans, szQuery, client, DBPrio_Normal);

	if(g_bIsBanned[client])
		return true;

	return false;
}

public int Native_BanClient(Handle plugin, int numParams) {

}

public int Native_UnBanClient(Handle plugin, int numParams) {

}

public int Native_GetBanType(Handle plugin, int numParams) {

}

public int Native_IsMuted(Handle plugin, int numParams) {

}

public int Native_MuteClient(Handle plugin, int numParams) {

}

public int Native_UnMuteClient(Handle plugin, int numParams) {

}

public int Native_GetMuteType(Handle plugin, int numParams) {

}

public int Native_IsGaged(Handle plugin, int numParams) {

}

public int Native_GagClient(Handle plugin, int numParams) {

}

public int Native_UnGagClient(Handle plugin, int numParams) {

}

public int Native_GetGagType(Handle plugin, int numParams) {

}

/////////////////
/// start SQL ///
/////////////////
public SQL_ViewPlayerBans(Handle owner, Handle hndl, const char[] error, any data) {
	int client = data;
	if(SQL_HasResultSet(hndl) && SQL_FetchRow(hndl)) {
		char szSteamID[128];
		char szUserIP[64];
		char szName[MAX_NAME_LENGTH];
		char szReason[256];

		SQL_FetchString(hndl, 0, szSteamID, 128);
		SQL_FetchString(hndl, 1, szUserIP, 64);
		SQL_FetchString(hndl, 2, szName, MAX_NAME_LENGTH);
		SQL_FetchString(hndl, 3, szReason, 256);
		int iTime = SQL_FetchInt(hndl, 4);
		int iLength = SQL_FetchInt(hndl, 5);

		// still banned
		if(GetTime() <= (iTime + iLength)) {
			char szClientID[128];
			GetClientAuthId(client, AuthId_SteamID64, szSteamID, 128);
			char[] szClientIP = new char[64];
			GetClientIP(client, szClientIP, 64);

			if(szClientID == szSteamID && szClientIP != szUserIP) {
				// creat new ban with different ip
			}
			if(szClientID != szSteamID && szClientIP == szUserIP) {
				// create new ban with different id
			}
			g_bIsBanned[client] = true;
		}
		else {
			g_bIsBanned[client] = false;
		}
	}
}


/////////////////
//// end SQL ////
/////////////////
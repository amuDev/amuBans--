#include <sourcemod>
#include <Helper-amuBans-->

#pragma newdecls required
#pragma semicolon 1

ConVar g_cvServerIP
		 , g_cvServerPort;

char g_szServerIP[24]
	 , g_szServerPort[7]
	 , g_szLogPath[256]
	 , g_szTargetID[128]
	 , g_szReason[256];

bool g_bIsBanned[MAXPLAYERS+1]
	 , g_bIsMuted[MAXPLAYERS+1]
	 , g_bIsGaged[MAXPLAYERS+1]
	 , g_bIsSilenced[MAXPLAYERS+1]
	 , g_bGoodCommand[MAXPLAYERS+1];

int g_iPunishTime
	, g_iTargetIP
	, g_iPunishDur;

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
	// TODO maybe remove natives?
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

// bans
	RegAdminCmd("sm_ban", Admin_BAN, ADMFLAG_BAN, "Add ban to sql");
	RegAdminCmd("sm_addban", Admin_AddBan, ADMFLAG_BAN, "Add ban to sql with steamid");
	RegAdminCmd("sm_unban", Admin_UnBan, ADMFLAG_BAN, "Remove ban from sql");
// mutes
	RegAdminCmd("sm_mute", Admin_Mute, ADMFLAG_BAN, "Add mute to sql");
  RegAdminCmd("sm_addmute", Admin_AddMute, ADMFLAG_BAN, "Add mute to sql with steamid");
  RegAdminCmd("sm_unmute", Admin_UnMute, ADMFLAG_BAN, "Remove mute from sql")
// gags
  RegAdminCmd("sm_gag", Admin_Gag, ADMFLAG_BAN, "Add gag to sql");
  RegAdminCmd("sm_addgag", Admin_AddGag, ADMFLAG_BAN, "Add gag to sql with steamid");
  RegAdminCmd("sm_ungag", Admin_UnGag, ADMFLAG_BAN, "Remove gag from sql")
// silences
  RegAdminCmd("sm_silence", Admin_Silence, ADMFLAG_BAN, "Add silence to sql");
  RegAdminCmd("sm_addsilence", Admin_AddSilence, ADMFLAG_BAN, "Add silence to sql with steamid");
  RegAdminCmd("sm_unsilence", Admin_UnSilence, ADMFLAG_BAN, "Remove silence from sql")

	RegAdminCmd("sm_checkbans", Admin_CheckBans, ADMFLAG_GENERIC, "Check active punishments from sql");

// mute and gags
	RegConsoleCmd("say", Client_Say);
	RegConsoleCmd("say_team", Client_Say);

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
	// TODO add new check here or something
	char szClientID[128];
	GetClientAuthId(client, AuthId_SteamID64, szClientID, 128);
	if(IsBanned(szClientID))
		KickClient(client, g_szReason);

	if(IsMuted(szClientID)) {
		// client id wont change when client is connected
		g_bIsMuted[client] = true;
		SetClientListeningFlags(client, VOICE_MUTED);
	}
	if(IsGaged(szClientID))
		// client id wont change when client is connected
		g_bIsGaged[client] = true;
	if(IsSilenced(szClientID))
		// client id wont change when client is connected
		g_bIsSilenced[client] = true;

	return;
}

public void OnClientDisconnect(int client) {
	SetClientListeningFlags(client, VOICE_NORMAL);
	g_bIsBanned[client] = false;
	g_bIsMuted[client] = false;
	g_bIsGaged[client] = false;
	g_bIsSilenced[client] = false;

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

void CheckArgs(char szTarget[128], char szDur[32], char szReason[256]) {
	int iTarget = FindTarget(client, szTarget);
	char szTargetID[128];
	GetClientAuthId(iTarget, AuthId_SteamID64, szTargetID, 128);

	if(szTargetID == '\0') {
		PrintToChat(client, "You must specify target. Command example: sm_ban <name or steamid64> <time (3d)> \"<reason in quotes>\"");
		return;
	}
	if(szDur == '\0') {
		PrintToChat(client, "You must specify duration. Command example: sm_ban <name or steamid64> <time (3d)> \"<reason in quotes>\"");
		return;
	}
	if(szReason == '\0') {
		PrintToChat(client, "You must specify reason. Command example: sm_ban <name or steamid64> <time (3d)> \"<reason in quotes>\"");
		return;
	}

	int iTemp;
	for(int i = 0; i <= 32; i++) {
		if(szDur[i] == '\0') { // find last char to check
			iTemp = --i; // might not sub 1 from i first?
			i = 33; // stop the loop
		}
	}

	char szTimeType[2] = szDur[iTemp];
	if(szTimeType[0] != "0" || "1" || "2" || "3" || "4" || "5" || "6" || "7" || "8" || "9")
		szDur[iTemp] = '\0'; // remove the char from string

	int iDur = -1;

	if(szTimeType[0] == "d") // Days
		// change time to minutes
		iDur = (StringToInt(szDur) * 1440);
	else if(szTimeType[0] == "m") // Months
		// change time to minutes
		iDur = (StringToInt(szDur) * 43800);
	else if(szTimeType[0] == "y") // Years
		// change time to minutes
		iDur = (StringToInt(szDur) * 525600);
	else if(szTimeType[0] == "p") // Perm
		// set time to 100 years (perm)
		iDur = 52560000;
	else if(szTimeType[0] == "0" || "1" || "2" || "3" || "4" || "5" || "6" || "7" || "8" || "9")
		// time is already minutes
		iDur = StringToInt(szTimeType);
	else if(szTimeType[0] != "d" && szTimeType[0] != "m" && szTimeType[0] != "y" && szTimeType[0] != "p") {
		PrintToChat(client, "Incorrect formatting on time, ex \"30\" for 30 minutes, \"3d\" for 3 days, \"3m\" for 3 months, \"p\" for perm");
		return;
	}

	// check the string wasnt bad
	// if there were multiple chars bandur is 0
	if(iDur == 0) {
		PrintToChat(client, "Time must be valid, ex \"30\" for 30 minutes, \"3d\" for 3 days, \"3m\" for 3 months, \"p\" for perm");
		return;
	}

	g_bGoodCommand[client] = true;

	// set globals
	g_iPunishTime = GetTime();
	g_iTargetIP = ;// TODO erik get ip from steamid
	g_iPunishDur = iDur;
	g_szReason = szReason;
	g_szTargetID = szTargetID;

	return;
}

void RemoveClientBan(int client, char szTargetID[128]) {
	// TODO erik
	// add sql to remove steamid's table
	// we still keep all bans on site though

	return;
}

void CheckPunishments(char szTargetID[128]) {
	// TODO erik?
	// check all sql, bans, mutes, and gags
	// for any active punishments

	return; 
}

bool IsBanned(char iTargetID) {

}

bool IsMuted(char iTargetID) {

}

bool IsGaged(char iTargetID) {

}

bool IsSilenced(char iTargetID) {
	
}

public Action Client_Say(int client, int args) {
	if(g_bIsGaged[client]) {
		// Get remaning time from SQL
		// add timer so we dont have tons of sql querys from some guy spamming
		//PrintToChat(client, "Sorry, you are not allowed to chat, you can chat again in %i minutes");
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action Admin_BAN(int client int args) {
	szTarget[128];
	szBanDur[32];
	szReason[256];

	GetCmdArg(1, szTarget, 128);
	GetCmdArg(2, szBanDur, 32);
	GetCmdArg(3, szReason, 256);

	g_bGoodCommand[client] = false;

	CheckArgs(szTarget, szBanDur, szReason);

	char szAdminID[128];
	GetClientAuthId(client, szAdminID, 128);

	int iTarget = FindTarget(client, szTarget);
	// get client ip from steamid stored in sql tabel
	// TODO erik
	int iTargetIP = GetClientIP(iTarget);

	if(g_bGoodCommand[client])
		BanClientID(szAdminID, g_szTargetID, iTargetIP, g_iPunishTime, g_iPunishDur, g_szReason);

	return Plugin_Handled;
}

public Action Admin_AddBan(int client, int args) {
	szTarget[128];
	szBanDur[32];
	szReason[256];

	GetCmdArg(1, szTarget, 128);
	GetCmdArg(2, szBanDur, 32);
	GetCmdArg(3, szReason, 256);

	g_bGoodCommand[client] = false;

	CheckArgs(szTarget, szBanDur, szReason);

	char szAdminID[128];
	GetClientAuthId(client, szAdminID, 128);

	int iTarget = FindTarget(client, szTarget);
	// get client ip from steamid stored in sql tabel
	// TODO erik
	int iTargetIP = GetClientIP(iTarget);
	int iCurrentTime = GetTime();

	if(g_bGoodCommand[client])
		BanClientID(szAdminID, g_szTargetID, iTargetIP, g_iPunishTime, g_iPunishDur, g_szReason);

	return Plugin_Handled;
}

public Action Admin_UnBan(int client, int args) {
	if(args < 1) {
		ReplyToCommand(client, "You must specify player steamid64");
		return Plugin_Handled;
	}

	szTargetID[128];
	GetCmdArg(1, szTargetID, 128);

	RemoveClientBan(client, szTargetID);

	return Plugin_Handled;
}

public Action Admin_Mute(int client, int args) {
	szTarget[128];
	szMuteDur[32];
	szReason[256];

	GetCmdArg(1, szTarget, 128);
	GetCmdArg(2, szMuteDur, 32);
	GetCmdArg(3, szReason, 256);

	g_bGoodCommand[client] = false;

	CheckArgs(szTarget, szMuteDur, szReason);

	char szAdminID[128];
	GetClientAuthId(client, szAdminID, 128);

	int iTarget = FindTarget(client, szTarget);
	// get client ip from steamid stored in sql tabel
	// TODO erik
	int iTargetIP = GetClientIP(iTarget);

	if(g_bGoodCommand[client])
		MuteClientID(szAdminID, g_szTargetID, iTargetIP, g_iPunishTime, g_iPunishDur, g_szReason);

	return Plugin_Handled;
}

public Action Admin_AddMute(int client, int args) {
	szTarget[128];
	szMuteDur[32];
	szReason[256];

	GetCmdArg(1, szTarget, 128);
	GetCmdArg(2, szMuteDur, 32);
	GetCmdArg(3, szReason, 256);

	g_bGoodCommand[client] = false;

	CheckArgs(szTarget, szMuteDur, szReason);

	char szAdminID[128];
	GetClientAuthId(client, szAdminID, 128);

	int iTarget = FindTarget(client, szTarget);
	char szTargetID[128];
	GetClientAuthId(iTarget, AuthId_SteamID64, szTargetID, 128);
	// get client ip from steamid stored in sql tabel
	// TODO erik
	int iTargetIP = GetClientIP(iTarget);

	if(g_bGoodCommand[client])
		MuteClientID(szAdminID, g_szTargetID, iTargetIP, g_iPunishTime, g_iPunishDur, g_szReason);

	return Plugin_Handled;
}

public Action Admin_UnMute(int client, int args) {
	if(args < 1) {
		ReplyToCommand(client, "You must specify player steamid64");
		return Plugin_Handled;
	}

	szTargetID[128];
	GetCmdArg(1, szTargetID, 128);

	RemoveClientMute(client, szTargetID);

	return Plugin_Handled;
}

public Action Admin_Gag(int client, int args) {
	szTarget[128];
	szGagDur[32];
	szReason[256];

	GetCmdArg(1, szTarget, 128);
	GetCmdArg(2, szGagDur, 32);
	GetCmdArg(3, szReason, 256);

	g_bGoodCommand[client] = false;

	CheckArgs(szTarget, szGagDur, szReason);

	char szAdminID[128];
	GetClientAuthId(client, szAdminID, 128);

	int iTarget = FindTarget(client, szTarget);
	char szTargetID[128];
	GetClientAuthId(iTarget, AuthId_SteamID64, szTargetID, 128);
	// get client ip from steamid stored in sql tabel
	// TODO erik
	int iTargetIP = GetClientIP(iTarget);

	if(g_bGoodCommand[client])
		MuteClientID(szAdminID, g_szTargetID, iTargetIP, g_iPunishTime, g_iPunishDur, g_szReason);

	return Plugin_Handled;
}

public Action Admin_AddGag(int client, int args) {
	szTarget[128];
	szGagDur[32];
	szReason[256];

	GetCmdArg(1, szTarget, 128);
	GetCmdArg(2, szGagDur, 32);
	GetCmdArg(3, szReason, 256);

	g_bGoodCommand[client] = false;

	CheckArgs(szTarget, szGagDur, szReason);

	char szAdminID[128];
	GetClientAuthId(client, szAdminID, 128);

	int iTarget = FindTarget(client, szTarget);
	char szTargetID[128];
	GetClientAuthId(iTarget, AuthId_SteamID64, szTargetID, 128);
	// get client ip from steamid stored in sql tabel
	// TODO erik
	int iTargetIP = GetClientIP(iTarget);

	if(g_bGoodCommand[client])
		MuteClientID(szAdminID, g_szTargetID, iTargetIP, g_iPunishTime, g_iPunishDur, g_szReason);

	return Plugin_Handled;
}

public Action Admin_UnGag(int client, int args) {
	if(args < 1) {
		ReplyToCommand(client, "You must specify player steamid64");
		return Plugin_Handled;
	}

	szTargetID[128];
	GetCmdArg(1, szTargetID, 128);

	RemoveClientGag(client, szTargetID);

	return Plugin_Handled;
}

public Action Admin_Silence(int client, int args) {
	szTarget[128];
	szSilenceDur[32];
	szReason[256];

	GetCmdArg(1, szTarget, 128);
	GetCmdArg(2, szSilenceDur, 32);
	GetCmdArg(3, szReason, 256);

	g_bGoodCommand[client] = false;

	CheckArgs(szTarget, szSilenceDur, szReason);

	char szAdminID[128];
	GetClientAuthId(client, szAdminID, 128);

	int iTarget = FindTarget(client, szTarget);
	char szTargetID[128];
	GetClientAuthId(iTarget, AuthId_SteamID64, szTargetID, 128);
	// get client ip from steamid stored in sql tabel
	// TODO erik
	int iTargetIP = GetClientIP(iTarget);

	if(g_bGoodCommand[client])
		MuteClientID(szAdminID, g_szTargetID, iTargetIP, g_iPunishTime, g_iPunishDur, g_szReason);

	return Plugin_Handled;
}

public Action Admin_AddSilence(int client, int args) {
	szTarget[128];
	szSilenceDur[32];
	szReason[256];

	GetCmdArg(1, szTarget, 128);
	GetCmdArg(2, szSilenceDur, 32);
	GetCmdArg(3, szReason, 256);

	g_bGoodCommand[client] = false;

	CheckArgs(szTarget, szSilenceDur, szReason);

	char szAdminID[128];
	GetClientAuthId(client, szAdminID, 128);

	int iTarget = FindTarget(client, szTarget);
	char szTargetID[128];
	GetClientAuthId(iTarget, AuthId_SteamID64, szTargetID, 128);
	// get client ip from steamid stored in sql tabel
	// TODO erik
	int iTargetIP = GetClientIP(iTarget);

	if(g_bGoodCommand[client])
		MuteClientID(szAdminID, g_szTargetID, iTargetIP, g_iPunishTime, g_iPunishDur, g_szReason);

	return Plugin_Handled;
}

public Action Admin_UnSilence(int client, int args) {
	if(args < 1) {
		ReplyToCommand(client, "You must specify player steamid64");
		return Plugin_Handled;
	}

	szTargetID[128];
	GetCmdArg(1, szTargetID, 128);

	RemoveClientSilence(client, szTargetID);

	return Plugin_Handled;
}

public Action Admin_CheckBans(int client, int args) {
	if(args < 1) {
		ReplyToCommand(client, "You must specify player steamid64");
		return Plugin_Handled;
	}

	szTargetID[128];
	GetCmdArg(1, szTargetID, 128);

	CheckPunishments(szTargetID);
}
/*
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

}*/

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
			g_szReason = szReason;
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
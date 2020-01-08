enum BanType {
	Ban_Map, // banned until map switches
	Ban_Perm, // banned permanently
	Ban_Time, // banned for x amout of time
	Ban_Not // not banned
}

enum GagType {
	Gag_Map, // gaged until map switches
	Gag_Perm, // gaged permanently
	Gag_Time, // gaged for x amout of time
	Gag_Not // not gaged
}

enum MuteType {
	Mute_Map, // muted until map switches
	Mute_Perm, // muted permanently
	Mute_Time, // muted for x amout of time
	Mute_Not // not muted
}

native bool AB_IsBanned(int client);
native bool AB_BanClient(const char[] adminid, const char[] steamid, int clientIP, int currenttime, int banddur, const char[] reason);
native bool AB_UnBanClient(const char[] steamid);
native BanType AB_GetBanType(const char[] steamid);

native bool AB_IsMuted(int client);
native bool AB_MuteClient(const char [] adminid, const char[] steamid, int clientIP, int currenttime, int mutedur, const char[] reason);
native bool AB_UnMuteClient(const char[] steamid);
native BanType AB_GetMuteType(const char[] steamid);

native bool AB_IsGaged(int client);
native bool AB_GagClient(const char [] adminid, const char[] steamid, int clientIP, int currenttime, int gagdur, const char[] reason);
native bool AB_UnGagClient(const char[] steamid);
native BanType AB_GetGagType(const char[] steamid);

public SharedPlugin __pl_amubansmm = {
	name = "amuBans--",
	file = "Main-amuBans.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

if !defined REQUIRE_PLUGIN
public void __pl_amubansmm_SetNTVOptional() {
	MarkNativeAsOptional("AB_IsBanned");
	MarkNativeAsOptional("AB_BanClient");
	MarkNativeAsOptional("AB_UnBanClient");
	MarkNativeAsOptional("AB_GetBanType");
	MarkNativeAsOptional("AB_IsMuted");
	MarkNativeAsOptional("AB_MuteClient");
	MarkNativeAsOptional("AB_UnMuteClient");
	MarkNativeAsOptional("AB_GetMuteType");
	MarkNativeAsOptional("AB_IsGaged");
	MarkNativeAsOptional("AB_GagClient");
	MarkNativeAsOptional("AB_UnGagClient");
	MarkNativeAsOptional("AB_GetGagType");

}

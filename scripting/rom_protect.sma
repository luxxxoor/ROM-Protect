#include <amxmisc>
#include <fakemeta>

#pragma semicolon 1

#if AMXX_VERSION_NUM < 182 
    #assert AMX Mod X v1.8.2 or later library required!
#endif 

new const Version[]           = "1.0.4s-dev",
			 Build               = 87,
			 Date[]              = "20.03.2016",
			 PluginName[]        = "ROM-Protect",
			 Terrorist[]         = "#Terrorist_Select",
			 Counter_Terrorist[] = "#CT_Select",
			 CfgFile[]           = "addons/amxmodx/configs/rom_protect.cfg",
			 LangFile[]          = "addons/amxmodx/data/lang/rom_protect.txt",
			 NewPluginLocation[] = "/addons/amxmodx/plugins/rom_protect_new.amxx",
			 LangType[]          = "%L";

enum INFO
{
	INFO_NAME,
	INFO_IP,
	INFO_AUTHID    
};

enum
{
    FM_TEAM_T = 1,
    FM_TEAM_CT,
    FM_TEAM_SPECTATOR
};

enum _:AdminLogin
{
	LoginPass[32],
	LoginAccess[32],
	LoginFlag[6]
}

#define OFFSET_TEAM  114 
#define fm_set_user_team(%1,%2)  set_pdata_int( %1, OFFSET_TEAM, %2 )
#define fm_get_user_team(%1)     get_pdata_int( %1, OFFSET_TEAM ) 

#if AMXX_VERSION_NUM < 183
	#define MAX_PLAYERS 32		
	#define MAX_NAME_LENGTH 32
	new AdminNum;
	new bool:IsFlooding[MAX_PLAYERS+1];
	new Float:Flooding[MAX_PLAYERS+1] = {0.0, ...},
			  Flood[MAX_PLAYERS+1] = {0, ...};		  
	enum _:Colors 
	{
		DontChange,
		Red,
		Blue,
		Grey
	}
#else		
	#if MAX_PLAYERS != 32		
		#define MAX_PLAYERS 32		
	#endif
#endif

new ArgNum[MAX_PLAYERS+1], Contor[MAX_PLAYERS+1], LogFile[128], MapName[32], ClSaidSameTh_Count[MAX_PLAYERS+1],
	bool:CorrectName[MAX_PLAYERS+1], bool:IsAdmin[MAX_PLAYERS+1], bool:FirstMsg[MAX_PLAYERS+1],
	bool:Gag[MAX_PLAYERS+1], bool:UnBlockedChat[MAX_PLAYERS+1];
new LastPass[MAX_PLAYERS+1][32], MenuText[MAX_PLAYERS+1][MAX_PLAYERS], Capcha[MAX_PLAYERS+1][8];
new Trie:LoginName, Trie:DefaultRes;
new PreviousMessage[MAX_PLAYERS+1][192]; // declarat global pentru a evita eroarea "Run time error 3: stack error"
new bool:IsLangUsed;

new const AllBasicOnChatCommads[][] =
{
	"amx_say", "amx_csay", "amx_psay", "amx_tsay", "amx_chat", "say_team", 
	"say", "amx_gag", "amx_kick", "amx_ban", "amx_banip", "amx_nick", "amx_rcon"
};

new const AllAutobuyCommands[][] =
{
	"cl_autobuy",
	"cl_rebuy",
	"cl_setautobuy",
	"cl_setrebuy"
};

enum _:AllCvars
{
	autobuy_bug,
	utf8_bom,
	Tag,
	cmd_bug,
	spec_bug,
	fake_players,
	fake_players_limit,
	fake_players_type,
	fake_players_punish,
#if AMXX_VERSION_NUM < 183
	admin_chat_flood,
	admin_chat_flood_time,
#endif
	advertise,
	advertise_time,
	delete_custom_hpk,
	delete_vault,
	plug_warn,
	plug_log,
	admin_login,
	admin_login_file,
	admin_login_debug,
	color_bug,
	motdfile,
	anti_pause,
	anti_ban_class,
	info,
	xfakeplayer_spam,
	xfakeplayer_spam_maxchars,
	xfakeplayer_spam_maxsais,
	xfakeplayer_spam_type,
	xfakeplayer_spam_punish,
	xfakeplayer_spam_capcha,
	xfakeplayer_spam_capcha_word,
	protcvars
};

new const CvarName[AllCvars][] = 
{
	"rom_autobuy_bug",
	"rom_utf8_bom",
	"rom_tag",
	"rom_cmd_bug",
	"rom_spec_bug",
	"rom_fake_players",
	"rom_fake_players_limit",
	"rom_fake_players_type",
	"rom_fake_players_punish",
#if AMXX_VERSION_NUM < 183
	"rom_admin_chat_flood",
	"rom_admin_chat_flood_time",
#endif
	"rom_advertise",
	"rom_advertise_time",
	"rom_delete_custom_hpk",
	"rom_delete_vault",
	"rom_warn",
	"rom_log",
	"rom_admin_login",
	"rom_admin_login_file",
	"rom_admin_login_debug",
	"rom_color_bug",
	"rom_motdfile",
	"rom_anti_pause",
	"rom_anti_ban_class",
	"rom_give_info",
	"rom_xfakeplayer_spam",
	"rom_xfakeplayer_spam_maxchars",
	"rom_xfakeplayer_spam_maxsais",
	"rom_xfakeplayer_spam_type",
	"rom_xfakeplayer_spam_punish",
	"rom_xfakeplayer_spam_capcha",
	"rom_xfakeplayer_spam_capcha_word",
	"rom_prot_cvars"
};


#if AMXX_VERSION_NUM >= 183
	enum _:CvarRange
	{
		hasMinValue,
		minValue,
		hasMaxValue,
		maxValue
	}

	new const CvarLimits[AllCvars][CvarRange] = 
	{
		{ 1, 0, 1, 1 },     // rom_autobuy_bug
		{ 1, 0, 1, 1 },     // rom_utf8_bom
		{ 0, 0, 0, 0 },     // rom_tag
		{ 1, 0, 1, 1 },     // rom_cmd_bug
		{ 1, 0, 1, 1 },     // rom_spec_bug
		{ 1, 0, 1, 1 },     // rom_fake_players
		{ 1, 3, 1, 10 },    // rom_fake_players_limit
		{ 1, 0, 1, 1 },     // rom_fake_players_type
		{ 1, 5, 1, 10080 }, // rom_fake_players_punish
		{ 1, 0, 1, 1 },     // rom_advertise
		{ 1, 30, 1, 480 },  // rom_advertise_time
		{ 1, 0, 1, 1 },     // rom_delete_custom_hpk
		{ 1, 0, 1, 2 },     // rom_delete_vault
		{ 1, 0, 1, 1 },     // rom_warn
		{ 1, 0, 1, 1 },     // rom_log
		{ 1, 0, 1, 1 },     // rom_admin_login
		{ 0, 0, 0, 0 },     // rom_admin_login_file
		{ 1, 0, 1, 1 },     // rom_admin_login_debug
		{ 1, 0, 1, 1 },     // rom_color_bug
		{ 1, 0, 1, 1 },     // rom_motdfile
		{ 1, 0, 1, 1 },     // rom_anti_pause
		{ 1, 0, 1, 4 },     // rom_anti_ban_class
		{ 1, 0, 1, 1 },     // rom_give_info
		{ 1, 0, 1, 2 },     // rom_xfakeplayer_spam
		{ 1, 5, 1, 15 },    // rom_xfakeplayer_spam_maxchars
		{ 1, 3, 0, 0 },     // rom_xfakeplayer_spam_maxsais
		{ 1, 0, 1, 2 },     // rom_xfakeplayer_spam_type
		{ 1, 5, 1, 10080 }, // rom_xfakeplayer_spam_punish
		{ 1, 0, 1, 1 },     // rom_xfakeplayer_spam_capcha
		{ 0, 0, 0, 0 },     // rom_xfakeplayer_spam_capcha_word
		{ 1, 0, 1, 1 }      // rom_prot_cvars
	};
#endif

new const CvarValue[AllCvars][] =
{
	"1",
	"1",	
	"*ROM-Protect",
	"1",
	"1",
	"1",
	"5",
	"1",
	"10",
#if AMXX_VERSION_NUM < 183
	"1",
	"0.75",
#endif
	"1",
	"120",
	"1",
	"1",
	"1",
	"1",
	"1",
	"users_login.ini",
	"0",
	"1",
	"1",
	"1",
	"2",
	"1",
	"1",
	"12",
	"10",
	"2",
	"5",
	"0",
	"/chat",
	"1"
};
	
new PlugCvar[AllCvars];

public plugin_precache()
{	
	registersPrecache();
	
	new CurentDate[15];
	get_localinfo("amxx_logs", LogFile, charsmax(LogFile));
	format(LogFile, charsmax(LogFile), "%s/%s", LogFile, PluginName);
	
	if ( !dir_exists(LogFile) )
	{
		mkdir(LogFile);
	}
	
	get_time("%d-%m-%Y", CurentDate, charsmax(CurentDate));
	format(LogFile, charsmax(LogFile), "%s/%s_%s.log", LogFile, PluginName, CurentDate);
	
	if ( !file_exists(LogFile) )
	{
		write_file(LogFile, "*Aici este salvata activitatea suspecta a fiecarui jucator.^n^n", -1);
	}
	
	get_mapname(MapName, charsmax(MapName));
	format(MapName, charsmax(MapName), "|%s| ", MapName);
	
	if ( file_exists(CfgFile) )
	{
		server_cmd("exec %s", CfgFile);
	}
	
	//set_task(60.0, "updatePlugin");
	
	set_task(5.0, "checkLang");
	set_task(10.0, "checkLangFile");
	set_task(15.0, "checkCfg");
	set_task(20.0, "loadAdminLogin");
	
	while ( file_exists(NewPluginLocation) )
	{
		delete_file(NewPluginLocation);
	}
}

public checkCfg()
{
	if ( !file_exists(CfgFile) )
	{
		WriteCfg(false);
	}
	else
	{
		new FilePointer = fopen(CfgFile, "rt");
		
		if ( !FilePointer ) 
		{
			return;
		}
		
		new Text[121], CurrentVersion[64], bool:IsCurrentVersionUsed;
		formatex(CurrentVersion, charsmax(CurrentVersion), "Versiunea : %s. Bulid : %d. Data lansarii versiunii : %s.", Version, Build, Date);
		
		while ( !feof(FilePointer) )
		{
			fgets(FilePointer, Text, charsmax(Text));
			
			if ( containi(Text, CurrentVersion) != -1 )
			{
				IsCurrentVersionUsed = true;
				break;
			}
		}
		fclose(FilePointer);
		
		if ( !IsCurrentVersionUsed )
		{
			WriteCfg(true);
			if ( getNum(PlugCvar[plug_log]) == 1 )
			{
				logCommand(LangType, LANG_SERVER, "ROM_UPDATE_CFG", getString(PlugCvar[Tag]));
			}
		}
	}
}

public checkLang()
{
	if ( !file_exists(LangFile) )
	{
		WriteLang(false);
	}
	else
	{
		IsLangUsed = false;
		new FilePointer = fopen(LangFile, "rt");
		
		if ( !FilePointer ) 
		{
			return;
		}
		
		new Text[121], CurrentVersion[64], bool:IsCurrentVersionUsed;
		formatex(CurrentVersion, charsmax(CurrentVersion), "Versiunea : %s. Bulid : %d. Data lansarii versiunii : %s.", Version, Build, Date);
		
		while ( !feof(FilePointer) )
		{
			fgets(FilePointer, Text, charsmax(Text));
			
			if ( contain(Text, CurrentVersion) != -1 )
			{
				IsCurrentVersionUsed = true;
				break;
			}
		}
		fclose(FilePointer);
		
		if ( !IsCurrentVersionUsed )
		{
			register_dictionary("rom_protect.txt");
			IsLangUsed = true;
			if ( getNum(PlugCvar[plug_log]) == 1 )
			{
				logCommand(LangType, LANG_SERVER, "ROM_UPDATE_LANG", getString(PlugCvar[Tag]));
			}
			WriteLang(true);
		}
	}
}

public checkLangFile()
{
	if (!IsLangUsed)
	{
		register_dictionary("rom_protect.txt");
	}
}

public plugin_init()
{
	registersInit();
	
	if ( getNum(PlugCvar[admin_login]) == 1)
	{
		LoginName = TrieCreate();
	}
	
	if ( getNum(PlugCvar[advertise]) == 1 )
	{
		set_task(getFloat(PlugCvar[advertise_time]), "showAdvertise", _, _, _, "b", 0);
	}
	
	if ( getNum(PlugCvar[utf8_bom]) == 1 )
	{
		DefaultRes = TrieCreate();
		TrieSetCell(DefaultRes, "de_storm.res", 1);
		TrieSetCell(DefaultRes, "default.res", 1);
		
		set_task(10.0, "cleanResFiles");
	}
}

public client_authorized(Index)
{
	if ( getNum(PlugCvar[cmd_bug]) == 1 )
	{
		new Name[MAX_NAME_LENGTH];
		get_user_name(Index, Name, charsmax(Name));
		stringFilter(Name, charsmax(Name));
		set_user_info(Index, "name", Name);
	}
	if ( getNum(PlugCvar[fake_players]) == 1 )
	{
		if ( clientUseSteamid(Index) )
		{
			query_client_cvar(Index, "fps_max", "checkBot");
		}
	
		new Players[MAX_PLAYERS], PlayersNum, Address[32], Address2[32];
		get_players(Players, PlayersNum, "c");
		for (new i = 0; i < PlayersNum; ++i)
		{
			get_user_ip(Index, Address, charsmax(Address), 1);
			get_user_ip(Players[i], Address2, charsmax(Address2), 1);
			if ( equal(Address, Address2) && !is_user_bot(Index) )
			{
				if ( ++Contor[Index] > getNum(PlugCvar[fake_players_limit]) )
				{
					switch ( getNum(PlugCvar[fake_players_type]) )
					{
						case 0:
						{
							new Limit[8];
							num_to_str(getNum(PlugCvar[fake_players_limit]), Limit, charsmax(Limit));
							console_print(Index, LangType, LANG_PLAYER, "ROM_FAKE_PLAYERS_KICK", getString(PlugCvar[Tag]), Limit);
							server_cmd("kick #%d ^"You got kicked. Check console.^"", get_user_userid(Index));
						}
						case 1: 
						{
							new Punish[8];
							num_to_str(getNum(PlugCvar[fake_players_punish]), Punish, charsmax(Punish));
							server_cmd("addip ^"%s^" ^"%s^";wait;writeip", Punish, Address);
							if ( getNum(PlugCvar[plug_warn]) == 1 )
							{
								new CvarTag[32];
								copy(CvarTag, charsmax(CvarTag), getString(PlugCvar[Tag]));
								#if AMXX_VERSION_NUM < 183
									client_print_color(0, Grey, LangType, LANG_PLAYER, "ROM_FAKE_PLAYERS", "^3", CvarTag, "^4", Address);
									client_print_color(0, Grey, LangType, LANG_PLAYER, "ROM_FAKE_PLAYERS_PUNISH", "^3", CvarTag, "^4", Punish);
								#else
									client_print_color(0, print_team_grey, LangType, LANG_PLAYER, "ROM_FAKE_PLAYERS", CvarTag, Address);
									client_print_color(0, print_team_grey, LangType, LANG_PLAYER, "ROM_FAKE_PLAYERS_PUNISH", CvarTag, Punish);
								#endif
							}
							if ( getNum(PlugCvar[plug_log]) == 1 )
							{
								logCommand(LangType, LANG_SERVER, "ROM_FAKE_PLAYERS_LOG", getString(PlugCvar[Tag]), Address);
							}
						}
					}
					break;
				}
			}
		}
	}
	switch ( getNum(PlugCvar[xfakeplayer_spam]))
	{
		case 1:
		{
			FirstMsg[Index] = true;
			Gag[Index] = false;
		}
		case 2:
		{
			if ( getNum(PlugCvar[xfakeplayer_spam_capcha]) == 1 )
			{
				new const AllChars[] = 
				{
					'A','B','C','D','E','F','G','H',
					'I','J','K','L','M','N','O','P',
					'Q','R','S','T','U','V','W','X',
					'Y','Z','a','b','c','d','e','f',
					'g','h','i','j','k','l','m','n',
					'o','p','q','r','s','t','u','v',
					'w','x','y','z','0','1','2','3',
					'4','5','6','7','8','9'
				};
				const MatrixSize = sizeof AllChars;
				formatex(Capcha[Index], charsmax(Capcha[]), "%c%c%c%c", AllChars[random(MatrixSize)], AllChars[random(MatrixSize)], AllChars[random(MatrixSize)], AllChars[random(MatrixSize)]);
			}
			else
			{
				formatex(Capcha[Index], charsmax(Capcha[]), "%s", getString(PlugCvar[xfakeplayer_spam_capcha_word]));
			}
		}
	}
	
} 

#if AMXX_VERSION_NUM < 183
	public client_disconnect(Index)
#else
	public client_disconnected(Index)
#endif
{
	if ( getNum(PlugCvar[fake_players]) == 1 )
	{
		Contor[Index] = 0;
	}
	if ( getNum(PlugCvar[xfakeplayer_spam]) == 1 )
	{
		ClSaidSameTh_Count[Index] = 0;
	}
	else
	{
		UnBlockedChat[Index] = false;
	}
	if ( IsAdmin[Index] )
	{
		IsAdmin[Index] = false;
		remove_user_flags(Index);
	}
}

public plugin_end()
{
	switch ( getNum(PlugCvar[delete_vault]) != 0 )
	{
		case 1:
		{
			write_file(getVaultDir(), "server_language en", -1);
		}
		case 2:
		{
			write_file(getVaultDir(), "server_language ro", -1);
		}
	}
	
	if ( getNum(PlugCvar[delete_custom_hpk]) == 1 )
	{
		new BaseDir[] = "/", DirPointer, File[32];
		
		DirPointer = open_dir(BaseDir, "", 0);
		
		while ( next_file(DirPointer, File, charsmax(File)) )
		{
			if ( File[0] == '.' )
			{
				continue;
			}
			
			if ( containi( File, "custom.hpk" ) != -1 )
			{
				delete_file(File);
				break;
			}
		}
		
		close_dir(DirPointer);
	}
}

public client_infochanged(Index)
{
	if ( !is_user_connected(Index) )
	{
		return;
	}
	
	new CmdBugCvarValue = getNum(PlugCvar[cmd_bug]), AdminLoginCvarValue = getNum(PlugCvar[admin_login]);
	if ( CmdBugCvarValue == 1 || AdminLoginCvarValue == 1)
	{
		new NewName[MAX_NAME_LENGTH], OldName[MAX_NAME_LENGTH];
		get_user_name(Index, OldName, charsmax(OldName));
		get_user_info(Index, "name", NewName, charsmax(NewName));
	
		if ( CmdBugCvarValue == 1 )
		{
			stringFilter(NewName, charsmax(NewName));
			set_user_info(Index, "name", NewName);
		}
	
		if ( AdminLoginCvarValue == 1 && !equali(NewName, OldName) && IsAdmin[Index] )
		{
			IsAdmin[Index] = false;
			remove_user_flags(Index);
		}
	}
	
	return;
}

public plugin_pause()
{
	if (getNum(PlugCvar[anti_pause]) == 1)
	{
		new PluginName[32];
		
		if (getNum(PlugCvar[plug_warn]) == 1)
		{
			#if AMXX_VERSION_NUM < 183
				client_print_color(0, Grey, LangType, LANG_PLAYER, "ROM_PLUGIN_PAUSE", "^3", getString(PlugCvar[Tag]), "^4");
			#else
				client_print_color(0, print_team_grey, LangType, LANG_PLAYER, "ROM_PLUGIN_PAUSE", getString(PlugCvar[Tag]));
			#endif
		}
		
		if (getNum(PlugCvar[plug_log]) == 1)
		{
			new CvarTag[32];
			copy(CvarTag, charsmax(CvarTag), getString(PlugCvar[Tag]));
			logCommand(LangType, LANG_SERVER, "ROM_PLUGIN_PAUSE_LOG", CvarTag, CvarTag);
		}
		
		get_plugin(-1, PluginName, charsmax(PluginName));
		server_cmd("amxx unpause %s", PluginName);
	}
}

public cmdPass(Index)
{
	if ( getNum(PlugCvar[admin_login]) != 1 || !LoginName )
	{
		return PLUGIN_HANDLED;
	}

	new Name[MAX_NAME_LENGTH], Password[32], CvarTag[32];
	
	get_user_name(Index, Name, charsmax(Name));
	read_argv(1, Password, charsmax(Password));
	remove_quotes(Password);
	copy(CvarTag, charsmax(CvarTag), getString(PlugCvar[Tag]));
	if (!Password[0])
	{
		#if AMXX_VERSION_NUM < 183
			client_print_color(Index, Grey, LangType, Index, "ROM_ADMIN_WITHOUT_PASS", "^3", CvarTag, "^4");
		#else
			client_print_color(Index, print_team_grey, LangType, Index, "ROM_ADMIN_WITHOUT_PASS", CvarTag);
		#endif
		console_print(Index, LangType, Index, "ROM_ADMIN_WITHOUT_PASS_PRINT", CvarTag);

		return PLUGIN_HANDLED;
	}

	loadAdminLogin();
	IsAdmin[Index] = false;
	getAccess(Index, Password, charsmax(Password));
	
	if (!IsAdmin[Index])
	{
		LastPass[Index][0] = EOS;
		if (!CorrectName[Index])
		{		
			#if AMXX_VERSION_NUM < 183
				client_print_color(Index, Grey, LangType, Index, "ROM_ADMIN_WRONG_NAME", "^3", CvarTag, "^4");
			#else
				client_print_color(Index, print_team_grey, LangType, Index, "ROM_ADMIN_WRONG_NAME", CvarTag);
			#endif
			console_print(Index, LangType, Index, "ROM_ADMIN_WRONG_NAME_PRINT", CvarTag);
		}
		else
		{
			#if AMXX_VERSION_NUM < 183
				client_print_color(Index, Grey, LangType, Index, "ROM_ADMIN_WRONG_PASS", "^3", CvarTag, "^4");
			#else
				client_print_color(Index, print_team_grey, LangType, Index, "ROM_ADMIN_WRONG_PASS", CvarTag);
			#endif
			console_print(Index, LangType, Index, "ROM_ADMIN_WRONG_PASS_PRINT", CvarTag);
		}
	}
	else
	{
		if ( equal(LastPass[Index], Password) )
		{
			#if AMXX_VERSION_NUM < 183
				client_print_color(Index, Grey, LangType, Index, "ROM_ADMIN_ALREADY_LOADED", "^3", CvarTag, "^4");
			#else
				client_print_color(Index, print_team_grey, LangType, Index, "ROM_ADMIN_ALREADY_LOADED", CvarTag);
			#endif
			console_print(Index, LangType, Index, "ROM_ADMIN_ALREADY_LOADED_PRINT", CvarTag);
		}
		else
		{
			#if AMXX_VERSION_NUM < 183
				client_print_color(Index, Grey, LangType, Index, "ROM_ADMIN_LOADED", "^3", CvarTag, "^4");
			#else
				client_print_color(Index, print_team_grey, LangType, Index, "ROM_ADMIN_LOADED", CvarTag);
			#endif
			console_print(Index, LangType, Index, "ROM_ADMIN_LOADED_PRINT", CvarTag);

			IsAdmin[Index] = true;
		}
	}

	return PLUGIN_HANDLED;
}

#if AMXX_VERSION_NUM < 183
	public hookAdminChat(Index)
	{
		new Said[2];
		
		read_argv(1, Said, charsmax(Said));

		if (Said[0] != '@')
		{
			return PLUGIN_CONTINUE;
		}

		new Float:maxChat = get_pcvar_float(PlugCvar[admin_chat_flood_time]);

		if (maxChat && getNum(PlugCvar[admin_chat_flood]) == 1)
		{
			new Float:NexTime = get_gametime();

			if (Flooding[Index] > NexTime)
			{
				if (Flood[Index] >= 3)
				{
					IsFlooding[Index] = true;
					set_task(1.0, "showAdminChatFloodWarning", Index);
					Flooding[Index] = NexTime + maxChat + 3.0;
					return PLUGIN_HANDLED;
				}
				++Flood[Index];
			}
			else
			{
				if (Flood[Index])
				{
					--Flood[Index];
				}
			}
			
			Flooding[Index] = NexTime + maxChat;
		}

		return PLUGIN_CONTINUE;
	}
#endif

public oldStyleMenusTeammenu(msg, des, rec)
{
	if ( is_user_connected(rec) && getNum(PlugCvar[spec_bug]) == 1 )
	{
		get_msg_arg_string(4, MenuText[rec], charsmax(MenuText[]));
		
		if ( equal(MenuText[rec], Terrorist) || equal(MenuText[rec], Counter_Terrorist) )
		{
			set_task(0.1, "blockSpecbugOldStyleMenus", rec);
		}
	}
}

public vGuiTeammenu(msg, des, rec)  
{  
	if ( getNum(PlugCvar[spec_bug]) == 1 )
	{
		if ( get_msg_arg_int(1) == 26 || get_msg_arg_int(1) == 27 )
		{
			ArgNum[rec] = get_msg_arg_int(1);
			set_task(0.1, "blockSpecbugVGui", rec);
		}
	}
}

public blockSpecbugOldStyleMenus(Index)
{
	if ( !is_user_alive(Index) && is_user_connected(Index) )
	{
		if ( fm_get_user_team(Index) == FM_TEAM_SPECTATOR && !is_user_alive(Index) )
		{
			if ( equal(MenuText[Index], Terrorist) && is_user_connected(Index) )
			{
				fm_set_user_team(Index, FM_TEAM_T);
			}
				
			if ( equal(MenuText[Index], Counter_Terrorist) && is_user_connected(Index) )
			{
				fm_set_user_team(Index, FM_TEAM_CT);
			}
				
			if ( getNum(PlugCvar[plug_warn]) )
			{
				#if AMXX_VERSION_NUM < 183
					client_print_color(Index,Grey, LangType, Index, "ROM_SPEC_BUG", "^3", getString(PlugCvar[Tag]), "^4");
				#else
					client_print_color(Index, print_team_grey, LangType, Index, "ROM_SPEC_BUG", getString(PlugCvar[Tag]));
				#endif
			}
			
			if (getNum(PlugCvar[plug_log]))
			{
				logCommand(LangType, LANG_SERVER, "ROM_SPEC_BUG_LOG", getString(PlugCvar[Tag]), getInfo(Index, INFO_NAME), getInfo(Index, INFO_AUTHID), getInfo(Index, INFO_IP));
			}
		}
		
		set_task(0.1, "blockSpecbugOldStyleMenus", Index);
	}
}

public blockSpecbugVGui(Index)
{
	if ( !is_user_alive(Index) && is_user_connected(Index) )
	{
		if ( fm_get_user_team(Index) == FM_TEAM_SPECTATOR )
		{
			new bool:ShowLogOrWarning[MAX_PLAYERS+1];
				
			if ( ArgNum[Index] == 26 )
			{
				fm_set_user_team(Index, FM_TEAM_T);
				ShowLogOrWarning[Index] = true;
			}    
			
			if ( ArgNum[Index] == 27 )
			{
				fm_set_user_team(Index, FM_TEAM_CT);
				ShowLogOrWarning[Index] = true;
			}   
			
			if ( getNum(PlugCvar[plug_warn]) == 1 && ShowLogOrWarning[Index] )
			{
				#if AMXX_VERSION_NUM < 183
					client_print_color(Index, Grey, LangType, Index, "ROM_SPEC_BUG", "^3", getString(PlugCvar[Tag]), "^4");
				#else
					client_print_color(Index, print_team_grey, LangType, Index, "ROM_SPEC_BUG", getString(PlugCvar[Tag]));
				#endif
			}
			
			if ( getNum( PlugCvar[plug_log]) == 1 && ShowLogOrWarning[Index] )
			{
				logCommand(LangType, LANG_SERVER, "ROM_SPEC_BUG_LOG", getString(PlugCvar[Tag]), getInfo(Index, INFO_NAME), getInfo(Index, INFO_AUTHID), getInfo(Index, INFO_IP));
			}
			
			ShowLogOrWarning[Index] = false;
		}
		
		set_task(0.1, "blockSpecbugVGui", Index);
	}
}

#if AMXX_VERSION_NUM < 183
	public showAdminChatFloodWarning(Index)
	{
		if ( IsFlooding[Index] )
		{
			if ( getNum(PlugCvar[plug_warn]) == 1 )
			{
				client_print_color(Index, Grey, LangType, Index, "ROM_ADMIN_CHAT_FLOOD", "^3", getString(PlugCvar[Tag]), "^4");
			}
			
			if ( getNum(PlugCvar[plug_log]) == 1 )
			{
				logCommand(LangType, LANG_SERVER, "ROM_ADMIN_CHAT_FLOOD_LOG", getString(PlugCvar[Tag]), getInfo(Index, INFO_NAME), getInfo(Index, INFO_AUTHID), getInfo(Index, INFO_IP));
			}
			
			IsFlooding[Index] = false;
		}
	}
#endif

public showAdvertise()
{
	#if AMXX_VERSION_NUM < 183
		client_print_color(0, Grey, LangType, LANG_PLAYER, "ROM_ADVERTISE", "^3", getString(PlugCvar[Tag]), "^4", "^3", PluginName, "^4", "^3", Version, "^4");
	#else
		client_print_color(0, print_team_grey, LangType, LANG_PLAYER, "ROM_ADVERTISE", getString(PlugCvar[Tag]), PluginName, Version);
	#endif
}

public cleanResFiles() 
{ 
	new MapsDir[] = "maps"; 
	new const ResExt[] = ".res"; 
	new ResFile[64], Len; 
	new DirPointer = open_dir(MapsDir, ResFile, charsmax(ResFile)); 
	
	if ( !DirPointer )
	{
		return; 
	}
	
	new FullPathFileName[128];
	
	do 
	{ 
		Len = strlen(ResFile);
		
		if ( Len > 4 && equali(ResFile[Len-4], ResExt) ) 
		{ 
			if ( TrieKeyExists(DefaultRes, ResFile) ) 
			{
				continue;
			}
			
			formatex(FullPathFileName, charsmax(FullPathFileName), "%s/%s", MapsDir, ResFile); 
			write_file(FullPathFileName, "/////////////////////////////////////////////////////////////^n", 0); 
		} 
	} 
	while ( next_file(DirPointer, ResFile, charsmax(ResFile)) );
	
	close_dir(DirPointer);
} 


public reloadLogin(Index, level, cid) 
{
	set_task(1.0, "reloadDelay");
}

public reloadDelay()
{
	new Players[MAX_PLAYERS], PlayersNum;
	
	get_players(Players, PlayersNum, "ch");
	
	for (new i = 0; i < PlayersNum; ++i)
	{
		if ( IsAdmin[Players[i]] )
		{
			getAccess(Players[i], LastPass[Players[i]], charsmax(LastPass[]));
		}
	}
}

public cvarFunc(Index) 
{ 
	if ( !is_user_admin(Index) )
	{
		return PLUGIN_CONTINUE;
	}
		
	if ( getNum(PlugCvar[motdfile]) == 1 )
	{
		new Cvar[32], Value[32]; 
		
		read_argv(1, Cvar, charsmax(Cvar));
		read_argv(2, Value, charsmax(Value));
		
		if ( equali(Cvar, "motdfile") && contain(Value, ".ini") != -1 ) 
		{
			if ( getNum(PlugCvar[plug_warn]) == 1 )
			{
				console_print(Index, LangType, Index, "ROM_MOTDFILE", getString(PlugCvar[Tag]));
			}
			
			if ( getNum(PlugCvar[plug_log]) == 1 )
			{
				logCommand(LangType, LANG_SERVER, "ROM_MOTDFILE_LOG", getString(PlugCvar[Tag]), getInfo(Index, INFO_NAME), getInfo(Index, INFO_AUTHID), getInfo(Index, INFO_IP));
			}
			
			return PLUGIN_HANDLED; 
		}
	}
	
	if ( getNum(PlugCvar[protcvars]) == 1 )
	{
		new Command[32]; 
		
		read_argv(1, Command, charsmax(Command));
		
		if ( containi(Command, "rom_") != -1 )
		{
			if ( getNum(PlugCvar[plug_warn]) == 1 )
			{
				console_print(Index, LangType, Index, "ROM_PROTCVARS", getString(PlugCvar[Tag]));
			}
			
			if ( getNum(PlugCvar[plug_log]) == 1 )
			{
				logCommand(LangType, LANG_SERVER, "ROM_PROTCVARS_LOG", getString(PlugCvar[Tag]), getInfo(Index, INFO_NAME), getInfo(Index, INFO_AUTHID), getInfo(Index, INFO_IP));
			}
			
			return PLUGIN_HANDLED; 
		}
	}
	
	return PLUGIN_CONTINUE; 
}

public rconFunc(Index) 
{ 
	if ( !is_user_admin(Index) )
	{
		return PLUGIN_CONTINUE;
	}
	
	if ( getNum(PlugCvar[motdfile]) == 1 )
	{
		new Command[32]; 
		
		read_args(Command, charsmax(Command));
		
		if ( containi(Command, "motdfile") && contain(Command, ".ini") != -1 ) 
		{
			if ( getNum(PlugCvar[plug_warn]) == 1 )
			{
				console_print(Index, LangType, Index, "ROM_MOTDFILE", getString(PlugCvar[Tag]));
			}
			
			if ( getNum(PlugCvar[plug_log]) == 1 )
			{
				logCommand(LangType, LANG_SERVER, "ROM_MOTDFILE_LOG", getString(PlugCvar[Tag]), getInfo(Index, INFO_NAME), getInfo(Index, INFO_AUTHID), getInfo(Index, INFO_IP));
			}
			
			return PLUGIN_HANDLED; 
		}
	}
	
	if ( getNum(PlugCvar[protcvars]) == 1 )
	{
		new Command[32]; 
		
		read_args(Command, charsmax(Command));
		
		if ( !equali(Command, "rom_info") && containi(Command, "rom_") != -1 )
		{
			if ( getNum(PlugCvar[plug_warn]) == 1 )
			{
				console_print(Index, LangType, Index, "ROM_PROTCVARS", getString(PlugCvar[Tag]));
			}
			
			if ( getNum(PlugCvar[plug_log]) == 1 )
			{
				logCommand(LangType, LANG_SERVER, "ROM_PROTCVARS_LOG", getString(PlugCvar[Tag]), getInfo(Index, INFO_NAME), getInfo(Index, INFO_AUTHID), getInfo(Index, INFO_IP));
			}
			
			return PLUGIN_HANDLED; 
		}
	}
	
	return PLUGIN_CONTINUE; 
}

public hookBanClassCommand(Index)
{ 
	if ( !is_user_admin(Index) )
	{
		return PLUGIN_CONTINUE;
	}
	
	new Value = getNum(PlugCvar[anti_ban_class]);
	
	if ( Value > 0 )
	{
		new Ip[32], IpNum[4][3], NumStr[1];
		
		read_argv(1, Ip, charsmax(Ip));
		
		if ( containi( Ip, "STEAM") != -1 || containi( Ip, "VALVE") != -1 )
		{
			return PLUGIN_CONTINUE;
		}
		
		for	(new i = 0; i < 4; ++i)
		{
			split(Ip, IpNum[i], charsmax(IpNum[]), Ip, charsmax(Ip), ".");
		}
		
		Value = getNum(PlugCvar[anti_ban_class]);
		
		if ( Value > 4 )
		{
			Value = 4;
		}
			
		num_to_str(Value, NumStr, charsmax(NumStr));
		
		switch (Value)
		{
			case 1:
			{
				if ( str_to_num(IpNum[0]) == 0 || str_to_num(IpNum[1]) == 0 || str_to_num(IpNum[2]) == 0 )
				{
					if (getNum(PlugCvar[plug_warn]) == 1)
					{
						console_print(Index, LangType, Index, "ROM_ANTI_BAN_CLASS", getString(PlugCvar[Tag]));
					}
					
					if (getNum(PlugCvar[plug_log]) == 1)
					{
						logCommand(LangType, LANG_SERVER, "ROM_ANTI_ANY_BAN_CLASS_LOG", getString(PlugCvar[Tag]), getInfo(Index, INFO_NAME), getInfo(Index, INFO_AUTHID), getInfo(Index, INFO_IP));
					}
					
					return PLUGIN_HANDLED;
				}
			}
			case 2:
			{
				if ( str_to_num(IpNum[0]) == 0 || str_to_num(IpNum[1]) == 0 )
				{
					if (getNum(PlugCvar[plug_warn]) == 1)
					{
						console_print(Index, LangType, Index, "ROM_ANTI_BAN_CLASS", getString(PlugCvar[Tag]));
					}
					
					if (getNum(PlugCvar[plug_log]) == 1)
					{
						logCommand(LangType, LANG_SERVER, "ROM_ANTI_SOME_BAN_CLASS_LOG", getString(PlugCvar[Tag]), getInfo(Index, INFO_NAME), getInfo(Index, INFO_AUTHID), getInfo(Index, INFO_IP), NumStr);
					}
					
					return PLUGIN_HANDLED;
				}
			}
			case 3:
			{
				if ( str_to_num(IpNum[0]) == 0 )
				{
					if (getNum(PlugCvar[plug_warn]) == 1)
					{
						console_print(Index, LangType, Index, "ROM_ANTI_BAN_CLASS", getString(PlugCvar[Tag]));
					}
					
					if (getNum(PlugCvar[plug_log]) == 1)
					{
						logCommand(LangType, LANG_SERVER, "ROM_ANTI_SOME_BAN_CLASS_LOG", getString(PlugCvar[Tag]), getInfo(Index, INFO_NAME), getInfo(Index, INFO_AUTHID), getInfo(Index, INFO_IP), NumStr);
					}
					
					return PLUGIN_HANDLED;
				}
			}
			default:
			{
				if (getNum(PlugCvar[plug_warn]) == 1)
				{
					console_print(Index, LangType, Index, "ROM_ANTI_BAN_CLASS", getString(PlugCvar[Tag]));
				}
				
				if (getNum(PlugCvar[plug_log]) == 1)
				{
					logCommand(LangType, LANG_SERVER, "ROM_ANTI_SOME_BAN_CLASS_LOG", getString(PlugCvar[Tag]), getInfo(Index, INFO_NAME), getInfo(Index, INFO_AUTHID), getInfo(Index, INFO_IP), NumStr);
				}
				
				return PLUGIN_HANDLED;
			}
		}
	}
	
	return PLUGIN_CONTINUE;
}

public hookBasicOnChatCommand(Index)
{
	new ColorBugCvarValue = getNum(PlugCvar[color_bug]), CmdBugCvarValue = getNum(PlugCvar[cmd_bug]);
	if ( CmdBugCvarValue == 1 || ColorBugCvarValue == 1 )
	{
		new Said[192], bool:IsUsedCmdBug[MAX_PLAYERS+1], bool:IsUsedColorBug[MAX_PLAYERS+1];
		
		read_args(Said, charsmax(Said));
		
		for (new i = 0; i < sizeof Said ; ++i)
		{
			if ( CmdBugCvarValue == 1 && (Said[i] == '#' && isalpha(Said[i+1])) || (Said[i] == '%' && Said[i+1] == 's') )
			{
				IsUsedCmdBug[Index] = true;
				break;
			}
			if ( ColorBugCvarValue == 1 )
			{
				if ( Said[i] == '' || Said[i] == '' || Said[i] == '' )
				{
					IsUsedColorBug[Index] = true;
					break;
				}
			}
		}
		new WarnCvarValue = getNum(PlugCvar[plug_warn]), LogCvarValue = getNum(PlugCvar[plug_log]);
		if ( IsUsedCmdBug[Index] )
		{
			if ( WarnCvarValue == 1 )
			{
				new CvarTag[32];
				copy(CvarTag, charsmax(CvarTag), getString(PlugCvar[Tag]));
				
				#if AMXX_VERSION_NUM < 183
					client_print_color( Index, Grey, LangType, Index, "ROM_CMD_BUG", "^3", CvarTag, "^4");
				#else
					client_print_color( Index, print_team_grey, LangType, Index, "ROM_CMD_BUG", CvarTag);
				#endif
				console_print(Index, LangType, Index, "ROM_CMD_BUG_PRINT", CvarTag);
			}
			if ( LogCvarValue == 1 )
			{
				logCommand(LangType, LANG_SERVER, "ROM_CMD_BUG_LOG", getString(PlugCvar[Tag]), getInfo(Index, INFO_NAME), getInfo(Index, INFO_AUTHID), getInfo(Index, INFO_IP));
			}
			IsUsedCmdBug[Index] = false;
			return PLUGIN_HANDLED;
		}
		if ( IsUsedColorBug[Index] )
		{
			if ( WarnCvarValue == 1 )
			{
				#if AMXX_VERSION_NUM < 183
					client_print_color( Index, Grey, LangType, Index, "ROM_COLOR_BUG", "^3", getString(PlugCvar[Tag]), "^4");
				#else
					client_print_color( Index, print_team_grey, LangType, Index, "ROM_COLOR_BUG", getString(PlugCvar[Tag]) );
				#endif
			}
			if ( LogCvarValue == 1 )
			{
				logCommand(LangType, LANG_SERVER, "ROM_COLOR_BUG_LOG", getString(PlugCvar[Tag]), getInfo(Index, INFO_NAME), getInfo(Index, INFO_AUTHID), getInfo(Index, INFO_IP));
			}
			IsUsedColorBug[Index] = false;
			return PLUGIN_HANDLED;
		}
	}
	return PLUGIN_CONTINUE;
}

public checkBot(Index, const Var[], const Value[])
{
    if ( equal(Var, "fps_max") && Value[0] == 'B' )
    {
		if ( getNum(PlugCvar[plug_log]) == 1 )
		{
			logCommand(LangType, LANG_SERVER, "ROM_FAKE_PLAYERS_DETECT_LOG", getString(PlugCvar[Tag]), getInfo(Index, INFO_NAME), getInfo(Index, INFO_AUTHID), getInfo(Index, INFO_IP));
		}
		
		console_print(Index, LangType, Index, "ROM_FAKE_PLAYERS_DETECT", getString(PlugCvar[Tag]));
		server_cmd("kick #%d ^"You got kicked. Check console.^"", get_user_userid(Index));
    }
}

public CheckAutobuyBug(Index)		
{		
	new Command[512];
	new Count = read_argc();
	
	for (new i = 1; i <= Count; ++i)
	{		
		read_argv(i, Command, charsmax(Command));
		if ( getNum(PlugCvar[autobuy_bug]) == 1 )
		{
			if ( checkLong(Command, charsmax(Command)) )
			{		
				if ( getNum(PlugCvar[plug_warn]) == 1 )
				{		
					#if AMXX_VERSION_NUM < 183		
						client_print_color( Index, Grey, LangType, Index, "ROM_AUTOBUY", "^3", getString(PlugCvar[Tag]), "^4");		
					#else		
						client_print_color( Index, print_team_grey, LangType, Index, "ROM_AUTOBUY", getString(PlugCvar[Tag]));
					#endif		
				}
			
				if ( getNum( PlugCvar[plug_log] ) == 1 )
				{
					logCommand(LangType, LANG_SERVER, "ROM_AUTOBUY_LOG", getString(PlugCvar[Tag]), getInfo(Index, INFO_NAME), getInfo(Index, INFO_AUTHID), getInfo(Index, INFO_IP));
				}
			
				return PLUGIN_HANDLED;		
			}
		}
	}
	
	return PLUGIN_CONTINUE;		
}

/*public updatePlugin()
{
	if ( getNum(PlugCvar[auto_update]) == 0 )
	{
		return;
	}
	if ( file_exists(NewPluginLocation) )
	{
		delete_file(NewPluginLocation);
	}
	#if AMXX_VERSION_NUM >= 182
		if ( getNum(PlugCvar[dev_update]) == 1 )
		{
			#if AMXX_VERSION_NUM == 183
				HTTP2_Download("http://www.romprotect.allalla.com/rom_protect_dev183.amxx", NewPluginLocation, "downloadComplete");
			#endif
			#if AMXX_VERSION_NUM == 182
				HTTP2_Download("http://www.romprotect.allalla.com/rom_protect_dev182.amxx", NewPluginLocation, "downloadComplete");
			#endif
		}
		else
		{
			#if AMXX_VERSION_NUM == 183
				HTTP2_Download("http://www.romprotect.allalla.com/rom_protect183.amxx", NewPluginLocation, "downloadComplete");
			#endif
			#if AMXX_VERSION_NUM == 182
				HTTP2_Download("http://www.romprotect.allalla.com/rom_protect182.amxx", NewPluginLocation, "downloadComplete");
			#endif
		}
	#else
		#if AMXX_VERSION_NUM == 181
			HTTP2_Download("http://www.romprotect.allalla.com/rom_protect181.amxx", NewPluginLocation, "downloadComplete");
		#endif
	#endif
}

public downloadComplete(Index, Error) 
{
	new PluginLocation[64];
	get_plugin(-1, PluginLocation, charsmax(PluginLocation));
	format(PluginLocation, charsmax(PluginLocation), "/addons/amxmodx/plugins/%s", PluginLocation);
	if ( Error == 0 && file_size(NewPluginLocation) > 40000 ) 
	{
		if ( file_size(PluginLocation) != file_size(NewPluginLocation) )
		{
			logCommand(LangType, LANG_SERVER, "ROM_AUTO_UPDATE_SUCCEED", getString(PlugCvar[Tag]));
		}
		delete_file(PluginLocation);
		rename_file(NewPluginLocation, PluginLocation, 1);
	}
	else
	{
		logCommand(LangType, LANG_SERVER, "ROM_AUTO_UPDATE_FAILED", getString(PlugCvar[Tag]));
		delete_file(NewPluginLocation);
	}
}*/

public giveClientInfo(Index)
{
	if ( getNum(PlugCvar[info]) != 1 )
	{
		return PLUGIN_HANDLED;
	}
		
	console_print(Index, "^n^n^nVersiune curenta : %s. Build : %d. Data lansarii versiunii : %s.", Version, Build, Date);
	#if AMXX_VERSION_NUM >= 183
		console_print(Index, "Autor : VrînceanAlex.lüxor. Comunitatea : FioriGinal.Ro" );
	#else
		console_print(Index, "Autor : VrinceanAlex.luxor. Comunitatea : FioriGinal.Ro" );
	#endif
	console_print(Index, "Link oficial : http://forum.fioriginal.ro/amxmodx-plugins-pluginuri/rom-protect-anti-IsFlooding-bug-fix-t28292.html");
	console_print(Index, "Contact : luxxxoor (Steam) / alex.vrincean (Skype).^n^n^n");
	
	return PLUGIN_HANDLED;
}

public giveServerInfo(Index)
{
	if ( getNum(PlugCvar[info]) != 1 )
	{
		return PLUGIN_HANDLED;
	}
	
	server_print("^n^n^nVersiune curenta : %s. Build : %d. Data lansarii versiunii : %s.", Version, Build, Date);
	server_print("Autor : luxor # Dr.Fio & DR2.IND. Comunitatea : FioriGinal.Ro" );
	server_print("Link oficial : http://forum.fioriginal.ro/amxmodx-plugins-pluginuri/rom-protect-anti-flood-bug-fix-t28292.html");
	server_print("Contact : luxxxoor (Steam) / alex.vrincean (Skype).");
	server_print("Sursa in dezvoltare : https://github.com/luxxxoor/ROM-Protect ^n");
	server_print("Acest plugin este unul OpenSource ! Este interzisa copierea/vinderea lui pentru a obtine bani.");
	server_print("Plugin-ul se afla in plina dezvoltare si este menit sa ofere un minim de siguranta serverelor care nu provin de la firme de host scumpe, care sa comfere siguranta serverelor.");
	server_print("Clientii pot edita plugin-ul dupa bunul lor plac, fie din fisierul configurator si fisier lang, fie direct din sursa acestuia.");
	server_print("Copyright 2014-2016");
	
	return PLUGIN_HANDLED;
}

public hookForXFakePlayerSpam(Index)
{
	new xFakePlayerCvarValue = getNum(PlugCvar[xfakeplayer_spam]);
	if ( is_user_admin(Index) )
	{
		if ( FirstMsg[Index] && xFakePlayerCvarValue == 1 )
		{
			FirstMsg[Index] = false;
		}
		return PLUGIN_CONTINUE;
	}
	switch( xFakePlayerCvarValue )
	{
		case 1 :
		{
			if ( Gag[Index] )
			{
				return PLUGIN_HANDLED;
			}
	
			new ClSaid[192];
			read_args(ClSaid, charsmax(ClSaid));
	
			if ( strlen(ClSaid) <= getNum(PlugCvar[xfakeplayer_spam_maxchars])+1 )
			{	
				if ( FirstMsg[Index] )
				{
					FirstMsg[Index] = false;
				}
				return PLUGIN_CONTINUE;
			}
			else
			{
				if ( FirstMsg[Index] )
				{
					FirstMsg[Index] = false;
					ClSaidSameTh_Count[Index]++;
					copy(PreviousMessage[Index], charsmax(PreviousMessage[]), ClSaid);
					return PLUGIN_HANDLED;
				}
			}
	
			if ( ClSaidSameTh_Count[Index]++ > 0 )
			{
				if ( equal(ClSaid, PreviousMessage[Index]) )
				{
					if ( getNum(PlugCvar[plug_warn]) == 1 )
					{
						#if AMXX_VERSION_NUM < 183
							client_print_color(Index, Grey, LangType, LANG_PLAYER, "ROM_XFAKE_PLAYERS_SPAM_WARN", "^3", getString(PlugCvar[Tag]), "^4");
						#else
							client_print_color(Index, print_team_grey, LangType, LANG_PLAYER, "ROM_XFAKE_PLAYERS_SPAM_WARN", getString(PlugCvar[Tag]));
						#endif
					}		
			
					if ( ClSaidSameTh_Count[Index] >= getNum(PlugCvar[xfakeplayer_spam_maxsais]) )
					{
						new Address[32];
						get_user_ip(Index, Address, charsmax(Address), 1);
						switch ( getNum(PlugCvar[xfakeplayer_spam_type]) )
						{
							case 0 :
							{
								#if AMXX_VERSION_NUM < 183
									client_print_color(Index, Grey, LangType, LANG_PLAYER, "ROM_XFAKE_PLAYERS_SPAM_GAG", "^3", getString(PlugCvar[Tag]), "^4");
								#else
									client_print_color(Index, print_team_grey, LangType, LANG_PLAYER, "ROM_XFAKE_PLAYERS_SPAM_GAG", getString(PlugCvar[Tag]));
								#endif
								Gag[Index] = true;
								return PLUGIN_HANDLED; 
							}
							case 1 :
							{
								if ( getNum(PlugCvar[plug_warn]) == 1 )
								{
									console_print(Index, LangType, Index, "ROM_XFAKE_PLAYERS_SPAM_KICK", getString(PlugCvar[Tag]));
									server_cmd("kick #%d ^"You got kicked. Check console.^"", get_user_userid(Index));
								}
								else
								{
									server_cmd("kick #%d", get_user_userid(Index));
								}
							}
							default :
							{
								new Punish[8];
					
								num_to_str(getNum(PlugCvar[xfakeplayer_spam_punish]), Punish, charsmax(Punish));
		
								if ( getNum(PlugCvar[plug_warn]) == 1 )
								{
									new CvarTag[32];
									copy(CvarTag, charsmax(CvarTag), getString(PlugCvar[Tag]));
							
									#if AMXX_VERSION_NUM < 183
										client_print_color(0, Grey, LangType, LANG_PLAYER, "ROM_XFAKE_PLAYERS_SPAM", "^3", CvarTag, "^4", Address);
										client_print_color(0, Grey, LangType, LANG_PLAYER, "ROM_XFAKE_PLAYERS_SPAM_PUNISH", "^3", CvarTag, "^4", Punish);
									#else
										client_print_color(0, print_team_grey, LangType, LANG_PLAYER, "ROM_XFAKE_PLAYERS_SPAM", CvarTag, Address);
										client_print_color(0, print_team_grey, LangType, LANG_PLAYER, "ROM_XFAKE_PLAYERS_SPAM_PUNISH", CvarTag, Punish);
									#endif
					
									console_print(Index, LangType, Index, "ROM_XFAKE_PLAYERS_SPAM_BAN", getString(PlugCvar[Tag]), Punish);
								}
						
								server_cmd("addip ^"%s^" ^"%s^";wait;writeip", Punish, Address);
							}
						}
				
						if ( getNum(PlugCvar[plug_log]) == 1 )
						{
							logCommand(LangType, LANG_SERVER, "ROM_XFAKE_PLAYERS_SPAM_LOG", getString(PlugCvar[Tag]), Address);
						}
					}
				
					return PLUGIN_HANDLED;
				}
				else
				{
					ClSaidSameTh_Count[Index] = 0;
				}
			}
		}
		case 2:
		{
			new ClSaid[32];
			read_args(ClSaid, charsmax(ClSaid));
			remove_quotes(ClSaid);
			if ( !UnBlockedChat[Index] )
			{
				if ( equal(ClSaid, Capcha[Index]) )
				{
					UnBlockedChat[Index] = true;
					#if AMXX_VERSION_NUM < 183
						client_print_color(Index, Grey, LangType, LANG_PLAYER, "ROM_XFAKE_PLAYERS_ALLOW_USE_CHAT", "^3", getString(PlugCvar[Tag]), "^4");
					#else
						client_print_color(Index, print_team_grey, LangType, LANG_PLAYER, "ROM_XFAKE_PLAYERS_ALLOW_USE_CHAT", getString(PlugCvar[Tag]));
					#endif
					return PLUGIN_HANDLED;
				}
				else
				{	
					#if AMXX_VERSION_NUM < 183
						client_print_color(Index, Grey, LangType, LANG_PLAYER, "ROM_XFAKE_PLAYERS_CAPCHA", "^3", getString(PlugCvar[Tag]), "^4", "^3", Capcha[Index], "^4");
					#else
						client_print_color(Index, print_team_grey, LangType, LANG_PLAYER, "ROM_XFAKE_PLAYERS_CAPCHA", getString(PlugCvar[Tag]), Capcha[Index]);
					#endif
					return PLUGIN_HANDLED;
				}
			}
		}
		default :
		{
			return PLUGIN_CONTINUE;
		}
	}
	return PLUGIN_CONTINUE;
}

public delayforSavingLastPass(UserPass[], Index)
{
	copy(LastPass[Index], charsmax(LastPass[]), UserPass);
}

getAccess(Index, UserPass[], len)
{
	new UserName[MAX_NAME_LENGTH];

	get_user_name(Index, UserName, charsmax(UserName));
	
	if ( !(get_user_flags(Index) & ADMIN_CHAT) )
	{
		remove_user_flags(Index);
	}
	strtolower(UserName);
	#if AMXX_VERSION_NUM < 183
		for (new i = 0; i < AdminNum; ++i)
	#else
		for (new i = 0; i < TrieGetSize(LoginName); ++i)
	#endif
	{
		if ( TrieKeyExists(LoginName, UserName) )
		{
			CorrectName[Index] = true;
		}
		else
		{
			CorrectName[Index] = false;
			continue;
		}
		new TempData[AdminLogin];
		TrieGetArray(LoginName, UserName, TempData, charsmax(TempData));
		
		if ( equal(TempData[LoginFlag], "f") && CorrectName[Index] )
		{
			if ( equal(TempData[LoginPass], UserPass) || IsAdmin[Index] )
			{
				new Access = read_flags(TempData[LoginAccess]);
				set_user_flags(Index, Access);
				IsAdmin[Index] = true;
				set_task(0.1, "delayforSavingLastPass", Index, UserPass, len);
			}
			
			break;
		}
	}
}

public loadAdminLogin()
{
	new Path[64];
	
	get_localinfo("amxx_configsdir", Path, charsmax(Path));
	format(Path, charsmax(Path), "%s/%s", Path, getString(PlugCvar[admin_login_file]));
	
	if ( !file_exists(Path) )
	{
		new FilePointer = fopen(Path, "wt");
		
		if ( !FilePointer ) 
		{
			return;
		}
		
		if ( getNum(PlugCvar[plug_log]) == 1 )
		{
			logCommand( LangType, LANG_SERVER, "ROM_FILE_NOT_FOUND", getString(PlugCvar[Tag]), Path);
		}
		
		fputs(FilePointer, "; Aici vor fi inregistrate adminele protejate.^n");
		fputs(FilePointer, "; Exemplu de adaugare admin : ^"nume^" ^"parola^" ^"acces^" ^"f^"^n");
		
		fclose(FilePointer);
	}
	else
	{
		new Text[121], Name[MAX_NAME_LENGTH], Password[32], Access[26], Flags[6],
			FilePointer = fopen(Path, "rt");
		
		if ( !FilePointer ) 
		{
			return;
		}
		
		TrieClear(LoginName);
		
		#if AMXX_VERSION_NUM < 183
			AdminNum = 0;
		#endif
		
		while (!feof(FilePointer))
		{
			fgets(FilePointer, Text, charsmax(Text));

			trim(Text);
		
			if ( (Text[0] == ';') || !strlen(Text) || ((Text[0] == '/') && (Text[1] == '/')) )
			{
				continue;
			}
		
			if (parse(Text, Name, charsmax(Name), Password, charsmax(Password), Access, charsmax(Access), Flags, charsmax(Flags)) != 4)
			{
				continue;
			}
		
			new TempData[AdminLogin];
			strtolower(Name);
			copy(TempData[LoginPass], charsmax(TempData[LoginPass]), Password);
			copy(TempData[LoginAccess], charsmax(TempData[LoginAccess]), Access);
			copy(TempData[LoginFlag], charsmax(TempData[LoginFlag]), Flags);
			TrieSetArray(LoginName, Name, TempData, charsmax(TempData));
		
			#if AMXX_VERSION_NUM < 183
				++AdminNum;
			#endif
		
			if (getNum(PlugCvar[admin_login_debug]) == 1)
			{
				server_print(LangType, LANG_SERVER, "ROM_ADMIN_DEBUG", Name, Password, Access, Flags);
			}
		}
		
		fclose(FilePointer);
	}

	
}

logCommand(const StandardMessage[], any:...)
{
	new Message[256], LogMessage[256], Time[32];
	
	get_time(" %H:%M:%S ", Time, charsmax(Time));
	vformat(Message, charsmax(Message), StandardMessage, 2);
	formatex(LogMessage, charsmax(LogMessage), "L %s%s%s", Time, MapName, Message);
	
	server_print(LogMessage);
	write_file(LogFile, LogMessage, -1);
}

getInfo(Index, INFO:Type)
{
	new const Server[32] = "SERVER"; // Trebuie sa aibe acealasi numar de caractere pentru a nu primi "error 047".
	switch ( Type )
	{
		case INFO_NAME:
		{
			new Name[32];
			get_user_name(Index, Name, charsmax(Name));
			
			return Name;
		}
		case INFO_IP:
		{
			new Ip[32];
			get_user_ip(Index, Ip, charsmax(Ip), 1);
			
			return Ip;
		}
		case INFO_AUTHID:
		{
			new AuthID[32];
			if ( Index )
			{
				get_user_authid(Index, AuthID, charsmax(AuthID));
				
				return AuthID;
			}
			else
			{
				return Server;
			}
		}
	}
	
	return Server; // Un return care nu se va apela niciodata, insa compilatorul nu va mai primi warning.
}

getString(Cvar)
{
	new CvarString[32]; 
	get_pcvar_string(Cvar, CvarString, charsmax(CvarString));
	
	return CvarString;
}

getNum(Cvar)
{
	new CvarNum;
	CvarNum = get_pcvar_num(Cvar);
	
	return CvarNum;
}

Float:getFloat(Cvar)
{
	new Float:CvarFloat = get_pcvar_float(Cvar);
	
	return CvarFloat;
} 

registersPrecache()
{
	if (getHldsVersion() < 6027)
	{
		#if AMXX_VERSION_NUM >= 183
			PlugCvar[autobuy_bug] = create_cvar("rom_autobuy_bug" ,"1", _, _, true, 0.0, true, 1.0);
			PlugCvar[utf8_bom] = create_cvar("rom_utf8_bom", "0", _, _, true, 0.0, true, 1.0);
		#else
			PlugCvar[autobuy_bug] = register_cvar("rom_autobuy_bug", "1");
			PlugCvar[utf8_bom] = register_cvar("rom_utf8_bom", "0");
		#endif
	}
	else
	{
		#if AMXX_VERSION_NUM >= 183
			PlugCvar[autobuy_bug] = create_cvar("rom_autobuy_bug" ,"0", _, _, true, 0.0, true, 1.0);
			PlugCvar[utf8_bom] = create_cvar("rom_utf8_bom", "1", _, _, true, 0.0, true, 1.0);
		#else
			PlugCvar[autobuy_bug] = register_cvar("rom_autobuy_bug", "0");
			PlugCvar[utf8_bom] = register_cvar("rom_utf8_bom", "1");
		#endif
	}
	
	for (new i = 2; i < AllCvars; i++)
	{
		#if AMXX_VERSION_NUM >= 183
			PlugCvar[i] = create_cvar(CvarName[i] ,CvarValue[i], _, _, bool:CvarLimits[i][hasMinValue], float(CvarLimits[i][minValue]),
									  bool:CvarLimits[i][hasMaxValue], float(CvarLimits[i][maxValue]));
		#else
			PlugCvar[i] = register_cvar(CvarName[i] ,CvarValue[i]);
		#endif
	}
}

registersInit()
{
	register_plugin(PluginName, Version, "FioriGinal.Ro");
	register_cvar("rom_protect", Version, FCVAR_SERVER | FCVAR_SPONLY);
	
	register_message(get_user_msgid("ShowMenu"), "oldStyleMenusTeammenu");
	register_message(get_user_msgid("VGUIMenu"), "vGuiTeammenu");
	
	register_clcmd("say", "hookForXFakePlayerSpam");
	register_clcmd("say_team", "hookForXFakePlayerSpam");
	
	for (new i = 0; i < sizeof AllBasicOnChatCommads; ++i)
	{
		register_concmd(AllBasicOnChatCommads[i], "hookBasicOnChatCommand");	
	
	}
	
	#if AMXX_VERSION_NUM < 183
		register_clcmd("say_team", "hookAdminChat");
	#endif
	
	if (getHldsVersion() < 6027)
	{
		for (new i = 0; i < sizeof AllAutobuyCommands; ++i)
		{
			register_clcmd(AllAutobuyCommands[i], "CheckAutobuyBug");
		}
	}
	
	if ( find_plugin_byfile("advanced_bans.amxx") != -1 ) // in cazul in care acest plugin va fi detectat, serverul nu va mai avea nevoie de aceasta protectie
		register_concmd("amx_addban", "hookBanClassCommand");
	
	register_concmd("amx_reloadadmins", "reloadLogin");	
	register_concmd("amx_cvar", "cvarFunc");
	register_clcmd("amx_rcon", "rconFunc");
	register_clcmd("login", "cmdPass");
	register_clcmd("rom_info", "giveClientInfo");
	register_srvcmd("rom_info", "giveServerInfo");
}

public stringFilter(String[], Len)
{
	new LeftBuffer[MAX_NAME_LENGTH], RightBuffef[MAX_NAME_LENGTH], MidBuffer[3];
	for (new i = 0; i <= Len; ++i)
	{
		if ( i+1 < MAX_NAME_LENGTH )
		{
			if ( (String[i] == '#' && isalpha(String[i+1])) || (String[i] == '+' && isalpha(String[i+1])) )
			{
				formatex(MidBuffer, charsmax(MidBuffer), "%c%c", String[i], String[i+1]);
				split(String, LeftBuffer, charsmax(LeftBuffer), RightBuffef, charsmax(RightBuffef), MidBuffer);
				format(String, Len, "%s%c %c%s", LeftBuffer, String[i], String[i+1], RightBuffef);
			}
			
		}
	}
}

bool:clientUseSteamid(Index) 
{	
	new AuthID[35]; 
	get_user_authid(Index, AuthID, charsmax(AuthID) );
	
	return (contain(AuthID , ":") != -1 && containi(AuthID , "STEAM") != -1) ? true : false; 
}

getHldsVersion()
{
	new VersionPonter, VersionString[24], Pos;
	new const VersionSizeNum = 4;
   
	VersionPonter = get_cvar_pointer("sv_version");
	get_pcvar_string(VersionPonter, VersionString, charsmax(VersionString));
	Pos = strlen(VersionString) - VersionSizeNum;
	format(VersionString, VersionSizeNum, "%s", VersionString[Pos]);
	
	return str_to_num(VersionString);
}

bool:checkLong(cCommand[], Len)
{
	new mCommand[512];
	
	while (strlen(mCommand))
	{
		strtok(cCommand, mCommand, charsmax(mCommand), cCommand, Len , ' ', 1);
		if ( strlen( mCommand ) > 31 )
		{
			return true;
		}
	}
	
	return false;
}

getVaultDir()
{
	new BaseDir[128];
	
	get_basedir(BaseDir, charsmax(BaseDir));
	format(BaseDir, charsmax(BaseDir), "%s/data/vault.ini", BaseDir);
	
	if ( file_exists(BaseDir) )
	{
		delete_file(BaseDir);	
	}
	
	return BaseDir;
}

WriteCfg( bool:exist )
{	
	new FilePointer = fopen(CfgFile, "wt");
	
	if ( !FilePointer ) 
	{
		return;
	}
	
	writeSignature(FilePointer);
	
	fputs(FilePointer, "// Verificare daca CFG-ul a fost executat cu succes.^n");
	fputs(FilePointer, "echo ^"*ROM-Protect : Fisierul rom_protect.cfg a fost gasit. Incep protejarea serverului.^"^n^n");
	fputs(FilePointer, "// Cvar      : rom_cmd_bug^n");
	fputs(FilePointer, "// Scop      : Urmareste chat-ul si opeste bugurile de tip ^"client overflow^" care dau crush client-elor jucatorilor.^n");
	fputs(FilePointer, "// Impact    : Serverul nu pateste nimic, insa playerii acestuia primesc ^"quit^" indiferent de ce client folosesc, iar serverul ramane gol.^n");
	fputs(FilePointer, "// Nota      : -^n");
	fputs(FilePointer, "// Update    : Incepand cu versiunea 1.0.1s, plugin-ul protejeaza serverele si de noul cmd-bug bazat pe caracterul '#'. Plugin-ul blocheaza de acum '#' si '%' in chat si '#' in nume.^n");
	fputs(FilePointer, "// Update    : Incepand cu versiunea 1.0.3a, plugin-ul devine mai inteligent, si va bloca doar posibilele folosiri ale acestui bug, astfel incat caracterele '#' si '%' vor putea fi folosite, insa nu in toate cazurile.^n");
	fputs(FilePointer, "// Update    : Incepand cu versiunea 1.0.3s, plugin-ul inlatura si bugul provotat de caracterul '+' in nume, acesta incercand sa deruteze playerii sau adminii (nu apare numele jucatorului in meniuri).^n");
	fputs(FilePointer, "// Update    : Incepand cu versiunea 1.0.4b, plugin-ul verifica si comenzile de baza care pot elibera mesaje in chat (ex: amx_say, amx_psay, etc.), adica toate comenzile prezente in adminchat.amxx.^n");
	fputs(FilePointer, "// Update    : Incepand cu versiunea 1.0.4f, plugin-ul devine mai indulgent cu jucatorii, si nu va mai inlocui caractere '#' si '+' cu un spatiu din nume, ci va pune un spatiu dupa acestea.^n");
	fputs(FilePointer, "// Valoarea 0: Functia este dezactivata.^n");
	fputs(FilePointer, "// Valoarea 1: Atacul este blocat. [Default]^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_cmd_bug ^"%d^"^n^n", getNum(PlugCvar[cmd_bug]));
	}
	else
	{
		fputs(FilePointer, "rom_cmd_bug ^"1^"^n^n");
	}
	
	fputs(FilePointer, "// Cvar      : rom_spec_bug^n");
	fputs(FilePointer, "// Scop      : Urmareste activitatea jucatorilor si opreste schimbarea echipei la spectator daca acestia au deschis meniul de selectare al modelului, pentru a opri specbug.^n");
	fputs(FilePointer, "// Impact    : Serverul primeste crash in momentul in care se apeleaza la acest bug.^n");
	fputs(FilePointer, "// Nota      : Este posibil ca in unele cazuri (inca necunoscute) plugin-ul sa detecteze anumiti jucatori si cand nu se apeleaza la acest bug.^n");
	fputs(FilePointer, "// Valoarea 0: Functia este dezactivata.^n");
	fputs(FilePointer, "// Valoarea 1: Atacul este blocat. [Default]^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_spec_bug ^"%d^"^n^n", getNum(PlugCvar[spec_bug]));
	}
	else
	{
		fputs(FilePointer, "rom_spec_bug ^"1^"^n^n");
	}

	#if AMXX_VERSION_NUM < 183
		fputs(FilePointer, "// Cvar      : rom_admin_chat_flood^n");
		fputs(FilePointer, "// Scop      : Urmareste activitatea jucatorilor care folosesc chat-ul adminilor, daca persoanele incearca sa flood-eze acest chat sunt opriti fortat.^n");
		fputs(FilePointer, "// Impact    : Serverul nu pateste nimic, insa cei cu acces la ^"admin chat^"(U@) primesc kick cu motivul : ^"Reliable channel overflowed^".^n");
		fputs(FilePointer, "// Nota      : Acesta functie este disponibila doar pentru serverele cu AMXX 1.8.1 sau AMXX 1.8.2 .^n");
		fputs(FilePointer, "// Valoarea 0: Functia este dezactivata.^n");
		fputs(FilePointer, "// Valoarea 1: Atacul este blocat. [Default]^n");
		if (exist)
		{
			fprintf(FilePointer, "rom_admin_chat_flood ^"%d^"^n", getNum(PlugCvar[admin_chat_flood]));
		}
		else
		{
			fputs(FilePointer, "rom_admin_chat_flood ^"1^"^n^n");  
		}
		
		fputs(FilePointer, "// Cvar      : rom_admin_chat_flood_time (Activat numai in cazul in care cvarul ^"rom_admin_chat_flood^" este setat pe 1)^n");
		fputs(FilePointer, "// Utilizare : Limiteaza timpul maxim de trimitere al mai multor mesaje de catre acelasi cleint in chat-ul adminilor, blocand astfel atacurile tip ^"chat overflow^".^n");
		fputs(FilePointer, "// Nota      : Este recomandat sa nu se modifice valoarea standard a cvar-ului, pentru ca protectia sa functioneze corect.^n");
		if (exist)
		{
			fprintf(FilePointer, "rom_admin_chat_flood_time ^"%.2f^"^n", getFloat(PlugCvar[admin_chat_flood_time]));
		}
		else
		{
			fputs(FilePointer, "rom_admin_chat_flood_time ^"0.75^"^n^n");
		}
	#endif
		
	fputs(FilePointer, "// Cvar      : rom_autobuy_bug^n");		
	fputs(FilePointer, "// Scop      : Urmareste comenzile de tip autobuy/rebuy, iar daca acestea devin suspecte sunt oprite.^n");		
	fputs(FilePointer, "// Impact    : Serverul primeste crash in momentul in care se apeleaza la acest bug.^n");		
	fputs(FilePointer, "// Nota      : Serverele cu engine HLDS 6xxx nu mai sunt vulnerabile la acest bug.^n");		
	fputs(FilePointer, "// Valoarea 0: Functia este dezactivata.^n");		
	fputs(FilePointer, "// Valoarea 1: Atacul este blocat. [Default]^n");		
	if (exist)		
	{		
		fprintf(FilePointer, "rom_autobuy_bug ^"%d^"^n^n", getNum(PlugCvar[autobuy_bug]));
	}		
	else
	{
		if (getHldsVersion() < 6027)
		{
			fputs(FilePointer, "rom_autobuy_bug ^"1^"^n^n");
		}
		else
		{
			fputs(FilePointer, "rom_autobuy_bug ^"0^"^n^n");
		}
	}	
	
	fputs(FilePointer, "// Cvar      : rom_fake_players^n");
	fputs(FilePointer, "// Scop      : Urmareste persoanele conectate pe server si intervine atunci cand numarul persoanelor cu acelasi ip il depaseste pe cel setat in cvarul rom_fake_players_limit.^n");
	fputs(FilePointer, "// Impact    : Serverul poate sa fie tinut in loc (lumea asteptand dupa acesti jucatori sa moara, insa acestia nu o vor face), iar jucatorii morti vor parasi serverul.^n");
	fputs(FilePointer, "// Nota      : Daca sunt mai multe persoane care impart aceasi legatura de internet pot fi banate (N minute), in acest caz ridicati cvarul : rom_fake_players_limit sau opriti rom_fake_players.^n");
	fputs(FilePointer, "// Valoarea 0: Functia este dezactivata.^n");
	fputs(FilePointer, "// Valoarea 1: Atacul este blocat prin ban 30 minute. [Default]^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_fake_players ^"%d^"^n^n", getNum(PlugCvar[fake_players]));
	}
	else
	{
		fputs(FilePointer, "rom_fake_players ^"1^"^n^n");
	}
	
	fputs(FilePointer, "// Cvar      : rom_fake_players_limit (Activat numai in cazul in care cvarul ^"rom_fake_players^" este setat pe 1)^n");
	fputs(FilePointer, "// Utilizare : Limiteaza numarul maxim de persoane de pe acelasi IP, blocand astfel atacurile tip fake-player.^n");
	fputs(FilePointer, "// Nota      : Se recomanda ca acest cvar sa nu fie scazut sub valoarea ^"3^".^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_fake_players_limit ^"%d^"^n^n", getNum(PlugCvar[fake_players_limit]));
	}
	else
	{
		fputs(FilePointer, "rom_fake_players_limit ^"5^"^n^n");
	} 
	
	fputs(FilePointer, "// Cvar      : rom_fake_players_type (Activat numai in cazul in care cvarul ^"rom_fake_players^" este setat pe 1)^n");
	fputs(FilePointer, "// Utilizare : Selecteaza tipul de protectie impotriva fake-player-ilor.^n");
	fputs(FilePointer, "// Nota      : In cazul in care sunt prea multi jucatori de pe acelasi ip, setati acest cvar pe valoarea ^"1^".^n");
	fputs(FilePointer, "// Valoarea 0: Daca sunt prea multi jucatori de pe acelasi ip, cei noi intrati vor primi kick.^n");
	fputs(FilePointer, "// Valoarea 1: Daca sunt prea multi jucatori de pe acelasi ip, acestia vor primi ban. [Default]^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_fake_players_type ^"%d^"^n^n", getNum(PlugCvar[fake_players_type]));
	}
	else
	{
		fputs(FilePointer, "rom_fake_players_type ^"1^"^n^n");
	} 
	
	fputs(FilePointer, "// Cvar      : rom_fake_players_punish  Activat numai in cazul in care cvarul ^"rom_fake_players_type^" este setat pe 1)^n");
	fputs(FilePointer, "// Utilizare : Blocheaza ip-ul atacatorului pentru un interval de timp, masurat in minute.^n");
	fputs(FilePointer, "// Nota      : Recomandam sa nu setati o valoarea prea mare, deoarece in cazul unei detectari eronate jucatorii serverului pot avea de suferit.^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_fake_players_punish ^"%d^"^n^n", getNum(PlugCvar[fake_players_punish]));
	}
	else
	{
		fputs(FilePointer, "rom_fake_players_punish ^"10^"^n^n");
	} 
	
	fputs(FilePointer, "// Cvar      : rom_delete_custom_hpk");
	fputs(FilePointer, "// Scop      : La finalul fiecarei harti, se va sterge fisierul custom.hpk.^n");
	fputs(FilePointer, "// Impact    : Serverul experimenteaza probleme la schimbarea hartii, aceasta putand sa dureze si pana la 60secunde.^n");
	fputs(FilePointer, "// Nota      : Eroarea ^"ERROR: couldn't open custom.hpk^" poate fi ignorata, deoarece ea nu afecteaza serverul in nici un mod.^n");
	fputs(FilePointer, "// Valoarea 0: Functie este dezactivata.^n");
	fputs(FilePointer, "// Valoarea 1: Fisierul este sters. [Default]^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_delete_custom_hpk ^"%d^"^n^n", getNum(PlugCvar[delete_custom_hpk]));
	}
	else
	{
		fputs(FilePointer, "rom_delete_custom_hpk ^"1^"^n^n");
	}
	
	fputs(FilePointer, "// Cvar      : rom_delete_vault^n");
	fputs(FilePointer, "// Scop      : La finalul fiecarei harti, se va sterge fisierul vault.ini.^n");
	fputs(FilePointer, "// Impact    : Serverul experimenteaza probleme la schimbarea hartii, aceasta putand sa dureze si pana la 60secunde.^n");
	fputs(FilePointer, "// Nota      : In cazul in care salvati anumite date in acest fisier (^"vault.ini^"), setati cvar-ul pe valoarea ^"0^".^n");
	fputs(FilePointer, "// Valoarea 0: Functie este dezactivata.^n");
	fputs(FilePointer, "// Valoarea 1: Fisierul este sters si e setat ^"server_language en^" in vault.ini. [Default]^n");
	fputs(FilePointer, "// Valoarea 2: Fisierul este sters si e setat ^"server_language ro^" in vault.ini.^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_delete_vault ^"%d^"^n^n", getNum(PlugCvar[delete_vault]));
	}
	else
	{
		fputs(FilePointer, "rom_delete_vault ^"1^"^n^n");
	}
	
	fputs(FilePointer, "// Cvar      : rom_advertise^n");
	fputs(FilePointer, "// Efect     : Afiseaza un mesaj prin care anunta clientii ca serverul este protejat de *ROM-Protect.^n");
	fputs(FilePointer, "// Nota      : Mesajul poate fi modificat din fisierul LANG. (^"data/lang/rom_protect.txt^")^n");
	fputs(FilePointer, "// Valoarea 0: Mesajele sunt dezactivate.^n");
	fputs(FilePointer, "// Valoarea 1: Mesajele sunt activate. [Default]^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_advertise ^"%d^"^n^n", getNum(PlugCvar[advertise]));
	}
	else
	{
		fputs(FilePointer, "rom_advertise ^"1^"^n^n");
	}

	fputs(FilePointer, "// Cvar      : rom_advertise_time (Activat numai in cazul in care cvarul ^"rom_advertise^" este setat pe 1)^n");
	fputs(FilePointer, "// Utilizare : Seteaza ca mesajul sa apara o data la N secunde.^n");
	fputs(FilePointer, "// Nota      : Se recomanda sa nu setati acest cvar pe o valoare prea mica, altfel mesajul va face spam in chat.^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_advertise_time ^"%d^"^n^n", getNum(PlugCvar[advertise_time]));
	}
	else
	{
		fputs(FilePointer, "rom_advertise_time ^"120^"^n^n");
	}
	
	fputs(FilePointer, "// Cvar      : rom_warn^n");
	fputs(FilePointer, "// Efect     : Afiseaza mesaje prin care anunta clientii care incearca sa distube activitatea normala a serverului.^n");
	fputs(FilePointer, "// Nota      : Mesajele pot fi modificate din fisierul LANG. (^"data/lang/rom_protect.txt^")^n");
	fputs(FilePointer, "// Valoarea 0: Mesajele sunt dezactivate.^n");
	fputs(FilePointer, "// Valoarea 1: Mesajele sunt activate. [Default]^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_warn ^"%d^"^n^n", getNum(PlugCvar[plug_warn]));
	}
	else
	{
		fputs(FilePointer, "rom_warn ^"1^"^n^n");
	}
	
	fputs(FilePointer, "// Cvar      : rom_log");
	fputs(FilePointer, "// Efect     : Permite pluginului sa inregistreze activiatatea sa (in log-uri separate).^n");
	fputs(FilePointer, "// Nota      : Daca acest cvar este pornit, in consola serverlui vor fi printate mesajele intiparite in log.^n");
	fputs(FilePointer, "// Valoarea 0: Functia este dezactivata.^n");
	fputs(FilePointer, "// Valoarea 1: Functia este activata.^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_log ^"%d^"^n^n", getNum(PlugCvar[plug_log]));
	}
	else
	{
		fputs(FilePointer, "rom_log ^"1^"^n^n");
	}
	
	fputs(FilePointer, "// Cvar      : rom_admi_login");
	fputs(FilePointer, "// Scop      : Permite autentificarea adminilor prin comanda ^"login parola^" in consola (nu necesita setinfo)^n");
	fputs(FilePointer, "// Impact    : Parolele adminilor sunt foarte usor de furat, e destul doar sa intri pe un server iar parola ta nu mai este in sigurata.^n");
	fputs(FilePointer, "// Nota      : Adminurile se adauga normal ^"nume^" ^"parola^" ^"acces^" ^"f^".^n");
	fputs(FilePointer, "// Update    : Incepand de la versiunea 1.0.3a, comanda in chat !login sau /login dispare, deoarece nu era folosita.^n");
	fputs(FilePointer, "// Valoarea 0: Functie este dezactivata.^n");
	fputs(FilePointer, "// Valoarea 1: Functia este activata. [Default]^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_admin_login ^"%d^"^n^n", getNum(PlugCvar[admin_login]));
	}
	else
	{
		fputs(FilePointer, "rom_admin_login ^"1^"^n^n");
	}
	
	fputs(FilePointer, "// Cvar      : rom_admin_login_file (Activat numai in cazul in care cvarul ^"rom_admin_login^" este setat pe 1)^n");
	fputs(FilePointer, "// Efect     : Selecteaza fisierul de unde sa fie citite adminele cu flag ^"f^"^n");
	fputs(FilePointer, "// Nota      : De preferat sa nu se suprapuna cu fisierul de adminurile ^"normale^", altfel unele din adminele protejate pot fi incarcate de plugin-ul de baza, creeand neplaceri.^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_admin_login_file ^"%s^"^n^n", getString(PlugCvar[admin_login_file]));
	}
	else
	{
		fputs(FilePointer, "rom_admin_login_file ^"users_login.ini^"^n^n");
	}
	
	fputs(FilePointer, "// Cvar      : rom_admin_login_debug (Activat numai in cazul in care cvarul ^"rom_admin_login^" este setat pe 1)^n");
	fputs(FilePointer, "// Efect     : In cazul in care adminurile nu se incarca corect acesta va printa in consola serverului argumentele citite (nume - parola - acces - flag).^n");
	fputs(FilePointer, "// Nota      : Daca funtia este pornita, poate crea lag, scopul ei este doar de a verifica daca adminurile sunt puse corect.^n");
	fputs(FilePointer, "// Valoarea 0: Functie este dezactivata. [Default]^n");
	fputs(FilePointer, "// Valoarea 1: Argumentele sunt printate in consola.^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_admin_login_debug ^"%d^"^n^n", getNum(PlugCvar[admin_login_debug]));
	}
	else
	{
		fputs(FilePointer, "rom_admin_login_debug ^"0^"^n^n");
	}
	
	fputs(FilePointer, "// Cvar      : rom_utf8_bom^n");
	fputs(FilePointer, "// Scop      : Verifica fiecare fisier .res in maps, si daca descopera urme UTF8-BOM le elimina.^n");
	fputs(FilePointer, "// Impact    : Serverul da crash cu eroarea : Host_Error: PF_precache_generic_I: Bad string.^n");
	fputs(FilePointer, "// Nota      : Eroarea apare doar la versiunile de HLDS 6***.^n");
	fputs(FilePointer, "// Valoarea 0: Functie este dezactivata.^n");
	fputs(FilePointer, "// Valoarea 1: Fisierul este decontaminat. [Default]^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_utf8_bom ^"%d^"^n^n", getNum(PlugCvar[utf8_bom]));
	}
	else
	{
		if (getHldsVersion() >= 6027)
		{
			fputs(FilePointer, "rom_utf8_bom ^"1^"^n^n");
		}
		else
		{
			fputs(FilePointer, "rom_utf8_bom ^"0^"^n^n");
		}
	}	
	
	fputs(FilePointer, "// Cvar      : rom_tag^n");
	fputs(FilePointer, "// Utilizare : Seteaza tag-ul pluginului. (Numele acestuia)^n");
	fputs(FilePointer, "// Nota      : De preferat numele tag-ului sa nu depaseasca 32 de caractere, altfel acesta nu va aparea cum trebuie in chat.^n");
	fputs(FilePointer, "// Update    : Incepand de la versiunea 1.0.2s, plugin-ul *ROM-Protect devine mult mai primitor si te lasa chiar sa ii schimbi numele.^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_tag ^"%s^"^n^n", getString(PlugCvar[Tag]));
	}
	else
	{
		fputs(FilePointer, "rom_tag ^"*ROM-Protect^"^n^n");	
	}
	
	fputs(FilePointer, "// Cvar      : rom_color_bug^n");
	fputs(FilePointer, "// Scop      : Urmareste chatul si opeste bugurile de tip color-bug care alerteaza playerii si adminii.^n");
	fputs(FilePointer, "// Impact    : Serverul nu pateste nimic, insa playerii sau adminii vor fi alertati de culorile folosite de unul din clienti.^n");
	fputs(FilePointer, "// Nota      : Daca nu sunteti afectati de acest bug, se recomanda oprirea functiei.^n");
	fputs(FilePointer, "// Valoarea 0: Functia este dezactivata.^n");
	fputs(FilePointer, "// Valoarea 1: Bug-ul este blocat. [Default]^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_color_bug ^"%d^"^n^n", getNum(PlugCvar[color_bug]));
	}
	else
	{
		fputs(FilePointer, "rom_color_bug ^"1^"^n^n");
	}
	
	fputs(FilePointer, "// Cvar      : rom_motdfile^n");
	fputs(FilePointer, "// Scop      : Urmareste activitatea adminilor prin comanda amx_cvar si incearca sa opreasca modificare cvarului motdfile intr-un fisier .ini.^n");
	fputs(FilePointer, "// Impact    : Serverul nu pateste nimic, insa adminul care foloseste acest exploit poate fura date importante din server, precum lista de admini, lista de pluginuri etc.^n");
	fputs(FilePointer, "// Nota      : In curand, se va folosi un algoritm mult mai bun si mai corect, insa doar pentru AMXX 1.8.3 .^n");
	fputs(FilePointer, "// Update    : Incepand de la versiunea 1.0.4f, plugin-ul va bloca acest furt de informatii si prin comadna amx_rcon.^n");
	fputs(FilePointer, "// Valoarea 0: Functia este dezactivata.^n");
	fputs(FilePointer, "// Valoarea 1: Bug-ul este blocat. [Default]^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_motdfile ^"%d^"^n^n", getNum(PlugCvar[motdfile]));
	}
	else
	{
		fputs(FilePointer, "rom_motdfile ^"1^"^n^n");	
	}
	
	fputs(FilePointer, "// Cvar      : rom_anti_pause^n");
	fputs(FilePointer, "// Scop      : Urmareste ca plugin-ul de protectie ^"ROM-Protect^" sa nu poata fi pus pe pauza de catre un raufacator.^n");
	fputs(FilePointer, "// Impact    : Serverul nu mai este protejat de plugin, acesta fiind expus la mai multe exploituri.^n");
	fputs(FilePointer, "// Nota      : Daca doriti sa puteti dezactiva plugin-ul, este recomadat sa setati acest cvar pe valoarea ^"0^".^n");
	fputs(FilePointer, "// Valoarea 0: Functia este dezactivata.^n");
	fputs(FilePointer, "// Valoarea 1: Bug-ul este blocat. [Default]^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_anti_pause ^"%d^"^n^n", getNum(PlugCvar[anti_pause]));
	}
	else
	{
		fputs(FilePointer, "rom_anti_pause ^"1^"^n^n");
	}
	
	fputs(FilePointer, "// Cvar      : rom_anti_ban_class^n");
	fputs(FilePointer, "// Scop      : Urmareste activitatea comezii amx_addban, astfel incat sa nu se poata da ban pe mai multe clase ip.^n");
	fputs(FilePointer, "// Impact    : Serverul nu pateste nimic, insa daca se dau ban-uri pe clasa, foarte multi jucatori nu se vor mai putea conecta la server.^n");
	fputs(FilePointer, "// Nota      : Functia nu urmareste decat comanda amx_addban.^n");
	fputs(FilePointer, "// Valoarea 0: Functia este dezactivata.^n");
	fputs(FilePointer, "// Valoarea 1: Functia va bloca comanda daca detecteaza ban-ul pe o clasa de ip.^n");
	fputs(FilePointer, "// Valoarea 2: Functia va bloca comanda daca detecteaza ban-ul pe doua clase de ip. [Default]^n");
	fputs(FilePointer, "// Valoarea 3: Functia va bloca comanda daca detecteaza ban-ul pe trei clase de ip.^n");
	fputs(FilePointer, "// Valoarea 4: Functia va bloca comanda daca detecteaza ban-ul pe toate clasele de ip.^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_anti_ban_class ^"%d^"^n^n", getNum(PlugCvar[anti_ban_class]));
	}
	else
	{
		fputs(FilePointer, "rom_anti_ban_class ^"2^"^n^n");
	}
/*	
	fputs(FilePointer, "// Cvar      : rom_auto_update^n");
	fputs(FilePointer, "// Scop      : Descarca si inlocuieste plugin-ul automat, pentru a face singur setarile de siguranta.^n");
	fputs(FilePointer, "// Impact    : Actualizeaza automat plugin-ul la schimbarea hartii.^n");
	fputs(FilePointer, "// Nota      : In cazul in care intampinati probleme dese la descarcarea actualizarii automate, este recomandat sa setati acest cvar pe valoarea ^"0^".^n");
	fputs(FilePointer, "// Valoarea 0: Functia este dezactivata.^n");
	fputs(FilePointer, "// Valoarea 1: Plugin-ul se va auto-actualiza. [Default]^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_auto_update ^"%d^"^n^n", getNum(PlugCvar[auto_update]));
	}
	else
	{
		fputs(FilePointer, "rom_auto_update ^"1^"^n^n");
	}
#if AMXX_VERSION_NUM >= 182
	fputs(FilePointer, "// Cvar      : rom_dev_update (Activat numai in cazul in care cvarul ^"rom_auto_update^" este setat pe 1)^n");
	//server_print("debug 1");
	fputs(FilePointer, "// Utilizare : Permite descarcarea update-urilor beta.^n");
	fputs(FilePointer, "// Nota      : Atentie, update-urile beta nu sunt stabile si pot provoca caderea serverului!^n");
	fputs(FilePointer, "// Nota      : Aceasta facilitate o au doar serverele cu AMXX 1.8.2 sau AMXX 1.8.3 .^n");
	fputs(FilePointer, "// Valoarea 0: Functia este dezactivata.^n");
	fputs(FilePointer, "// Valoarea 1: Plugin-ul se va auto-actualiza si cu update-uri beta. [Default]^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_dev_update ^"%d^"^n^n", getNum(PlugCvar[dev_update]));
	}
	else
	{
		fputs(FilePointer, "rom_dev_update ^"0^"^n^n");
	}
#endif
*/
	
	fputs(FilePointer, "// Cvar      : rom_give_info^n");
	fputs(FilePointer, "// Scop      : Serverul va trimite utilizatorului informatii despre plugin.^n");
	fputs(FilePointer, "// Impact    : Cand cineva va scrie ^"rom_info^" in consola, ii vor fi livrate informatiile (tot in consola).^n");
	fputs(FilePointer, "// Nota      : Daca mesajul este transmis prin intermediul consolei serverului, acesta va primi cateva informatii suplimentare.^n");
	fputs(FilePointer, "// Valoarea 0: Functia este dezactivata.^n");
	fputs(FilePointer, "// Valoarea 1: Functia este activata. [Default]^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_give_info ^"%d^"^n^n", getNum(PlugCvar[info]));
	}
	else
	{
		fputs(FilePointer, "rom_give_info ^"1^"^n^n");
	}
	
	fputs(FilePointer, "// Cvar      : rom_xfakeplayer_spam^n");
	fputs(FilePointer, "// Scop      : Blocheaza posibilele tentative de atacuri de boti, care au scop sa faca reclama la anumite servere in 2 modalitati.^n");
	fputs(FilePointer, "// Impact    : Botii fac reclama la alte servere, enervand jucatorii/staff-ul serverului.^n");
	fputs(FilePointer, "// Nota      : Daca un jucator scrie primul mesaj mai lung de N caractere (N = valoarea cvar-ului rom_xfakeplayer_spam_maxchars), acesta va fi blocat de catre plugin. (In cazul in care pluginul are valoarea 1)^n");
	fputs(FilePointer, "// Valoarea 0: Functia este dezactivata.^n");
	fputs(FilePointer, "// Valoarea 1: Pluginul va protejat serverul prin interzicerea primului say in chat, urmarind uratoarele say-uri daca sunt la fel, acesta va pedepsi acel client (Foloseste cvarurile de mai jos) [Default]^n");
	fputs(FilePointer, "// Valoarea 2: Pluginul va interzice oricarui client sa scrie in chat pana cand nu va introduce un cod capcha in chat. (cod prestabilit sau cod la intamplare, asta se seteaza la cvar-ul rom_xfakeplayer_spam_capcha)");
	if (exist)
	{
		fprintf(FilePointer, "rom_xfakeplayer_spam ^"%d^"^n^n", getNum(PlugCvar[xfakeplayer_spam]));
	}
	else
	{
		fputs(FilePointer, "rom_xfakeplayer_spam ^"1^"^n^n");
	}
	
	fputs(FilePointer, "// Cvar      : rom_xfakeplayer_spam_maxchars (Activat numai in cazul in care cvarul ^"rom_xfakeplayer_spam^" este setat pe 1)^n");
	fputs(FilePointer, "// Utilizare : Selecteaza numarul maxim de caractere care il poate scrie un jucator pentru ca acesta sa nu fie verificat si anulat.^n");
	fputs(FilePointer, "// Nota      : Atentie, numarul de caractere trebuie sa nu fie mai mare de 15 caractere, altfel protectia va fi inutila.^n");
	fputs(FilePointer, "// Valoarea 0: Functia este dezactivata.^n");
	fputs(FilePointer, "// Valoarea 1: Functia este activata. [Default]^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_xfakeplayer_spam_maxchars ^"%d^"^n^n", getNum(PlugCvar[xfakeplayer_spam_maxchars]));
	}
	else
	{
		fputs(FilePointer, "rom_xfakeplayer_spam_maxchars ^"12^"^n^n");
	}
	
	fputs(FilePointer, "// Cvar      : rom_xfakeplayer_spam_maxsais (Activat numai in cazul in care cvarul ^"rom_xfakeplayer_spam^" este setat pe 1)^n");
	fputs(FilePointer, "// Utilizare : Selecteaza numarul mesajelor identice trimise pana cand ip-ul sa primeasca ban.^n");
	fputs(FilePointer, "// Nota      : Atentie, numarul de mesaje identice trimise trebuie sa nu fie mai mic de 3, altfel protectia s-ar putea sa baneze unii jucatori.^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_xfakeplayer_spam_maxsais ^"%d^"^n^n", getNum(PlugCvar[xfakeplayer_spam_maxsais]));
	}
	else
	{
		fputs(FilePointer, "rom_xfakeplayer_spam_maxsais ^"10^"^n^n");
	}
	
	fputs(FilePointer, "// Cvar      : rom_xfakeplayer_spam_type (Activat numai in cazul in care cvarul ^"rom_xfakeplayer_spam^" este setat pe 1)^n");
	fputs(FilePointer, "// Utilizare : Selecteaza tipul de protectie impotriva botilor xfake-player.^n");
	fputs(FilePointer, "// Nota      : Atentie, daca cvar-ul este setat pe valoarea ^"0^", jucatorii xfake-player vor continua sa ramana pe server.^n");
	fputs(FilePointer, "// Valoarea 0: Jucatorul nu va mai putea vorbi.^n");
	fputs(FilePointer, "// Valoarea 1: Jucatorul va primi kick.^n");
	fputs(FilePointer, "// Valoarea 2: Jucatorul va primi ban pentru o valoare setata in cvar-ul rom_xfakeplayer_spam_punish. [Default]^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_xfakeplayer_spam_type ^"%d^"^n^n", getNum(PlugCvar[xfakeplayer_spam_type]));
	}
	else
	{
		fputs(FilePointer, "rom_xfakeplayer_spam_type ^"2^"^n^n");
	}
	
	fputs(FilePointer, "// Cvar      : rom_xfakeplayer_spam_punish (Activat numai in cazul in care cvarul ^"rom_xfakeplayer_spam_type^" este setat pe 2)^n");
	fputs(FilePointer, "// Utilizare : Blocheaza ip-ul atacatorului pentru un interval de timp, masurat in minute.^n");
	fputs(FilePointer, "// Nota      : Se recomanda sa nu se seteze o valoare prea mare pentru acest cvar, in cazul unei detectari false, jucatorul poate avea de suferit.^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_xfakeplayer_spam_punish ^"%d^"^n^n", getNum(PlugCvar[xfakeplayer_spam_punish]));
	}
	else
	{
		fputs(FilePointer, "rom_xfakeplayer_spam_punish ^"5^"^n^n");
	}
	
	fputs(FilePointer, "// Cvar      : rom_xfakeplayer_spam_capcha (Activat numai in cazul in care cvarul ^"rom_xfakeplayer_spam_type^" este setat pe 2)^n");
	fputs(FilePointer, "// Utilizare : Nu lasa clientii de pe server sa foloseasca chat-ul pana nu scriu in chat un anumit cod.^n");
	fputs(FilePointer, "// Nota      : Daca aveti un server cu multi clienti straini, se recomanda valoarea 0.^n");
	fputs(FilePointer, "// Valoarea 0: Chat-ul se va debloca printr-un cod prestabilit. (in cvarul rom_xfakeplayer_spam_capcha_word) [Default]^n");
	fputs(FilePointer, "// Valoarea 1: Chat-ul se va debloca printr-un cod la intamplare (random).^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_xfakeplayer_spam_capcha ^"%d^"^n^n", getNum(PlugCvar[xfakeplayer_spam_capcha]));
	}
	else
	{
		fputs(FilePointer, "rom_xfakeplayer_spam_capcha ^"0^"^n^n");
	}	
	
	fputs(FilePointer, "// Cvar      : rom_xfakeplayer_spam_capcha_word (Activat numai in cazul in care cvarul ^"rom_xfakeplayer_spam_capcha^" este setat pe 0)^n");
	fputs(FilePointer, "// Utilizare : Seteaza un cod prestabilit, iar prin scrierea codului in chat de catre client, ^n");
	fputs(FilePointer, "// Nota      : De preferat codul sa nu contina prea multe caractere, unii clienti urasc sa scrie coduri lungi de pste 5 caractere.^n");
	fputs(FilePointer, "// Update    : Incepand de la versiunea 1.0.2s, plugin-ul *ROM-Protect devine mult mai primitor si te lasa chiar sa ii schimbi numele.^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_xfakeplayer_spam_capcha_word ^"%s^"^n^n", getString(PlugCvar[xfakeplayer_spam_capcha_word]));
	}
	else
	{
		fputs(FilePointer, "rom_xfakeplayer_spam_capcha_word ^"/chat^"^n^n");	
	}
	
	fputs(FilePointer, "// Cvar      : rom_prot_cvars^n");
	fputs(FilePointer, "// Scop      : Impiedica schimbarea cvar-elor acestui plugin. Permitand schimbarea lor doar din consola serverului sau din configurator.^n");
	fputs(FilePointer, "// Impact    : Protectiile pot fi afectate, iar serverul este pus in pericol.^n");
	fputs(FilePointer, "// Nota      : Daca doriti sa puteti schimba valorile din accesul de admin, cvar-ul va trebui setat pe valoarea ^"0^".^n");
	fputs(FilePointer, "// Valoarea 0: Functia este dezactivata.^n");
	fputs(FilePointer, "// Valoarea 1: Functia este activata. [Default]^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_prot_cvars ^"%d^"^n^n", getNum(PlugCvar[protcvars]));
	}
	else
	{
		fputs(FilePointer, "rom_prot_cvars ^"1^"^n^n");
	}

	fclose(FilePointer);
}

WriteLang( bool:exist )
{
	if (exist)
	{		
		new Line[512], FilePointer = fopen(LangFile, "wt");
		
		if ( !FilePointer ) 
		{
			return;
		}
		
		#if AMXX_VERSION_NUM < 183
			writeSignature(FilePointer);
		#else
			writeSignature(FilePointer, true);
		#endif
		
		fputs(FilePointer, "[en]^n^n");
		
		formatex(Line, charsmax(Line), "ROM_UPDATE_CFG = %L^n", LANG_SERVER, "ROM_UPDATE_CFG", "^%s" );
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_UPDATE_CFG = %s : Am actualizat fisierul CFG : rom_protect.cfg.^n");
		}
		else
		{
			fputs(FilePointer, Line);
		}
		
		formatex(Line, charsmax(Line), "ROM_UPDATE_LANG = %L^n", LANG_SERVER, "ROM_UPDATE_LANG", "^%s" );
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_UPDATE_LANG = %s : Am actualizat fisierul LANG : rom_protect.txt.^n");
		}
		else
		{
			fputs(FilePointer, Line);
		}
		
		#if AMXX_VERSION_NUM < 183
			formatex(Line, charsmax(Line), "ROM_FAKE_PLAYERS = %L^n", LANG_SERVER, "ROM_FAKE_PLAYERS", "^%s", "^%s", "^%s", "^%s");
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_FAKE_PLAYERS = %s%s : %sS-a observat un numar prea mare de persoane de pe ip-ul : %s .^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
			
			formatex(Line, charsmax(Line), "ROM_FAKE_PLAYERS_PUNISH = %L^n", LANG_SERVER, "ROM_FAKE_PLAYERS_PUNISH", "^%s", "^%s", "^%s", "^%s");
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_FAKE_PLAYERS_PUNISH = %s%s : %sIp-ul a primit ban %s minute pentru a nu afecta jocul.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}		
		#else
			formatex(Line, charsmax(Line), "ROM_FAKE_PLAYERS = %L^n", LANG_SERVER, "ROM_FAKE_PLAYERS", "^%s", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_FAKE_PLAYERS = ^^3%s : ^^4S-a observat un numar prea mare de persoane de pe ip-ul : %s .^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
				
			formatex(Line, charsmax(Line), "ROM_FAKE_PLAYERS_PUNISH = %L^n", LANG_SERVER, "ROM_FAKE_PLAYERS_PUNISH", "^%s", "^%s");
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_FAKE_PLAYERS_PUNISH = ^^3%s : ^^4Ip-ul a primit ban %s minute pentru a nu afecta jocul.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#endif
		
		formatex(Line, charsmax(Line), "ROM_FAKE_PLAYERS_LOG = %L^n", LANG_SERVER, "ROM_FAKE_PLAYERS_LOG", "^%s", "^%s"  );
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_FAKE_PLAYERS_LOG = %s : S-a depistat un atac de ^"xFake-Players^" de la IP-ul : %s .^n");
		}
		else
		{
			fputs(FilePointer, Line);
		}
		
		formatex(Line, charsmax(Line), "ROM_FAKE_PLAYERS_KICK = %L^n", LANG_SERVER, "ROM_FAKE_PLAYERS_KICK", "^%s", "^%s"  );
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_FAKE_PLAYERS_KICK = %s : Nu poti intra pe server, deoarece sunt inca %s jucatori cu acelasi ip-ul ca al tau.^n");
		}
		else
		{
			fputs(FilePointer, Line);
		}		
			
		formatex(Line, charsmax(Line), "ROM_FAKE_PLAYERS_DETECT = %L^n", LANG_SERVER, "ROM_FAKE_PLAYERS_DETECT", "^%s"  );
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_FAKE_PLAYERS_DETECT = %s : Ai primit kick deoarece deoarece esti suspect de fake-client. Te rugam sa folosesti alt client.^n");
		}
		else
		{
			fputs(FilePointer, Line);
		}
			
		formatex(Line, charsmax(Line), "ROM_FAKE_PLAYERS_DETECT_LOG = %L^n", LANG_SERVER, "ROM_FAKE_PLAYERS_DETECT_LOG", "^%s", "^%s", "^%s", "^%s" );
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_FAKE_PLAYERS_DETECT_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca suspect de ^"xFake-Players^" sau ^"xSpammer^".^n");
		}
		else
		{
			fputs(FilePointer, Line);
		}
			
		#if AMXX_VERSION_NUM < 183
			formatex(Line, charsmax(Line), "ROM_PLUGIN_PAUSE = %L^n", LANG_SERVER, "ROM_PLUGIN_PAUSE", "^%s", "^%s", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_PLUGIN_PAUSE = %s%s : %sNe pare rau, dar din anumite motive, acest plugin nu poate fi pus pe pauza.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#else
			formatex(Line, charsmax(Line), "ROM_PLUGIN_PAUSE = %L^n", LANG_SERVER, "ROM_PLUGIN_PAUSE", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_PLUGIN_PAUSE = ^^3%s : ^^4Ne pare rau, dar din anumite motive, acest plugin nu poate fi pus pe pauza.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#endif
		
		formatex(Line, charsmax(Line), "ROM_PLUGIN_PAUSE_LOG = %L^n", LANG_SERVER, "ROM_PLUGIN_PAUSE_LOG", "^%s", "^%s" );
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_PLUGIN_PAUSE_LOG = %s : S-a depistat o incercare a opririi pluginului de protectie %s. Operatiune a fost blocata.^n");
		}
		else
		{
			fputs(FilePointer, Line);
		}
			
		#if AMXX_VERSION_NUM < 183 
			formatex(Line, charsmax(Line), "ROM_ADMIN_WRONG_NAME = %L^n", LANG_SERVER, "ROM_ADMIN_WRONG_NAME", "^%s", "^%s", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_ADMIN_WRONG_NAME = %s%s : %sNu s-a gasit nici un admin care sa poarte acest nickname.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#else
			formatex(Line, charsmax(Line), "ROM_ADMIN_WRONG_NAME = %L^n", LANG_SERVER, "ROM_ADMIN_WRONG_NAME", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_ADMIN_WRONG_NAME = ^^3%s : ^^4Nu s-a gasit nici un admin care sa poarte acest nickname.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#endif
		
		formatex(Line, charsmax(Line), "ROM_ADMIN_WRONG_NAME_PRINT = %L^n", LANG_SERVER, "ROM_ADMIN_WRONG_NAME_PRINT", "^%s" );
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_ADMIN_WRONG_NAME_PRINT = %s : Nu s-a gasit nici un admin care sa poarte acest nickname.^n");
		}
		else
		{
			fputs(FilePointer, Line);
		}
			
		#if AMXX_VERSION_NUM < 183
			formatex(Line, charsmax(Line), "ROM_ADMIN_WRONG_PASS = %L^n", LANG_SERVER, "ROM_ADMIN_WRONG_PASS", "^%s", "^%s", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_ADMIN_WRONG_PASS = %s%s : %sParola introdusa de tine este incorecta.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#else
			formatex(Line, charsmax(Line), "ROM_ADMIN_WRONG_PASS = %L^n", LANG_SERVER, "ROM_ADMIN_WRONG_PASS", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_ADMIN_WRONG_PASS = ^^3%s : ^^4Parola introdusa de tine este incorecta.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#endif
		
		formatex(Line, charsmax(Line), "ROM_ADMIN_WRONG_PASS_PRINT = %L^n", LANG_SERVER, "ROM_ADMIN_WRONG_PASS_PRINT", "^%s" );
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_ADMIN_WRONG_PASS_PRINT = %s : Parola introdusa de tine este incorecta.^n");
		}
		else
		{
			fputs(FilePointer, Line);
		}
			
		#if AMXX_VERSION_NUM < 183
			formatex(Line, charsmax(Line), "ROM_ADMIN_LOADED = %L^n", LANG_SERVER, "ROM_ADMIN_LOADED", "^%s", "^%s", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_ADMIN_LOADED = %s%s : %sAdmin-ul tau a fost incarcat.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#else
			formatex(Line, charsmax(Line), "ROM_ADMIN_LOADED = %L^n", LANG_SERVER, "ROM_ADMIN_LOADED", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_ADMIN_LOADED = ^^3%s : ^^4Admin-ul tau a fost incarcat.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#endif
		
		formatex(Line, charsmax(Line), "ROM_ADMIN_LOADED_PRINT = %L^n", LANG_SERVER, "ROM_ADMIN_LOADED_PRINT", "^%s" );
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_ADMIN_LOADED_PRINT = %s : Admin-ul tau a fost incarcat.^n");
		}
		else
		{
			fputs(FilePointer, Line);
		}
			
		#if AMXX_VERSION_NUM < 183
			formatex(Line, charsmax(Line), "ROM_ADMIN_ALREADY_LOADED = %L^n", LANG_SERVER, "ROM_ADMIN_ALREADY_LOADED", "^%s", "^%s", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_ADMIN_ALREADY_LOADED = %s%s : %sAdmin-ul tau este deja incarcat.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#else
			formatex(Line, charsmax(Line), "ROM_ADMIN_ALREADY_LOADED = %L^n", LANG_SERVER, "ROM_ADMIN_ALREADY_LOADED", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_ADMIN_ALREADY_LOADED = ^^3%s : ^^4Admin-ul tau este deja incarcat.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#endif
		
		formatex(Line, charsmax(Line), "ROM_ADMIN_ALREADY_LOADED_PRINT = %L^n", LANG_SERVER, "ROM_ADMIN_ALREADY_LOADED_PRINT", "^%s" );
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_ADMIN_ALREADY_LOADED_PRINT = %s : Admin-ul tau este deja incarcat.^n");
		}
		else
		{
			fputs(FilePointer, Line);
		}


		#if AMXX_VERSION_NUM < 183
			formatex(Line, charsmax(Line), "ROM_ADMIN_WITHOUT_PASS = %L^n", LANG_SERVER, "ROM_ADMIN_WITHOUT_PASS", "^%s", "^%s", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_ADMIN_WITHOUT_PASS = %s%s : %sNu ai introdus nici o parola, comanda se scris in consola astfel : login ^"parola ta^".^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#else
			formatex(Line, charsmax(Line), "ROM_ADMIN_WITHOUT_PASS = %L^n", LANG_SERVER, "ROM_ADMIN_WITHOUT_PASS", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_ADMIN_WITHOUT_PASS = ^^3%s : ^^4Nu ai introdus nici o parola, comanda se scris in consola astfel : login ^"parola ta^".^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#endif
		
		formatex(Line, charsmax(Line), "ROM_ADMIN_WITHOUT_PASS_PRINT = %L^n", LANG_SERVER, "ROM_ADMIN_WITHOUT_PASS_PRINT", "^%s" );
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_ADMIN_WITHOUT_PASS_PRINT = %s : Nu ai introdus nici o parola, comanda se scris in consola astfel : login ^"parola ta^".^n");
		}
		else
		{
			fputs(FilePointer, Line); 
		}
			
		#if AMXX_VERSION_NUM < 183
			formatex(Line, charsmax(Line), "ROM_CMD_BUG = %L^n", LANG_SERVER, "ROM_CMD_BUG", "^%s", "^%s", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_CMD_BUG = %s%s : %sS-au observat caractere interzise in textul trimis de tine. Mesajul tau a fost eliminat.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#else
			formatex(Line, charsmax(Line), "ROM_CMD_BUG = %L^n", LANG_SERVER, "ROM_CMD_BUG", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_CMD_BUG = ^^3%s : ^^4S-au observat caractere interzise in textul trimis de tine. Mesajul tau a fost eliminat.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#endif	 
		
		formatex(Line, charsmax(Line), "ROM_CMD_BUG_LOG = %L^n", LANG_SERVER, "ROM_CMD_BUG_LOG", "^%s", "^%s", "^%s", "^%s" );
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_CMD_BUG_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"CMD_BUG^" ca sa strice buna functionare a serverului.^n");
		}
		else
		{
			fputs(FilePointer, Line);
		}
			
		formatex(Line, charsmax(Line), "ROM_CMD_BUG_PRINT = %L^n", LANG_SERVER, "ROM_CMD_BUG_PRINT", "^%s");
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_CMD_BUG_PRINT = %s : S-au observat caractere interzise in textul trimis de tine. Mesajul tau a fost eliminat.^n");
		}
		else
		{
			fputs(FilePointer, Line);
		}
	
		#if AMXX_VERSION_NUM < 183
			formatex(Line, charsmax(Line), "ROM_COLOR_BUG = %L^n", LANG_SERVER, "ROM_COLOR_BUG", "^%s", "^%s", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_COLOR_BUG = %s%s : %sS-au observat caractere suspecte in textul trimis de tine. Mesajul tau a fost eliminat.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#else
			formatex(Line, charsmax(Line), "ROM_COLOR_BUG = %L^n", LANG_SERVER, "ROM_COLOR_BUG", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_COLOR_BUG = ^^3%s : ^^4S-au observat caractere suspecte in textul trimis de tine. Mesajul tau a fost eliminat.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#endif
		
		formatex(Line, charsmax(Line), "ROM_COLOR_BUG_LOG = %L^n", LANG_SERVER, "ROM_COLOR_BUG_LOG", "^%s", "^%s", "^%s", "^%s" );
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			
			fputs(FilePointer, "ROM_COLOR_BUG_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"COLOR_BUG^" ca sa alerteze playerii sau adminii.^n");
		}
		else
		{
			fputs(FilePointer, Line);
		}
			
		formatex(Line, charsmax(Line), "ROM_COLOR_BUG_PRINT = %L^n", LANG_SERVER, "ROM_COLOR_BUG_PRINT", "^%s");
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_COLOR_BUG_PRINT = %s : S-au observat caractere suspecte in textul trimis de tine. Mesajul tau a fost eliminat.^n");
		}
		else
		{
			fputs(FilePointer, Line);
		}
			
		#if AMXX_VERSION_NUM < 183
			formatex(Line, charsmax(Line), "ROM_SPEC_BUG = %L^n", LANG_SERVER, "ROM_SPEC_BUG", "^%s", "^%s", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_SPEC_BUG = %s%s : %sAi facut o miscare suspecta asa ca te-am mutat la echipa precedenta.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#else
			formatex(Line, charsmax(Line), "ROM_SPEC_BUG = %L^n", LANG_SERVER, "ROM_SPEC_BUG", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_SPEC_BUG = ^^3%s : ^^4Ai facut o miscare suspecta asa ca te-am mutat la echipa precedenta.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#endif
		
		formatex(Line, charsmax(Line), "ROM_SPEC_BUG_LOG = %L^n", LANG_SERVER, "ROM_SPEC_BUG_LOG", "^%s", "^%s", "^%s", "^%s" );
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_SPEC_BUG_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"SPEC_BUG^" ca sa strice buna functionare a serverului.^n");
		}
		else
		{
			fputs(FilePointer, Line);
		}
			
		#if AMXX_VERSION_NUM < 183
			formatex(Line, charsmax(Line), "ROM_ADMIN_CHAT_FLOOD = %L^n", LANG_SERVER, "ROM_ADMIN_CHAT_FLOOD", "^%s", "^%s", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_ADMIN_CHAT_FLOOD = %s%s : %sS-a observat un mic IsFlooding la chat primit din partea ta. Mesajele trimise de tine vor fi filtrate.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}

			formatex(Line, charsmax(Line), "ROM_ADMIN_CHAT_FLOOD_LOG = %L^n", LANG_SERVER, "ROM_ADMIN_CHAT_FLOOD_LOG", "^%s", "^%s", "^%s", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_ADMIN_CHAT_FLOOD_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"ADMIN_CHAT_FLOOD^" ca sa dea kick adminilor de pe server.^n");	
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#endif
		
		#if AMXX_VERSION_NUM < 183
			formatex(Line, charsmax(Line), "ROM_AUTOBUY = %L^n", LANG_SERVER, "ROM_AUTOBUY", "^%s", "^%s", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_AUTOBUY = %s%s : %sComanda trimisa de tine are valori suspecte, asa ca am blocat-o.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#else
			formatex(Line, charsmax(Line), "ROM_AUTOBUY = %L^n", LANG_SERVER, "ROM_AUTOBUY", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_AUTOBUY = ^^3%s : ^^4Comanda trimisa de tine are valori suspecte, asa ca am blocat-o.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#endif
		
		formatex(Line, charsmax(Line), "ROM_AUTOBUY_LOG = %L^n", LANG_SERVER, "ROM_AUTOBUY_LOG", "^%s", "^%s", "^%s", "^%s" );
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_AUTOBUY_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"AUTOBUY_BUG^" ca sa strice buna functionare a serverului.^n");
		}
		else
		{
			fputs(FilePointer, Line);
		}
		
		formatex(Line, charsmax(Line), "ROM_FILE_NOT_FOUND = %L^n", LANG_SERVER, "ROM_FILE_NOT_FOUND", "^%s", "^%s" );
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_FILE_NOT_FOUND = %s : Fisierul %s nu exista.^n");
		}
		else
		{
			fputs(FilePointer, Line);
		}
			
		formatex(Line, charsmax(Line), "ROM_ADMIN_DEBUG = %L^n", LANG_SERVER, "ROM_ADMIN_DEBUG", "^%s", "^%s", "^%s", "^%s" );
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_ADMIN_DEBUG = Nume : %s - Parola : %s - Acces : %s - Flag : %s^n");
		}
		else
		{
			fputs(FilePointer, Line);
		}
			
		formatex(Line, charsmax(Line), "ROM_MOTDFILE = %L^n", LANG_SERVER, "ROM_MOTDFILE", "^%s" );
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_MOTDFILE = %s : S-a detectat o miscare suspecta din partea ta, comanda ta a fost blocata.^n");
		}
		else
		{
			fputs(FilePointer, Line);
		}
			
		formatex(Line, charsmax(Line), "ROM_MOTDFILE_LOG = %L^n", LANG_SERVER, "ROM_MOTDFILE_LOG", "^%s", "^%s", "^%s", "^%s" );
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_MOTDFILE_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca cvar-ul ^"motdfile^" ca sa fure informatii din acest server.^n");	
		}
		else
		{
			fputs(FilePointer, Line);
		}
			
		#if AMXX_VERSION_NUM < 183
			formatex(Line, charsmax(Line), "ROM_ADVERTISE = %L^n", LANG_SERVER, "ROM_ADVERTISE", "^%s", "^%s", "^%s", "^%s", "^%s", "^%s", "^%s", "^%s", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_ADVERTISE = %s%s :%s Acest server este supravegheat de plugin-ul de protectie %s%s%s versiunea %s%s%s .^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#else
			formatex(Line, charsmax(Line), "ROM_ADVERTISE = %L^n", LANG_SERVER, "ROM_ADVERTISE", "^%s", "^%s", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_ADVERTISE = ^^3%s :^^4 Acest server este supravegheat de plugin-ul de protectie ^^3%s^^4 versiunea ^^3%s^^4 .^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#endif
		
		formatex(Line, charsmax(Line), "ROM_ANTI_BAN_CLASS = %L^n", LANG_SERVER, "ROM_ANTI_BAN_CLASS", "^%s" );
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_ANTI_BAN_CLASS = %s : S-au detectat un numar prea mare de ban-uri pe clasa de ip, comanda ta a fost blocata.^n");
		}
		else
		{
			fputs(FilePointer, Line);
		}
		
		formatex(Line, charsmax(Line), "ROM_ANTI_ANY_BAN_CLASS_LOG = %L^n", LANG_SERVER, "ROM_ANTI_ANY_BAN_CLASS_LOG", "^%s", "^%s", "^%s", "^%s" );
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_ANTI_ANY_BAN_CLASS_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa dea ban pe clasa de ip.^n");	
		}
		else
		{
			fputs(FilePointer, Line);
		}
		
		formatex(Line, charsmax(Line), "ROM_ANTI_SOME_BAN_CLASS_LOG = %L^n", LANG_SERVER, "ROM_ANTI_SOME_BAN_CLASS_LOG", "^%s", "^%s", "^%s", "^%s", "^%s" );
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, Line);
		}
		else
		{
			fputs(FilePointer, "ROM_ANTI_SOME_BAN_CLASS_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa dea ban pe mai mult de %s clase de ip.^n");	
		}
		
		formatex(Line, charsmax(Line), "ROM_AUTO_UPDATE_SUCCEED = %L^n", LANG_SERVER, "ROM_AUTO_UPDATE_SUCCEED", "^%s");
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_AUTO_UPDATE_SUCCEED = %s : S-a efectuat auto-actualizarea pluginului.^n");	
		}
		else
		{
			fputs(FilePointer, Line);
		}
		
		formatex(Line, charsmax(Line), "ROM_AUTO_UPDATE_FAILED = %L^n", LANG_SERVER, "ROM_AUTO_UPDATE_FAILED", "^%s"); 
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_AUTO_UPDATE_FAILED = %s : S-a intampinat o eroare la descarcare, iar plugin-ul nu s-a putut auto-actualiza.^n");	
		}
		else
		{
			fputs(FilePointer, Line);
		}
		
		#if AMXX_VERSION_NUM < 183
			formatex(Line, charsmax(Line), "ROM_XFAKE_PLAYERS_SPAM_WARN = %L^n", LANG_SERVER, "ROM_XFAKE_PLAYERS_SPAM_WARN", "^%s", "^%s", "^%s");
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_XFAKE_PLAYERS_SPAM_WARN = %s%s : %sMesajul tau a fost eliminat pentru a elimina o tentativa de ^"BOT SPAM^".^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#else
			formatex(Line, charsmax(Line), "ROM_XFAKE_PLAYERS_SPAM_WARN = %L^n", LANG_SERVER, "ROM_XFAKE_PLAYERS_SPAM_WARN", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_XFAKE_PLAYERS_SPAM_WARN = ^^3%s : ^^4Mesajul tau a fost eliminat pentru a elimina o tentativa de ^"BOT SPAM^".^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#endif
		
		#if AMXX_VERSION_NUM < 183
			formatex(Line, charsmax(Line), "ROM_XFAKE_PLAYERS_SPAM = %L^n", LANG_SERVER, "ROM_XFAKE_PLAYERS_SPAM", "^%s", "^%s", "^%s", "^%s");
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_XFAKE_PLAYERS_SPAM = %s%s : %sS-a depistat o tentativa de ^"BOT SPAM^" de la ip-ul : %s .^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
			
			formatex(Line, charsmax(Line), "ROM_XFAKE_PLAYERS_SPAM_PUNISH = %L^n", LANG_SERVER, "ROM_XFAKE_PLAYERS_SPAM_PUNISH", "^%s", "^%s", "^%s", "^%s");
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_XFAKE_PLAYERS_SPAM_PUNISH = %s%s : %sIp-ul a primit ban %s minute pentru a nu afecta jocul.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}		
		#else
			formatex(Line, charsmax(Line), "ROM_XFAKE_PLAYERS_SPAM = %L^n", LANG_SERVER, "ROM_XFAKE_PLAYERS_SPAM", "^%s", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_XFAKE_PLAYERS_SPAM = ^^3%s : ^^4S-a depistat o tentativa de ^"BOT SPAM^" de la ip-ul : %s .^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
				
			formatex(Line, charsmax(Line), "ROM_XFAKE_PLAYERS_SPAM_PUNISH = %L^n", LANG_SERVER, "ROM_XFAKE_PLAYERS_SPAM_PUNISH", "^%s", "^%s");
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_XFAKE_PLAYERS_SPAM_PUNISH = ^^3%s : ^^4Ip-ul a primit ban %s minute pentru a nu afecta jocul.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#endif
		
		formatex(Line, charsmax(Line), "ROM_XFAKE_PLAYERS_SPAM_BAN = %L^n", LANG_SERVER, "ROM_XFAKE_PLAYERS_SPAM_BAN", "^%s", "^%s"  );
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_XFAKE_PLAYERS_SPAM_BAN = %s : Ai fost detectat ca fiind un bot xfake_player, asa ca ai fost banat pentru %s minute.^n");
		}
		else
		{
			fputs(FilePointer, Line);
		}
		
		formatex(Line, charsmax(Line), "ROM_XFAKE_PLAYERS_SPAM_KICK = %L^n", LANG_SERVER, "ROM_XFAKE_PLAYERS_SPAM_KICK", "^%s"  );
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_XFAKE_PLAYERS_SPAM_KICK = %s : Ai fost detectat ca fiind un bot xfake_player, asa ca ai primit kick.^n");
		}
		else
		{
			fputs(FilePointer, Line);
		}
		
		#if AMXX_VERSION_NUM < 183
			formatex(Line, charsmax(Line), "ROM_XFAKE_PLAYERS_SPAM_GAG = %L^n", LANG_SERVER, "ROM_XFAKE_PLAYERS_SPAM_GAG", "^%s", "^%s", "^%s");
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_XFAKE_PLAYERS_SPAM_GAG = %s%s : %sAi fost detectat ca fiind un bot xfake_player, nu vei mai putea folosi chat-ul pana nu te vei reconecta.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#else
			formatex(Line, charsmax(Line), "ROM_XFAKE_PLAYERS_SPAM_GAG = %L^n", LANG_SERVER, "ROM_XFAKE_PLAYERS_SPAM_GAG", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_XFAKE_PLAYERS_SPAM_GAG = ^^3%s : ^^4Ai fost detectat ca fiind un bot xfake_player, nu vei mai putea folosi chat-ul pana nu te vei reconecta.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#endif
		
		formatex(Line, charsmax(Line), "ROM_XFAKE_PLAYERS_SPAM_LOG = %L^n", LANG_SERVER, "ROM_XFAKE_PLAYERS_SPAM_LOG", "^%s", "^%s"  );
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_XFAKE_PLAYERS_SPAM_LOG = %s : S-a depistat un atac de ^"BOT SPAM^" de la IP-ul : %s .^n");
		}
		else
		{
			fputs(FilePointer, Line);
		}
		
		#if AMXX_VERSION_NUM < 183
			formatex(Line, charsmax(Line), "ROM_XFAKE_PLAYERS_ALLOW_USE_CHAT = %L^n", LANG_SERVER, "ROM_XFAKE_PLAYERS_ALLOW_USE_CHAT", "^%s", "^%s", "^%s");
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_XFAKE_PLAYERS_ALLOW_USE_CHAT = %s%s : %sAi introdus capcha-ul corect, acum vei putea folosi chat-ul.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#else
			formatex(Line, charsmax(Line), "ROM_XFAKE_PLAYERS_ALLOW_USE_CHAT = %L^n", LANG_SERVER, "ROM_XFAKE_PLAYERS_ALLOW_USE_CHAT", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_XFAKE_PLAYERS_ALLOW_USE_CHAT = ^^3%s : ^^4Ai introdus capcha-ul corect, acum vei putea folosi chat-ul.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#endif
		
		#if AMXX_VERSION_NUM < 183
			formatex(Line, charsmax(Line), "ROM_XFAKE_PLAYERS_CAPCHA = %L^n", LANG_SERVER, "ROM_XFAKE_PLAYERS_CAPCHA", "^%s", "^%s", "^%s", "^%s", "^%s", "^%s");
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_XFAKE_PLAYERS_CAPCHA = %s%s : %sPentru a folosi chat-ul scrie urmatorul cod : %s%s%s.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#else
			formatex(Line, charsmax(Line), "ROM_XFAKE_PLAYERS_CAPCHA = %L^n", LANG_SERVER, "ROM_XFAKE_PLAYERS_CAPCHA", "^%s", "^%s");
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_XFAKE_PLAYERS_CAPCHA = ^^3%s : ^^4Pentru a folosi chat-ul scrie urmatorul cod : ^^3%s^^4.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#endif
		
		formatex(Line, charsmax(Line), "ROM_PROTCVARS = %L^n", LANG_SERVER, "ROM_PROTCVARS", "^%s");
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_PROTCVARS = %s : Cvar-ururile acestui plugin sunt protejate, comanda ta nu a avut efect.^n");
		}
		else
		{
			fputs(FilePointer, Line);
		}
		
		formatex(Line, charsmax(Line), "ROM_PROTCVARS_LOG = %L^n", LANG_SERVER, "ROM_PROTCVARS_LOG", "^%s", "^%s", "^%s", "^%s");
		if ( contain(Line, "ML_NOTFOUND") != -1 )
		{
			fputs(FilePointer, "ROM_PROTCVARS_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa schimbe cvar-urile pluginului de protectie, astea pot fi schimbate doar din fisierul configurator.^n");	
		}
		else
		{
			fputs(FilePointer, Line);
		}
		
		fclose(FilePointer);
	}
	else
	{
		new FilePointer = fopen(LangFile, "wt");
		
		if ( !FilePointer ) 
		{
			return;
		}
		
		#if AMXX_VERSION_NUM < 183
			writeSignature(FilePointer);
		#else
			writeSignature(FilePointer, true);
		#endif
		
		fputs(FilePointer, "[en]^n^n");
		fputs(FilePointer, "ROM_UPDATE_CFG = %s : Am actualizat fisierul CFG : rom_protect.cfg.^n");
		fputs(FilePointer, "ROM_UPDATE_LANG = %s : Am actualizat fisierul LANG : rom_protect.txt.^n");
		
		#if AMXX_VERSION_NUM < 183
			fputs(FilePointer, "ROM_FAKE_PLAYERS = %s%s : %sS-a observat un numar prea mare de persoane de pe ip-ul : %s .^n");
			fputs(FilePointer, "ROM_FAKE_PLAYERS_PUNISH = %s%s : %sIp-ul a primit ban %s minute pentru a nu afecta jocul.^n");
		#else
			fputs(FilePointer, "ROM_FAKE_PLAYERS = ^^3%s : ^^4S-a observat un numar prea mare de persoane de pe ip-ul : %s .^n");
			fputs(FilePointer, "ROM_FAKE_PLAYERS_PUNISH = ^^3%s :^^4 Ip-ul a primit ban %s minute pentru a nu afecta jocul.^n");
		#endif
		
		fputs(FilePointer, "ROM_FAKE_PLAYERS_LOG = %s : S-a depistat un atac de ^"xFake-Players^" de la IP-ul : %s .^n");
		fputs(FilePointer, "ROM_FAKE_PLAYERS_KICK = %s : Nu poti intra pe server, deoarece sunt inca %s jucatori cu acelasi ip-ul ca al tau.^n");
		
		fputs(FilePointer, "ROM_FAKE_PLAYERS_DETECT = %s : Ai primit kick deoarece deoarece esti suspect de fake-client. Te rugam sa folosesti alt client.^n");
		fputs(FilePointer, "ROM_FAKE_PLAYERS_DETECT_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca suspect de ^"xFake-Players^" sau ^"xSpammer^".^n");
		
		#if AMXX_VERSION_NUM < 183
			fputs(FilePointer, "ROM_PLUGIN_PAUSE = %s%s : %sNe pare rau, dar din anumite motive, acest plugin nu poate fi pus pe pauza.^n");
		#else
			fputs(FilePointer, "ROM_PLUGIN_PAUSE = ^^3%s : ^^4Ne pare rau, dar din anumite motive, acest plugin nu poate fi pus pe pauza.^n");
		#endif
		
		fputs(FilePointer, "ROM_PLUGIN_PAUSE_LOG = %s : S-a depistat o incercare a opririi pluginului de protectie %s. Operatiune a fost blocata.^n");
		
		#if AMXX_VERSION_NUM < 183
			fputs(FilePointer, "ROM_ADMIN_WRONG_NAME = %s%s : %sNu s-a gasit nici un admin care sa poarte acest nickname.^n");
		#else
			fputs(FilePointer, "ROM_ADMIN_WRONG_NAME = ^^3%s : ^^4Nu s-a gasit nici un admin care sa poarte acest nickname.^n");
		#endif
		
		fputs(FilePointer, "ROM_ADMIN_WRONG_NAME_PRINT = %s : Nu s-a gasit nici un admin care sa poarte acest nickname.^n");
		
		#if AMXX_VERSION_NUM < 183
			fputs(FilePointer, "ROM_ADMIN_WRONG_PASS = %s%s : %sParola introdusa de tine este incorecta.^n");
		#else
			fputs(FilePointer, "ROM_ADMIN_WRONG_PASS = ^^3%s : ^^4Parola introdusa de tine este incorecta.^n");
		#endif
		
		fputs(FilePointer, "ROM_ADMIN_WRONG_PASS_PRINT = %s : Parola introdusa de tine este incorecta.^n");
		
		#if AMXX_VERSION_NUM < 183
			fputs(FilePointer, "ROM_ADMIN_LOADED = %s%s : %sAdmin-ul tau a fost incarcat.^n");
		#else
			fputs(FilePointer, "ROM_ADMIN_LOADED = ^^3%s : ^^4Admin-ul tau a fost incarcat.^n");
		#endif
		
		fputs(FilePointer, "ROM_ADMIN_LOADED_PRINT = %s : Admin-ul tau a fost incarcat.^n");
		
		#if AMXX_VERSION_NUM < 183
			fputs(FilePointer, "ROM_ADMIN_ALREADY_LOADED = %s%s : %sAdmin-ul tau este deja incarcat.^n");
		#else
			fputs(FilePointer, "ROM_ADMIN_ALREADY_LOADED = ^^3%s : ^^4Admin-ul tau este deja incarcat.^n");
		#endif
		
		fputs(FilePointer, "ROM_ADMIN_ALREADY_LOADED_PRINT = %s : Admin-ul tau este deja incarcat.^n");

		#if AMXX_VERSION_NUM < 183
			fputs(FilePointer, "ROM_ADMIN_WITHOUT_PASS = %s%s : %sNu ai introdus nici o parola, comanda se scris in consola astfel : login ^"parola ta^".^n");
		#else
			fputs(FilePointer, "ROM_ADMIN_WITHOUT_PASS = ^^3%s : ^^4Nu ai introdus nici o parola, comanda se scris in consola astfel : login ^"parola ta^".^n");
		#endif 
		
		fputs(FilePointer, "ROM_ADMIN_WITHOUT_PASS_PRINT = %s : Nu ai introdus nici o parola, comanda se scris in consola astfel : login ^"parola ta^".^n");

		#if AMXX_VERSION_NUM < 183
			fputs(FilePointer, "ROM_CMD_BUG = %s%s : %sS-au observat caractere interzise in textul trimis de tine. Mesajul tau a fost eliminat.^n");
		#else
			fputs(FilePointer, "ROM_CMD_BUG = ^^3%s : ^^4S-au observat caractere interzise in textul trimis de tine. Mesajul tau a fost eliminat.^n");
		#endif 
		
		fputs(FilePointer, "ROM_CMD_BUG_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"CMD_BUG^" ca sa strice buna functionare a serverului.^n");
		fputs(FilePointer, "ROM_CMD_BUG_PRINT = %s : S-au observat caractere interzise in textul trimis de tine. Mesajul tau a fost eliminat.^n");
		
		#if AMXX_VERSION_NUM < 183
			fputs(FilePointer, "ROM_COLOR_BUG = %s%s : %sS-au observat caractere suspecte in textul trimis de tine. Mesajul tau a fost eliminat.^n");
		#else
			fputs(FilePointer, "ROM_COLOR_BUG = ^^3%s : ^^4S-au observat caractere suspecte in textul trimis de tine. Mesajul tau a fost eliminat.^n");
		#endif
		
		fputs(FilePointer, "ROM_COLOR_BUG_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"COLOR_BUG^" ca sa alerteze playerii sau adminii.^n");
		fputs(FilePointer, "ROM_COLOR_BUG_PRINT = %s : S-au observat caractere suspecte in textul trimis de tine. Mesajul tau a fost eliminat.^n");		
		
		#if AMXX_VERSION_NUM < 183
			fputs(FilePointer, "ROM_SPEC_BUG = %s%s : %sAi facut o miscare suspecta asa ca te-am mutat la echipa precedenta.^n");
		#else
			fputs(FilePointer, "ROM_SPEC_BUG = ^^3%s : ^^4Ai facut o miscare suspecta asa ca te-am mutat la echipa precedenta.^n");
		#endif
		
		fputs(FilePointer, "ROM_SPEC_BUG_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"SPEC_BUG^" ca sa strice buna functionare a serverului.^n");
		
		#if AMXX_VERSION_NUM < 183
			fputs(FilePointer, "ROM_ADMIN_CHAT_FLOOD = %s%s : %sS-a observat un mic IsFlooding la chat primit din partea ta. Mesajele trimise de tine vor fi filtrate.^n");
			fputs(FilePointer, "ROM_ADMIN_CHAT_FLOOD_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"ADMIN_CHAT_FLOOD^" ca sa dea kick adminilor de pe server.^n");	
		#endif
		
		#if AMXX_VERSION_NUM < 183
			fputs(FilePointer, "ROM_AUTOBUY = %s%s : %sComanda trimisa de tine are valori suspecte, asa ca am blocat-o.^n");
		#else
			fputs(FilePointer, "ROM_AUTOBUY = ^^3%s : ^^4Comanda trimisa de tine are valori suspecte, asa ca am blocat-o.^n");
		#endif
		
		fputs(FilePointer, "ROM_AUTOBUY_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"AUTOBUY_BUG^" ca sa strice buna functionare a serverului.^n");
		
		fputs(FilePointer, "ROM_FILE_NOT_FOUND = %s : Fisierul %s nu exista.^n");
		
		fputs(FilePointer, "ROM_ADMIN_DEBUG = Nume : %s - Parola : %s - Acces : %s - Flag : %s^n");
		
		fputs(FilePointer, "ROM_MOTDFILE = %s : S-a detectat o miscare suspecta din partea ta, comanda ta a fost blocata.^n");
		fputs(FilePointer, "ROM_MOTDFILE_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca cvar-ul ^"motdfile^" ca sa fure informatii din acest server.^n");		
		
		#if AMXX_VERSION_NUM < 183
			fputs(FilePointer, "ROM_ADVERTISE = %s%s :%s Acest server este supravegheat de plugin-ul de protectie %s%s%s versiunea %s%s%s .^n");
		#else
			fputs(FilePointer, "ROM_ADVERTISE = ^^3%s :^^4 Acest server este supravegheat de plugin-ul de protectie ^^3%s^^4 versiunea ^^3%s^^4 .^n");
		#endif
		
		fputs(FilePointer, "ROM_ANTI_BAN_CLASS = %s : S-au detectat u numar prea mare de ban-uri pe clasa de ip, comanda ta a fost blocata.^n");
		fputs(FilePointer, "ROM_ANTI_ANY_BAN_CLASS_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa dea ban pe clasa de ip.^n");	
		fputs(FilePointer, "ROM_ANTI_SOME_BAN_CLASS_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa dea ban pe mai mult de %s clase de ip.^n");

		fputs(FilePointer, "ROM_AUTO_UPDATE_SUCCEED = %s : S-a efectuat auto-actualizarea pluginului.^n");	
		fputs(FilePointer, "ROM_AUTO_UPDATE_FAILED = %s : S-a intampinat o eroare la descarcare, iar plugin-ul nu s-a putut auto-actualiza.^n");	
		
		#if AMXX_VERSION_NUM < 183
			fputs(FilePointer, "ROM_XFAKE_PLAYERS_SPAM_WARN = %s%s : %sMesajul tau a fost eliminat pentru a elimina o tentativa de ^"BOT SPAM^".^n");
		#else
			fputs(FilePointer, "ROM_XFAKE_PLAYERS_SPAM_WARN = ^^3%s : ^^4Mesajul tau a fost eliminat pentru a elimina o tentativa de ^"BOT SPAM^".^n");
		#endif
		
		#if AMXX_VERSION_NUM < 183
			fputs(FilePointer, "ROM_XFAKE_PLAYERS_SPAM = %s%s : %sS-a depistat o tentativa de ^"BOT SPAM^" de la ip-ul : %s .^n");
			fputs(FilePointer, "ROM_XFAKE_PLAYERS_SPAM_PUNISH = %s%s : %sIp-ul a primit ban %s minute pentru a nu afecta jocul.^n");
		#else
			fputs(FilePointer, "ROM_XFAKE_PLAYERS_SPAM = ^^3%s : ^^4S-a depistat o tentativa de ^"BOT SPAM^" de la ip-ul : %s .^n");
			fputs(FilePointer, "ROM_XFAKE_PLAYERS_SPAM_PUNISH = ^^3%s : ^^4Ip-ul a primit ban %s minute pentru a nu afecta jocul.^n");
		#endif
		
		fputs(FilePointer, "ROM_XFAKE_PLAYERS_SPAM_BAN = %s : Ai fost detectat ca fiind un bot xfake_player, asa ca ai fost banat pentru %s minute.^n");
		fputs(FilePointer,"ROM_XFAKE_PLAYERS_SPAM_KICK = %s : Ai fost detectat ca fiind un bot xfake_player, asa ca ai primit kick.^n");
		
		#if AMXX_VERSION_NUM < 183
			fputs(FilePointer, "ROM_XFAKE_PLAYERS_SPAM_GAG = %s%s : %sAi fost detectat ca fiind un bot xfake_player, nu vei mai putea folosi chat-ul pana nu te vei reconecta.^n");
		#else
			fputs(FilePointer, "ROM_XFAKE_PLAYERS_SPAM_GAG = ^^3%s : ^^4Ai fost detectat ca fiind un bot xfake_player, nu vei mai putea folosi chat-ul pana nu te vei reconecta.^n");
		#endif
		
		fputs(FilePointer, "ROM_XFAKE_PLAYERS_SPAM_LOG = %s : S-a depistat un atac de ^"BOT SPAM^" de la IP-ul : %s .^n");
		
		#if AMXX_VERSION_NUM < 183
			fputs(FilePointer, "ROM_XFAKE_PLAYERS_ALLOW_USE_CHAT = %s%s : %sAi introdus capcha-ul corect, acum vei putea folosi chat-ul.^n");
		#else
			fputs(FilePointer, "ROM_XFAKE_PLAYERS_ALLOW_USE_CHAT = ^^3%s : ^^4Ai introdus capcha-ul corect, acum vei putea folosi chat-ul.^n");
		#endif
		
		#if AMXX_VERSION_NUM < 183
			fputs(FilePointer, "ROM_XFAKE_PLAYERS_CAPCHA = %s%s : %sPentru a folosi chat-ul scrie urmatorul cod : %s%s%s.^n");
		#else
			fputs(FilePointer, "ROM_XFAKE_PLAYERS_CAPCHA = ^^3%s : ^^4Pentru a folosi chat-ul scrie urmatorul cod : ^^3%s^^4.^n");
		#endif
		
		fputs(FilePointer, "ROM_PROTCVARS = %s : Cvar-ururile acestui plugin sunt protejate, comanda ta nu a avut efect.^n");
		fputs(FilePointer, "ROM_PROTCVARS_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa schimbe cvar-urile pluginului de protectie, astea pot fi schimbate doar din fisierul configurator.^n");
		
		fclose(FilePointer);
	}
	
	register_dictionary("rom_protect.txt");
	IsLangUsed = true;
}
#if AMXX_VERSION_NUM < 183
	writeSignature(FilePointer)
#else
	writeSignature(FilePointer, bool:isLangFile = false)
#endif
{
	fputs(FilePointer, "// *ROM-Protect");
	fputs(FilePointer, "// Plugin OpenSource anti-IsFlooding/bug-fix pentru orice server. ^n");
	fprintf(FilePointer, "// Versiunea : %s. Bulid : %d. Data lansarii versiunii : %s.^n", Version, Build, Date); 
	fputs(FilePointer, "// Autor : lüxor # Dr.Fio & DR2.IND (+ eNd.) - SteamID (contact) : luxxxoor^n");
	fputs(FilePointer, "// O productie FioriGinal.ro - site : www.fioriginal.ro^n");
	fputs(FilePointer, "// Link forum de dezvoltare : http://forum.fioriginal.ro/amxmodx-plugins-pluginuri/rom-protect-anti-flood-bug-fix-t28292.html^n");
	fputs(FilePointer, "// Link sursa : https://github.com/luxxxoor/ROM-Protect^n");
	#if AMXX_VERSION_NUM >= 183
		if ( isLangFile )
		{
			fputs(FilePointer, "^n// Colori : ^^1 - Culoarea aleasa de jucator cu con_color.^n");
			fputs(FilePointer, "//          ^^3 - Culoare gri.^n");
			fputs(FilePointer, "//          ^^4 - Culoare verde.^n");
		}
	#endif
	fputs(FilePointer, "^n^n^n");
}

// header http2.inc
#if defined _http2_included
	#endinput
#endif
#define _http2_included

#include <sockets>
#include <engine>
#include <regex>

/*
* HTTP2
* v2.40
* By [ --{-@ ] Black Rose
*
* Based on HTTP v0.4 by Bugsy
*/

#if !defined HTTP2_MAX_DOWNLOAD_SLOTS
	#define HTTP2_MAX_DOWNLOAD_SLOTS	4
#endif

#if !defined HTTP2_BUFFER_SIZE
	#define HTTP2_BUFFER_SIZE			32768
#endif

#if !defined HTTP2_THINK_INTERVAL
	#define HTTP2_THINK_INTERVAL		0.01
#endif

#if !defined HTTP2_QUE_INTERVAL
	#define HTTP2_QUE_INTERVAL			1.0
#endif

#if !defined HTTP2_Version
	#define HTTP2_Version				2.40
#endif

#if !defined HTTP2_VersionNum
	#define HTTP2_VersionNum			240
#endif

#if !defined HTTP2_VersionString
	#define HTTP2_VersionString			"2.40"
#endif

#define _HTTP2_STATUS_ACTIVE			(1<<0)
#define _HTTP2_STATUS_FIRSTRUN			(1<<1)
#define _HTTP2_STATUS_CHUNKED_TRANSFER	(1<<2)
#define _HTTP2_STATUS_LARGE_SIZE		(1<<3)

#define _HTTP2_ishex(%0) ( ( '0' <= %0 <= '9' || 'a' <= %0 <= 'f' || 'A' <= %0 <= 'F' ) ? true : false)
#define _HTTP2_isurlsafe(%0) ( ( '0' <= %0 <= '9' || 'a' <= %0 <= 'z' || 'A' <= %0 <= 'Z' || %0 == '-' || %0 == '_' || %0 == '.' || %0 == '~' || %0 == '%' || %0 == ' ' ) ? true : false)
#define _HTTP2_ctod(%0) ( '0' <= %0 <= '9' ? %0 - '0' : 'A' <= %0 <= 'Z' ? %0 -'A' + 10 : 'a' <= %0 <= 'z' ? %0 -'a' + 10 : 0 )
#define _HTTP2_dtoc(%0) ( 0 <= %0 <= 9 ? %0 + '0' : 10 <= %0 <= 35 ? %0 + 'A' - 10 : 0 )

#define REQUEST_GET		0
#define REQUEST_POST	1
#define REQUEST_HEAD	2

new const _HTTP2_RequestTypes[][] = {
	"GET",
	"POST",
	"HEAD"
};

new const _HTTP2_Base64Table[] =
/*
*0000000000111111111122222222223333333333444444444455555555556666
*0123456789012345678901234567890123456789012345678901234567890123*/
"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

enum _HTTP2_ItemDataEnum {
	_FileName[128],
	_BytesReceived,
	_BytesReceivedLarge[16],
	_Filesize,
	_FilesizeLarge[16],
	_hFile,
	_hSocket,
	_hProgressHandler,
	_hCompleteHandler,
	_Port,
	_Status,
	_RequestType,
	_EndOfChunk,
	_PostVars[1024]
}

enum _HTTP2_URLDataEnum {
	_Scheme[10],
	_Host[128],
	_URLPort,
	_User[128],
	_Pass[128],
	_Path[128],
	_Query[256],
	_Fragment[128]
};

enum _HTTP2_QueDataEnum {
	_QueURL[512],
	_QueFilename[128],
	_QueCompleteHandler[33],
	_QueProgressHandler[33],
	_QuePort,
	_QueRequestType,
	_QueUsername[128],
	_QuePassword[128],
	_QuePostVars[1024]
};

new _gHTTP2_Information[HTTP2_MAX_DOWNLOAD_SLOTS][_HTTP2_ItemDataEnum];
new _gHTTP2_URLParsed[HTTP2_MAX_DOWNLOAD_SLOTS][_HTTP2_URLDataEnum];
new _gHTTP2_QueData[_HTTP2_QueDataEnum];
new _gHTTP2_DataBuffer[HTTP2_BUFFER_SIZE];
new _gHTTP2_BufferLen;

new _gHTTP2_ReturnDummy;
new _gHTTP2_DownloadEntity;
new _gHTTP2_BufferSizeLarge[16];
new _gHTTP2_OneLarge[1];
new bool:_gHTTP2_Initialized;

new _gHTTP2_PostVars[1024];

new Array:_gHTTP2_Que_hArray;

new _gHTTP2_QueEntity;
new bool:_gHTTP2_QueInitialized;

/*
* HTTP2_isFilesizeLarge(Index)
*
* If the filesize in bytes is beyond the limitations of integers the function will return true.
*/
stock bool:HTTP2_isFilesizeLarge(Index)
	return _gHTTP2_Information[Index][_Status] & _HTTP2_STATUS_LARGE_SIZE ? true : false;

/*
* HTTP2_getBytesReceived(Index)
*
* Returns total ammount of bytes received for Index.
*/
stock HTTP2_getBytesReceived(Index)
	return _gHTTP2_Information[Index][_BytesReceived];

/*
* HTTP2_getBytesReceivedLarge(Index, string[], len)
*
* Formats total ammount of bytes received for Index in string form.
*/
stock HTTP2_getBytesReceivedLarge(Index, string[], len)
	_HTTP2_large_tostring(_gHTTP2_Information[Index][_BytesReceivedLarge], sizeof _gHTTP2_Information[][_BytesReceivedLarge], string, len);

/*
* HTTP2_getNewBytesReceived()
*
* Returns the ammount of bytes that was received in this chunk.
*/
stock HTTP2_getNewBytesReceived()
	return _gHTTP2_BufferLen;

/*
* HTTP2_getFilesize(Index)
*
* Returns the filesize of Index.
* If unknown it will return -1.
*/
stock HTTP2_getFilesize(Index)
	return _gHTTP2_Information[Index][_Filesize];

/*
* HTTP2_getFilesizeLarge(Index, string[], len)
*
* Formats the large filesize of Index in string form.
*/
stock HTTP2_getFilesizeLarge(Index, string[], len)
	_HTTP2_large_tostring(_gHTTP2_Information[Index][_FilesizeLarge], sizeof _gHTTP2_Information[][_FilesizeLarge], string, len);

/*
* HTTP2_getFilename(Index)
*
* Returns the filename of Index.
*/
stock HTTP2_getFilename(Index, name[], len)
	copy(name, len, _gHTTP2_Information[Index][_FileName]);

/*
* HTTP2_getData(Data[], len, &datalen)
*
* Fills variable Data[] with the last chunk downloaded.
* len decides the maximum size of Data[].
* datalen will return the ammount of bytes that was received in this chunk.
*
* For performance reasons HTTP2_getData2() should be used whenever possible.
*/
stock HTTP2_getData(Dest[], len, &datalen) {
	
	static _HTTP2_getData_i, _HTTP2_getData_max;
	
	_HTTP2_getData_max = min(len, _gHTTP2_BufferLen);
	
	Dest[len] = 0;
	datalen = _gHTTP2_BufferLen;
	
	for ( _HTTP2_getData_i = 0 ; _HTTP2_getData_i <= _HTTP2_getData_max ; _HTTP2_getData_i++ )
		Dest[_HTTP2_getData_i] = _gHTTP2_DataBuffer[_HTTP2_getData_i];
}

/*
* HTTP2_getDataUnsafe()
* HTTP2_getData2()
*
* This is a direct connection to the data buffer.
* This will be faster because you don't need to spend time copying data between 2 buffers just to read it.
*
* Since the forward is called after the data has been written you don't need to worry about corrupting it.
* So it's not really unsafe.
*/
#define HTTP2_getDataUnsafe() _gHTTP2_DataBuffer
#define HTTP2_getData2() _gHTTP2_DataBuffer

/*
* HTTP2_UpdatePlugin(const URL[])
*
* Updates current plugin with binary from chosen URL.
*/
stock HTTP2_UpdatePlugin(const URL[]) {
	new tempfile[14];
	do
		formatex(tempfile, charsmax(tempfile), "temp%d.amxx", random_num(1000,9999));
	while ( file_exists(tempfile) )
	HTTP2_Download(URL, tempfile, "_HTTP2_PluginUpdater_Complete");
}

/*
* HTTP2_Abort(Index, bool:DeleteFile = true)
*
* Aborts the transfer of selected download index.
* If DeleteFile is set to true the partially downloaded file will be deleted.
*/
stock HTTP2_Abort(Index, bool:DeleteFile = true) {
	_HTTP2_TransferDone(Index, 0, false);
	
	if ( DeleteFile && _gHTTP2_Information[Index][_FileName] && file_exists(_gHTTP2_Information[Index][_FileName]) )
		delete_file(_gHTTP2_Information[Index][_FileName]);
}

/*
* HTTP2_AddPostVar(const variable[], const value[])
*
* Adds a POST variable to the header.
* This function is used before HTTP2_Download() or HTTP_AddToQue(), similar to set/show hudmessage.
* It can be used multiple times before each download.
*/
stock HTTP2_AddPostVar(const variable[], const value[]) {
	
	static _HTTP2_var[1024], _HTTP2_val[1024];
	new len = strlen(_gHTTP2_PostVars);
	
	copy(_HTTP2_var, charsmax(_HTTP2_var), variable);
	copy(_HTTP2_val, charsmax(_HTTP2_val), value);
	
	_HTTP2_URLEncode(_HTTP2_var, charsmax(_HTTP2_var));
	_HTTP2_URLEncode(_HTTP2_val, charsmax(_HTTP2_val));
	
	formatex(_gHTTP2_PostVars[len], charsmax(_gHTTP2_PostVars) - len, "%s%s=%s", len ? "&" : "", _HTTP2_var, _HTTP2_val);
}

/*
* Number of parameters for the callbacks are 1 (Index) for the progress event and 2 (Index, Error) for the complete event.
* Error codes:
*     0   Download done. No problems encountered.
* Positive returns is unhandled HTTP return codes. For example 404.
* Negative is internal errors.
*    -1   No response code was found in the HTTP response header or it was outside the accepted range (200-307).
*    -2   Server is sending bad data or sizes for a chunked transfer or HTTP2 has problems reading them.
*    -3   Nothing received in last packet. Most likely due to an error.
*    -4   HTTP2 was redirected but could not follow due to a socket error.
*/

/*
* HTTP2_Download(const URL[], const Filename[] = "", const CompleteHandler[] = "", const ProgressHandler[] = "", Port = (80<<443), RequestType = REQUEST_GET, const Username[] = "", const Password[] = "", ...)
*
* Begins download of a URL. Read parameters for information.
*
*
* Parameters:
*
*   const URL[]
*      URL that you want to download.
*
*   (Optional) const Filename[]
*      Where should the information be stored? If no filename is entered it will download as a "stream".
*      This means the data will be thrown away after it passes the buffer.
*      You can read the data on progress forward and make use of it there.
*
*   (Optional) const CompleteHandler[] = ""
*      The function you want called when the download is complete.
*
*   (Optional) const ProgressHandler[] = ""
*      The function you want called when the download is in progress.
*      This will be called every downloaded chunk
*
*   (Optional) Port = (80<<443)
*      The port that should be used.
*      If this is left at default it will use 80 for http.
*
*   (Optional) RequestType = REQUEST_GET
*      What type of request should be used.
*      If this is left at default it will use GET.
*      Possible values so far are REQUEST_GET and REQUEST_POST.
*
*   (Optional) const Username[] = ""
*   (Optional) const Password[] = ""
*      These are used to login to sites that require you to.
*      It's only used for Basic authentication, not POST for example.
*
* Returns an index of the download that may be used to abort the download.
*/
stock HTTP2_Download(const URL[], const Filename[] = "", const CompleteHandler[] = "", const ProgressHandler[] = "", Port = (80<<443), RequestType = REQUEST_GET, const Username[] = "", const Password[] = "", ... /* For possible future use */) {
	
	if ( ! Filename[0] && ! ProgressHandler[0] ) {
		log_amx("[HTTP2] Filename or progress handler is missing.");
		return -1;
	}
	
	new i;
	while ( i < HTTP2_MAX_DOWNLOAD_SLOTS && ( _gHTTP2_Information[i][_Status] & _HTTP2_STATUS_ACTIVE ) ) { i++; }
	
	if ( i == HTTP2_MAX_DOWNLOAD_SLOTS ) {
		log_amx("[HTTP2] Out of free download slots.");
		_gHTTP2_PostVars[0] = 0;
		return -1;
	}
	
	_HTTP2_ParseURL(URL,
	_gHTTP2_URLParsed[i][_Scheme], charsmax(_gHTTP2_URLParsed[][_Scheme]),
	_gHTTP2_URLParsed[i][_User], charsmax(_gHTTP2_URLParsed[][_User]),
	_gHTTP2_URLParsed[i][_Pass], charsmax(_gHTTP2_URLParsed[][_Pass]),
	_gHTTP2_URLParsed[i][_Host], charsmax(_gHTTP2_URLParsed[][_Host]),
	_gHTTP2_URLParsed[i][_URLPort],
	_gHTTP2_URLParsed[i][_Path], charsmax(_gHTTP2_URLParsed[][_Path]),
	_gHTTP2_URLParsed[i][_Query], charsmax(_gHTTP2_URLParsed[][_Query]),
	_gHTTP2_URLParsed[i][_Fragment], charsmax(_gHTTP2_URLParsed[][_Fragment]));
	
	_gHTTP2_Information[i][_Port] = _gHTTP2_URLParsed[i][_URLPort] ? _gHTTP2_URLParsed[i][_URLPort] : Port == (80<<443) ? equali(_gHTTP2_URLParsed[i][_Scheme], "https") ? 443 : 80 : Port;
	
	if ( ! _gHTTP2_URLParsed[i][_User] )
		copy(_gHTTP2_URLParsed[i][_User], charsmax(_gHTTP2_URLParsed[][_User]), Username);
	
	if ( ! _gHTTP2_URLParsed[i][_Pass] )
		copy(_gHTTP2_URLParsed[i][_Pass], charsmax(_gHTTP2_URLParsed[][_Pass]), Password);
	
	if ( ! Filename[0] )
	_gHTTP2_Information[i][_hFile] = 0;
	else if ( ! ( _gHTTP2_Information[i][_hFile] = fopen(Filename, "wb") ) ) {
		log_amx("[HTTP2] Error creating local file.");
		_gHTTP2_PostVars[0] = 0;
		return -1;
	}
	
	static _HTTP2_Plugin[64];
	get_plugin(-1 , _HTTP2_Plugin, charsmax(_HTTP2_Plugin), "", 0, "", 0, "", 0, "", 0);
	new ResultNum = find_plugin_byfile(_HTTP2_Plugin, 0);
	
	if ( ProgressHandler[0] )
		_gHTTP2_Information[i][_hProgressHandler] = CreateOneForward(ResultNum, ProgressHandler, FP_CELL);
	if ( CompleteHandler[0] )
		_gHTTP2_Information[i][_hCompleteHandler] = CreateOneForward(ResultNum, CompleteHandler, FP_CELL, FP_CELL);
	
	_gHTTP2_Information[i][_hSocket] = socket_open(_gHTTP2_URLParsed[i][_Host], _gHTTP2_Information[i][_Port], SOCKET_TCP, ResultNum);
	
	if ( ResultNum ) {
		switch ( ResultNum ) {
			case 1: log_amx("[HTTP2] Socket error: Error while creating socket.");
			case 2: log_amx("[HTTP2] Socket error: Couldn't resolve hostname. (%s)", _gHTTP2_URLParsed[i][_Host]);
			case 3: log_amx("[HTTP2] Socket error: Couldn't connect to host. (%s:%d)", _gHTTP2_URLParsed[i][_Host], _gHTTP2_Information[i][_Port]);
		}
		_gHTTP2_PostVars[0] = 0;
		return -1;
	}
	
	static _HTTP2_Request[2048], _HTTP2_Auth[256], _HTTP2_TempStr[256], _HTTP2_TempScheme[10];
	
	copy(_HTTP2_TempScheme, charsmax(_HTTP2_TempScheme), _gHTTP2_URLParsed[i][_Scheme]);
	strtoupper(_HTTP2_TempScheme);
	
	new RequestLen = formatex(_HTTP2_Request, charsmax(_HTTP2_Request), "%s /%s%s%s%s%s %s/1.1^r^nHost: %s", _HTTP2_RequestTypes[RequestType], _gHTTP2_URLParsed[i][_Path], _gHTTP2_URLParsed[i][_Query] ? "?" : "", _gHTTP2_URLParsed[i][_Query], _gHTTP2_URLParsed[i][_Fragment] ? "#" : "", _gHTTP2_URLParsed[i][_Fragment], _HTTP2_TempScheme, _gHTTP2_URLParsed[i][_Host]);
	
	if ( _gHTTP2_URLParsed[i][_User] || _gHTTP2_URLParsed[i][_Pass] ) {
		formatex(_HTTP2_TempStr, charsmax(_HTTP2_TempStr), "%s:%s", _gHTTP2_URLParsed[i][_User], _gHTTP2_URLParsed[i][_Pass]);
		_HTTP2_Encode64(_HTTP2_TempStr, _HTTP2_Auth, charsmax(_HTTP2_Auth));
	
		RequestLen += formatex(_HTTP2_Request[RequestLen], charsmax(_HTTP2_Request) - RequestLen, "^r^nAuthorization: Basic %s", _HTTP2_Auth);
	}
	
	if ( RequestType == REQUEST_POST && _gHTTP2_PostVars[0] ) {
		RequestLen += formatex(_HTTP2_Request[RequestLen], charsmax(_HTTP2_Request) - RequestLen, "^r^nContent-Length: %d", strlen(_gHTTP2_PostVars));
		RequestLen += formatex(_HTTP2_Request[RequestLen], charsmax(_HTTP2_Request) - RequestLen, "^r^nContent-Type: application/x-www-form-urlencoded");
		RequestLen += formatex(_HTTP2_Request[RequestLen], charsmax(_HTTP2_Request) - RequestLen, "^r^n^r^n%s", _gHTTP2_PostVars);
		copy(_gHTTP2_Information[i][_PostVars], charsmax(_gHTTP2_Information[][_PostVars]), _gHTTP2_PostVars);
		_gHTTP2_PostVars[0] = 0;
	}
	
	formatex(_HTTP2_Request[RequestLen], charsmax(_HTTP2_Request) - RequestLen, "^r^n^r^n");
	
	socket_send(_gHTTP2_Information[i][_hSocket], _HTTP2_Request, strlen(_HTTP2_Request));
	
	if ( ! _gHTTP2_DownloadEntity ) {
		_gHTTP2_DownloadEntity = create_entity("info_target");
		
		if ( ! _gHTTP2_DownloadEntity ) {
			log_amx("[HTTP2] Failed to create entity.");
			_gHTTP2_PostVars[0] = 0;
			return -1;
		}
		
		entity_set_string(_gHTTP2_DownloadEntity, EV_SZ_classname, "http2_downloadentity");
		entity_set_float(_gHTTP2_DownloadEntity, EV_FL_nextthink, get_gametime() + HTTP2_THINK_INTERVAL);
	}
	
	if ( ! _gHTTP2_Initialized ) {
		register_think("http2_downloadentity", "_HTTP2_DownloadThread");
		_HTTP2_large_fromint(_gHTTP2_BufferSizeLarge, sizeof _gHTTP2_BufferSizeLarge, HTTP2_BUFFER_SIZE);
		_gHTTP2_Initialized = true;
	}
	
	copy(_gHTTP2_Information[i][_FileName], charsmax(_gHTTP2_Information[][_FileName]), Filename);
	_gHTTP2_Information[i][_Status] = _HTTP2_STATUS_ACTIVE;
	_gHTTP2_Information[i][_Status] |= _HTTP2_STATUS_FIRSTRUN;
	_gHTTP2_Information[i][_RequestType] = RequestType;
	
	return i;
}

/*
* HTTP2_AddToQue(const URL[], const Filename[] = "", const CompleteHandler[] = "", const ProgressHandler[] = "", Port = (80<<443), RequestType = REQUEST_GET, const Username[] = "", const Password[] = "", ...)
*
* Ques up an item to be downloaded. Formatted exactly like HTTP2_Download().
* Use this when you're looping through a lot of downloads to avoid filling up the download slots.
* This function will not generate a direct error. The errors will occur at HTTP2_Download().
*
* Returns position in que.
*/
stock HTTP2_AddToQue(const URL[], const Filename[] = "", const CompleteHandler[] = "", const ProgressHandler[] = "", Port = (80<<443), RequestType = REQUEST_GET, const Username[] = "", const Password[] = "", ... /* For possible future use */) {
	
	if ( ! _gHTTP2_QueInitialized ) {
		_gHTTP2_Que_hArray = ArrayCreate(sizeof _gHTTP2_QueData, 10);
		register_think("http2_queentity", "_HTTP2_QueThread");
		_gHTTP2_QueInitialized = true;
	}
	
	copy(_gHTTP2_QueData[_QueURL], charsmax(_gHTTP2_QueData[_QueURL]), URL);
	copy(_gHTTP2_QueData[_QueFilename], charsmax(_gHTTP2_QueData[_QueFilename]), Filename);
	copy(_gHTTP2_QueData[_QueCompleteHandler], charsmax(_gHTTP2_QueData[_QueCompleteHandler]), CompleteHandler);
	copy(_gHTTP2_QueData[_QueProgressHandler], charsmax(_gHTTP2_QueData[_QueProgressHandler]), ProgressHandler);
	copy(_gHTTP2_QueData[_QueUsername], charsmax(_gHTTP2_QueData[_QueUsername]), Username);
	copy(_gHTTP2_QueData[_QuePassword], charsmax(_gHTTP2_QueData[_QuePassword]), Password);
	
	_gHTTP2_QueData[_QuePort] = Port;
	_gHTTP2_QueData[_QueRequestType] = RequestType;
	
	if ( RequestType == REQUEST_POST && _gHTTP2_PostVars[0] ) {
		copy(_gHTTP2_QueData[_QuePostVars], charsmax(_gHTTP2_QueData[_QuePostVars]), _gHTTP2_PostVars);
		_gHTTP2_PostVars[0] = 0;
	}
	
	ArrayPushArray(_gHTTP2_Que_hArray, _gHTTP2_QueData);
	
	if ( ! _gHTTP2_QueEntity ) {
		_gHTTP2_QueEntity = create_entity("info_target");
		
		if ( ! _gHTTP2_QueEntity ) {
			log_amx("[HTTP2] Failed to create entity.");
			return -1;
		}
		
		entity_set_string(_gHTTP2_QueEntity, EV_SZ_classname, "http2_queentity");
		entity_set_float(_gHTTP2_QueEntity, EV_FL_nextthink, get_gametime() + HTTP2_QUE_INTERVAL);
	}
	
	return ArraySize(_gHTTP2_Que_hArray);
}

public _HTTP2_DownloadThread(ent) {
	
	static _HTTP2_Index;
	
	for ( _HTTP2_Index = 0 ; _HTTP2_Index < HTTP2_MAX_DOWNLOAD_SLOTS ; _HTTP2_Index++ ) {
		
		if ( ! ( _gHTTP2_Information[_HTTP2_Index][_Status] & _HTTP2_STATUS_ACTIVE ) )
			continue;
		
		if ( ! socket_change(_gHTTP2_Information[_HTTP2_Index][_hSocket], 1000) )
			continue;
		
		if ( _gHTTP2_Information[_HTTP2_Index][_Status] & _HTTP2_STATUS_CHUNKED_TRANSFER &&
			_gHTTP2_Information[_HTTP2_Index][_BytesReceived] == _gHTTP2_Information[_HTTP2_Index][_EndOfChunk] ) {
			
			new tempdata[1], strHex[6], i, bool:error;
			
			while ( ! error ) {
				socket_recv(_gHTTP2_Information[_HTTP2_Index][_hSocket], tempdata, 2);
				
				switch ( tempdata[0] ) {
					case '^n' : {
						if ( i )
							break;
					}
					case '^r' : {}
					default : {
						if ( _HTTP2_ishex(tempdata[0]) )
							strHex[i++] = tempdata[0];
						else
							error = true;
					}
				}
			}
			
			if ( error ) {
				_HTTP2_TransferDone(_HTTP2_Index, -2, true);
				continue;
			}
			
			_HTTP2_GetChunkSize(strHex, _gHTTP2_Information[_HTTP2_Index][_EndOfChunk]);
			
			if ( ! _gHTTP2_Information[_HTTP2_Index][_EndOfChunk] ) {
				_gHTTP2_Information[_HTTP2_Index][_Filesize] = _gHTTP2_Information[_HTTP2_Index][_BytesReceived];
				_HTTP2_TransferDone(_HTTP2_Index, 0, true);
				continue;
			}
			
			_gHTTP2_Information[_HTTP2_Index][_EndOfChunk] += _gHTTP2_Information[_HTTP2_Index][_BytesReceived];
		}
		
		static HTTP2_tempLarge[16];
		new tempsize;
		
		if ( _gHTTP2_Information[_HTTP2_Index][_Status] & _HTTP2_STATUS_FIRSTRUN )
			tempsize = 2048;
		else {
			if ( _gHTTP2_Information[_HTTP2_Index][_Status] & _HTTP2_STATUS_CHUNKED_TRANSFER )
				tempsize = min(_gHTTP2_Information[_HTTP2_Index][_EndOfChunk] - _gHTTP2_Information[_HTTP2_Index][_BytesReceived] + 1, HTTP2_BUFFER_SIZE);
			else {
				if ( _gHTTP2_Information[_HTTP2_Index][_Status] & _HTTP2_STATUS_LARGE_SIZE ) {
					
					_HTTP2_large_add(HTTP2_tempLarge, sizeof HTTP2_tempLarge, _gHTTP2_Information[_HTTP2_Index][_FilesizeLarge], sizeof _gHTTP2_Information[][_FilesizeLarge]);
					_HTTP2_large_sub(HTTP2_tempLarge, sizeof HTTP2_tempLarge, _gHTTP2_Information[_HTTP2_Index][_BytesReceivedLarge], sizeof _gHTTP2_Information[][_BytesReceivedLarge]);
					_HTTP2_large_add(HTTP2_tempLarge, sizeof HTTP2_tempLarge, _gHTTP2_OneLarge, sizeof _gHTTP2_OneLarge);
					
					if ( _HTTP2_large_comp(HTTP2_tempLarge, sizeof HTTP2_tempLarge, _gHTTP2_BufferSizeLarge, sizeof _gHTTP2_BufferSizeLarge) == 1 )
						tempsize = HTTP2_BUFFER_SIZE;
					else
						tempsize = _HTTP2_large_toint(HTTP2_tempLarge, sizeof HTTP2_tempLarge);
				}
				else
					tempsize = min(_gHTTP2_Information[_HTTP2_Index][_Filesize] - _gHTTP2_Information[_HTTP2_Index][_BytesReceived] + 1, HTTP2_BUFFER_SIZE);
			}
		}
		
		if ( ! (  _gHTTP2_BufferLen = socket_recv(_gHTTP2_Information[_HTTP2_Index][_hSocket], _gHTTP2_DataBuffer, tempsize) ) ) {
			_HTTP2_TransferDone(_HTTP2_Index, -3, true);
			continue;
		}
		
		if ( _gHTTP2_Information[_HTTP2_Index][_Status] & _HTTP2_STATUS_FIRSTRUN ) {
			_gHTTP2_Information[_HTTP2_Index][_Status] &= ~_HTTP2_STATUS_FIRSTRUN;
			
			static _HTTP2_ReturnCodeExtended[32], _HTTP2_Location[512];
			new ReturnCode;
			
			_gHTTP2_BufferLen -= _HTTP2_ParseHeader(_HTTP2_Index, ReturnCode, _HTTP2_ReturnCodeExtended, charsmax(_HTTP2_ReturnCodeExtended), _HTTP2_Location, charsmax(_HTTP2_Location));
			
			if ( 300 <= ReturnCode <= 307 ) {
				if ( _HTTP2_FollowLocation(_HTTP2_Index, _HTTP2_Location) )
					continue;
				else {
					_HTTP2_TransferDone(_HTTP2_Index, -4, true);
					continue;
				}
			}
			else if ( ! ( 200 <= ReturnCode <= 299 ) ) {
				if ( ! ReturnCode )
					ReturnCode = -1;
				
				_HTTP2_TransferDone(_HTTP2_Index, ReturnCode, true);
				continue;
			}
			if ( _gHTTP2_Information[_HTTP2_Index][_Status] & _HTTP2_STATUS_CHUNKED_TRANSFER ) {
				new Shift = _HTTP2_GetChunkSize(_gHTTP2_DataBuffer, _gHTTP2_Information[_HTTP2_Index][_EndOfChunk]);
				_gHTTP2_BufferLen = _HTTP2_ShiftData(_gHTTP2_DataBuffer, Shift, _gHTTP2_BufferLen);
			}
		}
		
		if ( _gHTTP2_Information[_HTTP2_Index][_hFile] )
			fwrite_blocks(_gHTTP2_Information[_HTTP2_Index][_hFile], _gHTTP2_DataBuffer, _gHTTP2_BufferLen, BLOCK_BYTE);
		
		_gHTTP2_Information[_HTTP2_Index][_BytesReceived] += _gHTTP2_BufferLen;
		
		if ( _gHTTP2_Information[_HTTP2_Index][_Status] & _HTTP2_STATUS_LARGE_SIZE ) {
			_HTTP2_large_fromint(HTTP2_tempLarge, sizeof HTTP2_tempLarge, _gHTTP2_BufferLen);
			_HTTP2_large_add(_gHTTP2_Information[_HTTP2_Index][_BytesReceivedLarge], sizeof _gHTTP2_Information[][_BytesReceivedLarge], HTTP2_tempLarge, sizeof HTTP2_tempLarge);
			
		}
		
		if ( _gHTTP2_Information[_HTTP2_Index][_hProgressHandler] ) {
			
			ExecuteForward(_gHTTP2_Information[_HTTP2_Index][_hProgressHandler], _gHTTP2_ReturnDummy, _HTTP2_Index);
			
			if ( _gHTTP2_ReturnDummy == PLUGIN_HANDLED ) {
				_HTTP2_TransferDone(_HTTP2_Index, 0, false);
				continue;
			}
		}
		
		if ( ( _gHTTP2_Information[_HTTP2_Index][_Status] & _HTTP2_STATUS_LARGE_SIZE
			&& ! _HTTP2_large_comp(_gHTTP2_Information[_HTTP2_Index][_BytesReceivedLarge], sizeof _gHTTP2_Information[][_BytesReceivedLarge], _gHTTP2_Information[_HTTP2_Index][_FilesizeLarge], sizeof _gHTTP2_Information[][_FilesizeLarge]) )
		||
			( ! ( _gHTTP2_Information[_HTTP2_Index][_Status] & _HTTP2_STATUS_LARGE_SIZE )
			&& _gHTTP2_Information[_HTTP2_Index][_BytesReceived] == _gHTTP2_Information[_HTTP2_Index][_Filesize] )
		) {
			_HTTP2_TransferDone(_HTTP2_Index, 0, true);
			continue;
		}
	}
	
	entity_set_float(_gHTTP2_DownloadEntity, EV_FL_nextthink, get_gametime() + HTTP2_THINK_INTERVAL);
}

public _HTTP2_QueThread() {
	new count;
	
	for ( new i = 0 ; i < HTTP2_MAX_DOWNLOAD_SLOTS ; i++ ) {
		if ( ! ( _gHTTP2_Information[i][_Status] & _HTTP2_STATUS_ACTIVE ) )
			count++;
	}
	
	new Arraysize = ArraySize(_gHTTP2_Que_hArray);
	if ( count > Arraysize )
		count = Arraysize;
	
	while ( count-- ) {
		ArrayGetArray(_gHTTP2_Que_hArray, 0, _gHTTP2_QueData);
		ArrayDeleteItem(_gHTTP2_Que_hArray, 0);
		
		if ( _gHTTP2_QueData[_QueRequestType] == REQUEST_POST )
			copy(_gHTTP2_PostVars, charsmax(_gHTTP2_PostVars), _gHTTP2_QueData[_QuePostVars]);
		
		HTTP2_Download(_gHTTP2_QueData[_QueURL], _gHTTP2_QueData[_QueFilename], _gHTTP2_QueData[_QueCompleteHandler], _gHTTP2_QueData[_QueProgressHandler], _gHTTP2_QueData[_QuePort], _gHTTP2_QueData[_QueRequestType], _gHTTP2_QueData[_QueUsername], _gHTTP2_QueData[_QuePassword]);
	}
	
	if ( ! ArraySize(_gHTTP2_Que_hArray) ) {
		entity_set_int(_gHTTP2_QueEntity, EV_INT_flags, FL_KILLME);
		call_think(_gHTTP2_QueEntity);
		
		_gHTTP2_QueEntity = 0;
		return;
	}
	
	entity_set_float(_gHTTP2_QueEntity, EV_FL_nextthink, get_gametime() + HTTP2_QUE_INTERVAL);
}

_HTTP2_TransferDone(Index, Error, bool:CallHandler) {
	
	if ( _gHTTP2_Information[Index][_hFile] )
		fclose(_gHTTP2_Information[Index][_hFile]);
	
	socket_close(_gHTTP2_Information[Index][_hSocket]);
	
	if ( CallHandler && _gHTTP2_Information[Index][_hCompleteHandler] )
		ExecuteForward(_gHTTP2_Information[Index][_hCompleteHandler], _gHTTP2_ReturnDummy, Index, Error);
	
	DestroyForward(_gHTTP2_Information[Index][_hProgressHandler]);
	DestroyForward(_gHTTP2_Information[Index][_hCompleteHandler]);
	
	_gHTTP2_Information[Index][_BytesReceived] = 0;
	_gHTTP2_Information[Index][_Filesize] = 0;
	_gHTTP2_Information[Index][_EndOfChunk] = 0;
	_gHTTP2_Information[Index][_hProgressHandler] = 0;
	_gHTTP2_Information[Index][_hCompleteHandler] = 0;
	_gHTTP2_Information[Index][_hFile] = 0;
	_gHTTP2_Information[Index][_Status] = 0;
	_gHTTP2_Information[Index][_PostVars] = 0;
	
	for ( new i = 0 ; i < sizeof _gHTTP2_Information ; i++ ) {
		if ( _gHTTP2_Information[i][_Status] & _HTTP2_STATUS_ACTIVE )
			return;
	}
	
	entity_set_int(_gHTTP2_DownloadEntity, EV_INT_flags, FL_KILLME);
	call_think(_gHTTP2_DownloadEntity);
	
	_gHTTP2_DownloadEntity = 0;
}

_HTTP2_FollowLocation(Index, const Location[]) {
	
	socket_close(_gHTTP2_Information[Index][_hSocket]);
	new bool:Relative = true;
	
	static _HTTP2_Follow_TempURLParsed[_HTTP2_URLDataEnum];
	
	arrayset(_HTTP2_Follow_TempURLParsed, 0, sizeof _HTTP2_Follow_TempURLParsed);
	_HTTP2_ParseURL(Location,
	_HTTP2_Follow_TempURLParsed[_Scheme], charsmax(_HTTP2_Follow_TempURLParsed[_Scheme]),
	_HTTP2_Follow_TempURLParsed[_User], charsmax(_HTTP2_Follow_TempURLParsed[_User]),
	_HTTP2_Follow_TempURLParsed[_Pass], charsmax(_HTTP2_Follow_TempURLParsed[_Pass]),
	_HTTP2_Follow_TempURLParsed[_Host], charsmax(_HTTP2_Follow_TempURLParsed[_Host]),
	_HTTP2_Follow_TempURLParsed[_URLPort],
	_HTTP2_Follow_TempURLParsed[_Path], charsmax(_HTTP2_Follow_TempURLParsed[_Path]),
	_HTTP2_Follow_TempURLParsed[_Query], charsmax(_HTTP2_Follow_TempURLParsed[_Query]),
	_HTTP2_Follow_TempURLParsed[_Fragment], charsmax(_HTTP2_Follow_TempURLParsed[_Fragment]));
	
	if ( _HTTP2_Follow_TempURLParsed[_Scheme] )
		copy(_gHTTP2_URLParsed[Index][_Scheme], charsmax(_gHTTP2_URLParsed[][_Scheme]), _HTTP2_Follow_TempURLParsed[_Scheme]);
	if ( _HTTP2_Follow_TempURLParsed[_Host] ) {
		copy(_gHTTP2_URLParsed[Index][_Host], charsmax(_gHTTP2_URLParsed[][_Host]), _HTTP2_Follow_TempURLParsed[_Host]);
		Relative = false;
	}
	if ( _HTTP2_Follow_TempURLParsed[_URLPort] )
		_gHTTP2_Information[Index][_Port] = _HTTP2_Follow_TempURLParsed[_URLPort];
	if ( _HTTP2_Follow_TempURLParsed[_User] )
		copy(_gHTTP2_URLParsed[Index][_User], charsmax(_gHTTP2_URLParsed[][_User]), _HTTP2_Follow_TempURLParsed[_User]);
	if ( _HTTP2_Follow_TempURLParsed[_Pass] )
		copy(_gHTTP2_URLParsed[Index][_Pass], charsmax(_gHTTP2_URLParsed[][_Pass]), _HTTP2_Follow_TempURLParsed[_Pass]);
	if ( _HTTP2_Follow_TempURLParsed[_Path] ) {
		if ( Relative )
			add(_gHTTP2_URLParsed[Index][_Path], charsmax(_gHTTP2_URLParsed[][_Path]), _HTTP2_Follow_TempURLParsed[_Path]);
		else
			copy(_gHTTP2_URLParsed[Index][_Path], charsmax(_gHTTP2_URLParsed[][_Path]), _HTTP2_Follow_TempURLParsed[_Path]);
	}
	if ( _HTTP2_Follow_TempURLParsed[_Query] )
		copy(_gHTTP2_URLParsed[Index][_Query], charsmax(_gHTTP2_URLParsed[][_Query]), _HTTP2_Follow_TempURLParsed[_Query]);
	if ( _HTTP2_Follow_TempURLParsed[_Fragment] )
		copy(_gHTTP2_URLParsed[Index][_Fragment], charsmax(_gHTTP2_URLParsed[][_Fragment]), _HTTP2_Follow_TempURLParsed[_Fragment]);
	
	new ResultNum;
	_gHTTP2_Information[Index][_hSocket] = socket_open(_gHTTP2_URLParsed[Index][_Host], _gHTTP2_Information[Index][_Port], SOCKET_TCP, ResultNum);
	
	if ( ResultNum ) {
		switch ( ResultNum ) {
		case 1: log_amx("[HTTP2] Socket error: Error while creating socket.");
		case 2: log_amx("[HTTP2] Socket error: Couldn't resolve hostname.");
		case 3: log_amx("[HTTP2] Socket error: Couldn't connect to given hostname:port.");
		}
		return 0;
	}
	
	static _HTTP2_Request[2048], _HTTP2_Auth[256], _HTTP2_TempStr[256], _HTTP2_TempScheme[10];
	
	copy(_HTTP2_TempScheme, charsmax(_HTTP2_TempScheme), _gHTTP2_URLParsed[Index][_Scheme]);
	strtoupper(_HTTP2_TempScheme);
	
	new RequestLen = formatex(_HTTP2_Request, charsmax(_HTTP2_Request), "%s /%s%s%s%s%s %s/1.1^r^nHost: %s", _HTTP2_RequestTypes[_gHTTP2_Information[Index][_RequestType]], _gHTTP2_URLParsed[Index][_Path], _gHTTP2_URLParsed[Index][_Query] ? "?" : "", _gHTTP2_URLParsed[Index][_Query], _gHTTP2_URLParsed[Index][_Fragment] ? "#" : "", _gHTTP2_URLParsed[Index][_Fragment], _HTTP2_TempScheme, _gHTTP2_URLParsed[Index][_Host]);
	
	if ( _gHTTP2_URLParsed[Index][_User] || _gHTTP2_URLParsed[Index][_Pass] ) {
		formatex(_HTTP2_TempStr, charsmax(_HTTP2_TempStr), "%s:%s", _gHTTP2_URLParsed[Index][_User], _gHTTP2_URLParsed[Index][_Pass]);
		_HTTP2_Encode64(_HTTP2_TempStr, _HTTP2_Auth, charsmax(_HTTP2_Auth));
		
		RequestLen += formatex(_HTTP2_Request[RequestLen], charsmax(_HTTP2_Request) - RequestLen, "^r^nAuthorization: Basic %s", _HTTP2_Auth);
	}
	
	if ( _gHTTP2_Information[Index][_RequestType] == REQUEST_POST && _gHTTP2_Information[Index][_PostVars] ) {
		RequestLen += formatex(_HTTP2_Request[RequestLen], charsmax(_HTTP2_Request) - RequestLen, "^r^nContent-Length: %d", strlen(_gHTTP2_Information[Index][_PostVars]));
		RequestLen += formatex(_HTTP2_Request[RequestLen], charsmax(_HTTP2_Request) - RequestLen, "^r^nContent-Type: application/x-www-form-urlencoded");
		RequestLen += formatex(_HTTP2_Request[RequestLen], charsmax(_HTTP2_Request) - RequestLen, "^r^n^r^n%s", _gHTTP2_Information[Index][_PostVars]);
	}
	
	formatex(_HTTP2_Request[RequestLen], charsmax(_HTTP2_Request) - RequestLen, "^r^n^r^n");
	
	socket_send(_gHTTP2_Information[Index][_hSocket], _HTTP2_Request, strlen(_HTTP2_Request));
	
	_gHTTP2_Information[Index][_Status] = _HTTP2_STATUS_ACTIVE;
	_gHTTP2_Information[Index][_Status] |= _HTTP2_STATUS_FIRSTRUN;
	
	return 1;
}

_HTTP2_ParseHeader(Index, &ReturnCode, ReturnCodeExtended[], ReturnCodeExtendedLen, Location[], LocationLen) {
	
	static _HTTP2_TempStr[256];
	new HeaderLen, iPos, c;
	
	HeaderLen = containi(_gHTTP2_DataBuffer, "^r^n^r^n") + 1;
	
	if ( HeaderLen ) {
		HeaderLen += 3;
		
		iPos = containi(_gHTTP2_DataBuffer, "HTTP/1.1 ") + 9;
		
		if ( iPos != 8 && iPos < HeaderLen ) {
			while ( _gHTTP2_DataBuffer[iPos + c] != '^r' && c < charsmax(_HTTP2_TempStr) )
				_HTTP2_TempStr[c] = _gHTTP2_DataBuffer[iPos + c++];
			
			_HTTP2_TempStr[c] = 0;
			ReturnCode = str_to_num(_HTTP2_TempStr);
			
			iPos += c + 1;
			c = 0;
			while ( _gHTTP2_DataBuffer[iPos + c] != '^r' && _gHTTP2_DataBuffer[iPos + c] != '^n' && c < ReturnCodeExtendedLen )
				ReturnCodeExtended[c] = _gHTTP2_DataBuffer[iPos + c++];
			ReturnCodeExtended[c] = 0;
		}
		
		iPos = containi(_gHTTP2_DataBuffer, "Transfer-Encoding: ") + 19;
		c = 0;
		
		if ( iPos != 18 && iPos < HeaderLen ) {
			while ( _gHTTP2_DataBuffer[iPos + c] != '^r' && c < charsmax(_HTTP2_TempStr) )
				_HTTP2_TempStr[c] = _gHTTP2_DataBuffer[iPos + c++];
			
			_HTTP2_TempStr[c] = 0;
			
			if ( equali(_HTTP2_TempStr, "chunked") )
				_gHTTP2_Information[Index][_Status] |= _HTTP2_STATUS_CHUNKED_TRANSFER;
		}
		
		if ( 300 <= ReturnCode <= 399 ) {
			iPos = containi(_gHTTP2_DataBuffer, "Location: ") + 10;
			c = 0;
			
			if ( iPos != 9 && iPos < HeaderLen ) {
				while ( _gHTTP2_DataBuffer[iPos + c] != '^r' && c < LocationLen )
					Location[c] = _gHTTP2_DataBuffer[iPos + c++];
				
				Location[c] = 0;
			}
		}
		
		iPos = containi(_gHTTP2_DataBuffer, "Content-Length: ") + 16;
		c = 0;
		
		if ( iPos != 15 && iPos < HeaderLen ) {
			while ( _gHTTP2_DataBuffer[iPos + c] != '^r' && c < charsmax(_HTTP2_TempStr) )
				_HTTP2_TempStr[c] = _gHTTP2_DataBuffer[iPos + c++];
			
			_HTTP2_TempStr[c] = 0;
			_gHTTP2_Information[Index][_Filesize] = str_to_num(_HTTP2_TempStr);
			_HTTP2_large_fromstring(_gHTTP2_Information[Index][_FilesizeLarge], sizeof _gHTTP2_Information[][_FilesizeLarge], _HTTP2_TempStr);
			
			static HTTP2_tempLarge[16];
			_HTTP2_large_fromint(HTTP2_tempLarge, sizeof HTTP2_tempLarge, _gHTTP2_Information[Index][_Filesize]);
			
			if ( _HTTP2_large_comp(_gHTTP2_Information[Index][_FilesizeLarge], sizeof _gHTTP2_Information[][_FilesizeLarge], HTTP2_tempLarge, sizeof HTTP2_tempLarge) != 0 )
				_gHTTP2_Information[Index][_Status] |= _HTTP2_STATUS_LARGE_SIZE;
		}
		else
			_gHTTP2_Information[Index][_Filesize] = -1;
		
		_HTTP2_ShiftData(_gHTTP2_DataBuffer, HeaderLen, _gHTTP2_BufferLen);
	}
	
	return HeaderLen;
}

_HTTP2_ParseURL(const URL[], Scheme[]="", Schemelen=0, User[]="", Userlen=0, Pass[]="", Passlen=0, Host[]="", Hostlen=0, &Port, Path[]="", Pathlen=0, Query[]="", Querylen=0, Fragment[]="", Fragmentlen=0) {
	
	new temp;
	static Regex:_HTTP2_ParseURL_hRegex;
	
	if ( ! _HTTP2_ParseURL_hRegex )
		_HTTP2_ParseURL_hRegex = regex_compile("(?:(\w+):///?)?(?:([\w&\$\+\,/\.;=\[\]\{\}\|\\\^^\~%?#\-]+):([\w&\$\+\,/\.;=\[\]\{\}\|\\\^^\~%?#\-]+)@)?((?:[\w-]+\.)*[\w-]+\.[\w-]+)?(?::(\d+))?(?:/?([\w&\$\+\,/\.;=@\[\]\{\}\|\\\^^\~%\-]*))?(?:\?([\w&\$\+\,/\.;=@\[\]\{\}\|\\\^^\~%:\-]*))?(?:#([\w&\$\+\,/\.;=@\[\]\{\}\|\\\^^\~%:\-]*))?", temp, "", 0);
	/*
	Scheme		(?:(\w+):///?)?
	Auth		(?:([\w&\$\+\,/\.;=\[\]\{\}\|\\\^^\~%?#\-]+):([\w&\$\+\,/\.;=\[\]\{\}\|\\\^^\~%?#\-]+)@)?
	Host		((?:[\w-]+\.)*[\w-]+\.[\w-]+)?
	Port		(?::(\d+))?
	Path		(?:/?([\w&\$\+\,/\.;=@\[\]\{\}\|\\\^^\~%\- ]*))?
	Query		(?:\?([\w&\$\+\,/\.;=@\[\]\{\}\|\\\^^\~%:\- ]*))?
	Fragment	(?:#([\w&\$\+\,/\.;=@\[\]\{\}\|\\\^^\~%:\- ]*))?
	*/
	new TempPort[8];
	
	regex_match_c(URL, _HTTP2_ParseURL_hRegex, temp);
	
	regex_substr(_HTTP2_ParseURL_hRegex, 1, Scheme, Schemelen);
	if ( ! Scheme[0] || equali(Scheme, "https") )
		copy(Scheme, Schemelen, "http");
	regex_substr(_HTTP2_ParseURL_hRegex, 2, User, Userlen);
	regex_substr(_HTTP2_ParseURL_hRegex, 3, Pass, Passlen);
	regex_substr(_HTTP2_ParseURL_hRegex, 4, Host, Hostlen);
	regex_substr(_HTTP2_ParseURL_hRegex, 5, TempPort, charsmax(TempPort));
	Port = str_to_num(TempPort);
	regex_substr(_HTTP2_ParseURL_hRegex, 6, Path, Pathlen);
	regex_substr(_HTTP2_ParseURL_hRegex, 7, Query, Querylen);
	regex_substr(_HTTP2_ParseURL_hRegex, 8, Fragment, Fragmentlen);
}

_HTTP2_GetChunkSize(const Data[], &ChunkSize) {
	
	new i, c, Hex[6];
	
	while ( Data[i] == '^r' || Data[i] == '^n' )
		i++;
	
	while ( _HTTP2_ishex(Data[i]) )
		Hex[c++] = Data[i++];
	
	while ( Data[i] == '^r' || Data[i] == '^n' )
		i++;
	
	ChunkSize = _HTTP2_HexToDec(Hex);
	
	return i;
}

_HTTP2_ShiftData(Data[], Amt, Len) {
	
	static _HTTP2_ShiftData_i;
	
	for ( _HTTP2_ShiftData_i = Amt ; _HTTP2_ShiftData_i < Len ; _HTTP2_ShiftData_i++ )
		Data[_HTTP2_ShiftData_i - Amt] = Data[_HTTP2_ShiftData_i];
	
	for ( _HTTP2_ShiftData_i = Len - Amt ; _HTTP2_ShiftData_i < Len ; _HTTP2_ShiftData_i++ )
		Data[_HTTP2_ShiftData_i] = 0;
	
	return Len - Amt;
}

stock _HTTP2_URLEncode(string[], len) {
	new what[2], with[4] = "^%";
	
	replace_all(string, len, "^%", "^%25");
	
	for ( new i = 0 ; i < len ; i++ ) {
		
		if ( ! string[i] )
			break;
		
		if ( ! _HTTP2_isurlsafe(string[i]) ) {
			what[0] = string[i];
			_HTTP2_DecToHex(what[0], with[1], charsmax(with) - 1);
			replace_all(string, len, what, with);
		}
	}
	replace_all(string, len, " ", "+");
}

stock _HTTP2_URLDecode(string[], len) {
	
	replace_all(string, len, "+", " ");
	
	new what[4] = "^%", with[2];
	
	for ( new i = 0 ; i < len ; i++ ) {
		
		if ( ! string[i] )
			break;
		
		if ( string[i - 2] == '^%' && _HTTP2_ishex(string[i - 1]) && _HTTP2_ishex(string[i]) ) {
			what[1] = string[i - 1];
			what[2] = string[i];
			with[0] = _HTTP2_HexToDec(what);
			if ( ! _HTTP2_isurlsafe(with[0]) )
				replace_all(string, len, what, with);
		}
	}
	replace_all(string, len, "^%25", "^%");
}

public _HTTP2_PluginUpdater_Complete(Index, Error) {
	
	new pluginfile[320], tempfile[14], temp[1], len;
	
	if ( Error ) {
		get_plugin (-1, pluginfile, charsmax(pluginfile), temp, 0, temp, 0, temp, 0, temp, 0);
		log_amx("Error(%d) while autoupdating plugin: %s", pluginfile);
		return;
	}
	
	HTTP2_getFilename(Index, tempfile, charsmax(tempfile));
	
	len = get_localinfo("amxx_pluginsdir", pluginfile, charsmax(pluginfile));
	pluginfile[len++] = '/';
	get_plugin (-1, pluginfile[len], charsmax(pluginfile) - len, temp, 0, temp, 0, temp, 0, temp, 0);
	
	delete_file(pluginfile);
	rename_file(tempfile, pluginfile, 1);
}

_HTTP2_HexToDec(string[]) {
	
	new result, mult = 1;
	
	for ( new i = strlen(string) - 1 ; i >= 0 ; i-- ) {
		result += _HTTP2_ctod(string[i]) * mult;
		mult *= 16;
	}

	return result;
}

stock _HTTP2_DecToHex(val, out[], len) {
	
	setc(out, len, 0);
	
	for ( new i = len - 1 ; val && i > -1 ; --i, val /= 16 )
		out[len - i - 1] = _HTTP2_dtoc(val % 16);
	
	new len2 = strlen(out);
	out[len2] = 0;
	new temp;
	
	for ( new i = 0 ; i < len2 / 2 ; i++ ) {
		temp = out[i];
		out[i] = out[len2 - i - 1];
		out[len2 - i - 1] = temp;
	}
}

/* Encodes a string to Base64 */
stock _HTTP2_Encode64(const InputString[], OutputString[], len) {
	
	new nLength, resPos, nPos, cCode, cFillChar = '=';
	setc(OutputString, len, 0);
	
	for ( nPos = 0, resPos = 0, nLength = strlen(InputString) ; nPos < nLength ; nPos++ ) {
		
		cCode = (InputString[nPos] >> 2) & 0x3f;
		
		resPos += formatex(OutputString[resPos], len, "%c", _HTTP2_Base64Table[cCode]);
		
		cCode = (InputString[nPos] << 4) & 0x3f;
		if ( ++nPos < nLength )
			cCode |= (InputString[nPos] >> 4) & 0x0f;
		resPos += formatex(OutputString[resPos], len, "%c", _HTTP2_Base64Table[cCode]);
		
		if ( nPos < nLength ) {
			cCode = (InputString[nPos] << 2) & 0x3f;
			if ( ++nPos < nLength )
				cCode |= (InputString[nPos] >> 6) & 0x03;
			
			resPos += formatex(OutputString[resPos], len, "%c", _HTTP2_Base64Table[cCode]);
		}
		else {
			nPos++;
			resPos += formatex(OutputString[resPos], len, "%c", cFillChar);
		}
		
		if(nPos < nLength) {
			cCode = InputString[nPos] & 0x3f;
			resPos += formatex(OutputString[resPos], len, "%c", _HTTP2_Base64Table[cCode]);
		}
		else
			resPos += formatex(OutputString[resPos], len, "%c", cFillChar);
	}
}

stock _HTTP2_reverse_string(string[]) {
	
	new temp, len = strlen(string);
	
	for ( new i = 0 ; i < len / 2 ; i++ ) {
		temp = string[i];
		string[i] = string[len - i - 1];
		string[len - i - 1] = temp;
	}
}

stock _HTTP2_large_add(large[], const large_size, const add_what[], const add_size) {
	
	new carry;
	
	for ( new i = 0 ; i < large_size ; i++ ) {
	
		if ( carry ) {
			large[i] += carry;
			carry = large[i] / 10;
			large[i] %= 10;
		}
		
		if ( i < add_size ) {
			large[i] += add_what[i];
			carry += large[i] / 10;
			large[i] %= 10;
		}
	}
}

stock _HTTP2_large_sub(large[], const large_size, const sub_what[], const sub_size) {
	
	new carry;
	
	for ( new i = 0 ; i < large_size ; i++ ) {
		
		if ( i + 1 > large_size ) {
			large[i + 1]--;
			large[i] += 10;
		}
		
		if ( carry ) {
			large[i] += carry;
			carry = large[i] / 10;
			large[i] %= 10;
		}
		
		if ( i < sub_size ) {
			large[i] -= sub_what[i];
			carry += large[i] / 10;
			large[i] %= 10;
		}
	}
}

stock _HTTP2_large_fromstring(large[], const large_size, string[]) {
	
	arrayset(large, 0, large_size);
	
	new len = strlen(string);
	_HTTP2_reverse_string(string);
	
	for ( new i = 0 ; i < large_size && string[i] && i < len ; i++ )
		large[i] = _HTTP2_ctod(string[i]);
	
	_HTTP2_reverse_string(string);
}

stock _HTTP2_large_tostring(large[], const large_size, string[], const len) {
	
	for ( new i = 0 ; i < large_size && i < len ; i++ )
		string[i] = _HTTP2_dtoc(large[i]);
	
	new pos = strlen(string);
	while ( pos > 1 && string[pos - 1] == '0' )
		pos--;
	string[pos] = 0;
	
	_HTTP2_reverse_string(string);
}

stock _HTTP2_large_fromint(large[], const large_size, const int) {
	
	arrayset(large, 0, large_size);
	new int2 = int;
	
	for ( new i = 0 ; i < large_size && int2 ; i++ ) {
		large[i] = int2 % 10;
		int2 /= 10;
	}
}

stock _HTTP2_large_toint(large[], large_size) {
	
	new retval, mult = 1;
	
	for ( new i = 0 ; i < large_size ; i++ ) {
		retval += large[i] * mult;
		mult *= 10;
	}
	
	return retval;
}

stock _HTTP2_large_comp(large1[], const large1_size, large2[], const large2_size) {
	new len1 = large1_size;
	new len2 = large2_size;
	
	while ( --len1 > 0 && large1[len1] ) { }
	while ( --len2 > 0 && large2[len2] ) { }
	
	if ( len1 > len2 )
		return 1;
	
	if ( len2 > len1 )
		return -1;
	
	for ( new i = len1 ; i >= 0 ; i-- ) {
	
		if ( large1[i] > large2[i] )
			return 1;
		
		if ( large2[i] > large1[i] )
			return -1;
	}
	
	return 0;
}

#if AMXX_VERSION_NUM < 183
// header client_print_color.inc

/* Fun functions
*
* by Numb
*
* This file is provided as is (no warranties).
*/

stock const g_szTeamName[Colors][] = 
{
	"UNASSIGNED",
	"TERRORIST",
	"CT",
	"SPECTATOR"
};

stock client_print_color(Index, iColor=DontChange, const szMsg[], any:...)
{
	// check if Index is different from 0
	if( Index && !is_user_connected(Index) )
	{
		return 0;
	}

	if( iColor > Grey )
	{
		iColor = DontChange;
	}

	new szMessage[192];
	if( iColor == DontChange )
	{
		szMessage[0] = 0x04;
	}
	else
	{
		szMessage[0] = 0x03;
	}

	new iParams = numargs();
	// Specific player code
	if(Index)
	{
		if( iParams == 3 )
		{
			copy(szMessage[1], charsmax(szMessage)-1, szMsg);
		}
		else
		{
			vformat(szMessage[1], charsmax(szMessage)-1, szMsg, 4);
		}

		if( iColor )
		{
			new szTeam[11]; // store current team so we can restore it
			get_user_team(Index, szTeam, charsmax(szTeam));

			// set Index TeamInfo in consequence
			// so SayText msg gonna show the right color
			Send_TeamInfo(Index, Index, g_szTeamName[iColor]);

			// Send the message
			Send_SayText(Index, Index, szMessage);

			// restore TeamInfo
			Send_TeamInfo(Index, Index, szTeam);
		}
		else
		{
			Send_SayText(Index, Index, szMessage);
		}
	} 

	// Send message to all players
	else
	{
		// Figure out if at least 1 player is connected
		// so we don't send useless message if not
		// and we gonna use that player as team reference (aka SayText message sender) for color change
		new iPlayers[32], iNum;
		get_players(iPlayers, iNum, "ch");
		if( !iNum )
		{
			return 0;
		}

		new iFool = iPlayers[0];

		new iMlNumber, i, j;
		new Array:aStoreML = ArrayCreate();
		if( iParams >= 5 ) // ML can be used
		{
			for(j=4; j<iParams; j++)
			{
				// retrieve original param value and check if it's LANG_PLAYER value
				if( getarg(j) == LANG_PLAYER )
				{
					i=0;
					// as LANG_PLAYER == -1, check if next parm string is a registered language translation
					while( ( szMessage[ i ] = getarg( j + 1, i++ ) ) ) {}
					if( GetLangTransKey(szMessage) != TransKey_Bad )
					{
						// Store that arg as LANG_PLAYER so we can alter it later
						ArrayPushCell(aStoreML, j++);

						// Update ML array saire so we'll know 1st if ML is used,
						// 2nd how many args we have to alterate
						iMlNumber++;
					}
				}
			}
		}

		// If arraysize == 0, ML is not used
		// we can only send 1 MSG_BROADCAST message
		if( !iMlNumber )
		{
			if( iParams == 3 )
			{
				copy(szMessage[1], charsmax(szMessage)-1, szMsg);
			}
			else
			{
				vformat(szMessage[1], charsmax(szMessage)-1, szMsg, 4);
			}

			if( iColor )
			{
				new szTeam[11];
				get_user_team(iFool, szTeam, charsmax(szTeam));
				Send_TeamInfo(0, iFool, g_szTeamName[iColor]);
				Send_SayText(0, iFool, szMessage);
				Send_TeamInfo(0, iFool, szTeam);
			}
			else
			{
				Send_SayText(0, iFool, szMessage);
			}
		}

		// ML is used, we need to loop through all players,
		// format text and send a MSG_ONE_UNRELIABLE SayText message
		else
		{
			new szTeam[11], szFakeTeam[10];
			
			if( iColor )
			{
				get_user_team(iFool, szTeam, charsmax(szTeam));
				copy(szFakeTeam, charsmax(szFakeTeam), g_szTeamName[iColor]);
			}

			for( i = 0; i < iNum; i++ )
			{
				Index = iPlayers[i];

				for(j=0; j<iMlNumber; j++)
				{
					// Set all LANG_PLAYER args to player index ( = Index )
					// so we can format the text for that specific player
					setarg(ArrayGetCell(aStoreML, j), _, Index);
				}

				// format string for specific player
				vformat(szMessage[1], charsmax(szMessage)-1, szMsg, 4);

				if( iColor )
				{
					Send_TeamInfo(Index, iFool, szFakeTeam);
					Send_SayText(Index, iFool, szMessage);
					Send_TeamInfo(Index, iFool, szTeam);
				}
				else
				{
					Send_SayText(Index, iFool, szMessage);
				}
			}
			ArrayDestroy(aStoreML);
		}
	}
	return 1;
}

stock Send_TeamInfo(iReceiver, iPlayerId, szTeam[])
{
	static iTeamInfo = 0;
	if( !iTeamInfo )
	{
		iTeamInfo = get_user_msgid("TeamInfo");
	}
	message_begin(iReceiver ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, iTeamInfo, .player=iReceiver);
	write_byte(iPlayerId);
	write_string(szTeam);
	message_end();
}

stock Send_SayText(iReceiver, iPlayerId, szMessage[])
{
	static iSayText = 0;
	if( !iSayText )
	{
		iSayText = get_user_msgid("SayText");
	}
	message_begin(iReceiver ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, iSayText, .player=iReceiver);
	write_byte(iPlayerId);
	write_string(szMessage);
	message_end();
}

stock register_dictionary_colored(const filename[])
{
	if( !register_dictionary(filename) )
	{
		return 0;
	}

	new szFileName[256];
	get_localinfo("amxx_datadir", szFileName, charsmax(szFileName));
	format(szFileName, charsmax(szFileName), "%s/lang/%s", szFileName, filename);
	new fp = fopen(szFileName, "rt");
	if( !fp )
	{
		log_amx("Failed to open %s", szFileName);
		return 0;
	}

	new szBuffer[512], szLang[3], szKey[64], szTranslation[256], TransKey:iKey;

	while( !feof(fp) )
	{
		fgets(fp, szBuffer, charsmax(szBuffer));
		trim(szBuffer);

		if( szBuffer[0] == '[' )
		{
			strtok(szBuffer[1], szLang, charsmax(szLang), szBuffer, 1, ']');
		}
		else if( szBuffer[0] )
		{
			strbreak(szBuffer, szKey, charsmax(szKey), szTranslation, charsmax(szTranslation));
			iKey = GetLangTransKey(szKey);
			if( iKey != TransKey_Bad )
			{
				while( replace(szTranslation, charsmax(szTranslation), "!g", "^4") ){}
				while( replace(szTranslation, charsmax(szTranslation), "!t", "^3") ){}
				while( replace(szTranslation, charsmax(szTranslation), "!n", "^1") ){}
				AddTranslation(szLang, iKey, szTranslation[2]);
			}
		}
	}
	
	fclose(fp);
	return 1;
}

#endif

/*
*	 Contribuitori :
* SkillartzHD : -  Metoda anti-pause plugin.
*               -  Metoda anti-xfake-player si anti-xspammer.
*               -  Metoda auto-update plugin.
* COOPER :      -  Idee adaugare LANG si ajutor la introducerea acesteia in plugin.
* StefaN@CSX :  -  Gasire si reparare eroare parametrii la functia anti-xFake-Players.
* eNd :         -  Ajustat cod cu o noua metoda de inregistrare a cvarurilor.
* 001 :         -  Idee adaugare cvar rom_xfakeplayer_spam_type.
* HamletEagle : -  Distribuire tutorial despre noul tip de citire/scriere al fisierelor.
*/

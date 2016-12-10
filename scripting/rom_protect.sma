#include <amxmisc>
#include <fakemeta>

#pragma semicolon 1

#if AMXX_VERSION_NUM < 182 
    #assert AMX Mod X v1.8.2 or later library required!
#endif

//offsets
const m_iMenu = 205;
const Menu_OFF = 0;
const Menu_ChooseAppearance = 3;

new const Version[]       = "1.0.4s-dev",
			 Build        = 98,
			 Date[]       = "10.12.2016",
			 PluginName[] = "ROM-Protect",
			 CfgFile[]    = "addons/amxmodx/configs/rom_protect.cfg",
			 LangFile[]   = "addons/amxmodx/data/lang/rom_protect.txt",
			 IniFile[]    = "addons/amxmodx/configs/rom_protect.ini",
			 LangType[]   = "%L",
			 NoLogInfo     = -1;

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

new Counter[MAX_PLAYERS+1], LogFile[128], ClSaidSameTh_Count[MAX_PLAYERS+1],
	bool:CorrectName[MAX_PLAYERS+1], bool:IsAdmin[MAX_PLAYERS+1], bool:FirstMsg[MAX_PLAYERS+1],
	bool:Gag[MAX_PLAYERS+1], bool:UnBlockedChat[MAX_PLAYERS+1];
new LastPass[MAX_PLAYERS+1][32], Capcha[MAX_PLAYERS+1][8];
new Trie:LoginName, Trie:DefaultRes;
new PreviousMessage[MAX_PLAYERS+1][192]; // declarat global pentru a evita eroarea "Run time error 3: stack error"
new bool:IsLangUsed, bool:AdminsReloaded;

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
	protcvars,
	console_say
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
	"rom_prot_cvars",
	"rom_console_say"
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
		{ 1, 0, 1, 1 },     // rom_prot_cvars
		{ 1, 0, 1, 1 }      // rom_console_say
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
	"1",
	"1"
};
	
new PluginCvar[AllCvars];

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
	
	if ( file_exists(CfgFile) )
	{
		server_cmd("exec %s", CfgFile);
	}
	
	set_task(5.0, "checkLang");
	set_task(10.0, "checkLangFile");
	set_task(15.0, "checkCfg");
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
			if ( getInteger(PluginCvar[plug_log]) == 1 )
			{
				new CvarString[32];
				getString(PluginCvar[Tag], CvarString, charsmax(CvarString));
				logCommand(NoLogInfo, LangType, LANG_SERVER, "ROM_UPDATE_CFG", CvarString);
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
			if ( getInteger(PluginCvar[plug_log]) == 1 )
			{
				new CvarString[32];
				getString(PluginCvar[Tag], CvarString, charsmax(CvarString));
				logCommand(NoLogInfo, LangType, LANG_SERVER, "ROM_UPDATE_LANG", CvarString);
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
	
	if ( getInteger(PluginCvar[advertise]) == 1 )
	{
		set_task(getFloat(PluginCvar[advertise_time]), "showAdvertise", _, _, _, "b", 0);
	}
	
	if ( getInteger(PluginCvar[utf8_bom]) == 1 )
	{
		DefaultRes = TrieCreate();
		TrieSetCell(DefaultRes, "de_storm.res", 1);
		TrieSetCell(DefaultRes, "default.res", 1);
		
		set_task(10.0, "cleanResFiles");
	}
}

public client_connect(Index)
{
	if (getInteger(PluginCvar[cmd_bug]) == 1)
	{
		new Name[MAX_NAME_LENGTH];
		get_user_name(Index, Name, charsmax(Name));
		stringFilter(Name, charsmax(Name));
		set_user_info(Index, "name", Name);
	}
}

public client_authorized(Index)
{	
	new CvarString[32];
	if (getInteger(PluginCvar[fake_players]) == 1)
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
				if ( ++Counter[Index] > getInteger(PluginCvar[fake_players_limit]) )
				{
					getString(PluginCvar[Tag], CvarString, charsmax(CvarString));
					switch ( getInteger(PluginCvar[fake_players_type]) )
					{
						case 0:
						{
							new Limit[8];
							num_to_str(getInteger(PluginCvar[fake_players_limit]), Limit, charsmax(Limit));
							console_print(Index, LangType, LANG_PLAYER, "ROM_FAKE_PLAYERS_KICK", CvarString, Limit);
							server_cmd("kick #%d ^"You got kicked. Check console.^"", get_user_userid(Index));
						}
						case 1: 
						{
							new Punish[8];
							num_to_str(getInteger(PluginCvar[fake_players_punish]), Punish, charsmax(Punish));
							server_cmd("addip ^"%s^" ^"%s^";wait;writeip", Punish, Address);
							if ( getInteger(PluginCvar[plug_warn]) == 1 )
							{
								new CvarTag[32];
								copy(CvarTag, charsmax(CvarTag), CvarString);
								#if AMXX_VERSION_NUM < 183
									client_print_color(0, Grey, LangType, LANG_PLAYER, "ROM_FAKE_PLAYERS", "^3", CvarTag, "^4", Address);
									client_print_color(0, Grey, LangType, LANG_PLAYER, "ROM_FAKE_PLAYERS_PUNISH", "^3", CvarTag, "^4", Punish);
								#else
									client_print_color(0, print_team_grey, LangType, LANG_PLAYER, "ROM_FAKE_PLAYERS", CvarTag, Address);
									client_print_color(0, print_team_grey, LangType, LANG_PLAYER, "ROM_FAKE_PLAYERS_PUNISH", CvarTag, Punish);
								#endif
							}
							if ( getInteger(PluginCvar[plug_log]) == 1 )
							{
								logCommand(NoLogInfo, LangType, LANG_SERVER, "ROM_FAKE_PLAYERS_LOG", CvarString, Address);
							}
						}
					}
					break;
				}
			}
		}
	}
	switch ( getInteger(PluginCvar[xfakeplayer_spam]))
	{
		case 1:
		{
			FirstMsg[Index] = true;
			Gag[Index] = false;
		}
		case 2:
		{
			if ( getInteger(PluginCvar[xfakeplayer_spam_capcha]) == 1 )
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
				getString(PluginCvar[xfakeplayer_spam_capcha_word], CvarString, charsmax(CvarString));
				copy(Capcha[Index], charsmax(Capcha[]), CvarString);
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
	if ( getInteger(PluginCvar[fake_players]) == 1 )
	{
		Counter[Index] = 0;
	}
	if ( getInteger(PluginCvar[xfakeplayer_spam]) == 1 )
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
	switch ( getInteger(PluginCvar[delete_vault]) != 0 )
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
	
	if ( getInteger(PluginCvar[delete_custom_hpk]) == 1 )
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
	
	new CmdBugCvarValue = getInteger(PluginCvar[cmd_bug]), AdminLoginCvarValue = getInteger(PluginCvar[admin_login]);
	if ( CmdBugCvarValue == 1 || AdminLoginCvarValue == 1)
	{
		new NewName[MAX_NAME_LENGTH], OldName[MAX_NAME_LENGTH];
		get_user_name(Index, OldName, charsmax(OldName));
		get_user_info(Index, "name", NewName, charsmax(NewName));
		
		if (equali(NewName, OldName))
		{
			return;
		}
	
		if ( CmdBugCvarValue == 1 )
		{
			stringFilter(NewName, charsmax(NewName));
			set_user_info(Index, "name", NewName);
		}
	
		if ( AdminLoginCvarValue == 1 && IsAdmin[Index] )
		{
			IsAdmin[Index] = false;
			remove_user_flags(Index);
		}
	}
	
	return;
}

public plugin_pause()
{
	if (getInteger(PluginCvar[anti_pause]) == 1)
	{
		new PluginName[32], CvarString[32];
		getString(PluginCvar[Tag], CvarString, charsmax(CvarString));
		
		if (getInteger(PluginCvar[plug_warn]) == 1)
		{
			#if AMXX_VERSION_NUM < 183
				client_print_color(0, Grey, LangType, LANG_PLAYER, "ROM_PLUGIN_PAUSE", "^3", CvarString, "^4");
			#else
				client_print_color(0, print_team_grey, LangType, LANG_PLAYER, "ROM_PLUGIN_PAUSE", CvarString);
			#endif
		}
		
		if (getInteger(PluginCvar[plug_log]) == 1)
		{
			logCommand(NoLogInfo, LangType, LANG_SERVER, "ROM_PLUGIN_PAUSE_LOG", CvarString, CvarString);
		}
		
		get_plugin(-1, PluginName, charsmax(PluginName));
		server_cmd("amxx unpause %s", PluginName);
	}
}

public cmdPass(Index)
{
	if ( getInteger(PluginCvar[admin_login]) != 1 )
	{
		return PLUGIN_HANDLED;
	}

	new Name[MAX_NAME_LENGTH], Password[32], CvarString[32];
	
	get_user_name(Index, Name, charsmax(Name));
	read_argv(1, Password, charsmax(Password));
	remove_quotes(Password);
	getString(PluginCvar[Tag], CvarString, charsmax(CvarString));
	if (!Password[0])
	{
		#if AMXX_VERSION_NUM < 183
			client_print_color(Index, Grey, LangType, Index, "ROM_ADMIN_WITHOUT_PASS", "^3", CvarString, "^4");
		#else
			client_print_color(Index, print_team_grey, LangType, Index, "ROM_ADMIN_WITHOUT_PASS", CvarString);
		#endif
		console_print(Index, LangType, Index, "ROM_ADMIN_WITHOUT_PASS_PRINT", CvarString);

		return PLUGIN_HANDLED;
	}

	loadAdminLogin();
	IsAdmin[Index] = false;
	if ( !getAccess(Index, Password, charsmax(Password)) )
	{
		return PLUGIN_HANDLED;
	}
	
	if (!IsAdmin[Index])
	{
		LastPass[Index][0] = EOS;
		if (!CorrectName[Index])
		{		
			#if AMXX_VERSION_NUM < 183
				client_print_color(Index, Grey, LangType, Index, "ROM_ADMIN_WRONG_NAME", "^3", CvarString, "^4");
			#else
				client_print_color(Index, print_team_grey, LangType, Index, "ROM_ADMIN_WRONG_NAME", CvarString);
			#endif
			console_print(Index, LangType, Index, "ROM_ADMIN_WRONG_NAME_PRINT", CvarString);
		}
		else
		{
			#if AMXX_VERSION_NUM < 183
				client_print_color(Index, Grey, LangType, Index, "ROM_ADMIN_WRONG_PASS", "^3", CvarString, "^4");
			#else
				client_print_color(Index, print_team_grey, LangType, Index, "ROM_ADMIN_WRONG_PASS", CvarString);
			#endif
			console_print(Index, LangType, Index, "ROM_ADMIN_WRONG_PASS_PRINT", CvarString);
		}
	}
	else
	{
		if ( equal(LastPass[Index], Password) )
		{
			#if AMXX_VERSION_NUM < 183
				client_print_color(Index, Grey, LangType, Index, "ROM_ADMIN_ALREADY_LOADED", "^3", CvarString, "^4");
			#else
				client_print_color(Index, print_team_grey, LangType, Index, "ROM_ADMIN_ALREADY_LOADED", CvarString);
			#endif
			console_print(Index, LangType, Index, "ROM_ADMIN_ALREADY_LOADED_PRINT", CvarString);
		}
		else
		{
			#if AMXX_VERSION_NUM < 183
				client_print_color(Index, Grey, LangType, Index, "ROM_ADMIN_LOADED", "^3", CvarString, "^4");
			#else
				client_print_color(Index, print_team_grey, LangType, Index, "ROM_ADMIN_LOADED", CvarString);
			#endif
			console_print(Index, LangType, Index, "ROM_ADMIN_LOADED_PRINT", CvarString);

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

		new Float:maxChat = get_pcvar_float(PluginCvar[admin_chat_flood_time]);

		if (maxChat && getInteger(PluginCvar[admin_chat_flood]) == 1)
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

#if AMXX_VERSION_NUM < 183
	public showAdminChatFloodWarning(Index)
	{
		if ( IsFlooding[Index] )
		{
			new CvarString[32];
			getString(PluginCvar[Tag], CvarString, charsmax(CvarString));
			if ( getInteger(PluginCvar[plug_warn]) == 1 )
			{
				client_print_color(Index, Grey, LangType, Index, "ROM_ADMIN_CHAT_FLOOD", "^3", CvarString, "^4");
			}
			
			if ( getInteger(PluginCvar[plug_log]) == 1 )
			{
				logCommand(Index, LangType, LANG_SERVER, "ROM_ADMIN_CHAT_FLOOD_LOG", CvarString);
			}
			
			IsFlooding[Index] = false;
		}
	}
#endif

public showAdvertise()
{
	new CvarString[32];
	getString(PluginCvar[Tag], CvarString, charsmax(CvarString));
	
	#if AMXX_VERSION_NUM < 183
		client_print_color(0, Grey, LangType, LANG_PLAYER, "ROM_ADVERTISE", "^3", CvarString, "^4", "^3", PluginName, "^4", "^3", Version, "^4");
	#else
		client_print_color(0, print_team_grey, LangType, LANG_PLAYER, "ROM_ADVERTISE", CvarString, PluginName, Version);
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
	AdminsReloaded = true;
	set_task(1.0, "reloadDelay");
}

public client_command(Index)
{
	if (getInteger(PluginCvar[spec_bug]) == 1)
	{	
		new Command[15];
		read_argv(0, Command, charsmax(Command));
		if (equali(Command, "joinclass") || (equali(Command, "menuselect") && get_pdata_int(Index, m_iMenu) == Menu_ChooseAppearance))
		{
			if (get_user_team(Index) == 3)
			{
				set_pdata_int(Index, m_iMenu, Menu_OFF);
				engclient_cmd(Index, "jointeam", "6");
				return PLUGIN_HANDLED;
			}
		}
	}
	
	if (AdminsReloaded)
	{
		reloadDelay();
	}

	return PLUGIN_CONTINUE;
}

public reloadDelay()
{
	if (!AdminsReloaded)
	{
		return;
	}
	new Players[MAX_PLAYERS], PlayersNum;
	
	get_players(Players, PlayersNum, "ch");
	
	for (new i = 0; i < PlayersNum; ++i)
	{
		if ( IsAdmin[Players[i]] )
		{
			getAccess(Players[i], LastPass[Players[i]], charsmax(LastPass[]));
		}
	}
	
	AdminsReloaded = false;
}

public cvarFunc(Index) 
{ 
	if ( !is_user_admin(Index) )
	{
		return PLUGIN_CONTINUE;
	}
		
	if ( getInteger(PluginCvar[motdfile]) == 1 )
	{
		new Cvar[32], Value[32], CvarString[32];
		getString(PluginCvar[Tag], CvarString, charsmax(CvarString)); 
		
		read_argv(1, Cvar, charsmax(Cvar));
		read_argv(2, Value, charsmax(Value));
		
		if ( equali(Cvar, "motdfile") && contain(Value, ".ini") != -1 ) 
		{
			if ( getInteger(PluginCvar[plug_warn]) == 1 )
			{
				console_print(Index, LangType, Index, "ROM_MOTDFILE", CvarString);
			}
			
			if ( getInteger(PluginCvar[plug_log]) == 1 )
			{
				logCommand(Index, LangType, LANG_SERVER, "ROM_MOTDFILE_LOG", CvarString);
			}
			
			return PLUGIN_HANDLED; 
		}
	}
	
	if ( getInteger(PluginCvar[protcvars]) == 1 )
	{
		new Command[32], CvarString[32];
		getString(PluginCvar[Tag], CvarString, charsmax(CvarString)); 
		
		read_argv(1, Command, charsmax(Command));
		
		if ( containi(Command, "rom_") != -1 )
		{
			if ( getInteger(PluginCvar[plug_warn]) == 1 )
			{
				console_print(Index, LangType, Index, "ROM_PROTCVARS", CvarString);
			}
			
			if ( getInteger(PluginCvar[plug_log]) == 1 )
			{
				logCommand(Index, LangType, LANG_SERVER, "ROM_PROTCVARS_LOG", CvarString);
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
	
	if ( getInteger(PluginCvar[motdfile]) == 1 )
	{
		new Command[32], CvarString[32];
		getString(PluginCvar[Tag], CvarString, charsmax(CvarString));
		
		read_args(Command, charsmax(Command));
		
		if ( containi(Command, "motdfile") && contain(Command, ".ini") != -1 ) 
		{
			if ( getInteger(PluginCvar[plug_warn]) == 1 )
			{
				console_print(Index, LangType, Index, "ROM_MOTDFILE", CvarString);
			}
			
			if ( getInteger(PluginCvar[plug_log]) == 1 )
			{
				logCommand(Index, LangType, LANG_SERVER, "ROM_MOTDFILE_LOG", CvarString);
			}
			
			return PLUGIN_HANDLED; 
		}
	}
	
	if ( getInteger(PluginCvar[protcvars]) == 1 )
	{
		new Command[32], CvarString[32];
		getString(PluginCvar[Tag], CvarString, charsmax(CvarString));
		
		read_args(Command, charsmax(Command));
		
		if ( !equali(Command, "rom_info") && containi(Command, "rom_") != -1 )
		{
			if ( getInteger(PluginCvar[plug_warn]) == 1 )
			{
				console_print(Index, LangType, Index, "ROM_PROTCVARS", CvarString);
			}
			
			if ( getInteger(PluginCvar[plug_log]) == 1 )
			{
				logCommand(Index, LangType, LANG_SERVER, "ROM_PROTCVARS_LOG", CvarString);
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
	
	new Value = getInteger(PluginCvar[anti_ban_class]);
	
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
		
		Value = getInteger(PluginCvar[anti_ban_class]);
		
		if ( Value > 4 )
		{
			Value = 4;
		}
			
		num_to_str(Value, NumStr, charsmax(NumStr));
		
		new CvarString[32];
		getString(PluginCvar[Tag], CvarString, charsmax(CvarString));
		
		switch (Value)
		{
			case 1:
			{
				if ( str_to_num(IpNum[0]) == 0 || str_to_num(IpNum[1]) == 0 || str_to_num(IpNum[2]) == 0 )
				{
					if (getInteger(PluginCvar[plug_warn]) == 1)
					{
						console_print(Index, LangType, Index, "ROM_ANTI_BAN_CLASS", CvarString);
					}
					
					if (getInteger(PluginCvar[plug_log]) == 1)
					{
						logCommand(Index, LangType, LANG_SERVER, "ROM_ANTI_ANY_BAN_CLASS_LOG", CvarString);
					}
					
					return PLUGIN_HANDLED;
				}
			}
			case 2:
			{
				if ( str_to_num(IpNum[0]) == 0 || str_to_num(IpNum[1]) == 0 )
				{
					if (getInteger(PluginCvar[plug_warn]) == 1)
					{
						console_print(Index, LangType, Index, "ROM_ANTI_BAN_CLASS", CvarString);
					}
					
					if (getInteger(PluginCvar[plug_log]) == 1)
					{
						logCommand(Index, LangType, LANG_SERVER, "ROM_ANTI_SOME_BAN_CLASS_LOG", CvarString, NumStr);
					}
					
					return PLUGIN_HANDLED;
				}
			}
			case 3:
			{
				if ( str_to_num(IpNum[0]) == 0 )
				{
					if (getInteger(PluginCvar[plug_warn]) == 1)
					{
						console_print(Index, LangType, Index, "ROM_ANTI_BAN_CLASS", CvarString);
					}
					
					if (getInteger(PluginCvar[plug_log]) == 1)
					{
						logCommand(Index, LangType, LANG_SERVER, "ROM_ANTI_SOME_BAN_CLASS_LOG", CvarString, NumStr);
					}
					
					return PLUGIN_HANDLED;
				}
			}
			default:
			{
				if (getInteger(PluginCvar[plug_warn]) == 1)
				{
					console_print(Index, LangType, Index, "ROM_ANTI_BAN_CLASS", CvarString);
				}
				
				if (getInteger(PluginCvar[plug_log]) == 1)
				{
					logCommand(Index, LangType, LANG_SERVER, "ROM_ANTI_SOME_BAN_CLASS_LOG", CvarString, NumStr);
				}
				
				return PLUGIN_HANDLED;
			}
		}
	}
	
	return PLUGIN_CONTINUE;
}

public hookBasicOnChatCommand(Index)
{
	new ColorBugCvarValue = getInteger(PluginCvar[color_bug]), CmdBugCvarValue = getInteger(PluginCvar[cmd_bug]);
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
		new WarnCvarValue = getInteger(PluginCvar[plug_warn]), LogCvarValue = getInteger(PluginCvar[plug_log]), CvarString[32];
		getString(PluginCvar[Tag], CvarString, charsmax(CvarString));
		if ( IsUsedCmdBug[Index] )
		{
			if ( WarnCvarValue == 1 )
			{
				new CvarTag[32];
				copy(CvarTag, charsmax(CvarTag), CvarString);
				
				#if AMXX_VERSION_NUM < 183
					client_print_color( Index, Grey, LangType, Index, "ROM_CMD_BUG", "^3", CvarTag, "^4");
				#else
					client_print_color( Index, print_team_grey, LangType, Index, "ROM_CMD_BUG", CvarTag);
				#endif
				console_print(Index, LangType, Index, "ROM_CMD_BUG_PRINT", CvarTag);
			}
			if ( LogCvarValue == 1 )
			{
				logCommand(Index, LangType, LANG_SERVER, "ROM_CMD_BUG_LOG", CvarString);
			}
			IsUsedCmdBug[Index] = false;
			return PLUGIN_HANDLED;
		}
		if ( IsUsedColorBug[Index] )
		{
			if ( WarnCvarValue == 1 )
			{
				#if AMXX_VERSION_NUM < 183
					client_print_color( Index, Grey, LangType, Index, "ROM_COLOR_BUG", "^3", CvarString, "^4");
				#else
					client_print_color( Index, print_team_grey, LangType, Index, "ROM_COLOR_BUG", CvarString );
				#endif
			}
			if ( LogCvarValue == 1 )
			{
				logCommand(Index, LangType, LANG_SERVER, "ROM_COLOR_BUG_LOG", CvarString);
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
		new CvarString[32];
		getString(PluginCvar[Tag], CvarString, charsmax(CvarString));
		if ( getInteger(PluginCvar[plug_log]) == 1 )
		{
			logCommand(Index, LangType, LANG_SERVER, "ROM_FAKE_PLAYERS_DETECT_LOG", CvarString);
		}
		
		console_print(Index, LangType, Index, "ROM_FAKE_PLAYERS_DETECT", CvarString);
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
		if ( getInteger(PluginCvar[autobuy_bug]) == 1 )
		{
			new CvarString[32];
			getString(PluginCvar[Tag], CvarString, charsmax(CvarString));
			if ( checkLong(Command, charsmax(Command)) )
			{		
				if ( getInteger(PluginCvar[plug_warn]) == 1 )
				{		
					#if AMXX_VERSION_NUM < 183		
						client_print_color( Index, Grey, LangType, Index, "ROM_AUTOBUY", "^3", CvarString, "^4");		
					#else		
						client_print_color( Index, print_team_grey, LangType, Index, "ROM_AUTOBUY", CvarString);
					#endif		
				}
			
				if ( getInteger( PluginCvar[plug_log] ) == 1 )
				{
					logCommand(Index, LangType, LANG_SERVER, "ROM_AUTOBUY_LOG", CvarString);
				}
			
				return PLUGIN_HANDLED;		
			}
		}
	}
	
	return PLUGIN_CONTINUE;		
}

public giveClientInfo(Index)
{
	if ( getInteger(PluginCvar[info]) != 1 )
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
	if ( getInteger(PluginCvar[info]) != 1 )
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

public hookChat(Index)
{
	new Said[192];
	read_args(Said, charsmax(Said));
	
	if ( getInteger(PluginCvar[console_say]) && checkForBinds(Index, Said) == PLUGIN_HANDLED)
	{
		return PLUGIN_HANDLED;
	}
	if (hookForXFakePlayerSpam(Index, Said) == PLUGIN_HANDLED)
	{
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

checkForBinds(Index, Said[])
{
	if(Said[0] != '^"')
	{
		static Trie:SafeCommands;
		if (SafeCommands == Invalid_Trie)
		{
			SafeCommands = TrieCreate();
			
			if (!file_exists(IniFile))
			{
				write_file(IniFile, "//Aici vor fi adaugate comenzile de chat considerate safe, una sub alta :^n", 0);
				return PLUGIN_CONTINUE;
			}
			else
			{
				new FilePointer = fopen(IniFile, "rt");
		
				if (!FilePointer) 
				{
					return PLUGIN_CONTINUE;
				}
				
				new Text[121];
				
				while (!feof(FilePointer))
				{
					fgets(FilePointer, Text, charsmax(Text));
					trim(Text);
					
					if ((Text[0] == ';') || !Text[0] || ((Text[0] == '/') && (Text[1] == '/')))
					{
						continue;
					}
					
					strtolower(Text);
					TrieSetCell(SafeCommands, Text, 0);
				}
				fclose(FilePointer);
			}
			goto Valid;
		}
		else
		{
			Valid:
			strtolower(Said);
			if (TrieKeyExists(SafeCommands, Said))
			{
				return PLUGIN_CONTINUE;
			}
			
			new CvarString[32];
			getString(PluginCvar[Tag], CvarString, charsmax(CvarString));
			#if AMXX_VERSION_NUM < 183
				client_print_color(Index, Grey, LangType, LANG_PLAYER, "ROM_BIND_SPAM", "^3", CvarString, "^4");
			#else
				client_print_color(Index, print_team_grey, LangType, LANG_PLAYER, "ROM_BIND_SPAM", CvarString);
			#endif
			return PLUGIN_HANDLED;
		}
		return PLUGIN_CONTINUE;
	}
   
	return PLUGIN_CONTINUE;
}

hookForXFakePlayerSpam(Index, Said[])
{
	new xFakePlayerCvarValue = getInteger(PluginCvar[xfakeplayer_spam]), CvarString[32];
	if (is_user_admin(Index))
	{
		if ( FirstMsg[Index] && xFakePlayerCvarValue == 1 )
		{
			FirstMsg[Index] = false;
		}
		return PLUGIN_CONTINUE;
	}
	getString(PluginCvar[Tag], CvarString, charsmax(CvarString));
	switch( xFakePlayerCvarValue )
	{
		case 1 :
		{
			if (Gag[Index])
			{
				return PLUGIN_HANDLED;
			}
			
			remove_quotes(Said);
	
			if ( strlen(Said) <= getInteger(PluginCvar[xfakeplayer_spam_maxchars])+1 )
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
					copy(PreviousMessage[Index], charsmax(PreviousMessage[]), Said);
					return PLUGIN_HANDLED;
				}
			}
	
			if ( ClSaidSameTh_Count[Index]++ > 0 )
			{
				if ( equal(Said, PreviousMessage[Index]) )
				{
					if ( getInteger(PluginCvar[plug_warn]) == 1 )
					{
						#if AMXX_VERSION_NUM < 183
							client_print_color(Index, Grey, LangType, LANG_PLAYER, "ROM_XFAKE_PLAYERS_SPAM_WARN", "^3", CvarString, "^4");
						#else
							client_print_color(Index, print_team_grey, LangType, LANG_PLAYER, "ROM_XFAKE_PLAYERS_SPAM_WARN", CvarString);
						#endif
					}		
			
					if ( ClSaidSameTh_Count[Index] >= getInteger(PluginCvar[xfakeplayer_spam_maxsais]) )
					{
						new Address[32];
						get_user_ip(Index, Address, charsmax(Address), 1);
						switch ( getInteger(PluginCvar[xfakeplayer_spam_type]) )
						{
							case 0 :
							{
								#if AMXX_VERSION_NUM < 183
									client_print_color(Index, Grey, LangType, LANG_PLAYER, "ROM_XFAKE_PLAYERS_SPAM_GAG", "^3", CvarString, "^4");
								#else
									client_print_color(Index, print_team_grey, LangType, LANG_PLAYER, "ROM_XFAKE_PLAYERS_SPAM_GAG", CvarString);
								#endif
								Gag[Index] = true;
								return PLUGIN_HANDLED; 
							}
							case 1 :
							{
								if ( getInteger(PluginCvar[plug_warn]) == 1 )
								{
									console_print(Index, LangType, Index, "ROM_XFAKE_PLAYERS_SPAM_KICK", CvarString);
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
					
								num_to_str(getInteger(PluginCvar[xfakeplayer_spam_punish]), Punish, charsmax(Punish));
		
								if ( getInteger(PluginCvar[plug_warn]) == 1 )
								{
									new CvarTag[32];
									copy(CvarTag, charsmax(CvarTag), CvarString);
							
									#if AMXX_VERSION_NUM < 183
										client_print_color(0, Grey, LangType, LANG_PLAYER, "ROM_XFAKE_PLAYERS_SPAM", "^3", CvarTag, "^4", Address);
										client_print_color(0, Grey, LangType, LANG_PLAYER, "ROM_XFAKE_PLAYERS_SPAM_PUNISH", "^3", CvarTag, "^4", Punish);
									#else
										client_print_color(0, print_team_grey, LangType, LANG_PLAYER, "ROM_XFAKE_PLAYERS_SPAM", CvarTag, Address);
										client_print_color(0, print_team_grey, LangType, LANG_PLAYER, "ROM_XFAKE_PLAYERS_SPAM_PUNISH", CvarTag, Punish);
									#endif
					
									console_print(Index, LangType, Index, "ROM_XFAKE_PLAYERS_SPAM_BAN", CvarString, Punish);
								}
						
								server_cmd("addip ^"%s^" ^"%s^";wait;writeip", Punish, Address);
							}
						}
				
						if ( getInteger(PluginCvar[plug_log]) == 1 )
						{
							logCommand(NoLogInfo, LangType, LANG_SERVER, "ROM_XFAKE_PLAYERS_SPAM_LOG", CvarString, Address);
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
			remove_quotes(Said);
			if ( !UnBlockedChat[Index] )
			{
				if (equal(Said, Capcha[Index]))
				{
					UnBlockedChat[Index] = true;
					#if AMXX_VERSION_NUM < 183
						client_print_color(Index, Grey, LangType, LANG_PLAYER, "ROM_XFAKE_PLAYERS_ALLOW_USE_CHAT", "^3", CvarString, "^4");
					#else
						client_print_color(Index, print_team_grey, LangType, LANG_PLAYER, "ROM_XFAKE_PLAYERS_ALLOW_USE_CHAT", CvarString);
					#endif
					return PLUGIN_HANDLED;
				}
				else
				{	
					#if AMXX_VERSION_NUM < 183
						client_print_color(Index, Grey, LangType, LANG_PLAYER, "ROM_XFAKE_PLAYERS_CAPCHA", "^3", CvarString, "^4", "^3", Capcha[Index], "^4");
					#else
						client_print_color(Index, print_team_grey, LangType, LANG_PLAYER, "ROM_XFAKE_PLAYERS_CAPCHA", CvarString, Capcha[Index]);
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

bool:getAccess(Index, UserPass[], len)
{
	new UserName[MAX_NAME_LENGTH], CvarString[32];

	get_user_name(Index, UserName, charsmax(UserName));
	
	if (!(get_user_flags(Index) & ADMIN_RESERVATION))
	{
		getString(PluginCvar[Tag], CvarString, charsmax(CvarString));
		#if AMXX_VERSION_NUM < 183
			client_print_color(Index, Grey, LangType, LANG_PLAYER, "ROM_ADMIN_HASNT_SLOT", "^3", CvarString, "^4");
		#else
			client_print_color(Index, print_team_grey, LangType, LANG_PLAYER, "ROM_ADMIN_HASNT_SLOT", CvarString);
		#endif
		return false;
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
				remove_user_flags(Index);
				set_user_flags(Index, Access);
				IsAdmin[Index] = true;
				set_task(0.1, "delayforSavingLastPass", Index, UserPass, len);
			}
			
			break;
		}
	}
	
	return true;
}

public loadAdminLogin()
{
	new Path[64], CvarString[32];
	
	get_localinfo("amxx_configsdir", Path, charsmax(Path));
	getString(PluginCvar[admin_login_file], CvarString, charsmax(CvarString));
	format(Path, charsmax(Path), "%s/%s", Path, CvarString);
	
	if ( !file_exists(Path) )
	{
		new FilePointer = fopen(Path, "wt");
		
		if ( !FilePointer ) 
		{
			return;
		}
		
		if ( getInteger(PluginCvar[plug_log]) == 1 )
		{
			getString(PluginCvar[Tag], CvarString, charsmax(CvarString));
			logCommand(NoLogInfo, LangType, LANG_SERVER, "ROM_FILE_NOT_FOUND", CvarString, Path);
		}
		
		fputs(FilePointer, "; Aici vor fi inregistrate adminele protejate.^n");
		fputs(FilePointer, "; Exemplu de adaugare admin : ^"nume^" ^"parola^" ^"acces^" ^"f^"^n");
		
		fclose(FilePointer);
	}
	else
	{
		new FilePointer = fopen(Path, "rt");
		
		if ( !FilePointer ) 
		{
			return;
		}
		
		if (LoginName == Invalid_Trie)
		{
			LoginName = TrieCreate();
		}
		TrieClear(LoginName);
		
		#if AMXX_VERSION_NUM < 183
			AdminNum = 0;
		#endif
		
		new Text[121], Name[MAX_NAME_LENGTH], Password[32], Access[26], Flags[6], TempData[AdminLogin];
		
		while (!feof(FilePointer))
		{
			fgets(FilePointer, Text, charsmax(Text));

			trim(Text);
		
			if ( (Text[0] == ';') || !Text[0] || ((Text[0] == '/') && (Text[1] == '/')) )
			{
				continue;
			}
		
			if (parse(Text, Name, charsmax(Name), TempData[LoginPass], charsmax(TempData[LoginPass]), 
							TempData[LoginAccess], charsmax(TempData[LoginAccess]), TempData[LoginFlag], charsmax(TempData[LoginFlag])) != 4)
			{
				continue;
			}
		
			strtolower(Name);
			TrieSetArray(LoginName, Name, TempData, charsmax(TempData));
		
			#if AMXX_VERSION_NUM < 183
				++AdminNum;
			#endif
		
			if (getInteger(PluginCvar[admin_login_debug]) == 1)
			{
				server_print(LangType, LANG_SERVER, "ROM_ADMIN_DEBUG", Name, Password, Access, Flags);
			}
		}
		
		fclose(FilePointer);
	}

	
}

logCommand(Index, const StandardMessage[], any:...)
{
	new LogMessage[256], Time[32], MapName[64];
	
	get_time(" %H:%M:%S ", Time, charsmax(Time));
	vformat(LogMessage, charsmax(LogMessage), StandardMessage, 3);
	get_mapname(MapName, charsmax(MapName));
	format(LogMessage, charsmax(LogMessage), "L %s|%s| %s", Time, MapName, LogMessage);
	
	if (Index != NoLogInfo)
	{
		new String[32];
		get_user_name(Index, String, charsmax(String));
		#if AMXX_VERSION_NUM < 183
			replace_all(LogMessage, charsmax(LogMessage), "$name$", String);
		#else
			replace_string(LogMessage, charsmax(LogMessage), "$name$", String);
		#endif
			
		get_user_ip(Index, String, charsmax(String), any:true);
		#if AMXX_VERSION_NUM < 183
			replace_all(LogMessage, charsmax(LogMessage), "$ip$", String);
		#else
			replace_string(LogMessage, charsmax(LogMessage), "$ip$", String);
		#endif
			
		if (Index)
		{
			get_user_authid(Index, String, charsmax(String));
		}
		else
		{
			copy(String, charsmax(String), "SERVER");
		}
		#if AMXX_VERSION_NUM < 183
			replace_all(LogMessage, charsmax(LogMessage), "$authid$", String);
		#else
			replace_string(LogMessage, charsmax(LogMessage), "$authid$", String);
		#endif
	}
	
	server_print(LogMessage);
	write_file(LogFile, LogMessage, -1);
}

getString(Cvar, Buffer[], Len)
{
	get_pcvar_string(Cvar, Buffer, Len);
}

getInteger(Cvar)
{
	return get_pcvar_num(Cvar);
}

Float:getFloat(Cvar)
{	
	return get_pcvar_float(Cvar);
} 

registersPrecache()
{
	if (getHldsVersion() < 6027)
	{
		#if AMXX_VERSION_NUM >= 183
			PluginCvar[autobuy_bug] = create_cvar("rom_autobuy_bug" ,"1", _, _, true, 0.0, true, 1.0);
			PluginCvar[utf8_bom] = create_cvar("rom_utf8_bom", "0", _, _, true, 0.0, true, 1.0);
		#else
			PluginCvar[autobuy_bug] = register_cvar("rom_autobuy_bug", "1");
			PluginCvar[utf8_bom] = register_cvar("rom_utf8_bom", "0");
		#endif
	}
	else
	{
		#if AMXX_VERSION_NUM >= 183
			PluginCvar[autobuy_bug] = create_cvar("rom_autobuy_bug" ,"0", _, _, true, 0.0, true, 1.0);
			PluginCvar[utf8_bom] = create_cvar("rom_utf8_bom", "1", _, _, true, 0.0, true, 1.0);
		#else
			PluginCvar[autobuy_bug] = register_cvar("rom_autobuy_bug", "0");
			PluginCvar[utf8_bom] = register_cvar("rom_utf8_bom", "1");
		#endif
	}
	
	for (new i = 2; i < AllCvars; i++)
	{
		#if AMXX_VERSION_NUM >= 183
			PluginCvar[i] = create_cvar(CvarName[i] ,CvarValue[i], _, _, bool:CvarLimits[i][hasMinValue], float(CvarLimits[i][minValue]),
									  bool:CvarLimits[i][hasMaxValue], float(CvarLimits[i][maxValue]));
		#else
			PluginCvar[i] = register_cvar(CvarName[i] ,CvarValue[i]);
		#endif
	}
}

registersInit()
{
	register_plugin(PluginName, Version, "FioriGinal.Ro");
	register_cvar("rom_protect", Version, FCVAR_SERVER | FCVAR_SPONLY);
	
	register_clcmd("say", "hookChat");
	register_clcmd("say_team", "hookChat");
	
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
	for (new i = 0; String[i] != 0; ++i)
	{
		if ((String[i] == '#' || String[i] == '+') && isalpha(String[i+1]))
		{
			format(String[i+1], Len, " %s", String[i+1]);
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
	new FilePointer = fopen(CfgFile, "wt"), CvarString[32];
	
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
		fprintf(FilePointer, "rom_cmd_bug ^"%d^"^n^n", getInteger(PluginCvar[cmd_bug]));
	}
	else
	{
		fputs(FilePointer, "rom_cmd_bug ^"1^"^n^n");
	}
	
	fputs(FilePointer, "// Cvar      : rom_spec_bug^n");
	fputs(FilePointer, "// Scop      : Urmareste activitatea jucatorilor si opreste schimbarea echipei la spectator daca acestia au deschis meniul de selectare al modelului, pentru a opri specbug.^n");
	fputs(FilePointer, "// Impact    : Serverul primeste crash in momentul in care se apeleaza la acest bug.^n");
	fputs(FilePointer, "// Update    : Incepand cu versiunea 1.0.4s, plugin-ul nu mai face greseli, astfel incat nu se vor mai face detectii false.^n");
	fputs(FilePointer, "// Valoarea 0: Functia este dezactivata.^n");
	fputs(FilePointer, "// Valoarea 1: Atacul este blocat. [Default]^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_spec_bug ^"%d^"^n^n", getInteger(PluginCvar[spec_bug]));
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
			fprintf(FilePointer, "rom_admin_chat_flood ^"%d^"^n", getInteger(PluginCvar[admin_chat_flood]));
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
			fprintf(FilePointer, "rom_admin_chat_flood_time ^"%.2f^"^n", getFloat(PluginCvar[admin_chat_flood_time]));
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
		fprintf(FilePointer, "rom_autobuy_bug ^"%d^"^n^n", getInteger(PluginCvar[autobuy_bug]));
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
		fprintf(FilePointer, "rom_fake_players ^"%d^"^n^n", getInteger(PluginCvar[fake_players]));
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
		fprintf(FilePointer, "rom_fake_players_limit ^"%d^"^n^n", getInteger(PluginCvar[fake_players_limit]));
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
		fprintf(FilePointer, "rom_fake_players_type ^"%d^"^n^n", getInteger(PluginCvar[fake_players_type]));
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
		fprintf(FilePointer, "rom_fake_players_punish ^"%d^"^n^n", getInteger(PluginCvar[fake_players_punish]));
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
		fprintf(FilePointer, "rom_delete_custom_hpk ^"%d^"^n^n", getInteger(PluginCvar[delete_custom_hpk]));
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
		fprintf(FilePointer, "rom_delete_vault ^"%d^"^n^n", getInteger(PluginCvar[delete_vault]));
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
		fprintf(FilePointer, "rom_advertise ^"%d^"^n^n", getInteger(PluginCvar[advertise]));
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
		fprintf(FilePointer, "rom_advertise_time ^"%d^"^n^n", getInteger(PluginCvar[advertise_time]));
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
		fprintf(FilePointer, "rom_warn ^"%d^"^n^n", getInteger(PluginCvar[plug_warn]));
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
		fprintf(FilePointer, "rom_log ^"%d^"^n^n", getInteger(PluginCvar[plug_log]));
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
		fprintf(FilePointer, "rom_admin_login ^"%d^"^n^n", getInteger(PluginCvar[admin_login]));
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
		getString(PluginCvar[admin_login_file], CvarString, charsmax(CvarString));
		fprintf(FilePointer, "rom_admin_login_file ^"%s^"^n^n", CvarString);
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
		fprintf(FilePointer, "rom_admin_login_debug ^"%d^"^n^n", getInteger(PluginCvar[admin_login_debug]));
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
		fprintf(FilePointer, "rom_utf8_bom ^"%d^"^n^n", getInteger(PluginCvar[utf8_bom]));
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
		getString(PluginCvar[Tag], CvarString, charsmax(CvarString));
		fprintf(FilePointer, "rom_tag ^"%s^"^n^n", CvarString);
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
		fprintf(FilePointer, "rom_color_bug ^"%d^"^n^n", getInteger(PluginCvar[color_bug]));
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
		fprintf(FilePointer, "rom_motdfile ^"%d^"^n^n", getInteger(PluginCvar[motdfile]));
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
		fprintf(FilePointer, "rom_anti_pause ^"%d^"^n^n", getInteger(PluginCvar[anti_pause]));
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
		fprintf(FilePointer, "rom_anti_ban_class ^"%d^"^n^n", getInteger(PluginCvar[anti_ban_class]));
	}
	else
	{
		fputs(FilePointer, "rom_anti_ban_class ^"2^"^n^n");
	}
	
	fputs(FilePointer, "// Cvar      : rom_give_info^n");
	fputs(FilePointer, "// Scop      : Serverul va trimite utilizatorului informatii despre plugin.^n");
	fputs(FilePointer, "// Impact    : Cand cineva va scrie ^"rom_info^" in consola, ii vor fi livrate informatiile (tot in consola).^n");
	fputs(FilePointer, "// Nota      : Daca mesajul este transmis prin intermediul consolei serverului, acesta va primi cateva informatii suplimentare.^n");
	fputs(FilePointer, "// Valoarea 0: Functia este dezactivata.^n");
	fputs(FilePointer, "// Valoarea 1: Functia este activata. [Default]^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_give_info ^"%d^"^n^n", getInteger(PluginCvar[info]));
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
	fputs(FilePointer, "// Valoarea 2: Pluginul va interzice oricarui client sa scrie in chat pana cand nu va introduce un cod capcha in chat. (cod prestabilit sau cod la intamplare, asta se seteaza la cvar-ul rom_xfakeplayer_spam_capcha)^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_xfakeplayer_spam ^"%d^"^n^n", getInteger(PluginCvar[xfakeplayer_spam]));
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
		fprintf(FilePointer, "rom_xfakeplayer_spam_maxchars ^"%d^"^n^n", getInteger(PluginCvar[xfakeplayer_spam_maxchars]));
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
		fprintf(FilePointer, "rom_xfakeplayer_spam_maxsais ^"%d^"^n^n", getInteger(PluginCvar[xfakeplayer_spam_maxsais]));
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
		fprintf(FilePointer, "rom_xfakeplayer_spam_type ^"%d^"^n^n", getInteger(PluginCvar[xfakeplayer_spam_type]));
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
		fprintf(FilePointer, "rom_xfakeplayer_spam_punish ^"%d^"^n^n", getInteger(PluginCvar[xfakeplayer_spam_punish]));
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
		fprintf(FilePointer, "rom_xfakeplayer_spam_capcha ^"%d^"^n^n", getInteger(PluginCvar[xfakeplayer_spam_capcha]));
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
		getString(PluginCvar[xfakeplayer_spam_capcha_word], CvarString, charsmax(CvarString));
		fprintf(FilePointer, "rom_xfakeplayer_spam_capcha_word ^"%s^"^n^n", CvarString);
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
		fprintf(FilePointer, "rom_prot_cvars ^"%d^"^n^n", getInteger(PluginCvar[protcvars]));
	}
	else
	{
		fputs(FilePointer, "rom_prot_cvars ^"1^"^n^n");
	}
	
	fputs(FilePointer, "// Cvar      : rom_console_say^n");
	fputs(FilePointer, "// Scop      : Impiedica trimiterea mesajelor din consola, blocand astfel bindurile.^n");
	fputs(FilePointer, "// Impact    : Opreste spam-ul si de ce nu, unele reclame.^n");
	fputs(FilePointer, "// Nota      : Daca doriti sa adaugati cuvinte care sa reprezinte exceptii pentru acesta functie cuvintele trebuiesc scrise in fisierul ^"rom_protect.ini^".^n");
	fputs(FilePointer, "// Nota      : Aceasta protectie nu este perfecta, ci doar un filtu. Se poate trece usor de ea.");
	fputs(FilePointer, "// Valoarea 0: Functia este dezactivata.^n");
	fputs(FilePointer, "// Valoarea 1: Functia este activata. [Default]^n");
	if (exist)
	{
		fprintf(FilePointer, "rom_console_say ^"%d^"^n^n", getInteger(PluginCvar[console_say]));
	}
	else
	{
		fputs(FilePointer, "rom_console_say ^"1^"^n^n");
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
			fputs(FilePointer, "ROM_FAKE_PLAYERS_DETECT_LOG = %s : L-am detectat pe ^"$name$^" [ $authid$ | $ip$ ] ca suspect de ^"xFake-Players^" sau ^"xSpammer^".^n");
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
		
		#if AMXX_VERSION_NUM < 183
			formatex(Line, charsmax(Line), "ROM_ADMIN_HASNT_SLOT = %L^n", LANG_SERVER, "ROM_ADMIN_HASNT_SLOT", "^%s", "^%s", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_ADMIN_HASNT_SLOT = %s%s : %sNu iti poti incarca adminul daca nu ai slot.^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#else
			formatex(Line, charsmax(Line), "ROM_ADMIN_HASNT_SLOT = %L^n", LANG_SERVER, "ROM_ADMIN_HASNT_SLOT", "^%s" );
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_ADMIN_HASNT_SLOT = ^^3%s : ^^4Nu iti poti incarca adminul daca nu ai slot.^n");
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
			fputs(FilePointer, "ROM_CMD_BUG_LOG = %s : L-am detectat pe ^"$name$^" [ $authid$ | $ip$ ] ca a incercat sa foloseasca ^"CMD_BUG^" ca sa strice buna functionare a serverului.^n");
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
			
			fputs(FilePointer, "ROM_COLOR_BUG_LOG = %s : L-am detectat pe ^"$name$^" [ $authid$ | $ip$ ] ca a incercat sa foloseasca ^"COLOR_BUG^" ca sa alerteze playerii sau adminii.^n");
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
			fputs(FilePointer, "ROM_SPEC_BUG_LOG = %s : L-am detectat pe ^"$name$^" [ $authid$ | $ip$ ] ca a incercat sa foloseasca ^"SPEC_BUG^" ca sa strice buna functionare a serverului.^n");
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
				fputs(FilePointer, "ROM_ADMIN_CHAT_FLOOD_LOG = %s : L-am detectat pe ^"$name$^" [ $authid$ | $ip$ ] ca a incercat sa foloseasca ^"ADMIN_CHAT_FLOOD^" ca sa dea kick adminilor de pe server.^n");	
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
			fputs(FilePointer, "ROM_AUTOBUY_LOG = %s : L-am detectat pe ^"$name$^" [ $authid$ | $ip$ ] ca a incercat sa foloseasca ^"AUTOBUY_BUG^" ca sa strice buna functionare a serverului.^n");
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
			fputs(FilePointer, "ROM_MOTDFILE_LOG = %s : L-am detectat pe ^"$name$^" [ $authid$ | $ip$ ] ca a incercat sa foloseasca cvar-ul ^"motdfile^" ca sa fure informatii din acest server.^n");	
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
			fputs(FilePointer, "ROM_ANTI_ANY_BAN_CLASS_LOG = %s : L-am detectat pe ^"$name$^" [ $authid$ | $ip$ ] ca a incercat sa dea ban pe clasa de ip.^n");	
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
			fputs(FilePointer, "ROM_ANTI_SOME_BAN_CLASS_LOG = %s : L-am detectat pe ^"$name$^" [ $authid$ | $ip$ ] ca a incercat sa dea ban pe mai mult de %s clase de ip.^n");	
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
		
		
		#if AMXX_VERSION_NUM < 183
			formatex(Line, charsmax(Line), "ROM_BIND_SPAM = %L^n", LANG_SERVER, "ROM_BIND_SPAM", "^%s", "^%s", "^%s");
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_BIND_SPAM = %s%s : %sNu ai voie sa trimiti mesaje prin intermediul consolei !^n");
			}
			else
			{
				fputs(FilePointer, Line);
			}
		#else
			formatex(Line, charsmax(Line), "ROM_BIND_SPAM = %L^n", LANG_SERVER, "ROM_BIND_SPAM", "^%s");
			if ( contain(Line, "ML_NOTFOUND") != -1 )
			{
				fputs(FilePointer, "ROM_BIND_SPAM = ^^3%s : ^^4Nu ai voie sa trimiti mesaje prin intermediul consolei !.^n");
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
			fputs(FilePointer, "ROM_PROTCVARS_LOG = %s : L-am detectat pe ^"$name$^" [ $authid$ | $ip$ ] ca a incercat sa schimbe cvar-urile pluginului de protectie, astea pot fi schimbate doar din fisierul configurator.^n");	
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
		fputs(FilePointer, "ROM_FAKE_PLAYERS_DETECT_LOG = %s : L-am detectat pe ^"$name$^" [ $authid$ | $ip$ ] ca suspect de ^"xFake-Players^" sau ^"xSpammer^".^n");
		
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
		
		#if AMXX_VERSION_NUM < 183
			fputs(FilePointer, "ROM_ADMIN_HASNT_SLOT = %s%s : %sNu iti poti incarca adminul daca nu ai slot.^n");
		#else
			fputs(FilePointer, "ROM_ADMIN_HASNT_SLOT = ^^3%s : ^^4Nu iti poti incarca adminul daca nu ai slot.^n");
		#endif 
		
		fputs(FilePointer, "ROM_ADMIN_WITHOUT_PASS_PRINT = %s : Nu ai introdus nici o parola, comanda se scris in consola astfel : login ^"parola ta^".^n");

		#if AMXX_VERSION_NUM < 183
			fputs(FilePointer, "ROM_CMD_BUG = %s%s : %sS-au observat caractere interzise in textul trimis de tine. Mesajul tau a fost eliminat.^n");
		#else
			fputs(FilePointer, "ROM_CMD_BUG = ^^3%s : ^^4S-au observat caractere interzise in textul trimis de tine. Mesajul tau a fost eliminat.^n");
		#endif 
		
		fputs(FilePointer, "ROM_CMD_BUG_LOG = %s : L-am detectat pe ^"$name$^" [ $authid$ | $ip$ ] ca a incercat sa foloseasca ^"CMD_BUG^" ca sa strice buna functionare a serverului.^n");
		fputs(FilePointer, "ROM_CMD_BUG_PRINT = %s : S-au observat caractere interzise in textul trimis de tine. Mesajul tau a fost eliminat.^n");
		
		#if AMXX_VERSION_NUM < 183
			fputs(FilePointer, "ROM_COLOR_BUG = %s%s : %sS-au observat caractere suspecte in textul trimis de tine. Mesajul tau a fost eliminat.^n");
		#else
			fputs(FilePointer, "ROM_COLOR_BUG = ^^3%s : ^^4S-au observat caractere suspecte in textul trimis de tine. Mesajul tau a fost eliminat.^n");
		#endif
		
		fputs(FilePointer, "ROM_COLOR_BUG_LOG = %s : L-am detectat pe ^"$name$^" [ $authid$ | $ip$ ] ca a incercat sa foloseasca ^"COLOR_BUG^" ca sa alerteze playerii sau adminii.^n");
		fputs(FilePointer, "ROM_COLOR_BUG_PRINT = %s : S-au observat caractere suspecte in textul trimis de tine. Mesajul tau a fost eliminat.^n");		
		
		#if AMXX_VERSION_NUM < 183
			fputs(FilePointer, "ROM_SPEC_BUG = %s%s : %sAi facut o miscare suspecta asa ca te-am mutat la echipa precedenta.^n");
		#else
			fputs(FilePointer, "ROM_SPEC_BUG = ^^3%s : ^^4Ai facut o miscare suspecta asa ca te-am mutat la echipa precedenta.^n");
		#endif
		
		fputs(FilePointer, "ROM_SPEC_BUG_LOG = %s : L-am detectat pe ^"$name$^" [ $authid$ | $ip$ ] ca a incercat sa foloseasca ^"SPEC_BUG^" ca sa strice buna functionare a serverului.^n");
		
		#if AMXX_VERSION_NUM < 183
			fputs(FilePointer, "ROM_ADMIN_CHAT_FLOOD = %s%s : %sS-a observat un mic IsFlooding la chat primit din partea ta. Mesajele trimise de tine vor fi filtrate.^n");
			fputs(FilePointer, "ROM_ADMIN_CHAT_FLOOD_LOG = %s : L-am detectat pe ^"$name$^" [ $authid$ | $ip$ ] ca a incercat sa foloseasca ^"ADMIN_CHAT_FLOOD^" ca sa dea kick adminilor de pe server.^n");	
		#endif
		
		#if AMXX_VERSION_NUM < 183
			fputs(FilePointer, "ROM_AUTOBUY = %s%s : %sComanda trimisa de tine are valori suspecte, asa ca am blocat-o.^n");
		#else
			fputs(FilePointer, "ROM_AUTOBUY = ^^3%s : ^^4Comanda trimisa de tine are valori suspecte, asa ca am blocat-o.^n");
		#endif
		
		fputs(FilePointer, "ROM_AUTOBUY_LOG = %s : L-am detectat pe ^"$name$^" [ $authid$ | $ip$ ] ca a incercat sa foloseasca ^"AUTOBUY_BUG^" ca sa strice buna functionare a serverului.^n");
		
		fputs(FilePointer, "ROM_FILE_NOT_FOUND = %s : Fisierul %s nu exista.^n");
		
		fputs(FilePointer, "ROM_ADMIN_DEBUG = Nume : %s - Parola : %s - Acces : %s - Flag : %s^n");
		
		fputs(FilePointer, "ROM_MOTDFILE = %s : S-a detectat o miscare suspecta din partea ta, comanda ta a fost blocata.^n");
		fputs(FilePointer, "ROM_MOTDFILE_LOG = %s : L-am detectat pe ^"$name$^" [ $authid$ | $ip$ ] ca a incercat sa foloseasca cvar-ul ^"motdfile^" ca sa fure informatii din acest server.^n");		
		
		#if AMXX_VERSION_NUM < 183
			fputs(FilePointer, "ROM_ADVERTISE = %s%s :%s Acest server este supravegheat de plugin-ul de protectie %s%s%s versiunea %s%s%s .^n");
		#else
			fputs(FilePointer, "ROM_ADVERTISE = ^^3%s :^^4 Acest server este supravegheat de plugin-ul de protectie ^^3%s^^4 versiunea ^^3%s^^4 .^n");
		#endif
		
		fputs(FilePointer, "ROM_ANTI_BAN_CLASS = %s : S-au detectat u numar prea mare de ban-uri pe clasa de ip, comanda ta a fost blocata.^n");
		fputs(FilePointer, "ROM_ANTI_ANY_BAN_CLASS_LOG = %s : L-am detectat pe ^"$name$^" [ $authid$ | $ip$ ] ca a incercat sa dea ban pe clasa de ip.^n");	
		fputs(FilePointer, "ROM_ANTI_SOME_BAN_CLASS_LOG = %s : L-am detectat pe ^"$name$^" [ $authid$ | $ip$ ] ca a incercat sa dea ban pe mai mult de %s clase de ip.^n");

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
		fputs(FilePointer, "ROM_PROTCVARS_LOG = %s : L-am detectat pe ^"$name$^" [ $authid$ | $ip$ ] ca a incercat sa schimbe cvar-urile pluginului de protectie, astea pot fi schimbate doar din fisierul configurator.^n");
		
		#if AMXX_VERSION_NUM < 183
			fputs(FilePointer, "ROM_BIND_SPAM = %s%s : %sNu ai voie sa trimiti mesaje prin intermediul consolei !.^n");
		#else
			fputs(FilePointer, "ROM_BIND_SPAM = ^^3%s : ^^4Nu ai voie sa trimiti mesaje prin intermediul consolei !^n");
		#endif
		
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
*               -  Cod pentru solutia spec bug.
* JaiLBreaK :   -  Metoda verificare mesaj daca este transmit din consola sau prin messagemode.
*/

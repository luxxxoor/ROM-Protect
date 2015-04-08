#include <amxmisc>
#include <fakemeta>

#pragma semicolon 1

#if AMXX_VERSION_NUM < 181 
    #assert AMX Mod X v1.8.1 or later library required!
#endif 

static const Version[]           = "1.0.4f-dev4",
			 Build               = 50,
			 PluginName[]        = "ROM-Protect",
			 Terrorist[]         = "#Terrorist_Select",
			 Counter_Terrorist[] = "#CT_Select",
			 CfgFile[]           = "addons/amxmodx/configs/rom_protect.cfg",
			 LangFile[]          = "addons/amxmodx/data/lang/rom_protect.txt",
			 PlugLocation[]      = "/addons/amxmodx/plugins/rom_protect.amxx",
			 OldPlugLocation[]   = "/addons/amxmodx/plugins/rom_protect.amxx.old",
			 LangType[]          = "%L",
			 NewLine             = -1;

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

#define OFFSET_TEAM  114 
#define fm_set_user_team(%1,%2)  set_pdata_int( %1, OFFSET_TEAM, %2 )
#define fm_get_user_team(%1)     get_pdata_int( %1, OFFSET_TEAM ) 

#if AMXX_VERSION_NUM < 183
	#define MAX_PLAYERS 32		
	#define MAX_NAME_LENGTH 32
	new bool:flood[MAX_PLAYERS+1];
	new Float:g_Flooding[MAX_PLAYERS+1] = {0.0, ...},
			  g_Flood[MAX_PLAYERS+1] = {0, ...};		  
	enum Color
	{
		NORMAL = 1, // clients scr_concolor cvar color
		GREEN, // Green Color
		TEAM_COLOR, // Red, grey, blue
		GREY, // grey
		RED, // Red
		BLUE, // Blue
	}
#else		
	#if MAX_PLAYERS != 32		
		#define MAX_PLAYERS 32		
	#endif
#endif

new ArgNum[MAX_PLAYERS+1], Contor[MAX_PLAYERS+1], File[128], MapName[32],
	bool:Name[MAX_PLAYERS+1], bool:IsAdmin[MAX_PLAYERS+1];
new LoginName[1024][32], LoginPass[1024][32], LoginAccess[1024][32], LoginFlag[1024][32],
	LastPass[MAX_PLAYERS+1][32], MenuText[MAX_PLAYERS+1][MAX_PLAYERS];
new AdminsNum, FileSize, bool:IsLangUsed;

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
	auto_update,
	info
};

new const CvarName[AllCvars][] = 
{
	"rom_autobuy_bug",
	"rom_utf8-bom",
	"rom_tag",
	"rom_cmd-bug",
	"rom_spec-bug",
	"rom_fake-players",
	"rom_fake-players_limit",
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
	"rom_color-bug",
	"rom_motdfile",
	"rom_anti-pause",
	"rom_anti-ban-class",
	"rom_auto_update",
	"rom_info"
};

new const CvarValue[AllCvars][] =
{
	"1",
	"1",	
	"*ROM-Protect",
	"1",
	"1",
	"1",
	"5",
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
	"1"
};

new PlugCvar[AllCvars];

new Trie:g_tDefaultRes;

new const char_list[ ] =
{
	'A','B','C','D','E','F','G','H',
	'I','J','K','L','M','N','O','P',
	'Q','R','S','T','U','V','W','X',
	'Y','Z','a','b','c','d','e','f',
	'g','h','i','j','k','l','m','n',
	'o','p','q','r','s','t','u','v',
	'w','x','y','z','!','@','#','$',
	'%','&','*','(',')','_','-','+',
	'=','\','|','[','{',']','}',':',
	',','<','.','>','/','?','0','1',
	'2','3','4','5','6','7','8','9'
};

public plugin_precache()
{	
	registersPrecache();
	
	new szCurentDate[15];
	get_localinfo("amxx_logs", File, charsmax(File));
	formatex(File, charsmax(File), "%s/%s", File, PluginName);
	
	if ( !dir_exists(File) )
	{
		mkdir(File);
	}
	
	get_time("%d-%m-%Y", szCurentDate, charsmax(szCurentDate));
	formatex(File, charsmax( File ), "%s/%s_%s.log", File, PluginName, szCurentDate);
	
	if ( !file_exists(File) )
	{
		write_file(File, "*Aici este salvata activitatea suspecta a fiecarui jucator.", NewLine);
		write_file(File, " ", NewLine);
		write_file(File, " ", NewLine);
	}
	
	get_mapname(MapName, charsmax(MapName));
	format(MapName, charsmax(MapName), "|%s| ", MapName);
	
	if ( file_exists(CfgFile) )
	{
		server_cmd("exec %s", CfgFile);
	}
	
	if ( getNum(PlugCvar[auto_update]) == 1 )
	{
		FileSize = file_size(PlugLocation);
		rename_file(PlugLocation, OldPlugLocation, 1);
		#if AMXX_VERSION_NUM == 183
			HTTP2_Download("http://rom-protect.lixter.com/rom_protect.amxx", PlugLocation, "Complete");
		#endif
		#if AMXX_VERSION_NUM == 182
			HTTP2_Download("http://rom-protect.lixter.com/rom_protect2.amxx", PlugLocation, "Complete");
		#endif
		#if AMXX_VERSION_NUM == 181
			HTTP2_Download("http://rom-protect.lixter.com/rom_protect1.amxx", PlugLocation, "Complete");
		#endif
	}
	
	
	set_task(5.0, "CheckLang");
	set_task(10.0, "CheckLangFile");
	set_task(15.0, "CheckCfg");
}

public CheckCfg()
{
	if ( !file_exists(CfgFile) )
	{
		WriteCfg(false);
	}
	else
	{
		new File = fopen(CfgFile, "r+");
		
		new Text[121], bool:FindVersion; 
		while ( !feof(File) )
		{
			fgets(File, Text, charsmax(Text));
			
			if ( containi(Text, Version) != -1 )
			{
				FindVersion = true;
				break;
			}
		}
		if ( !FindVersion )
		{
			WriteCfg(true);
			if ( getNum(PlugCvar[plug_log]) == 1 )
			{
				logCommand(LangType, LANG_SERVER, "ROM_UPDATE_CFG", getString(PlugCvar[Tag]));
			}
		}
	}
}

public CheckLang()
{
	if ( !file_exists(LangFile) )
	{
		WriteLang(false);
	}
	else
	{
		IsLangUsed = false;
		new File = fopen(LangFile, "r+");
		
		new Text[121], bool:IsCurrentVersionUsed;
		while ( !feof(File) )
		{
			fgets(File, Text, charsmax(Text));
			
			if ( containi(Text, Version) != -1 )
			{
				IsCurrentVersionUsed = true;
				break;
			}
		}
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

public CheckLangFile()
{
	if (!IsLangUsed)
	{
		register_dictionary("rom_protect.txt");
	}
}

public plugin_init()
{
	registersInit();
	
	if ( getNum(PlugCvar[advertise]) == 1 )
	{
		set_task(getFloat(PlugCvar[advertise_time]), "showAdvertise", _, _, _, "b", 0);
	}
	
	if ( getNum(PlugCvar[utf8_bom]) == 1 )
	{
		g_tDefaultRes = TrieCreate();
		TrieSetCell(g_tDefaultRes, "de_storm.res", 1);
		TrieSetCell(g_tDefaultRes, "default.res", 1);
		
		set_task(10.0, "cleanResFiles");
	}
}

public client_connect(id)
{
	if ( getNum(PlugCvar[cmd_bug]) == 1 )
	{
		new name[MAX_NAME_LENGTH];
		get_user_name(id, name, charsmax(name));
		stringFilter(name, charsmax(name));
		set_user_info(id, "name", name);
	}
	if ( getNum(PlugCvar[fake_players]) == 1 )
	{
		new players[MAX_PLAYERS], pnum, address[32], address2[32];
		if ( clientUseSteamid(id) )
		{
			query_client_cvar(id, "fps_max", "checkBot");
		}
		get_players(players, pnum, "c");
		for (new i = 0; i < pnum; ++i)
		{
			get_user_ip(id, address, charsmax(address), 1);
			get_user_ip(players[i], address2, charsmax(address2), 1);
			if ( equal(address, address2) && !is_user_bot(id) )
			{
				if ( ++Contor[id] > getNum(PlugCvar[fake_players_limit]) )
				{
					server_cmd("addip ^"30^" ^"%s^";wait;writeip", address);
					if ( getNum(PlugCvar[plug_warn]) == 1 )
					{
						#if AMXX_VERSION_NUM < 183
							ColorChat(0, GREY, LangType, LANG_PLAYER, "ROM_FAKE_PLAYERS", '^3', getString(PlugCvar[Tag]), '^4', address);
							ColorChat(0, GREY, LangType, LANG_PLAYER, "ROM_FAKE_PLAYERS_PUNISH", '^3', getString(PlugCvar[Tag]), '^4');
						#else
							client_print_color(0, print_team_grey, LangType, LANG_PLAYER, "ROM_FAKE_PLAYERS", getString(PlugCvar[Tag]), address);
							client_print_color(0, print_team_grey, LangType, LANG_PLAYER, "ROM_FAKE_PLAYERS_PUNISH", getString(PlugCvar[Tag]));
						#endif
					}
					if ( getNum(PlugCvar[plug_log]) == 1 )
					{
						logCommand(LangType, LANG_SERVER, "ROM_FAKE_PLAYERS_LOG", getString(PlugCvar[Tag]), address);
					}
					break;
				}
			}
		}
	}
} 

public client_disconnect(id)
{
	Contor[id] = 0;
	if ( IsAdmin[id] )
	{
		IsAdmin[id] = false;
		remove_user_flags(id);
	}
}

public plugin_end()
{
	if ( getNum(PlugCvar[delete_vault]) != 0 )
	{
		new baseDir[128], text[200] ;
		
		get_basedir(baseDir, charsmax(baseDir));
		formatex(baseDir, charsmax(baseDir), "%s/data/vault.ini", baseDir);
		
		if ( file_exists(baseDir) )
		{
			delete_file(baseDir);
			
			switch(getNum( PlugCvar[delete_vault]))
			{
				case 1:
				{
					formatex(text, charsmax(text), "server_language en", baseDir);
					write_file( baseDir, text, NewLine);
				}
				case 2:
				{
					formatex(text, charsmax(text) , "server_language ro", baseDir);
					write_file(baseDir, text, NewLine);
				}
			}
		}
	}
	if ( getNum(PlugCvar[delete_custom_hpk]) == 1 )
	{
		new baseDir[] = "/", dirPointer, File[32];
		
		dirPointer = open_dir(baseDir, "", 0);
		
		while ( next_file(dirPointer, File, charsmax(File)) )
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
		
		close_dir(dirPointer);
	}
	return PLUGIN_CONTINUE;
}


public client_infochanged(id)
{
	if (!is_user_connected(id))
	{
		return PLUGIN_CONTINUE;
	}
		
	static newName[MAX_NAME_LENGTH], oldName[MAX_NAME_LENGTH];
	get_user_name(id, oldName, charsmax(oldName));
	get_user_info(id, "name", newName, charsmax(newName));
	
	if (getNum(PlugCvar[cmd_bug]) == 1)
	{
		stringFilter(newName, charsmax(newName));
		set_user_info(id, "name", newName);
	}
	
	if (!equali(newName, oldName) && IsAdmin[id])
	{
		IsAdmin[id] = false;
		remove_user_flags(id);
	}
	
	return PLUGIN_CONTINUE;
}

public plugin_pause()
{
	if (getNum(PlugCvar[anti_pause]) == 1)
	{
		if (getNum(PlugCvar[plug_warn]) == 1)
		{
			#if AMXX_VERSION_NUM < 183
				ColorChat(0, GREY, LangType, LANG_PLAYER, "ROM_PLUGIN_PAUSE", '^3', getString(PlugCvar[Tag]), '^4');
			#else
				client_print_color(0, print_team_grey, LangType, LANG_PLAYER, "ROM_PLUGIN_PAUSE", getString(PlugCvar[Tag]));
			#endif
		}
		
		if (getNum(PlugCvar[plug_log]) == 1)
		{
				logCommand(LangType, LANG_SERVER, "ROM_PLUGIN_PAUSE_LOG", getString(PlugCvar[Tag]), getString(PlugCvar[Tag]));
		}
		
		server_cmd("amxx unpause rom_protect.amxx");
	}
}

public cmdPass(id)
{
	if ( getNum(PlugCvar[admin_login]) != 1 )
	{
		return PLUGIN_HANDLED;
	}

	new name[MAX_NAME_LENGTH], pass[32];
	
	get_user_name(id, name, charsmax(name));
	read_argv(1, pass, charsmax(pass));
	remove_quotes(pass);
	
	if (equal(LastPass[id], pass) && IsAdmin[id])
	{
		#if AMXX_VERSION_NUM < 183
			ColorChat(id, GREY, LangType, id, "ROM_ADMIN_ALREADY_LOADED", '^3', getString(PlugCvar[Tag]), '^4');
		#else
			client_print_color(id, print_team_grey, LangType, id, "ROM_ADMIN_ALREADY_LOADED", getString(PlugCvar[Tag]));
		#endif
		client_print(id, print_console, LangType, id, "ROM_ADMIN_ALREADY_LOADED_PRINT", getString(PlugCvar[Tag]));
		return PLUGIN_HANDLED;
	}	

	loadAdminLogin();
	getAccess(id, pass);
	
	if (!IsAdmin[id])
	{
		if (!Name[ id ])
		{
			#if AMXX_VERSION_NUM < 183
				ColorChat(id, GREY, LangType, id, "ROM_ADMIN_WRONG_NAME", '^3', getString(PlugCvar[Tag]), '^4');
			#else
				client_print_color(id, print_team_grey, LangType, id, "ROM_ADMIN_WRONG_NAME", getString(PlugCvar[Tag]));
			#endif
			client_print(id, print_console, LangType, id, "ROM_ADMIN_WRONG_NAME_PRINT", getString(PlugCvar[Tag]));
		}
		else
		{
			#if AMXX_VERSION_NUM < 183
				ColorChat(id, GREY, LangType, id, "ROM_ADMIN_WRONG_PASS", '^3', getString(PlugCvar[Tag]), '^4');
			#else
				client_print_color(id, print_team_grey, LangType, id, "ROM_ADMIN_WRONG_PASS", getString(PlugCvar[Tag]));
			#endif
			client_print(id, print_console, LangType, id, "ROM_ADMIN_WRONG_PASS_PRINT", getString(PlugCvar[Tag]));
		}
	}
	else
	{
		#if AMXX_VERSION_NUM < 183
			ColorChat(id, GREY, LangType, id, "ROM_ADMIN_LOADED", '^3', getString(PlugCvar[Tag]), '^4');
		#else
			client_print_color(id, print_team_grey, LangType, id, "ROM_ADMIN_LOADED", getString(PlugCvar[Tag]));
		#endif
		client_print(id, print_console, LangType, id, "ROM_ADMIN_LOADED_PRINT", getString(PlugCvar[Tag]));
	}
	
	return PLUGIN_CONTINUE;
}

#if AMXX_VERSION_NUM < 183
	public hookAdminChat(id)
	{
		new said[2];
		
		read_argv(1, said, charsmax(said));

		if (said[0] != '@')
		{
			return PLUGIN_CONTINUE;
		}

		new Float:maxChat = get_pcvar_float(PlugCvar[admin_chat_flood_time]);

		if (maxChat && getNum(PlugCvar[admin_chat_flood]) == 1)
		{
			new Float:nexTime = get_gametime();

			if (g_Flooding[id] > nexTime)
			{
				if (g_Flood[id] >= 3)
				{
					flood[id] = true;
					set_task(1.0, "showAdminChatFloodWarning", id);
					g_Flooding[id] = nexTime + maxChat + 3.0;
					return PLUGIN_HANDLED;
				}
				++g_Flood[id];
			}
			else
			{
				if (g_Flood[id])
				{
					--g_Flood[id];
				}
			}
			
			g_Flooding[id] = nexTime + maxChat;
		}

		return PLUGIN_CONTINUE;
	}
#endif

public oldStyleMenusTeammenu(msg, des, rec)
{
	if ( is_user_connected(rec) && getNum(PlugCvar[spec_bug]) == 1)
	{
		get_msg_arg_string(4, MenuText[rec], charsmax(MenuText));
		
		if (equal(MenuText[rec], Terrorist) || equal(MenuText[rec], Counter_Terrorist))
		{
			set_task(0.1, "blockSpecbugOldStyleMenus", rec);
		}
	}
}

public vGuiTeammenu(msg, des, rec)  
{  
	if ( getNum(PlugCvar[spec_bug]) == 1)
	{
		if ( get_msg_arg_int(1) == 26 || get_msg_arg_int(1) == 27 )
		{
			ArgNum[rec] = get_msg_arg_int(1);
			set_task(0.1, "blockSpecbugVGui", rec);
		}
	}
}

public blockSpecbugOldStyleMenus(id)
{
	if ( !is_user_alive(id) && is_user_connected(id) )
	{
		if ( fm_get_user_team(id) == FM_TEAM_SPECTATOR && !is_user_alive(id) )
		{
			if ( equal(MenuText[id], Terrorist) && is_user_connected(id) )
			{
				fm_set_user_team(id, FM_TEAM_T);
			}
				
			if ( equal(MenuText[id], Counter_Terrorist) && is_user_connected(id) )
			{
				fm_set_user_team(id, FM_TEAM_CT);
			}
				
			if ( getNum(PlugCvar[plug_warn]) )
			{
				#if AMXX_VERSION_NUM < 183
					ColorChat(id,GREY, LangType, id, "ROM_SPEC_BUG", '^3', getString(PlugCvar[Tag]), '^4');
				#else
					client_print_color(id, print_team_grey, LangType, id, "ROM_SPEC_BUG", getString(PlugCvar[Tag]));
				#endif
			}
			
			if (getNum(PlugCvar[plug_log]))
			{
				logCommand(LangType, LANG_SERVER, "ROM_SPEC_BUG_LOG", getString(PlugCvar[Tag]), getInfo(id, INFO_NAME), getInfo(id, INFO_AUTHID), getInfo(id, INFO_IP));
			}
		}
		
		set_task(0.1, "blockSpecbugOldStyleMenus", id);
	}
}

public blockSpecbugVGui(id)
{
	if ( !is_user_alive(id) && is_user_connected(id) )
	{
		if ( fm_get_user_team(id) == FM_TEAM_SPECTATOR )
		{
			new bool:bug_log[MAX_PLAYERS+1];
				
			if ( ArgNum[id] == 26 )
			{
				fm_set_user_team(id, FM_TEAM_T);
				bug_log[id] = true;
			}    
			
			if ( ArgNum[id] == 27 )
			{
				fm_set_user_team(id, FM_TEAM_CT);
				bug_log[id] = true;
			}   
			
			if ( getNum(PlugCvar[plug_warn]) == 1 && bug_log[id] )
			{
				#if AMXX_VERSION_NUM < 183
					ColorChat(id, GREY, LangType, id, "ROM_SPEC_BUG", '^3', getString(PlugCvar[Tag]), '^4');
				#else
					client_print_color(id, print_team_grey, LangType, id, "ROM_SPEC_BUG", getString(PlugCvar[Tag]));
				#endif
			}
			
			if ( getNum( PlugCvar[plug_log]) == 1 && bug_log[id] )
			{
				logCommand(LangType, LANG_SERVER, "ROM_SPEC_BUG_LOG", getString(PlugCvar[Tag]), getInfo(id, INFO_NAME), getInfo(id, INFO_AUTHID), getInfo(id, INFO_IP));
				bug_log[id] = false;
			}
		}
		
		set_task(0.1, "blockSpecbugVGui", id);
	}
}

#if AMXX_VERSION_NUM < 183
	public showAdminChatFloodWarning(id)
	{
		if ( flood[id] )
		{
			if ( getNum(PlugCvar[plug_warn]) == 1 )
			{
					ColorChat(id, GREY, LangType, id, "ROM_ADMIN_CHAT_FLOOD", '^3', getString(PlugCvar[Tag]), '^4');
			}
			
			if ( getNum(PlugCvar[plug_log]) == 1 )
			{
				logCommand(LangType, LANG_SERVER, "ROM_ADMIN_CHAT_FLOOD_LOG", getString(PlugCvar[Tag]), getInfo(id, INFO_NAME), getInfo(id, INFO_AUTHID), getInfo(id, INFO_IP));
			}
			
			flood[id] = false;
		}
	}
#endif

public showAdvertise()
{
	#if AMXX_VERSION_NUM < 183
		ColorChat(0, GREY, LangType, LANG_PLAYER, "ROM_ADVERTISE", '^3', getString(PlugCvar[Tag]), '^4', '^3', PluginName, '^4', '^3', Version, '^4');
	#else
		client_print_color(0, print_team_grey, LangType, LANG_PLAYER, "ROM_ADVERTISE", getString(PlugCvar[Tag]), PluginName, Version);
	#endif
}

public cleanResFiles() 
{ 
	new mapsFolder[] = "maps"; 
	new const resExt[] = ".res"; 
	new resFile[64], len; 
	new dp = open_dir(mapsFolder, resFile, charsmax(resFile)); 
	
	if ( !dp )
	{
		return; 
	}
	
	new fullPathFileName[128];
	
	do 
	{ 
		len = strlen(resFile);
		
		if ( len > 4 && equali(resFile[len-4], resExt) ) 
		{ 
			if ( TrieKeyExists(g_tDefaultRes, resFile) ) 
			{
				continue;
			}
			
			formatex(fullPathFileName, charsmax(fullPathFileName), "%s/%s", mapsFolder, resFile); 
			write_file(fullPathFileName, "/////////////////////////////////////////////////////////////^n", 0); 
		} 
	} 
	while (next_file(dp, resFile, charsmax(resFile)));
	
	close_dir(dp);
} 


public reloadLogin(id, level, cid) 
{
	set_task(1.0, "reloadDelay");
}

public reloadDelay()
{
	new players[MAX_PLAYERS], pnum;
	
	get_players(players, pnum, "ch");
	
	for (new i = 0; i < pnum; ++i)
	{
		if ( IsAdmin[players[i]] )
		{
			getAccess(players[i], LastPass[players[i]]);
		}
	}
}

public cvarFunc(id, level, cid) 
{ 
	if ( getNum(PlugCvar[motdfile]) == 1 )
	{
		new arg[32], arg2[32]; 
		
		read_argv(1, arg, charsmax(arg));
		read_argv(2, arg2, charsmax(arg2));
		
		if ( equali(arg, "motdfile") && contain(arg2, ".ini") != -1 ) 
		{
			if ( getNum(PlugCvar[plug_warn]) == 1 )
			{
				console_print(id, LangType, id, "ROM_MOTDFILE", getString(PlugCvar[Tag]));
			}
			
			if ( getNum(PlugCvar[plug_log]) == 1 )
			{
				logCommand(LangType, LANG_SERVER, "ROM_MOTDFILE_LOG", getString(PlugCvar[Tag]), getInfo(id, INFO_NAME), getInfo(id, INFO_AUTHID), getInfo(id, INFO_IP));
			}
			
			return PLUGIN_HANDLED; 
		}
	}
	
	return PLUGIN_CONTINUE; 
}

public hookBanClassCommand(id)
{ 
	if ( !is_user_admin(id) )
	{
		return PLUGIN_CONTINUE;
	}
	
	if ( getNum(PlugCvar[anti_ban_class]) > 0 )
	{
		new ip[32], IpNum[4][3], NumStr[1], Value;
		
		read_argv(1, ip, charsmax(ip));
		
		if ( containi( ip, "STEAM") != -1 || containi( ip, "VALVE") != -1 )
		{
			return PLUGIN_CONTINUE;
		}
		
		for	(new i = 0; i < 4; ++i)
		{
			split(ip, IpNum[i], charsmax(IpNum[]), ip, charsmax(ip), ".");
		}
		
		Value = getNum(PlugCvar[anti_ban_class]);
		
		if ( Value > 4 || Value < 0 )
		{
			Value = 4;
		}
			
		num_to_str(Value,NumStr,charsmax(NumStr));
		
		switch (Value)
		{
			case 1:
			{
				if ( !str_to_num(IpNum[0]) || !str_to_num(IpNum[1]) || !str_to_num(IpNum[2]) )
				{
					if (getNum(PlugCvar[plug_warn]) == 1)
					{
						console_print(id, LangType, id, "ROM_ANTI_BAN_CLASS", getString(PlugCvar[Tag]));
					}
					
					if (getNum(PlugCvar[plug_log]) == 1)
					{
						logCommand(LangType, LANG_SERVER, "ROM_ANTI_ANY_BAN_CLASS_LOG", getString(PlugCvar[Tag]), getInfo(id, INFO_NAME), getInfo(id, INFO_AUTHID), getInfo(id, INFO_IP));
					}
					
					return PLUGIN_HANDLED;
				}
			}
			case 2:
			{
				if ( !str_to_num(IpNum[0]) || !str_to_num(IpNum[1]) )
				{
					if (getNum(PlugCvar[plug_warn]) == 1)
					{
						console_print(id, LangType, id, "ROM_ANTI_BAN_CLASS", getString(PlugCvar[Tag]));
					}
					
					if (getNum(PlugCvar[plug_log]) == 1)
					{
						logCommand(LangType, LANG_SERVER, "ROM_ANTI_SOME_BAN_CLASS_LOG", getString(PlugCvar[Tag]), getInfo(id, INFO_NAME), getInfo(id, INFO_AUTHID), getInfo(id, INFO_IP), NumStr);
					}
					
					return PLUGIN_HANDLED;
				}
			}
			case 3:
			{
				if ( !str_to_num(IpNum[0]) )
				{
					if (getNum(PlugCvar[plug_warn]) == 1)
					{
						console_print(id, LangType, id, "ROM_ANTI_BAN_CLASS", getString(PlugCvar[Tag]));
					}
					
					if (getNum(PlugCvar[plug_log]) == 1)
					{
						logCommand(LangType, LANG_SERVER, "ROM_ANTI_SOME_BAN_CLASS_LOG", getString(PlugCvar[Tag]), getInfo(id, INFO_NAME), getInfo(id, INFO_AUTHID), getInfo(id, INFO_IP), NumStr);
					}
					
					return PLUGIN_HANDLED;
				}
			}
			default:
			{
				if (getNum(PlugCvar[plug_warn]) == 1)
				{
					console_print(id, LangType, id, "ROM_ANTI_BAN_CLASS", getString(PlugCvar[Tag]));
				}
				
				if (getNum(PlugCvar[plug_log]) == 1)
				{
					logCommand(LangType, LANG_SERVER, "ROM_ANTI_SOME_BAN_CLASS_LOG", getString(PlugCvar[Tag]), getInfo(id, INFO_NAME), getInfo(id, INFO_AUTHID), getInfo(id, INFO_IP), NumStr);
				}
				
				return PLUGIN_HANDLED;
			}
		}
	}
	
	return PLUGIN_CONTINUE;
}

public hookBasicOnChatCommand(id)
{
	if ( getNum(PlugCvar[color_bug]) == 1 || getNum(PlugCvar[cmd_bug]) == 1 )
	{
		new said[192];
		
		read_args(said, charsmax(said));
		
		new s_said[192], bool:b_said_cmd_bug[MAX_PLAYERS+1], bool:b_said_color_bug[MAX_PLAYERS+1];
		
		copy(s_said, charsmax( said ), said);
		
		for (new i = 0; i < sizeof s_said ; ++i)
		{
			if ( getNum(PlugCvar[cmd_bug]) == 1 && (s_said[ i ] == '#' && isalpha(s_said[i+1])) || (s_said[i] == '%' && s_said[i+1] == 's') )
			{
				b_said_cmd_bug[id] = true;
				break;
			}
			if ( getNum(PlugCvar[color_bug]) == 1 )
			{
				if ( s_said[i] == '' || s_said[i] == '' || s_said[i] == '' )
				{
					b_said_color_bug[id] = true;
					break;
				}
			}
		}
		
		if ( b_said_cmd_bug[id] )
		{
			if ( getNum(PlugCvar[plug_warn]) == 1 )
			{
				#if AMXX_VERSION_NUM < 183
					ColorChat( id, GREY, LangType, id, "ROM_CMD_BUG", '^3', getString(PlugCvar[Tag]), '^4');
				#else
					client_print_color( id, print_team_grey, LangType, id, "ROM_CMD_BUG", getString(PlugCvar[Tag]) );
				#endif
				console_print(id, LangType, id, "ROM_CMD_BUG_PRINT", getString(PlugCvar[Tag]));
			}
			if ( getNum(PlugCvar[plug_log]) == 1 )
			{
				logCommand(LangType, LANG_SERVER, "ROM_CMD_BUG_LOG", getString(PlugCvar[Tag]), getInfo(id, INFO_NAME), getInfo(id, INFO_AUTHID), getInfo(id, INFO_IP));
			}
			b_said_cmd_bug[id] = false;
			return PLUGIN_HANDLED;
		}
		if ( b_said_color_bug[id] )
		{
			if ( getNum(PlugCvar[plug_warn]) == 1 )
			{
				#if AMXX_VERSION_NUM < 183
					ColorChat( id, GREY, LangType, id, "ROM_COLOR_BUG", '^3', getString(PlugCvar[Tag]), '^4');
				#else
					client_print_color( id, print_team_grey, LangType, id, "ROM_COLOR_BUG", getString(PlugCvar[Tag]) );
				#endif
			}
			if ( getNum(PlugCvar[plug_log]) == 1 )
			{
				logCommand(LangType, LANG_SERVER, "ROM_COLOR_BUG_LOG", getString(PlugCvar[Tag]), getInfo(id, INFO_NAME), getInfo(id, INFO_AUTHID), getInfo(id, INFO_IP));
			}
			b_said_color_bug[id] = false;
			return PLUGIN_HANDLED;
		}
	}
	return PLUGIN_CONTINUE;
}

public checkBot(id, const Var[], const Value[])
{
    if ( equal(Var, "fps_max") && Value[0] == 'B' )
    {
		if ( getNum(PlugCvar[plug_log]) == 1 )
		{
				logCommand(LangType, LANG_SERVER, "ROM_FAKE_PLAYERS_DETECT_LOG", getString(PlugCvar[Tag]), getInfo(id, INFO_NAME), getInfo(id, INFO_AUTHID), getInfo(id, INFO_IP));
		}
		
		console_print(id, LangType, id, "ROM_FAKE_PLAYERS_DETECT", getString(PlugCvar[Tag]));
		server_cmd("kick #%d ^"You got kicked. Check console.^"", get_user_userid(id));
    }
}

public CheckAutobuyBug(id)		
{		
	new Command[512];
	new Count = read_argc();
	
	for (new i = 1; i <= Count; ++i)
	{		
		read_argv(i, Command, charsmax(Command));
		if ( getNum(PlugCvar[autobuy_bug]) == 1 )
		{
			if ( CheckLong(Command, charsmax(Command)) )
			{		
				if ( getNum(PlugCvar[plug_warn]) == 1 )
				{		
					#if AMXX_VERSION_NUM < 183		
						ColorChat( id, GREY, LangType, id, "ROM_AUTOBUY", '^3', getString(PlugCvar[Tag]), '^4');		
					#else		
						client_print_color( id, print_team_grey, LangType, id, "ROM_AUTOBUY", getString(PlugCvar[Tag]));
					#endif		
				}
			
				if ( getNum( PlugCvar[plug_log] ) == 1 )
				{
					logCommand(LangType, LANG_SERVER, "ROM_AUTOBUY_LOG", getString(PlugCvar[Tag]), getInfo(id, INFO_NAME), getInfo(id, INFO_AUTHID), getInfo(id, INFO_IP));
				}
			
				return PLUGIN_HANDLED;		
			}
		}
	}
	
	return PLUGIN_CONTINUE;		
}

public Complete(Index, Error) 
{
	if ( Error == 0 && file_size(PlugLocation) > 40000 ) 
	{
		if ( FileSize != file_size(PlugLocation) )
		{
			logCommand(LangType, LANG_SERVER, "ROM_AUTO_UPDATE_SUCCEED", getString(PlugCvar[Tag]));
		}
		delete_file(OldPlugLocation);
	}
	else
	{
		logCommand(LangType, LANG_SERVER, "ROM_AUTO_UPDATE_FAILED", getString(PlugCvar[Tag]));
		delete_file(PlugLocation);
		rename_file(OldPlugLocation, PlugLocation, 1);
	}
}

public giveClientInfo(id)
{
	if ( getNum(PlugCvar[info]) != 1 )
	{
		return PLUGIN_HANDLED;
	}
		
	client_print(id, print_console, "^n^n^nVersiune curenta : %s. Build : %d", Version, Build);
	client_print(id, print_console, "Autor : lüxor # Dr.Fio & DR2.IND. Comunitatea : FioriGinal.Ro" );
	client_print(id, print_console, "Link oficial : http://forum.fioriginal.ro/amxmodx-plugins-pluginuri/rom-protect-anti-flood-bug-fix-t28292.html");
	client_print(id, print_console, "Contact : luxxxoor (Steam) / al3xdinamo13 (Skype).^n^n^n");
	
	return PLUGIN_CONTINUE;
}

public giveServerInfo(id)
{
	if ( getNum(PlugCvar[info]) != 1 )
	{
		return PLUGIN_HANDLED;
	}
	
	server_print("^n^n^nVersiune curenta : %s. Build : %d", Version, Build);
	server_print("Autor : lüxor # Dr.Fio & DR2.IND. Comunitatea : FioriGinal.Ro" );
	server_print("Link oficial : http://forum.fioriginal.ro/amxmodx-plugins-pluginuri/rom-protect-anti-flood-bug-fix-t28292.html");
	server_print("Contact : luxxxoor (Steam) / al3xdinamo13 (Skype).");
	server_print("Sursa in dezvoltare : https://github.com/luxxxoor/ROM-Protect ^n");
	server_print("Acest plugin este unul OpenSource ! Este interzisa copierea/vinderea lui pentru a scoate bani.");
	server_print("Pluginul se afla in plina dezvoltare si este menit sa ofere un minim de siguranta serverelor care \
				  nu provin de la firme de host scumpe, care sa comfere siguranta serverelor. Clientii pot  edita \
				  pluginul dupa bunul lui plac, fie din fisierul configurator si fisier lang, fie direct din sursa \
				  acestuia.");
	server_print("Copyright 2014-2015");
	
	return PLUGIN_CONTINUE;
}

loadAdminLogin()
{
	new path[64];
	
	get_localinfo("amxx_configsdir", path, charsmax(path));
	formatex(path, charsmax(path), "%s/%s", path, getString(PlugCvar[admin_login_file]));
	
	new file = fopen(path, "r+");
	
	if ( !file )
	{
		if ( getNum(PlugCvar[plug_log]) == 1 )
		{
			logCommand( LangType, LANG_SERVER, "ROM_FILE_NOT_FOUND", getString(PlugCvar[Tag]), getString(PlugCvar[admin_login_file]));
		}
		
		return;
	}
	
	new text[121], name[MAX_NAME_LENGTH], pass[32], acc[26], flags[6];
	
	for (AdminsNum = 0; !feof( file ); ++AdminsNum)
	{
		fgets(file, text, charsmax(text));
		
		trim(text);
		
		if ( (text[0] == ';') || !strlen(text) || (text[0] == '/') )
		{
			continue;
		}
		
		if (parse(text, name, charsmax(name), pass, charsmax(pass), acc, charsmax(acc), flags, charsmax(flags)) != 4)
		{
			continue;
		}
		
		copy(LoginName[AdminsNum], charsmax(LoginName[]),  name);
		copy(LoginPass[AdminsNum], charsmax(LoginPass[]),  pass);
		copy(LoginAccess[AdminsNum], charsmax(LoginAccess[]),  acc);
		copy(LoginFlag[AdminsNum], charsmax(LoginFlag[]),  flags);
		
		if (getNum(PlugCvar[admin_login_debug]) == 1)
		{
			server_print(LangType, LANG_SERVER, "ROM_ADMIN_DEBUG", LoginName[AdminsNum], LoginPass[AdminsNum], LoginAccess[AdminsNum], LoginFlag[AdminsNum]);
		}
	}

	fclose(file);
}

getAccess(id, UserPass[])
{
	new userName[MAX_NAME_LENGTH], acces;

	get_user_info(id, "name", userName, charsmax(userName));
	
	if ( !(get_user_flags(id) & ADMIN_CHAT) )
	{
		remove_user_flags(id);
	}

	for (new i = 1; i <= AdminsNum; ++i)
	{
		if ( equali(LoginName[i], userName) )
		{
			Name[id] = true;
		}
		else
		{
			Name[id] = false;
		}
		
		if (equal(LoginFlag[i], "f") && Name[id])
		{
			if ( equal(LoginPass[i], UserPass) || IsAdmin[id] )
			{
				IsAdmin[id] = true;
				acces = read_flags(LoginAccess[i]);
				set_user_flags(id, acces);
				copy(LastPass[id], charsmax(LastPass[]), UserPass);
			}
			
			break;
		}
	}
}

logCommand(const Msg[], any:...)
{
	new Message[256], LogMessage[256];
	
	vformat(Message, charsmax(Message), Msg , 2);
	formatex(LogMessage, charsmax(LogMessage), "L %s%s%s", getTime(), MapName, Message);
	
	server_print(LogMessage);
	write_file(File, LogMessage, NewLine);
}

getInfo(id, INFO:iInfo)
{
	new const Server[32] = "SERVER"; // Trebuie sa aibe acealasi numar de caractere pentru a nu primi "error 047".
	switch (iInfo)
	{
		case INFO_NAME:
		{
			new name[32];
			get_user_name(id, name, charsmax(name));
			
			return name;
		}
		case INFO_IP:
		{
			new ip[32];
			get_user_ip(id, ip, charsmax(ip), 1);
			
			return ip;
		}
		case INFO_AUTHID:
		{
			new authid[32];
			if (id)
			{
				get_user_authid(id, authid, charsmax(authid));
				
				return authid;
			}
			else
			{
				return Server;
			}
		}
	}
	
	return Server; // Un return care nu se va apela niciodata, insa compilatorul nu va mai primi warning.
}

getTime()
{
	new Time[32];
	get_time(" %H:%M:%S ", Time, charsmax(Time));
	
	return Time;
}

getString(Text)
{
	new File[32]; 
	get_pcvar_string(Text, File, charsmax(File));
	
	return File;
}

getNum(Text)
{
	new Num;
	Num = get_pcvar_num(Text);
	
	return Num;
}

Float:getFloat(Text)
{
	new Float:float = get_pcvar_float(Text);
	
	return float;
} 

registersPrecache()
{
	if (getHldsVersion() < 6027)
	{
		PlugCvar[autobuy_bug] = register_cvar("rom_autobuy_bug", "1");
		PlugCvar[utf8_bom] = register_cvar("rom_utf8-bom", "0");
	}
	else
	{
		PlugCvar[autobuy_bug] = register_cvar("rom_autobuy_bug" , "0");
		PlugCvar[utf8_bom] = register_cvar("rom_utf8-bom", "1");
	}
	
	for (new i = 2; i < AllCvars; i++)
	{
		PlugCvar[i] = register_cvar(CvarName[i] , CvarValue[i]);
	}
}

registersInit()
{
	register_plugin(PluginName, Version, "FioriGinal.Ro");
	register_cvar("rom_protect", Version, FCVAR_SERVER | FCVAR_SPONLY);
	
	register_message(get_user_msgid( "ShowMenu" ), "oldStyleMenusTeammenu");
	register_message(get_user_msgid( "VGUIMenu" ), "vGuiTeammenu");
	
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
	
	register_clcmd("login", "cmdPass");
	register_concmd("amx_cvar", "cvarFunc");
	register_concmd("amx_reloadadmins", "reloadLogin");
	register_concmd("amx_addban", "hookBanClassCommand");
	register_clcmd("ROM_INFO", "giveClientInfo");
	register_srvcmd("ROM_INFO", "giveServerInfo");
}

public stringFilter(string[], len)
{
	for (new i = 0; i <= len; ++i)
	{
		if ( i < MAX_NAME_LENGTH )
		{
			if ( (string[i] == '#' && isalpha(string[i+1])) || (string[i] == '+' && isalpha(string[i+1])) )
			{
				string[i] = ' ';
			}
		}
	}
}

bool:clientUseSteamid(id) 
{	
	new authid[35]; 
	get_user_authid(id, authid, charsmax(authid) );
	
	return (contain(authid , ":") != -1 && containi(authid , "STEAM") != -1) ? true : false; 
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

CheckLong(cCommand[], Len)
{
	new mCommand[512];
	
	while (strlen(mCommand))
	{
		strtok(cCommand, mCommand, charsmax( mCommand ), cCommand, Len , ' ', 1);
		if (strlen( mCommand ) > 31)
		{
			return true;
		}
	}
	
	return false;
}

stock bool:CheckName( id )
	{
	new name[ MAX_NAME_LENGTH ];
	new contor = 0;
	new bool:b_name = false;
	get_user_info( id, "name", name, charsmax( name ) );
	//new i = 0, j = 0
	for(new i = 0 ; i <= charsmax( name ); ++i)
		{
		for(new j = 0 ; j <= charsmax( char_list ); ++j)
			{
			if ( name[ i ] == char_list[ j ] )
				b_name = true;
		}
		if ( b_name )
			{
			//server_print("debug 3 - %d", contor);
			++contor;
			b_name = false
		}              
		else
		{
			contor = 0
		}
		if ( contor >= 3)
			{
			//server_print("debug 1 - %d", contor);
			return true;
		}
	}
	//server_print("debug 2 - %d - %d - %d", contor, i, j);
	return false;
	//isalpha(ch)
}

WriteCfg( bool:exist )
{
	if (exist)
	{
		delete_file(CfgFile);
	}
	new line[121];
	
	writeSignature(CfgFile);
	
	write_file(CfgFile, "// Verificare daca CFG-ul a fost executat cu succes." , NewLine);
	write_file(CfgFile, "echo ^"*ROM-Protect : Fisierul rom_protect.cfg a fost gasit. Incep protejarea serverului.^"" , NewLine);
	write_file(CfgFile, "// Cvar      : rom_cmd-bug" , NewLine);
	write_file(CfgFile, "// Scop      : Urmareste chatul si opeste bugurile de tip ^"%s^"/^"%s0^" care dau pluginurile peste cap." , NewLine);
	write_file(CfgFile, "// Impact    : Serverul nu pateste nimic, insa playerii acestuia primesc ^"quit^" indiferent de ce client folosesc, iar serverul ramane gol.", NewLine);
	write_file(CfgFile, "// Update    : Incepand cu versiunea 1.0.1s, pluginul protejeaza serverele si de noul cmd-bug bazat pe caracterul '#'. Pluginul blocheaza de acum '#' si '%' in chat si '#' in nume.", NewLine);
	write_file(CfgFile, "// Update    : Incepand cu versiunea 1.0.3a, pluginul devine mai inteligent, si va bloca doar posibilele folosiri ale acestui bug, astfel incat caracterele '#' si '%' vor putea fi folosite, insa nu in toate cazurile.", NewLine);
	write_file(CfgFile, "// Update    : Incepand cu versiunea 1.0.3s, pluginul incearca sa inlature bugul provotat de caracterul '+' in nume, acesta incercand sa deruteze playerii sau adminii (nu aparea numele jucatorului in meniuri).", NewLine);
	write_file(CfgFile, "// Update    : Incepand cu versiunea 1.0.4b, pluginul verifica si comenzile de baza care pot elibera mesaje in chat (ex: amx_say, amx_psay, etc.), adica toate comenzile prezente in adminchat.amxx.", NewLine);
	write_file(CfgFile, "// Valoarea 0: Functia este dezactivata." , NewLine);
	write_file(CfgFile, "// Valoarea 1: Atacul este blocat. [Default]" , NewLine);
	if (exist)
	{
		formatex(line, charsmax(line), "rom_cmd-bug ^"%d^"", getNum(PlugCvar[cmd_bug]));
		write_file(CfgFile, line , NewLine);
	}
	else
	{
		write_file(CfgFile, "rom_cmd-bug ^"1^"" , NewLine);
	}
	write_file( CfgFile, " ", NewLine);
	
	write_file( CfgFile, "// Cvar      : rom_spec-bug", NewLine);
	write_file( CfgFile, "// Scop      : Urmareste activitatea playerilor si opreste schimbarea echipei, pentru a opri specbug.", NewLine);
	write_file( CfgFile, "// Impact    : Serverul primeste crash in momentul in care se apeleaza la acest bug.", NewLine);
	write_file( CfgFile, "// Nota      : -", NewLine);
	write_file( CfgFile, "// Valoarea 0: Functia este dezactivata.", NewLine);
	write_file( CfgFile, "// Valoarea 1: Atacul este blocat. [Default]", NewLine);
	if (exist)
	{
		formatex(line, charsmax(line), "rom_spec-bug ^"%d^"", getNum( PlugCvar [ spec_bug ] ));
		write_file( CfgFile, line, NewLine);
	}
	else
	{
		write_file( CfgFile, "rom_spec-bug ^"1^"", NewLine);
	}
	write_file( CfgFile, " ", NewLine);

	#if AMXX_VERSION_NUM < 183
		write_file( CfgFile, "// Cvar      : rom_admin_chat_flood", NewLine);
		write_file( CfgFile, "// Scop      : Urmareste activitatea playerilor care folosesc chat-ul adminilor, daca persoanele incearca sa floodeze acest chat sunt opriti fortat.", NewLine);
		write_file( CfgFile, "// Impact    : Serverul nu pateste nimic, insa adminii primesc kick cu motivul : ^"reliable channel overflowed^".", NewLine);
		write_file( CfgFile, "// Nota      : -", NewLine);
		write_file( CfgFile, "// Valoarea 0: Functia este dezactivata.", NewLine);
		write_file( CfgFile, "// Valoarea 1: Atacul este blocat. [Default]", NewLine);
		if (exist)
		{
			formatex(line, charsmax(line), "rom_admin_chat_flood ^"%d^"", getNum( PlugCvar [ admin_chat_flood ] ));
			write_file( CfgFile, line, NewLine);
		}
		else
		{
			write_file( CfgFile, "rom_admin_chat_flood ^"1^"", NewLine);  
		}
		write_file( CfgFile, " ", NewLine);
		
		write_file( CfgFile, "// Cvar      : rom_admin_chat_flood_time ( Activat numai in cazul in care cvarul ^"rom_admin_chat_flood^" este setat pe 1 )", NewLine);
		write_file( CfgFile, "// Utilizare : Limiteaza numarul maxim de mesaje trimise de acelasi cleint in chatul adminilor, blocand astfel atacurile tip overflow.", NewLine);
		if (exist)
		{
			formatex(line, charsmax(line), "rom_admin_chat_flood_time ^"%.2f^"", getFloat(PlugCvar[admin_chat_flood_time]));
			write_file( CfgFile, line, NewLine);
		}
		else
		{
			write_file( CfgFile, "rom_admin_chat_flood_time ^"0.75^"", NewLine);
		}
		write_file( CfgFile, "", NewLine);
	#endif
		
	write_file( CfgFile, "// Cvar      : rom_autobuy_bug", NewLine);		
	write_file( CfgFile, "// Scop      : Urmareste comenzile de tip autobuy/rebuy, iar daca acestea devin suspecte sunt oprite.", NewLine);		
	write_file( CfgFile, "// Impact    : Serverul primeste crash in momentul in care se apeleaza la autobuybug.", NewLine);		
	write_file( CfgFile, "// Nota      : Serverele cu engine HLDS 6xxx nu mai sunt vulnerabile la acest bug.", NewLine);		
	write_file( CfgFile, "// Valoarea 0: Functia este dezactivata.", NewLine);		
	write_file( CfgFile, "// Valoarea 1: Atacul este blocat. [Default]", NewLine);		
	if (exist)		
	{		
		formatex(line, charsmax(line), "rom_autobuy_bug ^"%d^"", getNum(PlugCvar[autobuy_bug]));		
		write_file( CfgFile, line, NewLine);		
	}		
	else
	{
		if (getHldsVersion() < 6027)
		{
			write_file( CfgFile, "rom_autobuy_bug ^"1^"", NewLine);
		}
		else
		{
			write_file( CfgFile, "rom_autobuy_bug ^"0^"", NewLine);
		}
	}
	write_file( CfgFile, " ", NewLine);		
	
	write_file( CfgFile, "// Cvar      : rom_fake-players", NewLine);
	write_file( CfgFile, "// Scop      : Urmareste persoanele conectate pe server si baneaza atunci cand numarul persoanelor cu acelasi ip il depaseste pe cel setat in cvarul rom_fake-players_limit.", NewLine);
	write_file( CfgFile, "// Impact    : Serverul experimenteaza lag peste 200+ la orice jucator prezent pe server, cateodata chiar crash.", NewLine);
	write_file( CfgFile, "// Nota      : Daca sunt mai multe persoane care impart aceasi legatura de internet pot fi banate ( 0 minute ), in acest caz ridicati cvarul : rom_fake-players_limit sau opriti rom_fake-players.", NewLine);
	write_file( CfgFile, "// Valoarea 0: Functia este dezactivata.", NewLine);
	write_file( CfgFile, "// Valoarea 1: Atacul este blocat prin ban 30 minute. [Default]", NewLine);
	if (exist)
	{
		formatex(line, charsmax(line), "rom_fake-players ^"%d^"", getNum(PlugCvar[fake_players]));
		write_file( CfgFile, line, NewLine);
	}
	else
	{
		write_file( CfgFile, "rom_fake-players ^"1^"", NewLine);
	}
	write_file( CfgFile, " ", NewLine);
	
	write_file( CfgFile, "// Cvar      : rom_fake-players_limit ( Activat numai in cazul in care cvarul ^"rom_fake-players^" este setat pe 1 )", NewLine);
	write_file( CfgFile, "// Utilizare : Limiteaza numarul maxim de persoane de pe acelasi IP, blocand astfel atacurile tip fake-player.", NewLine);
	if (exist)
	{
		formatex(line, charsmax(line), "rom_fake-players_limit ^"%d^"", getNum(PlugCvar[fake_players_limit]));
		write_file( CfgFile, line, NewLine);
	}
	else
	{
		write_file( CfgFile, "rom_fake-players_limit ^"5^"", NewLine);
	}
	write_file( CfgFile, " ", NewLine);	
	
	write_file( CfgFile, "// Cvar      : rom_delete_custom_hpk", NewLine);
	write_file( CfgFile, "// Scop      : La finalul fiecarei harti, se va sterge fisierul custom.hpk.", NewLine);
	write_file( CfgFile, "// Impact    : Serverul experimenteaza probleme la schimbarea hartii, aceasta putand sa dureze si pana la 60secunde.", NewLine);
	write_file( CfgFile, "// Nota      : -", NewLine);
	write_file( CfgFile, "// Valoarea 0: Functie este dezactivata.", NewLine);
	write_file( CfgFile, "// Valoarea 1: Fisierul este sters. [Default]", NewLine);
	if (exist)
	{
		formatex(line, charsmax(line), "rom_delete_custom_hpk ^"%d^"", getNum( PlugCvar [ delete_custom_hpk ] ));
		write_file( CfgFile, line, NewLine);
	}
	else
	{
		write_file( CfgFile, "rom_delete_custom_hpk ^"1^"", NewLine);
	}
	write_file( CfgFile, " ", NewLine);
	
	write_file( CfgFile, "// Cvar      : rom_delete_vault ", NewLine);
	write_file( CfgFile, "// Scop      : La finalul fiecarei harti, se va sterge fisierul vault.ini.", NewLine);
	write_file( CfgFile, "// Impact    : Serverul experimenteaza probleme la schimbarea hartii, aceasta putand sa dureze si pana la 60secunde.", NewLine);
	write_file( CfgFile, "// Nota      : -", NewLine);
	write_file( CfgFile, "// Valoarea 0: Functie este dezactivata.", NewLine);
	write_file( CfgFile, "// Valoarea 1: Fisierul este sters si e setat ^"server_language en^" in vault.ini. [Default]", NewLine);
	write_file( CfgFile, "// Valoarea 2: Fisierul este sters si e setat ^"server_language ro^" in vault.ini.", NewLine);
	if (exist)
	{
		formatex(line, charsmax(line), "rom_delete_vault ^"%d^"", getNum( PlugCvar [ delete_vault ] ));
		write_file( CfgFile, line, NewLine);
	}
	else
	{
		write_file( CfgFile, "rom_delete_vault ^"1^"", NewLine);
	}
	write_file( CfgFile, " ", NewLine);	
	
	write_file( CfgFile, "// Cvar      : rom_advertise", NewLine);
	write_file( CfgFile, "// Efect     : Afiseaza un mesaj prin care anunta clientii ca serverul este protejat de *ROM-Protect.", NewLine);
	write_file( CfgFile, "// Valoarea 0: Mesajele sunt dezactivate.", NewLine);
	write_file( CfgFile, "// Valoarea 1: Mesajele sunt activate. [Default]", NewLine);
	if (exist)
	{
		formatex(line, charsmax(line), "rom_advertise ^"%d^"", getNum( PlugCvar [ advertise ] ));
		write_file( CfgFile, line, NewLine);
	}
	else
	{
		write_file( CfgFile, "rom_advertise ^"1^"", NewLine);
	}
	write_file( CfgFile, " ", NewLine);	

	write_file( CfgFile, "// Cvar      : rom_advertise_time ( Activat numai in cazul in care cvarul ^"rom_advertise^" este setat pe 1 )", NewLine);
	write_file( CfgFile, "// Utilizare : Seteaza ca mesajul sa apara o data la (cat este setat cvarul) secunda/secunde. ", NewLine);
	if (exist)
	{
		formatex(line, charsmax(line), "rom_advertise_time ^"%d^"", getNum( PlugCvar [ advertise_time ] ));
		write_file( CfgFile, line, NewLine);
	}
	else
	{
		write_file( CfgFile, "rom_advertise_time ^"120^"", NewLine);
	}
	write_file( CfgFile, " ", NewLine);
	
	write_file( CfgFile, "// Cvar      : rom_warn ", NewLine);
	write_file( CfgFile, "// Efect     : Afiseaza mesaje prin care anunta clientii care incearca sa distube activitatea normala a serverului. ", NewLine);
	write_file( CfgFile, "// Valoarea 0: Mesajele sunt dezactivate.", NewLine);
	write_file( CfgFile, "// Valoarea 1: Mesajele sunt activate. [Default]", NewLine);
	if (exist)
	{
		formatex(line, charsmax(line), "rom_warn ^"%d^"", getNum( PlugCvar [ plug_warn ] ));
		write_file( CfgFile, line, NewLine);
	}
	else
	{
		write_file( CfgFile, "rom_warn ^"1^"", NewLine);
	}
	write_file( CfgFile, " ", NewLine);
	
	write_file( CfgFile, "// Cvar  : rom_log", NewLine);
	write_file( CfgFile, "// Efect : Permite sau nu plugin-ului sa ne creeze fisiere.log.", NewLine);
	write_file( CfgFile, "// Valoarea 0: Functia este dezactivata.", NewLine);
	write_file( CfgFile, "// Valoarea 1: Functia este activata.", NewLine);
	if (exist)
	{
		formatex(line, charsmax(line), "rom_log ^"%d^"", getNum( PlugCvar [ plug_log ] ));
		write_file( CfgFile, line, NewLine);
	}
	else
	{
		write_file( CfgFile, "rom_log ^"1^"", NewLine);
	}
	write_file( CfgFile, " ", NewLine);
	
	write_file( CfgFile, "// Cvar      : rom_admin_login", NewLine);
	write_file( CfgFile, "// Scop      : Permite autentificarea adminilor prin comanda ^"login parola^" in consola (nu necesita setinfo)", NewLine);
	write_file( CfgFile, "// Impact    : Parolele adminilor sunt foarte usor de furat in ziua de astazi, e destul doar sa intri pe un server iar parola ta dispare.", NewLine);
	write_file( CfgFile, "// Nota      : Adminele se adauga normal ^"nume^" ^"parola^" ^"acces^" ^"f^".", NewLine);
	write_file( CfgFile, "// Update    : Incepand de la versiunea 1.0.3a, comanda in chat !login sau /login dispare, deoarece nu era folosita.", NewLine);
	write_file( CfgFile, "// Valoarea 0: Functie este dezactivata.", NewLine);
	write_file( CfgFile, "// Valoarea 1: Adminele sunt protejate. [Default]", NewLine);
	if (exist)
	{
		formatex(line, charsmax(line), "rom_admin_login ^"%d^"", getNum( PlugCvar [ admin_login ] ));
		write_file( CfgFile, line, NewLine);
	}
	else
	{
		write_file( CfgFile, "rom_admin_login ^"1^"", NewLine);
	}
	write_file( CfgFile, " ", NewLine);	
	
	write_file( CfgFile, "// Cvar  : rom_admin_login_file ( Activat numai in cazul in care cvarul ^"rom_admin_login^" este setat pe 1 )", NewLine);
	write_file( CfgFile, "// Efect : Selecteaza fisierul de unde sa fie citite adminele cu flag ^"f^"", NewLine);
	if (exist)
	{
		formatex(line, charsmax(line), "rom_admin_login_file ^"%s^"", getString(PlugCvar[admin_login_file ]));
		write_file( CfgFile, line, NewLine);
	}
	else
	{
		write_file( CfgFile, "rom_admin_login_file ^"users_login.ini^"", NewLine);
	}
	write_file( CfgFile, " ", NewLine);	
	
	write_file( CfgFile, "// Cvar  : rom_admin_login_debug ( Activat numai in cazul in care cvarul ^"rom_admin_login^" este setat pe 1 )", NewLine);
	write_file( CfgFile, "// Efect : In cazul in care adminele nu se incarca corect acesta va printa in consola serverului argumentele citite (nume - parola - acces - flag)", NewLine);
	write_file( CfgFile, "// Valoarea 0: Functie este dezactivata. [Default]", NewLine);
	write_file( CfgFile, "// Valoarea 1: Argumentele sunt printate in consola. ", NewLine);
	if (exist)
	{
		formatex(line, charsmax(line), "rom_admin_login_debug ^"%d^"", getNum( PlugCvar [ admin_login_debug ] ));
		write_file( CfgFile, line, NewLine);
	}
	else
	{
		write_file( CfgFile, "rom_admin_login_debug ^"0^"", NewLine);
	}
	write_file( CfgFile, " ", NewLine);	
	
	write_file( CfgFile, "// Cvar      : rom_utf8-bom", NewLine);
	write_file( CfgFile, "// Scop      : Verifica fiecare fisier .res in maps, si daca descopera caractere UTF8-BOM le elimina.", NewLine);
	write_file( CfgFile, "// Impact    : Serverul da crash cu eroarea : Host_Error: PF_precache_generic_I: Bad string.", NewLine);
	write_file( CfgFile, "// Nota      : Eroarea apare doar la versiunile de HLDS 6***.", NewLine);
	write_file( CfgFile, "// Valoarea 0: Functie este dezactivata.", NewLine);
	write_file( CfgFile, "// Valoarea 1: Fisierul este decontaminat. [Default]", NewLine);
	if (exist)
	{
		formatex(line, charsmax(line), "rom_utf8-bom ^"%d^"", getNum(PlugCvar[utf8_bom]));
		write_file(CfgFile, line, NewLine);
	}
	else
	{
		if (getHldsVersion() >= 6027)
		{
			write_file( CfgFile, "rom_utf8-bom ^"1^"", NewLine);
		}
		else
		{
			write_file( CfgFile, "rom_utf8-bom ^"0^"", NewLine);
		}
	}
	write_file( CfgFile, " ", NewLine);
	
	
	write_file( CfgFile, "// Cvar      : rom_tag ", NewLine);
	write_file( CfgFile, "// Utilizare : Seteaza tag-ul pluginului. (Numele acestuia)", NewLine);
	write_file( CfgFile, "// Nota      : Incepand de la versiunea 1.0.2s, pluginul *ROM-Protect devine mult mai primitor si te lasa chiar sa ii schimbi numele.", NewLine);
	if (exist)
	{
		formatex(line, charsmax(line), "rom_tag ^"%s^"", getString( PlugCvar [ Tag ] ));
		write_file( CfgFile, line, NewLine);
	}
	else
	{
		write_file( CfgFile, "rom_tag ^"*ROM-Protect^"", NewLine);	
	}
	write_file( CfgFile, " ", NewLine);
	
	write_file( CfgFile, "// Cvar      : rom_color-bug ", NewLine);
	write_file( CfgFile, "// Scop      : Urmareste chatul si opeste bugurile de tip color-bug care alerteaza playerii si adminii.", NewLine);
	write_file( CfgFile, "// Impact    : Serverul nu pateste nimic, insa playerii sau adminii vor fi alertati de culorile folosite de unul din clienti.", NewLine);
	write_file( CfgFile, "// Nota      : - ", NewLine);
	write_file( CfgFile, "// Valoarea 0: Functia este dezactivata.", NewLine);
	write_file( CfgFile, "// Valoarea 1: Bug-ul este blocat. [Default]", NewLine);
	if (exist)
	{
		formatex(line, charsmax(line), "rom_color-bug ^"%d^"", getNum( PlugCvar [ color_bug ] ));
		write_file( CfgFile, line, NewLine);
	}
	else
	{
		write_file( CfgFile, "rom_color-bug ^"1^"", NewLine);
	}
	write_file( CfgFile, " ", NewLine);
	
	write_file( CfgFile, "// Cvar      : rom_motdfile ", NewLine);
	write_file( CfgFile, "// Scop      : Urmareste activitatea adminilor prin comanda amx_cvar si incearca sa opreasca modificare cvarului motdfile intr-un fisier .ini.", NewLine);
	write_file( CfgFile, "// Impact    : Serverul nu pateste nimic, insa adminul care foloseste acest exploit poate fura date importante din server, precum lista de admini, lista de pluginuri etc .", NewLine);
	write_file( CfgFile, "// Nota      : Functia nu blocheaza deocamdata decat comanda amx_cvar.", NewLine);
	write_file( CfgFile, "// Valoarea 0: Functia este dezactivata.", NewLine);
	write_file( CfgFile, "// Valoarea 1: Bug-ul este blocat. [Default]", NewLine);
	if (exist)
	{
		formatex(line, charsmax(line), "rom_motdfile ^"%d^"", getNum( PlugCvar [ motdfile ] ));
		write_file( CfgFile, line, NewLine);
	}
	else
	{
		write_file( CfgFile, "rom_motdfile ^"1^"", NewLine);	
	}
	write_file( CfgFile, " ", NewLine);
	
	write_file( CfgFile, "// Cvar      : rom_anti-pause ", NewLine);
	write_file( CfgFile, "// Scop      : Urmareste ca pluginul de protectie ^"ROM-Protect^" sa nu poata fi pus pe pauza de catre un raufacator.", NewLine);
	write_file( CfgFile, "// Impact    : Serverul nu mai este protejat de plugin, acesta fiind expus la mai multe exploituri.", NewLine);
	write_file( CfgFile, "// Nota      : -", NewLine);
	write_file( CfgFile, "// Valoarea 0: Functia este dezactivata.", NewLine);
	write_file( CfgFile, "// Valoarea 1: Bug-ul este blocat. [Default]", NewLine);
	if (exist)
	{
		formatex(line, charsmax(line), "rom_anti-pause ^"%d^"", getNum(PlugCvar[anti_pause]) );
		write_file( CfgFile, line, NewLine);
	}
	else
	{
		write_file( CfgFile, "rom_anti-pause ^"1^"", NewLine);
	}
	write_file( CfgFile, " ", NewLine);
	
	write_file( CfgFile, "// Cvar      : rom_anti-ban-class ", NewLine);
	write_file( CfgFile, "// Scop      : Urmareste activitatea comezii amx_addban, astfel incat sa nu se poata da ban pe mai multe clase ip.", NewLine);
	write_file( CfgFile, "// Impact    : Serverul nu pateste nimic, insa daca se dau ban-uri pe clasa, foarte multi jucatori nu se vor mai putea conecta la server.", NewLine);
	write_file( CfgFile, "// Nota      : Functia nu urmareste decat comanda amx_addban.", NewLine);
	write_file( CfgFile, "// Valoarea 0: Functia este dezactivata.", NewLine);
	write_file( CfgFile, "// Valoarea 1: Functia va bloca comanda daca detecteaza ban-ul pe o clasa de ip.", NewLine);
	write_file( CfgFile, "// Valoarea 2: Functia va bloca comanda daca detecteaza ban-ul pe doua clase de ip. [Default]", NewLine);
	write_file( CfgFile, "// Valoarea 3: Functia va bloca comanda daca detecteaza ban-ul pe trei clase de ip.", NewLine);
	write_file( CfgFile, "// Valoarea 4: Functia va bloca comanda daca detecteaza ban-ul pe toate clasele de ip.", NewLine);
	if (exist)
	{
		formatex(line, charsmax(line), "rom_anti-ban-class ^"%d^"", getNum(PlugCvar[anti_ban_class]));
		write_file( CfgFile, line, NewLine);
	}
	else
	{
		write_file( CfgFile, "rom_anti-ban-class ^"2^"", NewLine);
	}
	write_file( CfgFile, " ", NewLine);
	
	write_file( CfgFile, "// Cvar      : rom_auto_update ", NewLine);
	write_file( CfgFile, "// Scop      : Descarca si inlocuieste pluginul automat, pentru a face singur setarile de siguranta.", NewLine);
	write_file( CfgFile, "// Impact    : Actualizeaza automat pluginul la schimbarea hartii.", NewLine);
	write_file( CfgFile, "// Nota      : -", NewLine);
	write_file( CfgFile, "// Valoarea 0: Functia este dezactivata.", NewLine);
	write_file( CfgFile, "// Valoarea 1: Pluginul se va auto-actualiza. [Default]", NewLine);
	if (exist)
	{
		formatex(line, charsmax(line), "rom_auto_update ^"%d^"", getNum(PlugCvar[auto_update]));
		write_file( CfgFile, line, NewLine);
	}
	else
	{
		write_file( CfgFile, "rom_auto_update ^"1^"", NewLine);
	}
	write_file( CfgFile, " ", NewLine);
	
	write_file( CfgFile, "// Cvar      : rom_info ", NewLine);
	write_file( CfgFile, "// Scop      : Serverul va trimite utilizatorului informatii despre plugin.", NewLine);
	write_file( CfgFile, "// Impact    : Cand cineva va scrie ROM_INFO in consola, ii vor fi livrate informatiile (tot in consola).", NewLine);
	write_file( CfgFile, "// Nota      : Daca mesajul este transmis prin intermediul consolei serverului, acesta va primi cateva informatii suplimentare.", NewLine);
	write_file( CfgFile, "// Valoarea 0: Functia este dezactivata.", NewLine);
	write_file( CfgFile, "// Valoarea 1: Functia este activata. [Default]", NewLine);
	if (exist)
	{
		formatex(line, charsmax(line), "rom_info ^"%d^"", getNum(PlugCvar[info]));
		write_file( CfgFile, line, NewLine);
	}
	else
	{
		write_file( CfgFile, "rom_info ^"1^"", NewLine);
	}
	write_file( CfgFile, " ", NewLine);
}

WriteLang( bool:exist )
	{
	new line[121];
	if (exist)
	{
		delete_file(LangFile);
		const MLNTsize = 11;
		
		
		writeSignature(LangFile);
		write_file( LangFile, "[en]", NewLine);
		write_file( LangFile, " ", NewLine);
		
		formatex(line, charsmax(line), "ROM_UPDATE_CFG = %L", LANG_SERVER, "ROM_UPDATE_CFG", "^%s" );
		if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
		{
			write_file( LangFile, line, NewLine);
		}
		else
		{
			write_file( LangFile, "ROM_UPDATE_CFG = %s : Am actualizat fisierul CFG : rom_protect.cfg.", NewLine);
		}
		
		formatex(line, charsmax(line), "ROM_UPDATE_LANG = %L", LANG_SERVER, "ROM_UPDATE_LANG", "^%s" );
		if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
		{
			write_file( LangFile, line, NewLine);
		}
		else
		{
			write_file( LangFile, "ROM_UPDATE_LANG = %s : Am actualizat fisierul LANG : rom_protect.txt.", NewLine);
		}
		
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_FAKE_PLAYERS = %L", LANG_SERVER, "ROM_FAKE_PLAYERS", "^%c", "^%s", "^%c", "^%s");
			if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
			{
				write_file( LangFile, line, NewLine);
			}
			else
			{
				write_file( LangFile, "ROM_FAKE_PLAYERS = %c%s : %cS-a observat un numar prea mare de persoane de pe ip-ul : %s .", NewLine);
			}
			
			formatex(line, charsmax(line), "ROM_FAKE_PLAYERS_PUNISH = %L", LANG_SERVER, "ROM_FAKE_PLAYERS_PUNISH", "^%c", "^%s", "^%c");
			if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
			{
				write_file( LangFile, line, NewLine);
			}
			else
			{
				write_file( LangFile, "ROM_FAKE_PLAYERS_PUNISH = %c%s : %cIp-ul a primit ban 30 minute pentru a nu afecta jocul.", NewLine);
			}
				
		#else
			formatex(line, charsmax(line), "ROM_FAKE_PLAYERS = %L", LANG_SERVER, "ROM_FAKE_PLAYERS", "^%s", "^%s" );
			if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
			{
				write_file( LangFile, line, NewLine);
			}
			else
			{
				write_file( LangFile, "ROM_FAKE_PLAYERS = ^^3%s : ^^4S-a observat un numar prea mare de persoane de pe ip-ul : %s .", NewLine);
			}
				
			formatex(line, charsmax(line), "ROM_FAKE_PLAYERS_PUNISH = %L", LANG_SERVER, "ROM_FAKE_PLAYERS_PUNISH", "^%s");
			if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
			{
				write_file( LangFile, line, NewLine);
			}
			else
			{
				write_file( LangFile, "ROM_FAKE_PLAYERS_PUNISH = ^^3%s : ^^4 Ip-ul a primit ban 30 minute pentru a nu afecta jocul.", NewLine);
			}
				
		#endif
		formatex(line, charsmax(line), "ROM_FAKE_PLAYERS_LOG = %L", LANG_SERVER, "ROM_FAKE_PLAYERS_LOG", "^%s", "^%s"  );
		if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
		{
			write_file( LangFile, line, NewLine);
		}
		else
		{
			write_file( LangFile, "ROM_FAKE_PLAYERS_LOG = %s : S-a depistat un atac de ^"xFake-Players^" de la IP-ul : %s .", NewLine);
		}
			
		formatex(line, charsmax(line), "ROM_FAKE_PLAYERS_DETECT = %L", LANG_SERVER, "ROM_FAKE_PLAYERS_DETECT", "^%s"  );
		if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
		{
			write_file( LangFile, line, NewLine);
		}
		else
		{
			write_file( LangFile, "ROM_FAKE_PLAYERS_DETECT = %s : Ai primit kick deoarece deoarece esti suspect de fake-client. Te rugam sa folosesti alt client.", NewLine);
		}
			
		formatex(line, charsmax(line), "ROM_FAKE_PLAYERS_DETECT_LOG = %L", LANG_SERVER, "ROM_FAKE_PLAYERS_DETECT_LOG", "^%s", "^%s", "^%s", "^%s" );
		if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
		{
			write_file( LangFile, line, NewLine);
		}
		else
		{
			write_file( LangFile, "ROM_FAKE_PLAYERS_DETECT_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca suspect de ^"xFake-Players^" sau ^"xSpammer^".", NewLine);
		}
			
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_PLUGIN_PAUSE = %L", LANG_SERVER, "ROM_PLUGIN_PAUSE", "^%c", "^%s", "^%c" );
			if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
			{
				write_file( LangFile, line, NewLine);
			}
			else
			{
				write_file( LangFile, "ROM_PLUGIN_PAUSE = %c%s : %cNe pare rau, dar din anumite motive, acest plugin nu poate fi pus pe pauza.", NewLine);
			}
		#else
			formatex(line, charsmax(line), "ROM_PLUGIN_PAUSE = %L", LANG_SERVER, "ROM_PLUGIN_PAUSE", "^%s" );
			if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
			{
				write_file( LangFile, line, NewLine);
			}
			else
			{
				write_file( LangFile, "ROM_PLUGIN_PAUSE = ^^3%s : ^^4Ne pare rau, dar din anumite motive, acest plugin nu poate fi pus pe pauza.", NewLine);
			}
		#endif
		
		formatex(line, charsmax(line), "ROM_PLUGIN_PAUSE_LOG = %L", LANG_SERVER, "ROM_PLUGIN_PAUSE_LOG", "^%s", "^%s" );
		if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
		{
			write_file( LangFile, line, NewLine);
		}
		else
		{
			write_file( LangFile, "ROM_PLUGIN_PAUSE_LOG = %s : S-a depistat o incercare a opririi pluginului de protectie %s. Operatiune a fost blocata.", NewLine);
		}
			
		#if AMXX_VERSION_NUM < 183 
			formatex(line, charsmax(line), "ROM_ADMIN_WRONG_NAME = %L", LANG_SERVER, "ROM_ADMIN_WRONG_NAME", "^%c", "^%s", "^%c" );
			if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
			{
				write_file( LangFile, line, NewLine);
			}
			else
			{
				write_file( LangFile, "ROM_ADMIN_WRONG_NAME = %c%s : %cNu s-a gasit nici un admin care sa poarte acest nickname.", NewLine);
			}
		#else
			formatex(line, charsmax(line), "ROM_ADMIN_WRONG_NAME = %L", LANG_SERVER, "ROM_ADMIN_WRONG_NAME", "^%s" );
			if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
			{
				write_file( LangFile, line, NewLine);
			}
			else
			{
				write_file( LangFile, "ROM_ADMIN_WRONG_NAME = ^^3%s : ^^4Nu s-a gasit nici un admin care sa poarte acest nickname.", NewLine);
			}
		#endif
		
		formatex(line, charsmax(line), "ROM_ADMIN_WRONG_NAME_PRINT = %L", LANG_SERVER, "ROM_ADMIN_WRONG_NAME_PRINT", "^%s" );
		if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
		{
			write_file( LangFile, line, NewLine);
		}
		else
		{
			write_file( LangFile, "ROM_ADMIN_WRONG_NAME_PRINT = %s : Nu s-a gasit nici un admin care sa poarte acest nickname.", NewLine);
		}
			
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_ADMIN_WRONG_PASS = %L", LANG_SERVER, "ROM_ADMIN_WRONG_PASS", "^%c", "^%s", "^%c" );
			if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
			{
				write_file( LangFile, line, NewLine);
			}
			else
			{
				write_file( LangFile, "ROM_ADMIN_WRONG_PASS = %c%s : %cParola introdusa de tine este incorecta.", NewLine);
			}
		#else
			formatex(line, charsmax(line), "ROM_ADMIN_WRONG_PASS = %L", LANG_SERVER, "ROM_ADMIN_WRONG_PASS", "^%s" );
			if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
			{
				write_file( LangFile, line, NewLine);
			}
			else
			{
				write_file( LangFile, "ROM_ADMIN_WRONG_PASS = ^^3%s : ^^4Parola introdusa de tine este incorecta.", NewLine);
			}
		#endif
		
		formatex(line, charsmax(line), "ROM_ADMIN_WRONG_PASS_PRINT = %L", LANG_SERVER, "ROM_ADMIN_WRONG_PASS_PRINT", "^%s" );
		if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
		{
			write_file( LangFile, line, NewLine);
		}
		else
		{
			write_file( LangFile, "ROM_ADMIN_WRONG_PASS_PRINT = %s : Parola introdusa de tine este incorecta.", NewLine);
		}
			
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_ADMIN_LOADED = %L", LANG_SERVER, "ROM_ADMIN_LOADED", "^%c", "^%s", "^%c" );
			if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
			{
				write_file( LangFile, line, NewLine);
			}
			else
			{
				write_file( LangFile, "ROM_ADMIN_LOADED = %c%s : %cAdmin-ul tau a fost incarcat.", NewLine);
			}
		#else
			formatex(line, charsmax(line), "ROM_ADMIN_LOADED = %L", LANG_SERVER, "ROM_ADMIN_LOADED", "^%s" );
			if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
			{
				write_file( LangFile, line, NewLine);
			}
			else
			{
				write_file( LangFile, "ROM_ADMIN_LOADED = ^^3%s : ^^4Admin-ul tau a fost incarcat.", NewLine);
			}
		#endif
		
		formatex(line, charsmax(line), "ROM_ADMIN_LOADED_PRINT = %L", LANG_SERVER, "ROM_ADMIN_LOADED_PRINT", "^%s" );
		if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
		{
			write_file( LangFile, line, NewLine);
		}
		else
		{
			write_file( LangFile, "ROM_ADMIN_LOADED_PRINT = %s : Admin-ul tau a fost incarcat.", NewLine);
		}
			
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_ADMIN_ALREADY_LOADED = %L", LANG_SERVER, "ROM_ADMIN_ALREADY_LOADED", "^%c", "^%s", "^%c" );
			if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
			{
				write_file( LangFile, line, NewLine);
			}
			else
			{
				write_file( LangFile, "ROM_ADMIN_ALREADY_LOADED = %c%s : %cAdmin-ul tau este deja incarcat.", NewLine);
			}
		#else
			formatex(line, charsmax(line), "ROM_ADMIN_ALREADY_LOADED = %L", LANG_SERVER, "ROM_ADMIN_ALREADY_LOADED", "^%s" );
			if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
			{
				write_file( LangFile, line, NewLine);
			}
			else
			{
				write_file( LangFile, "ROM_ADMIN_ALREADY_LOADED = ^^3%s : ^^4Admin-ul tau este deja incarcat.", NewLine);
			}
		#endif
		
		formatex(line, charsmax(line), "ROM_ADMIN_ALREADY_LOADED_PRINT = %L", LANG_SERVER, "ROM_ADMIN_ALREADY_LOADED_PRINT", "^%s" );
		if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
		{
			write_file( LangFile, line, NewLine);
		}
		else
		{
			write_file( LangFile, "ROM_ADMIN_ALREADY_LOADED_PRINT = %s : Admin-ul tau este deja incarcat.", NewLine);
		}
			
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_CMD_BUG = %L", LANG_SERVER, "ROM_CMD_BUG", "^%c", "^%s", "^%c" );
			if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
			{
				write_file( LangFile, line, NewLine);
			}
			else
			{
				write_file( LangFile, "ROM_CMD_BUG = %c%s : %cS-au observat caractere interzise in textul trimis de tine. Mesajul tau a fost eliminat.", NewLine);
			}
		#else
			formatex(line, charsmax(line), "ROM_CMD_BUG = %L", LANG_SERVER, "ROM_CMD_BUG", "^%s" );
			if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
			{
				write_file( LangFile, line, NewLine);
			}
			else
			{
				write_file( LangFile, "ROM_CMD_BUG = ^^3%s : ^^4S-au observat caractere interzise in textul trimis de tine. Mesajul tau a fost eliminat.", NewLine);
			}
		#endif	 
		
		formatex(line, charsmax(line), "ROM_CMD_BUG_LOG = %L", LANG_SERVER, "ROM_CMD_BUG_LOG", "^%s", "^%s", "^%s", "^%s" );
		if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
		{
			write_file( LangFile, line, NewLine);
		}
		else
		{
			write_file( LangFile, "ROM_CMD_BUG_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"CMD_BUG^" ca sa strice buna functionare a serverului.", NewLine);
		}
			
		formatex(line, charsmax(line), "ROM_CMD_BUG_PRINT = %L", LANG_SERVER, "ROM_CMD_BUG_PRINT", "^%s");
		if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
		{
			write_file( LangFile, line, NewLine);
		}
		else
		{
			write_file( LangFile, "ROM_CMD_BUG_PRINT = %s : S-au observat caractere interzise in textul trimis de tine. Mesajul tau a fost eliminat.", NewLine);
		}
	
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_COLOR_BUG = %L", LANG_SERVER, "ROM_COLOR_BUG", "^%c", "^%s", "^%c" );
			if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
			{
				write_file( LangFile, line, NewLine);
			}
			else
			{
				write_file( LangFile, "ROM_COLOR_BUG = %c%s : %cS-au observat caractere suspecte in textul trimis de tine. Mesajul tau a fost eliminat.", NewLine);
			}
		#else
			formatex(line, charsmax(line), "ROM_COLOR_BUG = %L", LANG_SERVER, "ROM_COLOR_BUG", "^%s" );
			if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
			{
				write_file( LangFile, line, NewLine);
			}
			else
			{
				write_file( LangFile, "ROM_COLOR_BUG = ^^3%s : ^^4S-au observat caractere suspecte in textul trimis de tine. Mesajul tau a fost eliminat.", NewLine);
			}
		#endif
		
		formatex(line, charsmax(line), "ROM_COLOR_BUG_LOG = %L", LANG_SERVER, "ROM_COLOR_BUG_LOG", "^%s", "^%s", "^%s", "^%s" );
		if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
		{
			write_file( LangFile, line, NewLine);
		}
		else
		{
			write_file( LangFile, "ROM_COLOR_BUG_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"COLOR_BUG^" ca sa alerteze playerii sau adminii.", NewLine);
		}
			
		formatex(line, charsmax(line), "ROM_COLOR_BUG_PRINT = %L", LANG_SERVER, "ROM_COLOR_BUG_PRINT", "^%s");
		if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
		{
			write_file( LangFile, line, NewLine);
		}
		else
		{
			write_file( LangFile, "ROM_COLOR_BUG_PRINT = %s : S-au observat caractere suspecte in textul trimis de tine. Mesajul tau a fost eliminat.", NewLine);
		}
			
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_SPEC_BUG = %L", LANG_SERVER, "ROM_SPEC_BUG", "^%c", "^%s", "^%c" );
			if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
			{
				write_file( LangFile, line, NewLine);
			}
			else
			{
				write_file( LangFile, "ROM_SPEC_BUG = %c%s : %cAi facut o miscare suspecta asa ca te-am mutat la echipa precedenta.", NewLine);
			}
		#else
			formatex(line, charsmax(line), "ROM_SPEC_BUG = %L", LANG_SERVER, "ROM_SPEC_BUG", "^%s" );
			if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
			{
				write_file( LangFile, line, NewLine);
			}
			else
			{
				write_file( LangFile, "ROM_SPEC_BUG = ^^3%s : ^^4Ai facut o miscare suspecta asa ca te-am mutat la echipa precedenta.", NewLine);
			}
		#endif
		
		formatex(line, charsmax(line), "ROM_SPEC_BUG_LOG = %L", LANG_SERVER, "ROM_SPEC_BUG_LOG", "^%s", "^%s", "^%s", "^%s" );
		if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
		{
			write_file( LangFile, line, NewLine);
		}
		else
		{
			write_file( LangFile, "ROM_SPEC_BUG_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"SPEC_BUG^" ca sa strice buna functionare a serverului.", NewLine);
		}
			
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_ADMIN_CHAT_FLOOD = %L", LANG_SERVER, "ROM_ADMIN_CHAT_FLOOD", "^%c", "^%s", "^%c" );
			if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
			{
				write_file( LangFile, line, NewLine);
			}
			else
			{
				write_file( LangFile, "ROM_ADMIN_CHAT_FLOOD = %c%s : %cS-a observat un mic flood la chat primit din partea ta. Mesajele trimise de tine vor fi filtrate.", NewLine);
			}

			formatex(line, charsmax(line), "ROM_ADMIN_CHAT_FLOOD_LOG = %L", LANG_SERVER, "ROM_ADMIN_CHAT_FLOOD_LOG", "^%s", "^%s", "^%s", "^%s" );
			if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
			{
				write_file( LangFile, line, NewLine);
			}
			else
			{
				write_file( LangFile, "ROM_ADMIN_CHAT_FLOOD_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"ADMIN_CHAT_FLOOD^" ca sa dea kick adminilor de pe server.", NewLine);	
			}
		#endif
		
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_AUTOBUY = %L", LANG_SERVER, "ROM_AUTOBUY", "^%c", "^%s", "^%c" );
			if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
			{
				write_file( LangFile, line, NewLine);
			}
			else
			{
				write_file( LangFile, "ROM_AUTOBUY = %c%s : %cComanda trimisa de tine are valori suspecte, asa ca am blocat-o.", NewLine);
			}
		#else
			formatex(line, charsmax(line), "ROM_AUTOBUY = %L", LANG_SERVER, "ROM_AUTOBUY", "^%s" );
			if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
			{
				write_file( LangFile, line, NewLine);
			}
			else
			{
				write_file( LangFile, "ROM_AUTOBUY = ^^3%s : ^^4Comanda trimisa de tine are valori suspecte, asa ca am blocat-o.", NewLine);
			}
		#endif
		
		formatex(line, charsmax(line), "ROM_AUTOBUY_LOG = %L", LANG_SERVER, "ROM_AUTOBUY_LOG", "^%s", "^%s", "^%s", "^%s" );
		if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
		{
			write_file( LangFile, line, NewLine);
		}
		else
		{
			write_file( LangFile, "ROM_AUTOBUY_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"AUTOBUY_BUG^" ca sa strice buna functionare a serverului.", NewLine);
		}
		
		formatex(line, charsmax(line), "ROM_FILE_NOT_FOUND = %L", LANG_SERVER, "ROM_FILE_NOT_FOUND", "^%s", "^%s" );
		if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
		{
			write_file( LangFile, line, NewLine);
		}
		else
		{
			write_file( LangFile, "ROM_FILE_NOT_FOUND = %s : Fisierul %s nu exista.", NewLine);
		}
			
		formatex(line, charsmax(line), "ROM_ADMIN_DEBUG = %L", LANG_SERVER, "ROM_ADMIN_DEBUG", "^%s", "^%s", "^%s", "^%s" );
		if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
		{
			write_file( LangFile, line, NewLine);
		}
		else
		{
			write_file( LangFile, "ROM_ADMIN_DEBUG = Nume : %s - Parola : %s - Acces : %s - Flag : %s", NewLine);
		}
			
		formatex(line, charsmax(line), "ROM_MOTDFILE = %L", LANG_SERVER, "ROM_MOTDFILE", "^%s" );
		if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
		{
			write_file( LangFile, line, NewLine);
		}
		else
		{
			write_file( LangFile, "ROM_MOTDFILE = %s : S-a detectat o miscare suspecta din partea ta, comanda ta a fost blocata.", NewLine);
		}
			
		formatex(line, charsmax(line), "ROM_MOTDFILE_LOG = %L", LANG_SERVER, "ROM_MOTDFILE_LOG", "^%s", "^%s", "^%s", "^%s" );
		if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
		{
			write_file( LangFile, line, NewLine);
		}
		else
		{
			write_file( LangFile, "ROM_MOTDFILE_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca cvar-ul ^"motdfile^" ca sa fure informatii din acest server.", NewLine);	
		}
			
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_ADVERTISE = %L", LANG_SERVER, "ROM_ADVERTISE", "^%c", "^%s", "^%c", "^%c", "^%s", "^%c", "^%c", "^%s", "^%c" );
			if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
			{
				write_file( LangFile, line, NewLine);
			}
			else
			{
				write_file( LangFile, "ROM_ADVERTISE = %c%s :%c Acest server este supravegheat de pluginul de protectie %c%s%c versiunea %c%s%c .", NewLine);
			}
		#else
			formatex(line, charsmax(line), "ROM_ADVERTISE = %L", LANG_SERVER, "ROM_ADVERTISE", "^%s", "^%s", "^%s" );
			if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
			{
				write_file( LangFile, line, NewLine);
			}
			else
			{
				write_file( LangFile, "ROM_ADVERTISE = ^^3%s :^^4 Acest server este supravegheat de pluginul de protectie ^^3%s^^4 versiunea ^^3%s^^4 .", NewLine);
			}
		#endif
		
		formatex(line, charsmax(line), "ROM_ANTI_BAN_CLASS = %L", LANG_SERVER, "ROM_ANTI_BAN_CLASS", "^%s" );
		if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
		{
			write_file( LangFile, line, NewLine);
		}
		else
		{
			write_file( LangFile, "ROM_ANTI_BAN_CLASS = %s : S-au detectat un numar prea mare de ban-uri pe clasa de ip, comanda ta a fost blocata.", NewLine);
		}
		
		formatex(line, charsmax(line), "ROM_ANTI_ANY_BAN_CLASS_LOG = %L", LANG_SERVER, "ROM_ANTI_ANY_BAN_CLASS_LOG", "^%s", "^%s", "^%s", "^%s" );
		if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
		{
			write_file( LangFile, line, NewLine);
		}
		else
		{
			write_file( LangFile, "ROM_ANTI_ANY_BAN_CLASS_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa dea ban pe clasa de ip.", NewLine);	
		}
		
		formatex(line, charsmax(line), "ROM_ANTI_SOME_BAN_CLASS_LOG = %L", LANG_SERVER, "ROM_ANTI_SOME_BAN_CLASS_LOG", "^%s", "^%s", "^%s", "^%s", "^%s" );
		if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
		{
			write_file( LangFile, line, NewLine);
		}
		else
		{
			write_file( LangFile, "ROM_ANTI_SOME_BAN_CLASS_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa dea ban pe mai mult de %s clase de ip.", NewLine);	
		}
		
		formatex(line, charsmax(line), "ROM_AUTO_UPDATE_SUCCEED = %L", LANG_SERVER, "ROM_AUTO_UPDATE_SUCCEED", "^%s");
		if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
		{
			write_file( LangFile, line, NewLine);
		}
		else
		{
			write_file( LangFile, "ROM_AUTO_UPDATE_SUCCEED = %s : S-a efectuat auto-actualizarea pluginului.", NewLine);	
		}
		
		formatex(line, charsmax(line), "ROM_AUTO_UPDATE_FAILED = %L", LANG_SERVER, "ROM_AUTO_UPDATE_FAILED", "^%s"); 
		if ( equal(line, "ML_NOTFOUND" , MLNTsize) )
		{
			write_file( LangFile, line, NewLine);
		}
		else
		{
			write_file( LangFile, "ROM_AUTO_UPDATE_FAILED = %s : S-a intampinat o eroare la descarcare, iar pluginul nu s-a putut auto-actualiza..", NewLine);	
		}
	}
	else
	{
		writeSignature(LangFile);
		write_file( LangFile, "[en]", NewLine);
		write_file( LangFile, " ", NewLine);
		write_file( LangFile, "ROM_UPDATE_CFG = %s : Am actualizat fisierul CFG : rom_protect.cfg.", NewLine);
		write_file( LangFile, "ROM_UPDATE_LANG = %s : Am actualizat fisierul LANG : rom_protect.txt.", NewLine);
		
		#if AMXX_VERSION_NUM < 183
			write_file( LangFile, "ROM_FAKE_PLAYERS = %c%s : %cS-a observat un numar prea mare de persoane de pe ip-ul : %s .", NewLine);
			write_file( LangFile, "ROM_FAKE_PLAYERS_PUNISH = %c%s : %cIp-ul a primit ban 30 minute pentru a nu afecta jocul.", NewLine);
		#else
			write_file( LangFile, "ROM_FAKE_PLAYERS = ^^3%s : ^^4S-a observat un numar prea mare de persoane de pe ip-ul : %s .", NewLine);
			write_file( LangFile, "ROM_FAKE_PLAYERS_PUNISH = ^^3%s : ^^4 Ip-ul a primit ban 30 minute pentru a nu afecta jocul.", NewLine);
		#endif
		
		write_file( LangFile, "ROM_FAKE_PLAYERS_LOG = %s : S-a depistat un atac de ^"xFake-Players^" de la IP-ul : %s .", NewLine);
		write_file( LangFile, "ROM_FAKE_PLAYERS_DETECT = %s : Ai primit kick deoarece deoarece esti suspect de fake-client. Te rugam sa folosesti alt client.", NewLine);
		write_file( LangFile, "ROM_FAKE_PLAYERS_DETECT_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca suspect de ^"xFake-Players^" sau ^"xSpammer^".", NewLine);
		
		#if AMXX_VERSION_NUM < 183
			write_file( LangFile, "ROM_PLUGIN_PAUSE = %c%s : %cNe pare rau, dar din anumite motive, acest plugin nu poate fi pus pe pauza.", NewLine);
		#else
			write_file( LangFile, "ROM_PLUGIN_PAUSE = ^^3%s : ^^4Ne pare rau, dar din anumite motive, acest plugin nu poate fi pus pe pauza.", NewLine);
		#endif
		
		write_file( LangFile, "ROM_PLUGIN_PAUSE_LOG = %s : S-a depistat o incercare a opririi pluginului de protectie %s. Operatiune a fost blocata.", NewLine);
		
		#if AMXX_VERSION_NUM < 183
			write_file( LangFile, "ROM_ADMIN_WRONG_NAME = %c%s : %cNu s-a gasit nici un admin care sa poarte acest nickname.", NewLine);
		#else
			write_file( LangFile, "ROM_ADMIN_WRONG_NAME = ^^3%s : ^^4Nu s-a gasit nici un admin care sa poarte acest nickname.", NewLine);
		#endif
		
		write_file( LangFile, "ROM_ADMIN_WRONG_NAME_PRINT = %s : Nu s-a gasit nici un admin care sa poarte acest nickname.", NewLine);
		
		#if AMXX_VERSION_NUM < 183
			write_file( LangFile, "ROM_ADMIN_WRONG_PASS = %c%s : %cParola introdusa de tine este incorecta.", NewLine);
		#else
			write_file( LangFile, "ROM_ADMIN_WRONG_PASS = ^^3%s : ^^4Parola introdusa de tine este incorecta.", NewLine);
		#endif
		
		write_file( LangFile, "ROM_ADMIN_WRONG_PASS_PRINT = %s : Parola introdusa de tine este incorecta.", NewLine);
		
		#if AMXX_VERSION_NUM < 183
			write_file( LangFile, "ROM_ADMIN_LOADED = %c%s : %cAdmin-ul tau a fost incarcat.", NewLine);
		#else
			write_file( LangFile, "ROM_ADMIN_LOADED = ^^3%s : ^^4Admin-ul tau a fost incarcat.", NewLine);
		#endif
		
		write_file( LangFile, "ROM_ADMIN_LOADED_PRINT = %s : Admin-ul tau a fost incarcat.", NewLine);
		
		#if AMXX_VERSION_NUM < 183
			write_file( LangFile, "ROM_ADMIN_ALREADY_LOADED = %c%s : %cAdmin-ul tau este deja incarcat.", NewLine);
		#else
			write_file( LangFile, "ROM_ADMIN_ALREADY_LOADED = ^^3%s : ^^4Admin-ul tau este deja incarcat.", NewLine);
		#endif
		
		write_file( LangFile, "ROM_ADMIN_ALREADY_LOADED_PRINT = %s : Admin-ul tau este deja incarcat.", NewLine);
		
		#if AMXX_VERSION_NUM < 183
			write_file( LangFile, "ROM_CMD_BUG = %c%s : %cS-au observat caractere interzise in textul trimis de tine. Mesajul tau a fost eliminat.", NewLine);
		#else
			write_file( LangFile, "ROM_CMD_BUG = ^^3%s : ^^4S-au observat caractere interzise in textul trimis de tine. Mesajul tau a fost eliminat.", NewLine);
		#endif
		
		write_file(LangFile, "ROM_CMD_BUG_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"CMD_BUG^" ca sa strice buna functionare a serverului.", NewLine);
		write_file(LangFile, "ROM_CMD_BUG_PRINT = %s : S-au observat caractere interzise in textul trimis de tine. Mesajul tau a fost eliminat.", NewLine);
		
		#if AMXX_VERSION_NUM < 183
			write_file( LangFile, "ROM_COLOR_BUG = %c%s : %cS-au observat caractere suspecte in textul trimis de tine. Mesajul tau a fost eliminat.", NewLine);
		#else
			write_file( LangFile, "ROM_COLOR_BUG = ^^3%s : ^^4S-au observat caractere suspecte in textul trimis de tine. Mesajul tau a fost eliminat.", NewLine);
		#endif
		
		write_file( LangFile, "ROM_COLOR_BUG_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"COLOR_BUG^" ca sa alerteze playerii sau adminii.", NewLine);
		write_file(LangFile, "ROM_COLOR_BUG_PRINT = %s : S-au observat caractere suspecte in textul trimis de tine. Mesajul tau a fost eliminat.", NewLine);		
		
		#if AMXX_VERSION_NUM < 183
			write_file( LangFile, "ROM_SPEC_BUG = %c%s : %cAi facut o miscare suspecta asa ca te-am mutat la echipa precedenta.", NewLine);
		#else
			write_file( LangFile, "ROM_SPEC_BUG = ^^3%s : ^^4Ai facut o miscare suspecta asa ca te-am mutat la echipa precedenta.", NewLine);
		#endif
		
		write_file( LangFile, "ROM_SPEC_BUG_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"SPEC_BUG^" ca sa strice buna functionare a serverului.", NewLine);
		
		#if AMXX_VERSION_NUM < 183
			write_file( LangFile, "ROM_ADMIN_CHAT_FLOOD = %c%s : %cS-a observat un mic flood la chat primit din partea ta. Mesajele trimise de tine vor fi filtrate.", NewLine);
			write_file( LangFile, "ROM_ADMIN_CHAT_FLOOD_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"ADMIN_CHAT_FLOOD^" ca sa dea kick adminilor de pe server.", NewLine);	
		#endif
		
		#if AMXX_VERSION_NUM < 183
			write_file( LangFile, "ROM_AUTOBUY = %c%s : %cComanda trimisa de tine are valori suspecte, asa ca am blocat-o.", NewLine);
		#else
			write_file( LangFile, "ROM_AUTOBUY = ^^3%s : ^^4Comanda trimisa de tine are valori suspecte, asa ca am blocat-o.", NewLine);
		#endif
		
		write_file( LangFile, "ROM_AUTOBUY_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"AUTOBUY_BUG^" ca sa strice buna functionare a serverului.", NewLine);
		
		write_file( LangFile, "ROM_FILE_NOT_FOUND = %s : Fisierul %s nu exista.", NewLine);
		
		write_file( LangFile, "ROM_ADMIN_DEBUG = Nume : %s - Parola : %s - Acces : %s - Flag : %s", NewLine);
		
		write_file( LangFile, "ROM_MOTDFILE = %s : S-a detectat o miscare suspecta din partea ta, comanda ta a fost blocata.", NewLine);
		write_file( LangFile, "ROM_MOTDFILE_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca cvar-ul ^"motdfile^" ca sa fure informatii din acest server.", NewLine);	
		
		#if AMXX_VERSION_NUM < 183
			write_file( LangFile, "ROM_ADVERTISE = %c%s :%c Acest server este supravegheat de pluginul de protectie %c%s%c versiunea %c%s%c .", NewLine);
		#else
			write_file( LangFile, "ROM_ADVERTISE = ^^3%s :^^4 Acest server este supravegheat de pluginul de protectie ^^3%s^^4 versiunea ^^3%s^^4 .", NewLine);
		#endif
		
		write_file( LangFile, "ROM_ANTI_BAN_CLASS = %s : S-au detectat u numar prea mare de ban-uri pe clasa de ip, comanda ta a fost blocata.", NewLine);
		write_file( LangFile, "ROM_ANTI_ANY_BAN_CLASS_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa dea ban pe clasa de ip.", NewLine);	
		write_file( LangFile, "ROM_ANTI_SOME_BAN_CLASS_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa dea ban pe mai mult de %s clase de ip.", NewLine);	
	}
	register_dictionary("rom_protect.txt");
	IsLangUsed = true;
}

writeSignature(const File[])
{
	new line[121];
	
	write_file( File, "// *ROM-Protect", NewLine);
	write_file( File, "// Plugin OpenSource anti-flood/bug-fix pentru orice server.", NewLine);
	formatex(line, charsmax(line), "// Versiunea %s. Bulit %d", Version, Build);
	write_file( File, line, NewLine); 
	write_file( File, "// Autor : lüxor # Dr.Fio & DR2.IND (+ eNd.) - SteamID (contact) : luxxxoor", NewLine);
	write_file( File, "// O productie FioriGinal.ro - site : www.fioriginal.ro", NewLine);
	write_file( File, "// Link forum de dezvoltare : http://forum.fioriginal.ro/amxmodx-plugins-pluginuri/rom-protect-anti-flood-bug-fix-t28292.html", NewLine);
	write_file( File, "// Link sursa : https://github.com/luxxxoor/ROM-Protect", -1);
	#if AMXX_VERSION_NUM >= 183
		if ( equal(File, LangFile) )
		{
			write_file( File, " ", NewLine);
			write_file( File, "// Colori : ^1 - Culoarea aleasa de jucator cu con_color.", -1);
			write_file( File, "//          ^3 - Culoare gri.", -1);
			write_file( File, "//          ^4 - Culoare verde.", -1);
		}
	#endif
	write_file( File, " ", NewLine);
	write_file( File, " ", NewLine);
	write_file( File, " ", NewLine);
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
// header ColorChat.inc

/* Fun functions
*
* by Numb
*
* This file is provided as is (no warranties).
*/

new TeamName[][] = 
{
	"",
	"TERRORIST",
	"CT",
	"SPECTATOR"
};

ColorChat(id, Color:type, const msg[], {Float,Sql,Result,_}:...)
{
	new message[256];

	switch(type)
	{
		case NORMAL: // clients scr_concolor cvar color
		{
			message[0] = 0x01;
		}
		case GREEN: // Green
		{
			message[0] = 0x04;
		}
		default: // White, Red, Blue
		{
			message[0] = 0x03;
		}
	}

	vformat(message[1], 251, msg, 4);

	// Make sure message is not longer than 192 character. Will crash the server.
	message[192] = '^0';

	new team, ColorChange, index, MSG_Type;
	
	if(id)
	{
		MSG_Type = MSG_ONE;
		index = id;
	} else {
		index = FindPlayer();
		MSG_Type = MSG_ALL;
	}
	
	team = get_user_team(index);
	ColorChange = ColorSelection(index, MSG_Type, type);

	ShowColorMessage(index, MSG_Type, message);
		
	if(ColorChange)
	{
		Team_Info(index, MSG_Type, TeamName[team]);
	}
}

ShowColorMessage(id, type, message[])
{
	static bool:saytext_used;
	static get_user_msgid_saytext;
	if(!saytext_used)
	{
		get_user_msgid_saytext = get_user_msgid("SayText");
		saytext_used = true;
	}
	message_begin(type, get_user_msgid_saytext, _, id);
	write_byte(id);
	write_string(message);
	message_end();	
}

Team_Info(id, type, team[])
{
	static bool:teaminfo_used;
	static get_user_msgid_teaminfo;
	if(!teaminfo_used)
	{
		get_user_msgid_teaminfo = get_user_msgid("TeamInfo");
		teaminfo_used = true;
	}
	message_begin(type, get_user_msgid_teaminfo, _, id);
	write_byte(id);
	write_string(team);
	message_end();

	return 1;
}

ColorSelection(index, type, Color:Type)
{
	switch(Type)
	{
		case RED:
		{
			return Team_Info(index, type, TeamName[1]);
		}
		case BLUE:
		{
			return Team_Info(index, type, TeamName[2]);
		}
		case GREY:
		{
			return Team_Info(index, type, TeamName[0]);
		}
	}

	return 0;
}

FindPlayer()
{
	new i = -1;

	while(i <= get_maxplayers())
	{
		if(is_user_connected(++i))
			return i;
	}

	return -1;
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
*/

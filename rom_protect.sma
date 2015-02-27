#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>

#if AMXX_VERSION_NUM < 183
	#include <ColorChat>
	#define MAX_PLAYERS 32
	#define MAX_NAME_LENGTH 32
	new bool:flood[MAX_PLAYERS + 1];
	new Float:g_Flooding[MAX_PLAYERS + 1] = {0.0, ...},
	g_Flood[MAX_PLAYERS + 1] = {0, ...};
#else
	#if MAX_PLAYERS > 32
		#define MAX_PLAYERS 32
	#endif
#endif

#pragma semicolon 1


new sz_MenuText[MAX_PLAYERS + 1][ MAX_PLAYERS],
	ArgNum[MAX_PLAYERS + 1], Contor[MAX_PLAYERS + 1],
	bool:Name[MAX_PLAYERS + 1], bool:Admin[MAX_PLAYERS + 1], LastPass[MAX_PLAYERS + 1][32], File[128], MapName[32];

static const Version[]     = "1.0.4f-dev",
			 Built         = 38,
			 pluginName[] = "ROM-Protect",
			 Terrorist[]   = "#Terrorist_Select",
			 CT_Select[]   = "#CT_Select",
			 cfgFile[]     = "addons/amxmodx/configs/rom_protect.cfg",
			 langFile[]    = "addons/amxmodx/data/lang/rom_protect.txt",
			 langType[]    = "%L",
			 newLine       = -1;

new LoginName[MAX_PLAYERS + 1][1024], LoginPass[MAX_PLAYERS + 1][1024], LoginAccess[MAX_PLAYERS + 1][1024], LoginFlag[MAX_PLAYERS + 1][1024];
new admin_number, bool:IsLangUsed;

enum
{
    FM_TEAM_T = 1,
    FM_TEAM_CT,
    FM_TEAM_SPECTATOR
}

#define OFFSET_TEAM  114 
#define fm_set_user_team(%1,%2)  set_pdata_int( %1, OFFSET_TEAM, %2 )
#define fm_get_user_team(%1)     get_pdata_int( %1, OFFSET_TEAM ) 

new const AllBasicOnChatCommads[][] =
{
	"amx_say", "amx_csay", "amx_psay", "amx_tsay", "amx_chat", "say_team", 
	"say", "amx_gag", "amx_kick", "amx_ban", "amx_banip", "amx_nick", "amx_rcon"
};

enum _:AllCvars
{
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
	utf8_bom,
	color_bug,
	motdfile,
	anti_pause,
	anti_ban_class
};

new const CvarName[AllCvars][] = 
{
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
	"rom_utf8-bom",
	"rom_color-bug",
	"rom_motdfile",
	"rom_anti-pause",
	"rom_anti-ban-class"
};

new const CvarValue[AllCvars][] =
{
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
	"1",
	"2"
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

enum INFO
{
	INFO_NAME,
	INFO_IP,
	INFO_AUTHID    
};

public plugin_precache( )
{	
	registersPrecache();
	
	new szCurentDate[15];
	get_localinfo("amxx_configsdir", File, charsmax(File));
	formatex(File, charsmax ( File ), "%s/%s", File, pluginName);
	
	if (!dir_exists(File))
		mkdir(File);
	
	get_time("%d-%m-%Y", szCurentDate, charsmax(szCurentDate));
	formatex(File, charsmax( File ), "%s/%s_%s.log", File, pluginName, szCurentDate);
	
	if( !file_exists( File ) )
		{
		write_file(File, "*Aici este salvata activitatea suspecta a fiecarui jucator. ", newLine);
		write_file(File, " ", newLine);
		write_file(File, " ", newLine);
	}
	
	get_mapname(MapName, charsmax(MapName));
	format(MapName, charsmax(MapName), "|%s| ", MapName);
	
	if (file_exists(cfgFile))
		server_cmd("exec %s", cfgFile);
	
	set_task(10.0, "CheckLang");
	set_task(15.0, "CheckLangFile");
	set_task(20.0, "CheckCfg");
}

public CheckCfg()
{
	if( !file_exists(cfgFile) )
		WriteCfg(false);
	else
	{
		new File = fopen(cfgFile, "r+");
		
		new Text[121], bool:FindVersion; 
		while (!feof(File))
		{
			fgets(File, Text, charsmax(Text));
			
			if (containi(Text, Version) != -1)
			{
				FindVersion = true;
				break;
			}
		}
		if (!FindVersion)
		{
			WriteCfg(true);
			if (getNum(PlugCvar[plug_log]) == 1)
				logCommand(langType, LANG_SERVER, "ROM_UPDATE_CFG", getString(PlugCvar[Tag]));
		}
	}
}

public CheckLang()
{
	if (!file_exists(langFile))
		WriteLang(false);
	else
	{
		IsLangUsed = false;
		new File = fopen(langFile, "r+");
		
		new Text[121], bool:isCurrentVersionUsed;
		while (!feof(File))
		{
			fgets(File, Text, charsmax(Text));
			
			if (containi(Text, Version) != -1)
			{
				isCurrentVersionUsed = true;
				break;
			}
		}
		if (!isCurrentVersionUsed)
		{
			register_dictionary("rom_protect.txt");
			IsLangUsed = true;
			if (getNum(PlugCvar[plug_log]) == 1)
				logCommand(langType, LANG_SERVER, "ROM_UPDATE_LANG", getString(PlugCvar[Tag]));
			WriteLang(true);
		}
	}
}

public CheckLangFile()
{
	if(!IsLangUsed)
		register_dictionary("rom_protect.txt");
}

public plugin_init( )
{
	registersInit();
	
	if( getNum(PlugCvar[advertise] ) == 1 )
		set_task(getFloat(PlugCvar[advertise_time]), "showAdvertise", _, _, _, "b", 0);
	
	if( getNum( PlugCvar[ utf8_bom ] ) == 1 )
	{
		g_tDefaultRes = TrieCreate();
		TrieSetCell( g_tDefaultRes , "de_storm.res", 1); 
		TrieSetCell( g_tDefaultRes , "default.res", 1); 
		
		set_task(10.0, "cleanResFiles");
	}
	
}

public client_connect(id)
{
	if (getNum(PlugCvar[cmd_bug]) == 1)
	{
		new name[MAX_NAME_LENGTH];
		get_user_name(id, name, charsmax(name));
		stringFilter(name, charsmax(name));
		set_user_info(id, "name", name);
	}
	if (getNum(PlugCvar[fake_players]) == 1)
	{
		new players[MAX_PLAYERS], pnum, address[32], address2[32];
		if(clientUseSteamid(id))
			query_client_cvar(id, "fps_max", "checkBot");
		get_players(players, pnum, "c");
		for (new i; i < pnum; ++i)
		{
			get_user_ip( id, address, charsmax( address ), 1 );
			get_user_ip( players[ i ], address2, charsmax(address2), 1 );
			if( equal( address, address2 ) && !is_user_bot( id ) )
			{
				if( ++Contor[ id ] > getNum( PlugCvar[fake_players_limit] ) )
				{
					server_cmd( "addip ^"30^" ^"%s^";wait;writeip", address );
					if( getNum( PlugCvar[plug_warn] ) == 1 )
					{
						#if AMXX_VERSION_NUM < 183
							ColorChat( 0, GREY, langType, LANG_PLAYER, "ROM_FAKE_PLAYERS", '^3', getString(PlugCvar[Tag]), '^4', address );
							ColorChat( 0, GREY, langType, LANG_PLAYER, "ROM_FAKE_PLAYERS_PUNISH", '^3', getString(PlugCvar[Tag]), '^4' );
						#else
							client_print_color( 0, print_team_grey, langType, LANG_PLAYER, "ROM_FAKE_PLAYERS", getString(PlugCvar[Tag]), address );
							client_print_color( 0, print_team_grey, langType, LANG_PLAYER, "ROM_FAKE_PLAYERS_PUNISH", getString(PlugCvar[Tag]) );
						#endif
					}
					if( getNum( PlugCvar[plug_log] ) == 1 )
						logCommand( langType, LANG_SERVER, "ROM_FAKE_PLAYERS_LOG", getString(PlugCvar[Tag]), address );
					break;
				}
			}
		}
	}
} 

public client_disconnect(id)
	{
	Contor[id] = 0;
	if( Admin[id] )
	{
		Admin[id] = false;
		remove_user_flags( id );
	}
}

public plugin_end()
{
	if (getNum(PlugCvar[delete_vault]) != 0)
	{
		new baseDir[128];
		new text[200] ;
		get_basedir(baseDir, charsmax(baseDir));
		formatex(baseDir, charsmax(baseDir), "%s/data/vault.ini", baseDir);
		if (file_exists(baseDir))
		{
			delete_file(baseDir);
			if (getNum( PlugCvar[delete_vault]) == 2)
			{
				formatex(text, charsmax(text) , "server_language ro", baseDir);
				write_file(baseDir, text, newLine);
			}
			if (getNum(PlugCvar[delete_vault]) == 1)
			{
				formatex(text, charsmax(text), "server_language en", baseDir);
				write_file( baseDir, text, newLine);
			}
		}
	}
	if (getNum(PlugCvar[delete_custom_hpk]) == 1)
	{
		new baseDir[] = "/", dirPointer, File[ 32 ];
		
		dirPointer = open_dir(baseDir, "", 0);
		
		while (next_file(dirPointer, File, charsmax(File)))
		{
			if (File[0] == '.')
				continue;
			
			if (containi( File, "custom.hpk" ) != -1)
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
		return PLUGIN_CONTINUE;
		
	static newName[MAX_NAME_LENGTH], oldName[MAX_NAME_LENGTH];
	get_user_name(id, oldName, charsmax(oldName));
	get_user_info(id, "name", newName, charsmax(newName));
	
	if (getNum(PlugCvar[cmd_bug]) == 1)
	{
		stringFilter(newName, charsmax(newName));
		set_user_info(id, "name", newName);
	}
	
	if (!equali(newName, oldName) && Admin[id])
	{
		Admin[id] = false;
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
				ColorChat(0, GREY, langType, LANG_PLAYER, "ROM_PLUGIN_PAUSE", '^3', getString(PlugCvar[Tag]), '^4');
			#else
				client_print_color(0, print_team_grey, langType, LANG_PLAYER, "ROM_PLUGIN_PAUSE", getString(PlugCvar[Tag]));
			#endif
		}
		if (getNum(PlugCvar[plug_log]) == 1)
				logCommand(langType, LANG_SERVER, "ROM_PLUGIN_PAUSE_LOG", getString(PlugCvar[Tag]), getString(PlugCvar[Tag]));
		server_cmd("amxx unpause rom_protect.amxx");
	}
}

public cmdPass(id)
{
	if (getNum(PlugCvar[admin_login]) == 0)
		return PLUGIN_HANDLED;
	new name[MAX_NAME_LENGTH], pass[32];
	get_user_name(id, name, charsmax(name));
	read_argv(1, pass, charsmax(pass));
	remove_quotes(pass);
	
	loadAdminLogin();
	getAccess(id, pass);
	
	if (!Admin[id])
	{
		if (!Name[ id ])
		{
			#if AMXX_VERSION_NUM < 183
				ColorChat(id, GREY, langType, id, "ROM_ADMIN_WRONG_NAME", '^3', getString(PlugCvar[Tag]), '^4');
			#else
				client_print_color(id, print_team_grey, langType, id, "ROM_ADMIN_WRONG_NAME", getString(PlugCvar[Tag]));
			#endif
			client_print(id, print_console, langType, id, "ROM_ADMIN_WRONG_NAME_PRINT", getString(PlugCvar[Tag]));
		}
		else
		{
			#if AMXX_VERSION_NUM < 183
				ColorChat(id, GREY, langType, id, "ROM_ADMIN_WRONG_PASS", '^3', getString(PlugCvar[Tag]), '^4');
			#else
				client_print_color(id, print_team_grey, langType, id, "ROM_ADMIN_WRONG_PASS", getString(PlugCvar[Tag]));
			#endif
			client_print(id, print_console, langType, id, "ROM_ADMIN_WRONG_PASS_PRINT", getString(PlugCvar[Tag]));
		}
	}
	else
	{
		#if AMXX_VERSION_NUM < 183
			ColorChat(id, GREY, langType, id, "ROM_ADMIN_LOADED", '^3', getString(PlugCvar[Tag]), '^4');
		#else
			client_print_color(id, print_team_grey, langType, id, "ROM_ADMIN_LOADED", getString(PlugCvar[Tag]));
		#endif
		client_print(id, print_console, langType, id, "ROM_ADMIN_LOADED_PRINT", getString(PlugCvar[Tag]));
	}
	
	return PLUGIN_CONTINUE;
}

#if AMXX_VERSION_NUM < 183
	public hookAdminChat(id)
	{
		new said[2];
		read_argv(1, said, charsmax(said));

		if (said[0] != '@')
			return PLUGIN_CONTINUE;

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
				if (g_Flood[id])
					--g_Flood[id];
			g_Flooding[id] = nexTime + maxChat;
		}

		return PLUGIN_CONTINUE;
	}
#endif

public oldStyleMenusTeammenu(msg, des, rec)
{
	if (is_user_connected(rec))
	{
		get_msg_arg_string(4, sz_MenuText[rec], charsmax(sz_MenuText));
		if (equal(sz_MenuText[rec], Terrorist) || equal(sz_MenuText[rec], CT_Select))
			set_task(0.1, "blockSpecbugOldStyleMenus", rec);
	}
}

public vGuiTeammenu(msg, des, rec)  
{  
	if (get_msg_arg_int(1) == 26 || get_msg_arg_int(1) == 27)
	{
		ArgNum[rec] = get_msg_arg_int(1);
		set_task(0.1, "blockSpecbugVGui", rec);
	}
}

public blockSpecbugOldStyleMenus(id)
{
	if (!is_user_alive(id) && is_user_connected(id) && getNum(PlugCvar[spec_bug]) == 1)
	{
		if (fm_get_user_team(id) == FM_TEAM_SPECTATOR && !is_user_alive(id))
		{
			if (equal(sz_MenuText[id], Terrorist) && is_user_connected(id))
				fm_set_user_team(id, FM_TEAM_T);
			if (equal(sz_MenuText[id], CT_Select) && is_user_connected(id))
				fm_set_user_team(id, FM_TEAM_CT);
			if (getNum(PlugCvar[plug_warn]))
			{
				#if AMXX_VERSION_NUM < 183
					ColorChat(id,GREY, langType, id, "ROM_SPEC_BUG", '^3', getString(PlugCvar[Tag]), '^4');
				#else
					client_print_color(id, print_team_grey, langType, id, "ROM_SPEC_BUG", getString(PlugCvar[Tag]));
				#endif
			}
			if (getNum(PlugCvar[plug_log]))
				logCommand(langType, LANG_SERVER, "ROM_SPEC_BUG_LOG", getString(PlugCvar[Tag]), getInfo(id, INFO_NAME), getInfo(id, INFO_AUTHID), getInfo(id, INFO_IP));
		}
		set_task(0.1, "blockSpecbugOldStyleMenus", id);
	}
}

public blockSpecbugVGui(id)
{
	new bool:bug_log[MAX_PLAYERS + 1];
	if (!is_user_alive(id) && is_user_connected(id) && getNum(PlugCvar[spec_bug]) == 1)
	{
		if (fm_get_user_team(id) == FM_TEAM_SPECTATOR)
		{
			if (ArgNum[id] == 26)
			{
				fm_set_user_team(id, FM_TEAM_T);
				bug_log[id] = true;
			}      
			if (ArgNum[id] == 27)
			{
				fm_set_user_team(id, FM_TEAM_CT);
				bug_log[id] = true;
			}      
			if (getNum(PlugCvar[plug_warn]) == 1 && bug_log[id])
			{
				#if AMXX_VERSION_NUM < 183
					ColorChat(id, GREY, langType, id, "ROM_SPEC_BUG", '^3', getString(PlugCvar[Tag]), '^4');
				#else
					client_print_color(id, print_team_grey, langType, id, "ROM_SPEC_BUG", getString(PlugCvar[Tag]));
				#endif
			}
			if (getNum( PlugCvar[plug_log]) == 1 && bug_log[id])
			{
				logCommand(langType, LANG_SERVER, "ROM_SPEC_BUG_LOG", getString(PlugCvar[Tag]), getInfo(id, INFO_NAME), getInfo(id, INFO_AUTHID), getInfo(id, INFO_IP));
				bug_log[id] = false;
			}
		}
		set_task(0.1, "blockSpecbugVGui", id);
	}
}

#if AMXX_VERSION_NUM < 183
	public showAdminChatFloodWarning(id)
	{
		if (flood[id])
		{
			if (getNum(PlugCvar[plug_warn]) == 1)
					ColorChat(id, GREY, langType, id, "ROM_ADMIN_CHAT_FLOOD", '^3', getString(PlugCvar[Tag]), '^4');
			if (getNum(PlugCvar[plug_log]) == 1)
				logCommand(langType, LANG_SERVER, "ROM_ADMIN_CHAT_FLOOD_LOG", getString(PlugCvar[Tag]), getInfo(id, INFO_NAME), getInfo(id, INFO_AUTHID), getInfo(id, INFO_IP));
			flood[id] = false;
		}
	}
#endif

public showAdvertise()
{
	#if AMXX_VERSION_NUM < 183
		ColorChat(0, GREY, langType, LANG_PLAYER, "ROM_ADVERTISE", '^3', getString(PlugCvar[Tag]), '^4', '^3', pluginName, '^4', '^3', Version, '^4');
	#else
		client_print_color(0, print_team_grey, langType, LANG_PLAYER, "ROM_ADVERTISE", getString(PlugCvar[Tag]), pluginName, Version);
	#endif
}

public cleanResFiles() 
{ 
	new mapsFolder[] = "maps"; 
	new const resExt[] = ".res"; 
	new resFile[64], len; 
	new dp = open_dir(mapsFolder, resFile, charsmax(resFile)); 
	
	if (!dp) 
		return; 
	
	new fullPathFileName[128]; 
	do 
	{ 
		len = strlen(resFile);
		if(len > 4 && equali(resFile[len-4], resExt)) 
		{ 
			if(TrieKeyExists(g_tDefaultRes, resFile)) 
				continue;
			
			formatex(fullPathFileName, charsmax(fullPathFileName), "%s/%s", mapsFolder, resFile); 
			write_file(fullPathFileName, "/////////////////////////////////////////////////////////////^n", 0); 
		} 
	} 
	while(next_file(dp, resFile, charsmax(resFile)));
	
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
	for (new i; i < pnum; ++i)
		if (Admin[players[i]])
			getAccess(players[i], LastPass[players[i]]);
}

public cvarFunc(id, level, cid) 
{ 
	if (getNum(PlugCvar[motdfile]) == 1)
	{
		new arg[32], arg2[32]; 
		
		read_argv(1, arg, charsmax(arg));
		read_argv(2, arg2, charsmax(arg2));
		
		if (equali(arg, "motdfile") && contain(arg2, ".ini") != -1) 
		{
			if (getNum(PlugCvar[plug_warn]) == 1)
				console_print(id, langType, id, "ROM_MOTDFILE", getString(PlugCvar[Tag]));
			if (getNum(PlugCvar[plug_log]) == 1)
				logCommand(langType, LANG_SERVER, "ROM_MOTDFILE_LOG", getString(PlugCvar[Tag]), getInfo(id, INFO_NAME), getInfo(id, INFO_AUTHID), getInfo(id, INFO_IP));
			return PLUGIN_HANDLED; 
		}
	}
	
	return PLUGIN_CONTINUE; 
}

public hookBanClassCommand(id)
{ 
	if ( id && !is_user_admin(id) )
		return PLUGIN_CONTINUE;
	
	if (getNum(PlugCvar[anti_ban_class]) > 0)
	{
		new ip[32], IpNum[4][3], NumStr[1], Value;
		read_argv(1, ip, charsmax(ip));
		
		for	(new i = 0; i < 4; ++i)
			split(ip, IpNum[i], charsmax(IpNum[]), ip, charsmax(ip), ".");
		
		Value = getNum(PlugCvar[anti_ban_class]);
		
		if (Value > 4 || Value < 0)
			Value = 4;
			
		num_to_str(Value,NumStr,charsmax(NumStr));
		
		switch (Value)
		{
			case 1:
			{
				if ( !str_to_num(IpNum[0]) || !str_to_num(IpNum[1]) || !str_to_num(IpNum[2]) )
				{
					if (getNum(PlugCvar[plug_warn]) == 1)
						console_print(id, langType, id, "ROM_ANTI_BAN_CLASS", getString(PlugCvar[Tag]));
					if (getNum(PlugCvar[plug_log]) == 1)
						logCommand(langType, LANG_SERVER, "ROM_ANTI_ANY_BAN_CLASS_LOG", getString(PlugCvar[Tag]), getInfo(id, INFO_NAME), getInfo(id, INFO_AUTHID), getInfo(id, INFO_IP));
					return PLUGIN_HANDLED;
				}
			}
			case 2:
			{
				if ( !str_to_num(IpNum[0]) || !str_to_num(IpNum[1]) )
				{
					if (getNum(PlugCvar[plug_warn]) == 1)
						console_print(id, langType, id, "ROM_ANTI_BAN_CLASS", getString(PlugCvar[Tag]));
					if (getNum(PlugCvar[plug_log]) == 1)
						logCommand(langType, LANG_SERVER, "ROM_ANTI_SOME_BAN_CLASS_LOG", getString(PlugCvar[Tag]), getInfo(id, INFO_NAME), getInfo(id, INFO_AUTHID), getInfo(id, INFO_IP), NumStr);
					return PLUGIN_HANDLED;
				}
			}
			case 3:
			{
				if ( !str_to_num(IpNum[0]) )
				{
					if (getNum(PlugCvar[plug_warn]) == 1)
						console_print(id, langType, id, "ROM_ANTI_BAN_CLASS", getString(PlugCvar[Tag]));
					if (getNum(PlugCvar[plug_log]) == 1)
						logCommand(langType, LANG_SERVER, "ROM_ANTI_SOME_BAN_CLASS_LOG", getString(PlugCvar[Tag]), getInfo(id, INFO_NAME), getInfo(id, INFO_AUTHID), getInfo(id, INFO_IP), NumStr);
					return PLUGIN_HANDLED;
				}
			}
			default:
			{
				if (getNum(PlugCvar[plug_warn]) == 1)
					console_print(id, langType, id, "ROM_ANTI_BAN_CLASS", getString(PlugCvar[Tag]));
				if (getNum(PlugCvar[plug_log]) == 1)
					logCommand(langType, LANG_SERVER, "ROM_ANTI_SOME_BAN_CLASS_LOG", getString(PlugCvar[Tag]), getInfo(id, INFO_NAME), getInfo(id, INFO_AUTHID), getInfo(id, INFO_IP), NumStr);
				return PLUGIN_HANDLED;
			}
		}
	}
	return PLUGIN_CONTINUE;
}

public hookBasicOnChatCommand(id)
{
	if (getNum(PlugCvar[color_bug]) == 1 || getNum(PlugCvar[cmd_bug]) == 1)
	{
		new said[192];
		read_args(said, charsmax(said));
		
		new s_said[192], bool:b_said_cmd_bug[MAX_PLAYERS + 1], bool:b_said_color_bug[MAX_PLAYERS + 1];
		copy(s_said, charsmax( said ), said);
		for (new i; i < sizeof s_said ; ++i)
		{
			if (getNum(PlugCvar[cmd_bug]) == 1 && (s_said[ i ] == '#' && isalpha(s_said[i+1])) || (s_said[i] == '%' && s_said[i+1] == 's'))
			{
				b_said_cmd_bug[id] = true;
				break;
			}
			if (getNum(PlugCvar[color_bug]) == 1)
			{
				if (s_said[i] == '' || s_said[i] == '' || s_said[i] == '')
				{
					b_said_color_bug[id] = true;
					break;
				}
			}
		}
		
		if (b_said_cmd_bug[id])
		{
			if (getNum(PlugCvar[plug_warn]) == 1)
			{
				#if AMXX_VERSION_NUM < 183
					ColorChat( id, GREY, langType, id, "ROM_CMD_BUG", '^3', getString(PlugCvar[Tag]), '^4');
				#else
					client_print_color( id, print_team_grey, langType, id, "ROM_CMD_BUG", getString(PlugCvar[Tag]) );
				#endif
				console_print(id, langType, id, "ROM_CMD_BUG_PRINT", getString(PlugCvar[Tag]));
			}
			if (getNum(PlugCvar[plug_log]) == 1)
				logCommand(langType, LANG_SERVER, "ROM_CMD_BUG_LOG", getString(PlugCvar[Tag]), getInfo(id, INFO_NAME), getInfo(id, INFO_AUTHID), getInfo(id, INFO_IP));
			b_said_cmd_bug[id] = false;
			return PLUGIN_HANDLED;
		}
		if (b_said_color_bug[id])
		{
			if (getNum(PlugCvar[plug_warn]) == 1)
			{
				#if AMXX_VERSION_NUM < 183
					ColorChat( id, GREY, langType, id, "ROM_COLOR_BUG", '^3', getString(PlugCvar[Tag]), '^4');
				#else
					client_print_color( id, print_team_grey, langType, id, "ROM_COLOR_BUG", getString(PlugCvar[Tag]) );
				#endif
			}
			if (getNum(PlugCvar[plug_log]) == 1)
				logCommand(langType, LANG_SERVER, "ROM_COLOR_BUG_LOG", getString(PlugCvar[Tag]), getInfo(id, INFO_NAME), getInfo(id, INFO_AUTHID), getInfo(id, INFO_IP));
			b_said_color_bug[id] = false;
			return PLUGIN_HANDLED;
		}
	}
	return PLUGIN_CONTINUE;
}

public checkBot(id,const szVar[], const szValue[])
{
    if (equal(szVar, "fps_max") && szValue[0] == 'B')
    {
		if (getNum(PlugCvar[plug_log]) == 1)
				logCommand(langType, LANG_SERVER, "ROM_FAKE_PLAYERS_DETECT_LOG", getString(PlugCvar[Tag]), getInfo(id, INFO_NAME), getInfo(id, INFO_AUTHID), getInfo(id, INFO_IP));
		console_print(id, langType, id, "ROM_FAKE_PLAYERS_DETECT", getString(PlugCvar[Tag]));
		server_cmd("kick #%d ^"You got kicked. Check console.^"", get_user_userid(id));
    }
}

loadAdminLogin()
{
	new path[64];
	get_localinfo("amxx_configsdir", path, charsmax(path));
	formatex(path, charsmax(path), "%s/%s", path, getString(PlugCvar[admin_login_file]));
	
	new file = fopen(path, "r+");
	
	if (!file)
	{
		if (getNum(PlugCvar[plug_log]) == 1)
			logCommand( langType, LANG_SERVER, "ROM_FILE_NOT_FOUND", getString(PlugCvar[Tag]), getString(PlugCvar[admin_login_file]));
		return;
	}
	
	new text[121], name[MAX_NAME_LENGTH], pass[32], acc[26], flags[6];
	for (admin_number = 0; !feof( file ); ++admin_number)
	{
		fgets(file, text, charsmax(text));
		
		trim(text);
		
		if ((text[0] == ';') || !strlen(text) || (text[0] == '/'))
			continue;
		
		if (parse(text, name, charsmax(name), pass, charsmax(pass), acc, charsmax(acc), flags, charsmax(flags)) != 4)
			continue;
		
		copy(LoginName[admin_number], charsmax(LoginName[]),  name);
		copy(LoginPass[admin_number], charsmax(LoginPass[]),  pass);
		copy(LoginAccess[admin_number], charsmax(LoginAccess[]),  acc);
		copy(LoginFlag[admin_number], charsmax(LoginFlag[]),  flags);
		
		if (getNum(PlugCvar[admin_login_debug]) == 1)
			server_print(langType, LANG_SERVER, "ROM_ADMIN_DEBUG", LoginName[admin_number], LoginPass[admin_number], LoginAccess[admin_number], LoginFlag[admin_number]);
	}
	fclose(file);
}

getAccess(const id, const userPass[])
{
	static userName[MAX_NAME_LENGTH], acces;
	get_user_info(id, "name", userName, charsmax(userName));
	if (!(get_user_flags(id) & ADMIN_CHAT))
		remove_user_flags(id);
	copy(LastPass[id], charsmax(LastPass[]), userPass);
	for (new i = 1; i <= admin_number; ++i)
	{
		if (equali(LoginName[i], userName))
			Name[id] = true;
		else
			Name[id] = false;
		if (equal(LoginFlag[i], "f") && Name[id])
		{
			if (equal(LoginPass[i], userPass) || Admin[id])
			{
				Admin[id] = true;
				acces = read_flags(LoginAccess[i]);
				set_user_flags(id, acces);
			}
			break;
		}
	}
}

logCommand(const szMsg[], any:...)
{
	new Message[256], LogMessage[256];
	vformat(Message, charsmax(Message), szMsg , 2);
	
	formatex(LogMessage, charsmax(LogMessage), "L %s%s%s", getTime(), MapName, Message);
	
	server_print(LogMessage);
	write_file(File, LogMessage, newLine);
}

getInfo(id, const INFO:iInfo)
{
	new Server[32] = "SERVER"; // Trebuie sa aibe acealasi numar de caractere pentru a nu primi "error 047".
	switch (iInfo)
	{
		case INFO_NAME:
		{
			static name[32];
			get_user_name(id, name, charsmax(name));
			
			return name;
		}
		case INFO_IP:
		{
			static ip[32];
			get_user_ip(id, ip, charsmax(ip), 1);
			
			return ip;
		}
		case INFO_AUTHID:
		{
			static authid[32];
			if (id)
			{
				get_user_authid(id, authid, charsmax(authid));
				return authid;
			}
			else
				return Server;
		}
	}
	return Server; // Un return care nu se va apela niciodata, insa compilatorul nu va mai primi warning.
}

getTime()
{
	static szTime[32];
	get_time(" %H:%M:%S ", szTime, charsmax(szTime));
	return szTime;
}

getString(text)
{
	static File[32]; 
	get_pcvar_string(text, File, charsmax(File));
	return File;
}

getNum(text)
{
	static num;
	num = get_pcvar_num(text);
	return num;
}

Float:getFloat(text)
{
	new Float:float = get_pcvar_float(text);
	return float;
} 

registersPrecache()
{
	for (new i; i < AllCvars; i++)
		PlugCvar[i] = register_cvar(CvarName[i] , CvarValue[i]);
}

registersInit()
{
	register_plugin(pluginName, Version, "FioriGinal.Ro");
	register_cvar("rom_protect", Version, FCVAR_SERVER | FCVAR_SPONLY);
	
	register_message(get_user_msgid( "ShowMenu" ), "oldStyleMenusTeammenu");
	register_message(get_user_msgid( "VGUIMenu" ), "vGuiTeammenu");
	
	for(new i; i < sizeof AllBasicOnChatCommads; ++i)
		register_concmd(AllBasicOnChatCommads[i], "hookBasicOnChatCommand");
	#if AMXX_VERSION_NUM < 183
		register_clcmd("say_team", "hookAdminChat");
	#endif
	register_clcmd("login", "cmdPass");
	register_concmd("amx_cvar", "cvarFunc");
	register_concmd("amx_reloadadmins", "reloadLogin");
	register_concmd("amx_addban", "hookBanClassCommand");
}

public stringFilter(string[], len)
{
	for (new i; i <= len; ++i)
		if (i < MAX_NAME_LENGTH)
			if ((string[i] == '#' && isalpha(string[i+1])) || (string[i] == '+' && isalpha(string[i+1])))
				string[i] = ' ';
}

bool:clientUseSteamid(id) 
{	
	new authid[35];  
	get_user_authid(id, authid, charsmax(authid) );
	return (contain(authid , ":") != -1 && containi(authid , "STEAM") != -1) ? true : false; 
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
			if( name[ i ] == char_list[ j ] )
				b_name = true;
		}
		if( b_name )
			{
			//server_print("debug 3 - %d", contor);
			++contor;
			b_name = false
		}              
		else
		{
			contor = 0
		}
		if( contor >= 3)
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
		delete_file(cfgFile);
	new line[121];
	
	writeSignature(cfgFile);
	
	write_file(cfgFile, "// Verificare daca CFG-ul a fost executat cu succes." , newLine);
	write_file(cfgFile, "echo ^"*ROM-Protect : Fisierul rom_protect.cfg a fost gasit. Incep protejarea serverului.^"" , newLine);
	write_file(cfgFile, "// Cvar      : rom_cmd-bug" , newLine);
	write_file(cfgFile, "// Scop      : Urmareste chatul si opeste bugurile de tip ^"%s^"/^"%s0^" care dau pluginurile peste cap." , newLine);
	write_file(cfgFile, "// Impact    : Serverul nu pateste nimic, insa playerii acestuia primesc ^"quit^" indiferent de ce client folosesc, iar serverul ramane gol." , newLine);
	write_file(cfgFile, "// Update    : Incepand cu versiunea 1.0.1s, pluginul protejeaza serverele si de noul cmd-bug bazat pe caracterul '#'. Pluginul blocheaza de acum '#' si '%' in chat si '#' in nume." , newLine);
	write_file(cfgFile, "// Update    : Incepand cu versiunea 1.0.3a, pluginul devine mai inteligent, si va bloca doar posibilele folosiri ale acestui bug, astfel incat caracterele '#' si '%' vor putea fi folosite, insa nu in toate cazurile." , newLine);
	write_file(cfgFile, "// Update    : Incepand cu versiunea 1.0.3s, pluginul incearca sa inlature bugul provotat de caracterul '+' in nume, acesta incercand sa deruteze playerii sau adminii (nu aparea numele jucatorului in meniuri)." , newLine);
	write_file(cfgFile, "// Update    : Incepand cu versiunea 1.0.4b, pluginul verifica si comenzile de baza care pot elibera mesaje in chat (ex: amx_say, amx_psay, etc.), adica toate comenzile prezente in adminchat.amxx." , newLine);
	write_file(cfgFile, "// Valoarea 0: Functia este dezactivata." , newLine);
	write_file(cfgFile, "// Valoarea 1: Atacul este blocat. [Default]" , newLine);
	if(exist)
	{
		formatex(line, charsmax(line), "rom_cmd-bug ^"%d^"", getNum(PlugCvar[cmd_bug]));
		write_file(cfgFile, line , newLine);
	}
	else
		write_file(cfgFile, "rom_cmd-bug ^"1^"" , newLine);
	write_file( cfgFile, " " , newLine );
	
	write_file( cfgFile, "// Cvar      : rom_spec-bug" , newLine );
	write_file( cfgFile, "// Scop      : Urmareste activitatea playerilor si opreste schimbarea echipei, pentru a opri specbug." , newLine );
	write_file( cfgFile, "// Impact    : Serverul primeste crash in momentul in care se apeleaza la acest bug." , newLine );
	write_file( cfgFile, "// Nota      : -" , newLine );
	write_file( cfgFile, "// Valoarea 0: Functia este dezactivata." , newLine );
	write_file( cfgFile, "// Valoarea 1: Atacul este blocat. [Default]" , newLine );
	if(exist)
	{
		formatex(line, charsmax(line), "rom_spec-bug ^"%d^"", getNum( PlugCvar [ spec_bug ] ));
		write_file( cfgFile, line , newLine );
	}
	else
		write_file( cfgFile, "rom_spec-bug ^"1^"" , newLine );
	write_file( cfgFile, " " , newLine );

	#if AMXX_VERSION_NUM < 183
		write_file( cfgFile, "// Cvar      : rom_admin_chat_flood" , newLine );
		write_file( cfgFile, "// Scop      : Urmareste activitatea playerilor care folosesc chat-ul adminilor, daca persoanele incearca sa floodeze acest chat sunt opriti fortat." , newLine );
		write_file( cfgFile, "// Impact    : Serverul nu pateste nimic, insa adminii primesc kick cu motivul : ^"reliable channel overflowed^"." , newLine );
		write_file( cfgFile, "// Nota      : -" , newLine );
		write_file( cfgFile, "// Valoarea 0: Functia este dezactivata." , newLine );
		write_file( cfgFile, "// Valoarea 1: Atacul este blocat. [Default]" , newLine );
		if(exist)
		{
			formatex(line, charsmax(line), "rom_admin_chat_flood ^"%d^"", getNum( PlugCvar [ admin_chat_flood ] ));
			write_file( cfgFile, line , newLine );
		}
		else
			write_file( cfgFile, "rom_admin_chat_flood ^"1^"" , newLine );  
		write_file( cfgFile, " " , newLine );

		write_file( cfgFile, "// Cvar      : rom_admin_chat_flood_time ( Activat numai in cazul in care cvarul ^"rom_admin_chat_flood^" este setat pe 1 )" , newLine );
		write_file( cfgFile, "// Utilizare : Limiteaza numarul maxim de mesaje trimise de acelasi cleint in chatul adminilor, blocand astfel atacurile tip overflow." , newLine );
		if(exist)
		{
			formatex(line, charsmax(line), "rom_admin_chat_flood_time ^"%.2f^"", getFloat(PlugCvar[admin_chat_flood_time]));
			write_file( cfgFile, line , newLine );
		}
		else
			write_file( cfgFile, "rom_admin_chat_flood_time ^"0.75^"" , newLine );
		write_file( cfgFile, "" , newLine );
	#endif
	write_file( cfgFile, "// Cvar      : rom_fake-players" , newLine );
	write_file( cfgFile, "// Scop      : Urmareste persoanele conectate pe server si baneaza atunci cand numarul persoanelor cu acelasi ip il depaseste pe cel setat in cvarul rom_fake-players_limit." , newLine );
	write_file( cfgFile, "// Impact    : Serverul experimenteaza lag peste 200+ la orice jucator prezent pe server, cateodata chiar crash." , newLine );
	write_file( cfgFile, "// Nota      : Daca sunt mai multe persoane care impart aceasi legatura de internet pot fi banate ( 0 minute ), in acest caz ridicati cvarul : rom_fake-players_limit sau opriti rom_fake-players." , newLine );
	write_file( cfgFile, "// Valoarea 0: Functia este dezactivata." , newLine );
	write_file( cfgFile, "// Valoarea 1: Atacul este blocat prin ban 30 minute. [Default]" , newLine );
	if(exist)
	{
		formatex(line, charsmax(line), "rom_fake-players ^"%d^"", getNum( PlugCvar [ fake_players ] ));
		write_file( cfgFile, line , newLine );
	}
	else
		write_file( cfgFile, "rom_fake-players ^"1^"" , newLine );
	write_file( cfgFile, " " , newLine );
	
	write_file( cfgFile, "// Cvar      : rom_fake-players_limit ( Activat numai in cazul in care cvarul ^"rom_fake-players^" este setat pe 1 )" , newLine );
	write_file( cfgFile, "// Utilizare : Limiteaza numarul maxim de persoane de pe acelasi IP, blocand astfel atacurile tip fake-player." , newLine );
	if(exist)
	{
		formatex(line, charsmax(line), "rom_fake-players_limit ^"%d^"", getNum( PlugCvar [ fake_players_limit ] ));
		write_file( cfgFile, line , newLine );
	}
	else
		write_file( cfgFile, "rom_fake-players_limit ^"5^"" , newLine );
	write_file( cfgFile, " " , newLine );	
	
	write_file( cfgFile, "// Cvar      : rom_delete_custom_hpk" , newLine );
	write_file( cfgFile, "// Scop      : La finalul fiecarei harti, se va sterge fisierul custom.hpk." , newLine );
	write_file( cfgFile, "// Impact    : Serverul experimenteaza probleme la schimbarea hartii, aceasta putand sa dureze si pana la 60secunde." , newLine );
	write_file( cfgFile, "// Nota      : -" , newLine );
	write_file( cfgFile, "// Valoarea 0: Functie este dezactivata." , newLine );
	write_file( cfgFile, "// Valoarea 1: Fisierul este sters. [Default]" , newLine );
	if(exist)
	{
		formatex(line, charsmax(line), "rom_delete_custom_hpk ^"%d^"", getNum( PlugCvar [ delete_custom_hpk ] ));
		write_file( cfgFile, line , newLine );
	}
	else
		write_file( cfgFile, "rom_delete_custom_hpk ^"1^"" , newLine );
	write_file( cfgFile, " " , newLine );
	
	write_file( cfgFile, "// Cvar      : rom_delete_vault " , newLine );
	write_file( cfgFile, "// Scop      : La finalul fiecarei harti, se va sterge fisierul vault.ini." , newLine );
	write_file( cfgFile, "// Impact    : Serverul experimenteaza probleme la schimbarea hartii, aceasta putand sa dureze si pana la 60secunde." , newLine );
	write_file( cfgFile, "// Nota      : -" , newLine );
	write_file( cfgFile, "// Valoarea 0: Functie este dezactivata." , newLine );
	write_file( cfgFile, "// Valoarea 1: Fisierul este sters si e setat ^"server_language en^" in vault.ini. [Default]" , newLine );
	write_file( cfgFile, "// Valoarea 2: Fisierul este sters si e setat ^"server_language ro^" in vault.ini." , newLine );
	if(exist)
	{
		formatex(line, charsmax(line), "rom_delete_vault ^"%d^"", getNum( PlugCvar [ delete_vault ] ));
		write_file( cfgFile, line , newLine );
	}
	else
		write_file( cfgFile, "rom_delete_vault ^"1^"" , newLine );
	write_file( cfgFile, " " , newLine );	
	
	write_file( cfgFile, "// Cvar      : rom_advertise" , newLine );
	write_file( cfgFile, "// Efect     : Afiseaza un mesaj prin care anunta clientii ca serverul este protejat de *ROM-Protect." , newLine );
	write_file( cfgFile, "// Valoarea 0: Mesajele sunt dezactivate." , newLine );
	write_file( cfgFile, "// Valoarea 1: Mesajele sunt activate. [Default]" , newLine );
	if(exist)
	{
		formatex(line, charsmax(line), "rom_advertise ^"%d^"", getNum( PlugCvar [ advertise ] ));
		write_file( cfgFile, line , newLine );
	}
	else
		write_file( cfgFile, "rom_advertise ^"1^"" , newLine );
	write_file( cfgFile, " " , newLine );	

	write_file( cfgFile, "// Cvar      : rom_advertise_time ( Activat numai in cazul in care cvarul ^"rom_advertise^" este setat pe 1 )" , newLine );
	write_file( cfgFile, "// Utilizare : Seteaza ca mesajul sa apara o data la (cat este setat cvarul) secunda/secunde. " , newLine );
	if(exist)
	{
		formatex(line, charsmax(line), "rom_advertise_time ^"%d^"", getNum( PlugCvar [ advertise_time ] ));
		write_file( cfgFile, line , newLine );
	}
	else
		write_file( cfgFile, "rom_advertise_time ^"120^"" , newLine );
	write_file( cfgFile, " " , newLine );
	
	write_file( cfgFile, "// Cvar      : rom_warn " , newLine );
	write_file( cfgFile, "// Efect     : Afiseaza mesaje prin care anunta clientii care incearca sa distube activitatea normala a serverului. " , newLine );
	write_file( cfgFile, "// Valoarea 0: Mesajele sunt dezactivate." , newLine );
	write_file( cfgFile, "// Valoarea 1: Mesajele sunt activate. [Default]" , newLine );
	if(exist)
	{
		formatex(line, charsmax(line), "rom_warn ^"%d^"", getNum( PlugCvar [ plug_warn ] ));
		write_file( cfgFile, line , newLine );
	}
	else
		write_file( cfgFile, "rom_warn ^"1^"" , newLine );
	write_file( cfgFile, " " , newLine );
	
	write_file( cfgFile, "// Cvar  : rom_log" , newLine );
	write_file( cfgFile, "// Efect : Permite sau nu plugin-ului sa ne creeze fisiere.log." , newLine );
	write_file( cfgFile, "// Valoarea 0: Functia este dezactivata." , newLine );
	write_file( cfgFile, "// Valoarea 1: Functia este activata." , newLine );
	if(exist)
	{
		formatex(line, charsmax(line), "rom_log ^"%d^"", getNum( PlugCvar [ plug_log ] ));
		write_file( cfgFile, line , newLine );
	}
	else
		write_file( cfgFile, "rom_log ^"1^"" , newLine );
	write_file( cfgFile, " " , newLine );
	
	write_file( cfgFile, "// Cvar      : rom_admin_login" , newLine );
	write_file( cfgFile, "// Scop      : Permite autentificarea adminilor prin comanda ^"login parola^" in consola (nu necesita setinfo)" , newLine );
	write_file( cfgFile, "// Impact    : Parolele adminilor sunt foarte usor de furat in ziua de astazi, e destul doar sa intri pe un server iar parola ta dispare." , newLine );
	write_file( cfgFile, "// Nota      : Adminele se adauga normal ^"nume^" ^"parola^" ^"acces^" ^"f^"." , newLine );
	write_file( cfgFile, "// Update    : Incepand de la versiunea 1.0.3a, comanda in chat !login sau /login dispare, deoarece nu era folosita." , newLine );
	write_file( cfgFile, "// Valoarea 0: Functie este dezactivata." , newLine );
	write_file( cfgFile, "// Valoarea 1: Adminele sunt protejate. [Default]" , newLine );
	if(exist)
	{
		formatex(line, charsmax(line), "rom_admin_login ^"%d^"", getNum( PlugCvar [ admin_login ] ));
		write_file( cfgFile, line , newLine );
	}
	else
		write_file( cfgFile, "rom_admin_login ^"1^"" , newLine );
	write_file( cfgFile, " " , newLine );	
	
	write_file( cfgFile, "// Cvar  : rom_admin_login_file ( Activat numai in cazul in care cvarul ^"rom_admin_login^" este setat pe 1 )" , newLine );
	write_file( cfgFile, "// Efect : Selecteaza fisierul de unde sa fie citite adminele cu flag ^"f^"" , newLine );
	if(exist)
	{
		formatex(line, charsmax(line), "rom_admin_login_file ^"%s^"", getString( PlugCvar [ admin_login_file ] ));
		write_file( cfgFile, line , newLine );
	}
	else
		write_file( cfgFile, "rom_admin_login_file ^"users_login.ini^"" , newLine );
	write_file( cfgFile, " " , newLine );	
	
	write_file( cfgFile, "// Cvar  : rom_admin_login_debug ( Activat numai in cazul in care cvarul ^"rom_admin_login^" este setat pe 1 )" , newLine );
	write_file( cfgFile, "// Efect : In cazul in care adminele nu se incarca corect acesta va printa in consola serverului argumentele citite (nume - parola - acces - flag)" , newLine );
	write_file( cfgFile, "// Valoarea 0: Functie este dezactivata. [Default]" , newLine );
	write_file( cfgFile, "// Valoarea 1: Argumentele sunt printate in consola. " , newLine );
	if(exist)
	{
		formatex(line, charsmax(line), "rom_admin_login_debug ^"%d^"", getNum( PlugCvar [ admin_login_debug ] ));
		write_file( cfgFile, line , newLine );
	}
	else
		write_file( cfgFile, "rom_admin_login_debug ^"0^"" , newLine );
	write_file( cfgFile, " " , newLine );	
	
	write_file( cfgFile, "// Cvar      : rom_utf8-bom" , newLine );
	write_file( cfgFile, "// Scop      : Verifica fiecare fisier .res in maps, si daca descopera caractere UTF8-BOM le elimina." , newLine );
	write_file( cfgFile, "// Impact    : Serverul da crash cu eroarea : Host_Error: PF_precache_generic_I: Bad string." , newLine );
	write_file( cfgFile, "// Nota      : Eroarea apare doar la versiunile de HLDS 6***." , newLine );
	write_file( cfgFile, "// Valoarea 0: Functie este dezactivata." , newLine );
	write_file( cfgFile, "// Valoarea 1: Fisierul este decontaminat. [Default]" , newLine );
	if(exist)
	{
		formatex(line, charsmax(line), "rom_utf8-bom ^"%d^"", getNum( PlugCvar [ utf8_bom ] ));
		write_file( cfgFile, line , newLine );
	}
	else
		write_file( cfgFile, "rom_utf8-bom ^"1^"" , newLine );
	write_file( cfgFile, " " , newLine );
	
	write_file( cfgFile, "// Cvar      : rom_tag " , newLine );
	write_file( cfgFile, "// Utilizare : Seteaza tag-ul pluginului. (Numele acestuia)" , newLine );
	write_file( cfgFile, "// Nota      : Incepand de la versiunea 1.0.2s, pluginul *ROM-Protect devine mult mai primitor si te lasa chiar sa ii schimbi numele." , newLine );
	if(exist)
	{
		formatex(line, charsmax(line), "rom_tag ^"%s^"", getString( PlugCvar [ Tag ] ));
		write_file( cfgFile, line , newLine );
	}
	else
		write_file( cfgFile, "rom_tag ^"*ROM-Protect^"" , newLine );	
	write_file( cfgFile, " " , newLine );
	
	write_file( cfgFile, "// Cvar      : rom_color-bug " , newLine );
	write_file( cfgFile, "// Scop      : Urmareste chatul si opeste bugurile de tip color-bug care alerteaza playerii si adminii." , newLine );
	write_file( cfgFile, "// Impact    : Serverul nu pateste nimic, insa playerii sau adminii vor fi alertati de culorile folosite de unul din clienti." , newLine );
	write_file( cfgFile, "// Nota      : - " , newLine );
	write_file( cfgFile, "// Valoarea 0: Functia este dezactivata." , newLine );
	write_file( cfgFile, "// Valoarea 1: Bug-ul este blocat. [Default]" , newLine );
	if(exist)
	{
		formatex(line, charsmax(line), "rom_color-bug ^"%d^"", getNum( PlugCvar [ color_bug ] ));
		write_file( cfgFile, line , newLine );
	}
	else
		write_file( cfgFile, "rom_color-bug ^"1^"" , newLine );
	write_file( cfgFile, " " , newLine );
	
	write_file( cfgFile, "// Cvar      : rom_motdfile " , newLine );
	write_file( cfgFile, "// Scop      : Urmareste activitatea adminilor prin comanda amx_cvar si incearca sa opreasca modificare cvarului motdfile intr-un fisier .ini." , newLine );
	write_file( cfgFile, "// Impact    : Serverul nu pateste nimic, insa adminul care foloseste acest exploit poate fura date importante din server, precum lista de admini, lista de pluginuri etc ." , newLine );
	write_file( cfgFile, "// Nota      : Functia nu blocheaza deocamdata decat comanda amx_cvar." , newLine );
	write_file( cfgFile, "// Valoarea 0: Functia este dezactivata." , newLine );
	write_file( cfgFile, "// Valoarea 1: Bug-ul este blocat. [Default]" , newLine );
	if(exist)
	{
		formatex(line, charsmax(line), "rom_motdfile ^"%d^"", getNum( PlugCvar [ motdfile ] ));
		write_file( cfgFile, line , newLine );
	}
	else
		write_file( cfgFile, "rom_motdfile ^"1^"" , newLine );	
	write_file( cfgFile, " " , newLine );
	
	write_file( cfgFile, "// Cvar      : rom_anti-pause " , newLine );
	write_file( cfgFile, "// Scop      : Urmareste ca pluginul de protectie ^"ROM-Protect^" sa nu poata fi pus pe pauza de catre un raufacator." , newLine );
	write_file( cfgFile, "// Impact    : Serverul nu mai este protejat de plugin, acesta fiind expus la mai multe exploituri." , newLine );
	write_file( cfgFile, "// Nota      : -" , newLine );
	write_file( cfgFile, "// Valoarea 0: Functia este dezactivata." , newLine );
	write_file( cfgFile, "// Valoarea 1: Bug-ul este blocat. [Default]" , newLine );
	if(exist)
	{
		formatex(line, charsmax(line), "rom_anti-pause ^"%d^"", getNum(PlugCvar[anti_pause]) );
		write_file( cfgFile, line , newLine );
	}
	else
		write_file( cfgFile, "rom_anti-pause ^"1^"" , newLine );
	write_file( cfgFile, " " , newLine );
	
	write_file( cfgFile, "// Cvar      : rom_anti-ban-class " , newLine );
	write_file( cfgFile, "// Scop      : Urmareste activitatea comezii amx_addban, astfel incat sa nu se poata da ban pe mai multe clase ip." , newLine );
	write_file( cfgFile, "// Impact    : Serverul nu pateste nimic, insa daca se dau ban-uri pe clasa, foarte multi jucatori nu se vor mai putea conecta la server." , newLine );
	write_file( cfgFile, "// Nota      : Functia nu urmareste decat comanda amx_addban" , newLine );
	write_file( cfgFile, "// Valoarea 0: Functia este dezactivata." , newLine );
	write_file( cfgFile, "// Valoarea 1: Functia va bloca comanda daca detecteaza ban-ul pe o clasa de ip." , newLine );
	write_file( cfgFile, "// Valoarea 2: Functia va bloca comanda daca detecteaza ban-ul pe doua clase de ip. [Default]" , newLine );
	write_file( cfgFile, "// Valoarea 3: Functia va bloca comanda daca detecteaza ban-ul pe trei clase de ip." , newLine );
	write_file( cfgFile, "// Valoarea 4: Functia va bloca comanda daca detecteaza ban-ul pe toate clasele de ip." , newLine );
	if(exist)
	{
		formatex(line, charsmax(line), "rom_anti-ban-class ^"%d^"", getNum(PlugCvar[anti_ban_class]));
		write_file( cfgFile, line , newLine );
	}
	else
		write_file( cfgFile, "rom_anti-ban-class ^"2^"" , newLine );
	write_file( cfgFile, " " , newLine );
}

WriteLang( bool:exist )
	{
	new line[121];
	if (exist)
	{
		delete_file(langFile);
		const eqSize = 11;
		
		
		writeSignature(langFile);
		write_file( langFile, "[en]", newLine );
		write_file( langFile, " ", newLine );
		
		formatex(line, charsmax(line), "ROM_UPDATE_CFG = %L", LANG_SERVER, "ROM_UPDATE_CFG", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_UPDATE_CFG = %s : Am actualizat fisierul CFG : rom_protect.cfg.", newLine );
		
		formatex(line, charsmax(line), "ROM_UPDATE_LANG = %L", LANG_SERVER, "ROM_UPDATE_LANG", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_UPDATE_LANG = %s : Am actualizat fisierul LANG : rom_protect.txt.", newLine );
		
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_FAKE_PLAYERS = %L", LANG_SERVER, "ROM_FAKE_PLAYERS", "^%c", "^%s", "^%c", "^%s");
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_FAKE_PLAYERS = %c%s : %cS-a observat un numar prea mare de persoane de pe ip-ul : %s .", newLine );
			
			formatex(line, charsmax(line), "ROM_FAKE_PLAYERS_PUNISH = %L", LANG_SERVER, "ROM_FAKE_PLAYERS_PUNISH", "^%c", "^%s", "^%c");
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_FAKE_PLAYERS_PUNISH = %c%s : %cIp-ul a primit ban 30 minute pentru a nu afecta jocul.", newLine );
				
		#else
			formatex(line, charsmax(line), "ROM_FAKE_PLAYERS = %L", LANG_SERVER, "ROM_FAKE_PLAYERS", "^%s", "^%s" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_FAKE_PLAYERS = ^^3%s : ^^4S-a observat un numar prea mare de persoane de pe ip-ul : %s .", newLine );
				
			formatex(line, charsmax(line), "ROM_FAKE_PLAYERS_PUNISH = %L", LANG_SERVER, "ROM_FAKE_PLAYERS_PUNISH", "^%s");
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_FAKE_PLAYERS_PUNISH = ^^3%s : ^^4 Ip-ul a primit ban 30 minute pentru a nu afecta jocul.", newLine );
				
		#endif
		formatex(line, charsmax(line), "ROM_FAKE_PLAYERS_LOG = %L", LANG_SERVER, "ROM_FAKE_PLAYERS_LOG", "^%s", "^%s"  );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_FAKE_PLAYERS_LOG = %s : S-a depistat un atac de ^"xFake-Players^" de la IP-ul : %s .", newLine );
			
		formatex(line, charsmax(line), "ROM_FAKE_PLAYERS_DETECT = %L", LANG_SERVER, "ROM_FAKE_PLAYERS_DETECT", "^%s"  );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_FAKE_PLAYERS_DETECT = %s : Ai primit kick deoarece deoarece esti suspect de fake-client. Te rugam sa folosesti alt client.", newLine );
			
		formatex(line, charsmax(line), "ROM_FAKE_PLAYERS_DETECT_LOG = %L", LANG_SERVER, "ROM_FAKE_PLAYERS_DETECT_LOG", "^%s", "^%s", "^%s", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_FAKE_PLAYERS_DETECT_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca suspect de ^"xFake-Players^" sau ^"xSpammer^".", newLine );
			
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_PLUGIN_PAUSE = %L", LANG_SERVER, "ROM_PLUGIN_PAUSE", "^%c", "^%s", "^%c" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_PLUGIN_PAUSE = %c%s : %cNe pare rau, dar din anumite motive, acest plugin nu poate fi pus pe pauza.", newLine );
		#else
			formatex(line, charsmax(line), "ROM_PLUGIN_PAUSE = %L", LANG_SERVER, "ROM_PLUGIN_PAUSE", "^%s" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_PLUGIN_PAUSE = ^^3%s : ^^4Ne pare rau, dar din anumite motive, acest plugin nu poate fi pus pe pauza.", newLine );
		#endif
		
		formatex(line, charsmax(line), "ROM_PLUGIN_PAUSE_LOG = %L", LANG_SERVER, "ROM_PLUGIN_PAUSE_LOG", "^%s", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_PLUGIN_PAUSE_LOG = %s : S-a depistat o incercare a opririi pluginului de protectie %s. Operatiune a fost blocata.", newLine );
			
		#if AMXX_VERSION_NUM < 183 
			formatex(line, charsmax(line), "ROM_ADMIN_WRONG_NAME = %L", LANG_SERVER, "ROM_ADMIN_WRONG_NAME", "^%c", "^%s", "^%c" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_ADMIN_WRONG_NAME = %c%s : %cNu s-a gasit nici un admin care sa poarte acest nickname.", newLine );
		#else
			formatex(line, charsmax(line), "ROM_ADMIN_WRONG_NAME = %L", LANG_SERVER, "ROM_ADMIN_WRONG_NAME", "^%s" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_ADMIN_WRONG_NAME = ^^3%s : ^^4Nu s-a gasit nici un admin care sa poarte acest nickname.", newLine );
		#endif
		
		formatex(line, charsmax(line), "ROM_ADMIN_WRONG_NAME_PRINT = %L", LANG_SERVER, "ROM_ADMIN_WRONG_NAME_PRINT", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_ADMIN_WRONG_NAME_PRINT = %s : Nu s-a gasit nici un admin care sa poarte acest nickname.", newLine );
			
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_ADMIN_WRONG_PASS = %L", LANG_SERVER, "ROM_ADMIN_WRONG_PASS", "^%c", "^%s", "^%c" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_ADMIN_WRONG_PASS = %c%s : %cParola introdusa de tine este incorecta.", newLine );
		#else
			formatex(line, charsmax(line), "ROM_ADMIN_WRONG_PASS = %L", LANG_SERVER, "ROM_ADMIN_WRONG_PASS", "^%s" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_ADMIN_WRONG_PASS = ^^3%s : ^^4Parola introdusa de tine este incorecta.", newLine );
		#endif
		
		formatex(line, charsmax(line), "ROM_ADMIN_WRONG_PASS_PRINT = %L", LANG_SERVER, "ROM_ADMIN_WRONG_PASS_PRINT", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_ADMIN_WRONG_PASS_PRINT = %s : Parola introdusa de tine este incorecta.", newLine );
			
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_ADMIN_LOADED = %L", LANG_SERVER, "ROM_ADMIN_LOADED", "^%c", "^%s", "^%c" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_ADMIN_LOADED = %c%s : %cAdmin-ul tau a fost incarcat.", newLine );
		#else
			formatex(line, charsmax(line), "ROM_ADMIN_LOADED = %L", LANG_SERVER, "ROM_ADMIN_LOADED", "^%s" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_ADMIN_LOADED = ^^3%s : ^^4Admin-ul tau a fost incarcat.", newLine );
		#endif
		
		formatex(line, charsmax(line), "ROM_ADMIN_LOADED_PRINT = %L", LANG_SERVER, "ROM_ADMIN_LOADED_PRINT", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_ADMIN_LOADED_PRINT = %s : Admin-ul tau a fost incarcat.", newLine );
			
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_CMD_BUG = %L", LANG_SERVER, "ROM_CMD_BUG", "^%c", "^%s", "^%c" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_CMD_BUG = %c%s : %cS-au observat caractere interzise in textul trimis de tine. Mesajul tau a fost eliminat.", newLine );
		#else
			formatex(line, charsmax(line), "ROM_CMD_BUG = %L", LANG_SERVER, "ROM_CMD_BUG", "^%s" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_CMD_BUG = ^^3%s : ^^4S-au observat caractere interzise in textul trimis de tine. Mesajul tau a fost eliminat.", newLine );
		#endif	 
		
		formatex(line, charsmax(line), "ROM_CMD_BUG_LOG = %L", LANG_SERVER, "ROM_CMD_BUG_LOG", "^%s", "^%s", "^%s", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_CMD_BUG_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"CMD_BUG^" ca sa strice buna functionare a serverului.", newLine );
			
		formatex(line, charsmax(line), "ROM_CMD_BUG_PRINT = %L", LANG_SERVER, "ROM_CMD_BUG_PRINT", "^%s");
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_CMD_BUG_PRINT = %s : S-au observat caractere interzise in textul trimis de tine. Mesajul tau a fost eliminat.", newLine );
	
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_COLOR_BUG = %L", LANG_SERVER, "ROM_COLOR_BUG", "^%c", "^%s", "^%c" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_COLOR_BUG = %c%s : %cS-au observat caractere suspecte in textul trimis de tine. Mesajul tau a fost eliminat.", newLine );
		#else
			formatex(line, charsmax(line), "ROM_COLOR_BUG = %L", LANG_SERVER, "ROM_COLOR_BUG", "^%s" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_COLOR_BUG = ^^3%s : ^^4S-au observat caractere suspecte in textul trimis de tine. Mesajul tau a fost eliminat.", newLine );
		#endif
		
		formatex(line, charsmax(line), "ROM_COLOR_BUG_LOG = %L", LANG_SERVER, "ROM_COLOR_BUG_LOG", "^%s", "^%s", "^%s", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_COLOR_BUG_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"COLOR_BUG^" ca sa alerteze playerii sau adminii.", newLine );
			
		formatex(line, charsmax(line), "ROM_COLOR_BUG_PRINT = %L", LANG_SERVER, "ROM_COLOR_BUG_PRINT", "^%s");
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_COLOR_BUG_PRINT = %s : S-au observat caractere suspecte in textul trimis de tine. Mesajul tau a fost eliminat.", newLine );
			
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_SPEC_BUG = %L", LANG_SERVER, "ROM_SPEC_BUG", "^%c", "^%s", "^%c" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_SPEC_BUG = %c%s : %cAi facut o miscare suspecta asa ca te-am mutat la echipa precedenta.", newLine );
		#else
			formatex(line, charsmax(line), "ROM_SPEC_BUG = %L", LANG_SERVER, "ROM_SPEC_BUG", "^%s" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_SPEC_BUG = ^^3%s : ^^4Ai facut o miscare suspecta asa ca te-am mutat la echipa precedenta.", newLine );
		#endif
		
		formatex(line, charsmax(line), "ROM_SPEC_BUG_LOG = %L", LANG_SERVER, "ROM_SPEC_BUG_LOG", "^%s", "^%s", "^%s", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_SPEC_BUG_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"SPEC_BUG^" ca sa strice buna functionare a serverului.", newLine );
			
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_ADMIN_CHAT_FLOOD = %L", LANG_SERVER, "ROM_ADMIN_CHAT_FLOOD", "^%c", "^%s", "^%c" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_ADMIN_CHAT_FLOOD = %c%s : %cS-a observat un mic flood la chat primit din partea ta. Mesajele trimise de tine vor fi filtrate.", newLine );

			formatex(line, charsmax(line), "ROM_ADMIN_CHAT_FLOOD_LOG = %L", LANG_SERVER, "ROM_ADMIN_CHAT_FLOOD_LOG", "^%s", "^%s", "^%s", "^%s" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_ADMIN_CHAT_FLOOD_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"ADMIN_CHAT_FLOOD^" ca sa dea kick adminilor de pe server.", newLine );	
		#endif
		formatex(line, charsmax(line), "ROM_FILE_NOT_FOUND = %L", LANG_SERVER, "ROM_FILE_NOT_FOUND", "^%s", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_FILE_NOT_FOUND = %s : Fisierul %s nu exista.", newLine );
			
		formatex(line, charsmax(line), "ROM_ADMIN_DEBUG = %L", LANG_SERVER, "ROM_ADMIN_DEBUG", "^%s", "^%s", "^%s", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_ADMIN_DEBUG = Nume : %s - Parola : %s - Acces : %s - Flag : %s", newLine );
			
		formatex(line, charsmax(line), "ROM_MOTDFILE = %L", LANG_SERVER, "ROM_MOTDFILE", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_MOTDFILE = %s : S-a detectat o miscare suspecta din partea ta, comanda ta a fost blocata.", newLine );
			
		formatex(line, charsmax(line), "ROM_MOTDFILE_LOG = %L", LANG_SERVER, "ROM_MOTDFILE_LOG", "^%s", "^%s", "^%s", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_MOTDFILE_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca cvar-ul ^"motdfile^" ca sa fure informatii din acest server.", newLine );	
			
		#if AMXX_VERSION_NUM < 183
			formatex(line, charsmax(line), "ROM_ADVERTISE = %L", LANG_SERVER, "ROM_ADVERTISE", "^%c", "^%s", "^%c", "^%c", "^%s", "^%c", "^%c", "^%s", "^%c" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_ADVERTISE = %c%s :%c Acest server este supravegheat de pluginul de protectie %c%s%c versiunea %c%s%c .", newLine );
		#else
			formatex(line, charsmax(line), "ROM_ADVERTISE = %L", LANG_SERVER, "ROM_ADVERTISE", "^%s", "^%s", "^%s" );
			if( equal(line, "ML_NOTFOUND" , eqSize) )
				write_file( langFile, line , newLine );
			else
				write_file( langFile, "ROM_ADVERTISE = ^^3%s :^^4 Acest server este supravegheat de pluginul de protectie ^^3%s^^4 versiunea ^^3%s^^4 .", newLine );
		#endif
		
		formatex(line, charsmax(line), "ROM_ANTI_BAN_CLASS = %L", LANG_SERVER, "ROM_ANTI_BAN_CLASS", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_ANTI_BAN_CLASS = %s : S-au detectat u numar prea mare de ban-uri pe clasa de ip, comanda ta a fost blocata.", newLine );
		
		formatex(line, charsmax(line), "ROM_ANTI_ANY_BAN_CLASS_LOG = %L", LANG_SERVER, "ROM_ANTI_ANY_BAN_CLASS_LOG", "^%s", "^%s", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_ANTI_ANY_BAN_CLASS_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa dea ban pe clasa de ip.", newLine );	
		
		formatex(line, charsmax(line), "ROM_ANTI_SOME_BAN_CLASS_LOG = %L", LANG_SERVER, "ROM_ANTI_SOME_BAN_CLASS_LOG", "^%s", "^%s", "^%s", "^%s" );
		if( equal(line, "ML_NOTFOUND" , eqSize) )
			write_file( langFile, line , newLine );
		else
			write_file( langFile, "ROM_ANTI_SOME_BAN_CLASS_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa dea ban pe mai mult de %s clase de ip.", newLine );	
	}
	else
	{
		writeSignature(langFile);
		write_file( langFile, "[en]", newLine );
		write_file( langFile, " ", newLine );
		write_file( langFile, "ROM_UPDATE_CFG = %s : Am actualizat fisierul CFG : rom_protect.cfg.", newLine );
		write_file( langFile, "ROM_UPDATE_LANG = %s : Am actualizat fisierul LANG : rom_protect.txt.", newLine );
		
		#if AMXX_VERSION_NUM < 183
			write_file( langFile, "ROM_FAKE_PLAYERS = %c%s : %cS-a observat un numar prea mare de persoane de pe ip-ul : %s .", newLine );
			write_file( langFile, "ROM_FAKE_PLAYERS_PUNISH = %c%s : %cIp-ul a primit ban 30 minute pentru a nu afecta jocul.", newLine );
		#else
			write_file( langFile, "ROM_FAKE_PLAYERS = ^^3%s : ^^4S-a observat un numar prea mare de persoane de pe ip-ul : %s .", newLine );
			write_file( langFile, "ROM_FAKE_PLAYERS_PUNISH = ^^3%s : ^^4 Ip-ul a primit ban 30 minute pentru a nu afecta jocul.", newLine );
		#endif
		
		write_file( langFile, "ROM_FAKE_PLAYERS_LOG = %s : S-a depistat un atac de ^"xFake-Players^" de la IP-ul : %s .", newLine );
		write_file( langFile, "ROM_FAKE_PLAYERS_DETECT = %s : Ai primit kick deoarece deoarece esti suspect de fake-client. Te rugam sa folosesti alt client.", newLine );
		write_file( langFile, "ROM_FAKE_PLAYERS_DETECT_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca suspect de ^"xFake-Players^" sau ^"xSpammer^".", newLine );
		
		#if AMXX_VERSION_NUM < 183
			write_file( langFile, "ROM_PLUGIN_PAUSE = %c%s : %cNe pare rau, dar din anumite motive, acest plugin nu poate fi pus pe pauza.", newLine );
		#else
			write_file( langFile, "ROM_PLUGIN_PAUSE = ^^3%s : ^^4Ne pare rau, dar din anumite motive, acest plugin nu poate fi pus pe pauza.", newLine );
		#endif
		
		write_file( langFile, "ROM_PLUGIN_PAUSE_LOG = %s : S-a depistat o incercare a opririi pluginului de protectie %s. Operatiune a fost blocata.", newLine );
		
		#if AMXX_VERSION_NUM < 183 
			write_file( langFile, "ROM_ADMIN_WRONG_NAME = %c%s : %cNu s-a gasit nici un admin care sa poarte acest nickname.", newLine );
		#else
			write_file( langFile, "ROM_ADMIN_WRONG_NAME = ^^3%s : ^^4Nu s-a gasit nici un admin care sa poarte acest nickname.", newLine );
		#endif
		
		write_file( langFile, "ROM_ADMIN_WRONG_NAME_PRINT = %s : Nu s-a gasit nici un admin care sa poarte acest nickname.", newLine );
		
		#if AMXX_VERSION_NUM < 183
			write_file( langFile, "ROM_ADMIN_WRONG_PASS = %c%s : %cParola introdusa de tine este incorecta.", newLine );
		#else
			write_file( langFile, "ROM_ADMIN_WRONG_PASS = ^^3%s : ^^4Parola introdusa de tine este incorecta.", newLine );
		#endif
		
		write_file( langFile, "ROM_ADMIN_WRONG_PASS_PRINT = %s : Parola introdusa de tine este incorecta.", newLine );
		
		#if AMXX_VERSION_NUM < 183
			write_file( langFile, "ROM_ADMIN_LOADED = %c%s : %cAdmin-ul tau a fost incarcat.", newLine );
		#else
			write_file( langFile, "ROM_ADMIN_LOADED = ^^3%s : ^^4Admin-ul tau a fost incarcat.", newLine );
		#endif
		
		write_file( langFile, "ROM_ADMIN_LOADED_PRINT = %s : Admin-ul tau a fost incarcat.", newLine );
		
		#if AMXX_VERSION_NUM < 183
			write_file( langFile, "ROM_CMD_BUG = %c%s : %cS-au observat caractere interzise in textul trimis de tine. Mesajul tau a fost eliminat.", newLine );
		#else
			write_file( langFile, "ROM_CMD_BUG = ^^3%s : ^^4S-au observat caractere interzise in textul trimis de tine. Mesajul tau a fost eliminat.", newLine );
		#endif
		
		write_file(langFile, "ROM_CMD_BUG_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"CMD_BUG^" ca sa strice buna functionare a serverului.", newLine );
		write_file(langFile, "ROM_CMD_BUG_PRINT = %s : S-au observat caractere interzise in textul trimis de tine. Mesajul tau a fost eliminat.", newLine);
		
		#if AMXX_VERSION_NUM < 183
			write_file( langFile, "ROM_COLOR_BUG = %c%s : %cS-au observat caractere suspecte in textul trimis de tine. Mesajul tau a fost eliminat.", newLine );
		#else
			write_file( langFile, "ROM_COLOR_BUG = ^^3%s : ^^4S-au observat caractere suspecte in textul trimis de tine. Mesajul tau a fost eliminat.", newLine );
		#endif
		
		write_file( langFile, "ROM_COLOR_BUG_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"COLOR_BUG^" ca sa alerteze playerii sau adminii.", newLine );
		write_file(langFile, "ROM_COLOR_BUG_PRINT = %s : S-au observat caractere suspecte in textul trimis de tine. Mesajul tau a fost eliminat.", newLine);		
		
		#if AMXX_VERSION_NUM < 183
			write_file( langFile, "ROM_SPEC_BUG = %c%s : %cAi facut o miscare suspecta asa ca te-am mutat la echipa precedenta.", newLine );
		#else
			write_file( langFile, "ROM_SPEC_BUG = ^^3%s : ^^4Ai facut o miscare suspecta asa ca te-am mutat la echipa precedenta.", newLine );
		#endif
		
		write_file( langFile, "ROM_SPEC_BUG_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"SPEC_BUG^" ca sa strice buna functionare a serverului.", newLine );
		
		#if AMXX_VERSION_NUM < 183
			write_file( langFile, "ROM_ADMIN_CHAT_FLOOD = %c%s : %cS-a observat un mic flood la chat primit din partea ta. Mesajele trimise de tine vor fi filtrate.", newLine );
			write_file( langFile, "ROM_ADMIN_CHAT_FLOOD_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca ^"ADMIN_CHAT_FLOOD^" ca sa dea kick adminilor de pe server.", newLine );	
		#endif
		
		write_file( langFile, "ROM_FILE_NOT_FOUND = %s : Fisierul %s nu exista.", newLine );
		
		write_file( langFile, "ROM_ADMIN_DEBUG = Nume : %s - Parola : %s - Acces : %s - Flag : %s", newLine );
		
		write_file( langFile, "ROM_MOTDFILE = %s : S-a detectat o miscare suspecta din partea ta, comanda ta a fost blocata.", newLine );
		write_file( langFile, "ROM_MOTDFILE_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa foloseasca cvar-ul ^"motdfile^" ca sa fure informatii din acest server.", newLine );	
		
		#if AMXX_VERSION_NUM < 183
			write_file( langFile, "ROM_ADVERTISE = %c%s :%c Acest server este supravegheat de pluginul de protectie %c%s%c versiunea %c%s%c .", newLine );
		#else
			write_file( langFile, "ROM_ADVERTISE = ^^3%s :^^4 Acest server este supravegheat de pluginul de protectie ^^3%s^^4 versiunea ^^3%s^^4 .", newLine );
		#endif
		
		write_file( langFile, "ROM_ANTI_BAN_CLASS = %s : S-au detectat u numar prea mare de ban-uri pe clasa de ip, comanda ta a fost blocata.", newLine );
		write_file( langFile, "ROM_ANTI_ANY_BAN_CLASS_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa dea ban pe clasa de ip.", newLine );	
		write_file( langFile, "ROM_ANTI_SOME_BAN_CLASS_LOG = %s : L-am detectat pe ^"%s^" [ %s | %s ] ca a incercat sa dea ban pe mai mult de %s clase de ip.", newLine );	
	}
	register_dictionary("rom_protect.txt");
	IsLangUsed = true;
}

writeSignature(const file[])
{
	new line[121];
	
	write_file( file, "// *ROM-Protect" , newLine );
	write_file( file, "// Plugin FREE anti-flood/bug-fix pentru orice server." , newLine );
	formatex(line, charsmax(line), "// Versiunea %s. Bulit %d", Version, Built);
	write_file( file, line , newLine ); 
	write_file( file, "// Autor : lüxor # Dr.Fio & DR2.IND (+ eNd.) - SteamID (contact) : luxxxoor" , newLine );
	write_file( file, "// O productie FioriGinal.ro - site : www.fioriginal.ro" , newLine );
	write_file( file, "// Link forum de dezvoltare : http://forum.fioriginal.ro/amxmodx-plugins-pluginuri/rom-protect-anti-flood-bug-fix-t28292.html" , newLine );
	write_file( file, "// Link sursa : https://github.com/luxxxoor/ROM-Protect", -1);
	write_file( file, " ", newLine );
	write_file( file, " ", newLine );
	write_file( file, " ", newLine );
}

/*
*	 Contribuitori :
* SkillartzHD : -  Metoda anti-pause plugin.
*               -  Metoda anti-xfake-player si anti-xspammer.
* COOPER :      -  Idee adaugare LANG si ajutor la introducerea acesteia in plugin.
* StefaN@CSX :  -  Gasire si reparare eroare parametrii la functia anti-xFake-Players.
* eNd :         -  Ajustat cod cu o noua metoda de inregistrare a cvarurilor.
*/

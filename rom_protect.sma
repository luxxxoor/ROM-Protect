//?
#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fakemeta>

#if AMXX_VERSION_NUM < 183
	#include <ColorChat>
	#define MAX_PLAYERS 33
	#define MAX_NAME_LENGTH 32
#endif

#pragma semicolon 1

new sz_MenuText[MAX_PLAYERS][ MAX_PLAYERS],
	num[MAX_PLAYERS], cnt[MAX_PLAYERS],
	bool:flood[MAX_PLAYERS], bool:Name[MAX_PLAYERS], bool:Admin[MAX_PLAYERS], g_szFile[128], last_pass[MAX_PLAYERS][MAX_PLAYERS];

static const Version[]   = "1.0.3s",
			 Built     = 1,
			 Plugin_name[] = "ROM-Protect",
			 Terrorist[] = "#Terrorist_Select",
			 CT_Select[] = "#CT_Select",
			 cfg[] = "addons/amxmodx/configs/rom_protect.cfg",
			 lang[] = "addons/amxmodx/data/lang/rom_protect.txt";

new loginName[1024][MAX_PLAYERS], loginPass[1024][MAX_PLAYERS], loginAccs[1024][MAX_PLAYERS], loginFlag[1024][MAX_PLAYERS];
new admin_number;

enum
{
    FM_TEAM_T = 1,
    FM_TEAM_CT,
    FM_TEAM_SPECTATOR
}

#define OFFSET_TEAM  114 
#define fm_set_user_team(%1,%2)  set_pdata_int( %1, OFFSET_TEAM, %2 )
#define fm_get_user_team(%1)     get_pdata_int( %1, OFFSET_TEAM ) 

enum _:g_Cvars
{
	Tag,
	cmd_bug,
	spec_bug,
	fake_players,
	fake_players_limit,
	admin_chat_flood,
	admin_chat_flood_time,
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
	anti_pause
	
};
new g_Cvar[g_Cvars];

new Float:g_Flooding[ MAX_PLAYERS ] = {0.0, ...},
	g_Flood[ MAX_PLAYERS ] = {0, ...};

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

enum
{
	INFO_NAME,
	INFO_IP,
	INFO_AUTHID    
};

public plugin_precache( )
	{	
	RegistersPrecache();
	
	new szCurentDate[ 15 ];
	get_localinfo( "amxx_configsdir", g_szFile, charsmax ( g_szFile ) );
	format( g_szFile, charsmax ( g_szFile ), "%s/%s", g_szFile, Plugin_name );
	
	if( !dir_exists( g_szFile ) )
		{
		mkdir( g_szFile );
	}
	
	get_time( "%d-%m-%Y", szCurentDate , charsmax ( szCurentDate ) );      
	format( g_szFile, charsmax( g_szFile ), "%s/%s_%s.log", g_szFile, Plugin_name, szCurentDate );
	
	if( !file_exists( g_szFile ) )
		{
		write_file( g_szFile, "*Aici este salvata activitatea suspecta a fiecarui jucator. ", -1 );
		write_file( g_szFile, " ", -1 );
		write_file( g_szFile, " ", -1 );
	}
	/*
	get_mapname( g_szMapName, charsmax( g_szMapName ) );
	format( g_szMapName, charsmax( g_szMapName ) , "*Harta: %s|", g_szMapName );
	*/
	
	if( file_exists( cfg ) )
		server_cmd( "exec %s", cfg );
	
	set_task(30.0, "CheckCFG");
	set_task(30.0, "CheckLang");
}

public CheckCFG()
	{
	if( !file_exists(cfg) )
		WriteCFG(false);
	else
	{
		new file = fopen( cfg, "r+" );
		
		new text[ 121 ], bool:cfg_file, bool:find_search; 
		while ( !feof( file ) )
			{
			fgets( file, text, charsmax( text ) );
			
			if( containi(text, Version) != -1 )
				find_search = true;
			else
			cfg_file = true;			
		}
		if(cfg_file && !find_search)
			{
			WriteCFG( true );
			cfg_file = false;
			if( GetNum( g_Cvar[plug_log] ) == 1 )
				LogCommand( "%L",LANG_PLAYER, "ROM_Update_Cfg", GetString(g_Cvar[Tag]) );
			server_print( "%L",LANG_PLAYER, "ROM_Update_Cfg", GetString(g_Cvar[Tag]) );
		}
	}
}

public CheckLang()
	{
	if( !file_exists(lang) )
		WriteLang(false);
	else
	{
		new file = fopen( lang, "r+" );
		
		new text[ 121 ], bool:lang_file, bool:find_search; 
		while ( !feof( file ) )
			{
			fgets( file, text, charsmax(text) );
			
			if( containi(text, Version) != -1 )
				find_search = true;
			else
			lang_file = true;			
		}
		if(lang_file && !find_search)
			{
			WriteLang( true );
			lang_file = false;
			if( GetNum( g_Cvar[plug_log] ) == 1 )
				LogCommand( "%L", LANG_PLAYER, "ROM_Update_Lang", GetString(g_Cvar[Tag]) );
			server_print( "%L",LANG_PLAYER, "ROM_Update_Lang", GetString(g_Cvar[Tag]) );
		}
	}
}

public plugin_init( )
	{
	RegistersInit();
	
	if( GetNum(g_Cvar[advertise] ) == 1 )
		{
		new Float:timp = get_pcvar_float(g_Cvar[advertise_time]);
		set_task(timp, "ChatMsgShow", _, _, _, "b", 0);
	}
	
	if( GetNum( g_Cvar[ utf8_bom ] ) == 1 )
		{
		g_tDefaultRes = TrieCreate();
		TrieSetCell( g_tDefaultRes , "de_storm.res", 1); 
		TrieSetCell( g_tDefaultRes , "default.res", 1); 
		
		set_task(10.0, "CleanResFiles");
	}
	
}

public plugin_cfg( )
	{   
	g_Cvar[admin_chat_flood_time] = get_cvar_pointer( "amx_flood_time" );
	
	if( !g_Cvar[admin_chat_flood_time] )
		{
		g_Cvar[admin_chat_flood_time] = register_cvar( "rom_admin_chat_flood_time", "0.75" );
	}     
}

public client_connect( id )
	{
	new players[ MAX_PLAYERS -1 ], pnum, address[ MAX_PLAYERS -1 ], address2[ MAX_PLAYERS -1 ], name[ MAX_NAME_LENGTH ];
	get_players( players, pnum, "ch" );
	//if( !CheckName(id) )
	//      set_user_info(id, "name", "*ROM-PROTECT ~ Alt nick.")
	get_user_name( id, name, charsmax( name ) );
	if( GetNum( g_Cvar[cmd_bug] )  == 1 )
		{
		new s_name[ MAX_NAME_LENGTH ], bool:b_name[ MAX_PLAYERS ];
		copy( s_name, charsmax( name ), name );
		static j;
		for( new i; i < sizeof( s_name ); ++i )  
			{
			j = i+1;
			if( i < 31)
				if( (s_name[ i ] == '#' && isalpha(s_name[ j ])) || (s_name[ i ] == '+' && isalpha(s_name[ j ])) )
					{
					s_name[ i ] = ' ';
					b_name[ id ] = true;
				}
		}
		
		if( b_name[ id ] )
			{
			set_user_info( id, "name", s_name );
			b_name[ id ] = false;
		}
	}
	for( new i; i < pnum; ++i)
		{
		get_user_ip( id, address, charsmax( address ), 1 );
		get_user_ip( players[ i ], address2, charsmax(address2), 1 );
		if( equal( address, address2 ) && !is_user_bot( id ) )
			{
			++cnt[ id ];
			if( cnt[ id ] > GetNum( g_Cvar[fake_players_limit] ) && GetNum( g_Cvar[fake_players] ) == 1 )
				{
				server_cmd( "addip ^"30^" ^"%s^";wait;writeip", address );
				server_print( "%L", LANG_PLAYER, "ROM_Fake_Players_Log", GetString(g_Cvar[Tag]), address );
				if( GetNum( g_Cvar[plug_warn] ) == 1 )
					{
					#if AMXX_VERSION_NUM < 183
						ColorChat( 0, GREY, "%L", LANG_PLAYER, "ROM_Fake_Players", '^3', GetString(g_Cvar[Tag]), '^4' );
						ColorChat( 0, GREY, "%L", LANG_PLAYER, "ROM_Fake_Players_Punish", '^3', GetString(g_Cvar[Tag]), '^4', address );
					#else
						client_print_color( 0, print_team_grey, "%L", LANG_PLAYER, "ROM_Fake_Players", GetString(g_Cvar[Tag]) );
						client_print_color( 0, print_team_grey, "%L", LANG_PLAYER, "ROM_Fake_Players_Punish", GetString(g_Cvar[Tag]), address );
					#endif
				}
				if( GetNum( g_Cvar[plug_log] ) == 1 )
					{
					LogCommand( "%L", LANG_PLAYER, "ROM_Fake_Players_Log", GetString(g_Cvar[Tag]), address );
				}
				break;
			}
		}
	}
}      

public client_disconnect(id)
	{
	cnt[ id ] = 0;
	if( Admin[ id ] )
		{
		Admin[ id ] = false;
		remove_user_flags( id );
	}
}

public plugin_end( )
	{
	if( GetNum( g_Cvar[delete_vault] ) != 0 )
		{
		new g_baseDir[ 128 ];
		new text[ 200 ];
		get_basedir( g_baseDir,127 );
		format( g_baseDir,127, "%s/data/vault.ini", g_baseDir );
		if( file_exists( g_baseDir ) )
			{
			delete_file( g_baseDir );
			if( GetNum( g_Cvar[delete_vault] ) == 2 )
				{
				format( text, 199, "server_language ro", g_baseDir);
				write_file( g_baseDir, text , -1 );
			}
			if( GetNum( g_Cvar[delete_vault] ) == 1 )
				{
				format( text, 199, "server_language en", g_baseDir );
				write_file( g_baseDir, text, -1) ;
			}
		}
	}
	if( GetNum( g_Cvar[delete_custom_hpk] ) == 1 )
		{
		new szDir[] = "/", DirPointer, szFile[ 32 ];
		
		DirPointer = open_dir( szDir, "", 0 );
		
		while( next_file( DirPointer, szFile, charsmax (szFile) ) )
			{
			if(szFile[ 0 ] == '.')
				continue;
			
			if( containi( szFile, "custom.hpk" ) != -1 )
				{
				delete_file( szFile );
				break;
			}
		}
		close_dir( DirPointer );
	}
	return PLUGIN_CONTINUE;
}


public client_infochanged( id )
	{
	if ( !is_user_connected( id ) )
		{
		return PLUGIN_CONTINUE;
	}
	new newname[ MAX_NAME_LENGTH ], oldname[ MAX_NAME_LENGTH ];
	get_user_name( id, oldname, charsmax( oldname ) );
	get_user_info( id, "name", newname, charsmax( newname ));
	
	if( GetNum( g_Cvar[cmd_bug] ) == 1 )
		{
		new s_name[ MAX_NAME_LENGTH ], bool:b_name[ MAX_PLAYERS ];
		copy( s_name, charsmax( newname ), newname );
		static j;
		for( new i; i < sizeof( s_name ); ++i )  
			{
			j = i+1;
			if( i < 31)
				{
				if ( (s_name[ i ] == '#' && isalpha(s_name[ j ])) || (s_name[ i ] == '+' && isalpha(s_name[ j ])) )
					{
					s_name[ i ] = ' ';
					b_name[ id ] = true;
				}
			}
		}
		
		if( b_name[ id ] )
			{
			set_user_info( id, "name", s_name );
			b_name[ id ] = false;
		}
	}
	
	if ( !equal( newname, oldname ) && Admin[ id ] )
		{
		Admin[ id ] = false;
		remove_user_flags( id );
	}
	
	return PLUGIN_CONTINUE;
}

public plugin_pause()
{
	if ( GetNum(g_Cvar[anti_pause]) == 1 )
	{
		server_print("%L", LANG_PLAYER, "ROM_Plugin_Pause_Log", GetString(g_Cvar[Tag]) );
		if ( GetNum(g_Cvar[plug_warn]) == 1)
			{
			#if AMXX_VERSION_NUM < 183
				ColorChat( 0, GREY, "%L", LANG_PLAYER, "ROM_Plugin_Pause", '^3', GetString(g_Cvar[Tag]), '^4' );
			#else
				client_print_color( 0, print_team_grey, "%L", LANG_PLAYER, "ROM_Plugin_Pause", GetString(g_Cvar[Tag]) );
			#endif
		}
		if( GetNum(g_Cvar[plug_log]) == 1)
				LogCommand( "%L", LANG_PLAYER, "ROM_Plugin_Pause_Log", GetString(g_Cvar[Tag]), GetString(g_Cvar[Tag]) );
		server_cmd("amxx unpause rom_protect.amxx");
	}
}

public CmdPass( id )
	{
	if( GetNum( g_Cvar[admin_login] ) == 0)
		return PLUGIN_HANDLED;
	new name[ MAX_NAME_LENGTH ], pass[ 32 ];
	get_user_name( id, name, charsmax( name ) );
	read_argv( 1, pass, charsmax( pass ) );
	remove_quotes( pass );
	
	LoadAdminLogin( );
	GetAccess( id, pass );
	
	if(!Admin[ id ])
		{
		if(!Name[ id ])
			{
			#if AMXX_VERSION_NUM < 183
				ColorChat( id, GREY, "%L", LANG_PLAYER, "ROM_Admin_Wrong_Name", '^3', GetString(g_Cvar[Tag]), '^4');
			#else
				client_print_color( id, print_team_grey, "%L", LANG_PLAYER, "ROM_Admin_Wrong_Name", GetString(g_Cvar[Tag]) );
			#endif
			client_print( id, print_console, "%s : %L", GetString(g_Cvar[Tag]), LANG_PLAYER, "ROM_Admin_Wrong_Name_Print" );
		}
		else
		{
			#if AMXX_VERSION_NUM < 183
				ColorChat( id, GREY, "%L", LANG_PLAYER, "ROM_Admin_Wrong_Pass", '^3', GetString(g_Cvar[Tag]), '^4');
			#else
				client_print_color( id, print_team_grey, "%L", LANG_PLAYER, "ROM_Admin_Wrong_Pass", GetString(g_Cvar[Tag]) );
			#endif
			client_print( id, print_console, "%L", GetString(g_Cvar[Tag]), LANG_PLAYER, "ROM_Admin_Wrong_Pass_Print" );
		}
	}
	else
	{
		#if AMXX_VERSION_NUM < 183
			ColorChat( id, GREY, "%L", LANG_PLAYER, "ROM_Admin_Loaded", '^3', GetString(g_Cvar[Tag]), '^4');
		#else
			client_print_color( id, print_team_grey, "%L", LANG_PLAYER, "ROM_Admin_Loaded", GetString(g_Cvar[Tag]) );
		#endif
		client_print( id, print_console, "%L", GetString(g_Cvar[Tag]), LANG_PLAYER, "ROM_Admin_Loaded_Print" );
	}
	
	return PLUGIN_CONTINUE;
}

public HookChat(id)
	{
	new said[ 192 ];
	read_args( said, charsmax( said ) );
	
	if( GetNum( g_Cvar[color_bug] )  == 1 || GetNum( g_Cvar[cmd_bug] ) == 1 )
		{
		new s_said[ 192 ], bool:b_said_cmd_bug[ MAX_PLAYERS ], bool:b_said_color_bug[ MAX_PLAYERS ];
		copy( s_said, charsmax( said ), said );
		static j;
		for( new i = 0; i < sizeof( s_said ); ++i )
			{
			j = i+1;
			if( GetNum( g_Cvar[cmd_bug] ) == 1 )
				if( s_said[ i ] == '#' && isalpha(s_said[ j ]) || s_said[ i ] == '%' && s_said[ j ] == 's' )
				{
				b_said_cmd_bug[ id ] = true;
				break;
			}
			if( GetNum( g_Cvar[color_bug] ) == 1)
				{
				if ( s_said[i] == '' || s_said[i] == '' || s_said[i] == '' )
					{
					b_said_color_bug[ id ] = true;
					break;
				}
			}
		}
		
		if(b_said_cmd_bug[ id ])
			{
			server_print("%L", LANG_PLAYER, "ROM_Cmd_Bug_Log", GetString(g_Cvar[Tag]), GetInfo( id, INFO_NAME ), GetInfo( id, INFO_AUTHID ), GetInfo( id, INFO_IP ));
			if( GetNum(g_Cvar[plug_warn]) == 1)
				{
				#if AMXX_VERSION_NUM < 183
					ColorChat( id, GREY, "%L", LANG_PLAYER, "ROM_Cmd_Bug", '^3', GetString(g_Cvar[Tag]), '^4');
				#else
					client_print_color( id, print_team_grey, "%L", LANG_PLAYER, "ROM_Cmd_Bug", GetString(g_Cvar[Tag]) );
				#endif
			}
			if( GetNum(g_Cvar[plug_log]) == 1)
				LogCommand("%L", LANG_PLAYER, "ROM_Cmd_Bug_Log", GetString(g_Cvar[Tag]), GetInfo( id, INFO_NAME ), GetInfo( id, INFO_AUTHID ), GetInfo( id, INFO_IP ));
			b_said_cmd_bug[ id ] = false;
			return PLUGIN_HANDLED;
		}
		if(b_said_color_bug[ id ])
			{
			server_print("%L", LANG_PLAYER, "ROM_Color_Bug_Log", GetString(g_Cvar[Tag]), GetInfo( id, INFO_NAME ), GetInfo( id, INFO_AUTHID ), GetInfo( id, INFO_IP ));
			if( GetNum(g_Cvar[plug_warn]) == 1)
				{
				#if AMXX_VERSION_NUM < 183
					ColorChat( id, GREY, "%L", LANG_PLAYER, "ROM_Color_Bug", '^3', GetString(g_Cvar[Tag]), '^4');
				#else
					client_print_color( id, print_team_grey, "%L", LANG_PLAYER, "ROM_Color_Bug", GetString(g_Cvar[Tag]) );
				#endif
			}
			if( GetNum(g_Cvar[plug_log]) == 1)
				LogCommand("%L", LANG_PLAYER, "ROM_Color_Bug_Log", GetString(g_Cvar[Tag]), GetInfo( id, INFO_NAME ), GetInfo( id, INFO_AUTHID ), GetInfo( id, INFO_IP ));
			b_said_color_bug[ id ] = false;
			return PLUGIN_HANDLED;
		}
	}
	
	new g_said[ 2 ];
	read_argv( 1, g_said, charsmax(g_said) );
	
	if (g_said[0] != '@')
		return PLUGIN_CONTINUE;
	
	new Float:maxChat = get_pcvar_float( g_Cvar[admin_chat_flood_time] );
	
	if ( maxChat && GetNum( g_Cvar[admin_chat_flood] ) == 1 )
		{
		new Float:nexTime = get_gametime( );
		
		if ( g_Flooding[ id ] > nexTime )
			{
			if  (g_Flood[ id ] >= 3 )
				{
				flood[ id ] = true;
				set_task( 1.0, "ShowProtection", id );
				g_Flooding[ id ] = nexTime + maxChat + 3.0;
				return PLUGIN_HANDLED;
			}
			++g_Flood[ id ];
		}
		else
		{
			if ( g_Flood[ id ] )
				{
				--g_Flood[id];
			}
		}
		g_Flooding[ id ] = nexTime + maxChat;
	}
	
	return PLUGIN_CONTINUE;
}

public OldStyleMenusTeammenu( msg, des, rec )
	{
	if( is_user_connected( rec ) )
		{
		get_msg_arg_string ( 4, sz_MenuText[ rec ], charsmax ( sz_MenuText ) );
		if( equal( sz_MenuText[rec], Terrorist ) || equal( sz_MenuText[rec], CT_Select ))
			{
			set_task( 0.1, "BlockSpecbugOldStyleMenus", rec );
		}
	}
}

public VGuiTeammenu( msg, des, rec )  
	{  
	if(get_msg_arg_int( 1 ) == 26 || get_msg_arg_int( 1 ) == 27 )
		{
		num[ rec ] = get_msg_arg_int( 1 );
		set_task( 0.1, "BlockSpecbugVGui", rec );
	}
}

public CheckLong( c_szCommand[ ],c_dwLen )
	{
	new m_szCommand[ 512 ];
	while( strlen( m_szCommand ) )
		{
		strtok( c_szCommand, m_szCommand, charsmax( m_szCommand ), c_szCommand, c_dwLen , ' ', 1 );
		if( strlen( m_szCommand ) > 31 )
			return true;
	}
	return false;
}

public BlockSpecbugOldStyleMenus( id )
	{
	if( !is_user_alive( id ) && is_user_connected( id ) && GetNum( g_Cvar[spec_bug] ) == 1 )
		{
		if( fm_get_user_team( id ) == FM_TEAM_SPECTATOR && !is_user_alive(id) )
			{
			if( equal( sz_MenuText[id], Terrorist ) && is_user_connected( id ) )
				{
				fm_set_user_team( id, FM_TEAM_T );
			}
			if( equal( sz_MenuText[id], CT_Select ) && is_user_connected( id ) )
				{
				fm_set_user_team( id, FM_TEAM_CT );
			}
			server_print("%L", LANG_PLAYER, "ROM_Spec_Bug_Log", GetString(g_Cvar[Tag]), GetInfo( id, INFO_NAME ), GetInfo( id, INFO_AUTHID ), GetInfo( id, INFO_IP ));
			if( GetNum( g_Cvar[plug_warn] ) )
				{
				#if AMXX_VERSION_NUM < 183
					ColorChat( id, GREY, "%L", LANG_PLAYER, "ROM_Spec_Bug", '^3', GetString(g_Cvar[Tag]), '^4');
				#else
					client_print_color( id, print_team_grey, "%L", LANG_PLAYER, "ROM_Spec_Bug", GetString(g_Cvar[Tag]) );
				#endif
			}
			if( GetNum( g_Cvar[plug_log] ))
				LogCommand("%L", LANG_PLAYER, "ROM_Spec_Bug_Log", GetString(g_Cvar[Tag]), GetInfo( id, INFO_NAME ), GetInfo( id, INFO_AUTHID ), GetInfo( id, INFO_IP ));
		}
		set_task( 0.1, "BlockSpecbugOldStyleMenus", id );
	}
}

public BlockSpecbugVGui( id )
	{
	new bool:bug_log[MAX_PLAYERS] = false;
	if( !is_user_alive( id ) && is_user_connected( id ) && GetNum( g_Cvar[spec_bug] ) == 1 )
		{
		if(fm_get_user_team( id ) == FM_TEAM_SPECTATOR )
			{
			if(num[ id ] == 26 )
				{
				fm_set_user_team(id, FM_TEAM_T );
				bug_log[id] = true;
			}      
			if(num[ id ] == 27 )
				{
				fm_set_user_team(id, FM_TEAM_CT );
				bug_log[id] = true;
			}      
			server_print("%L", LANG_PLAYER, "ROM_Spec_Bug_Log", GetString(g_Cvar[Tag]), GetInfo( id, INFO_NAME ), GetInfo( id, INFO_AUTHID ), GetInfo( id, INFO_IP ));
			if( GetNum( g_Cvar[plug_warn] ) == 1 && bug_log[id])
				{
				#if AMXX_VERSION_NUM < 183
					ColorChat( id, GREY, "%L", LANG_PLAYER, "ROM_Spec_Bug", '^3', GetString(g_Cvar[Tag]), '^4');
				#else
					client_print_color( id, print_team_grey, "%L", LANG_PLAYER, "ROM_Spec_Bug", GetString(g_Cvar[Tag]) );
				#endif
			}
			if( GetNum( g_Cvar[plug_log] ) == 1 && bug_log[id])
				{
				LogCommand("%L", LANG_PLAYER, "ROM_Spec_Bug_Log", GetString(g_Cvar[Tag]), GetInfo( id, INFO_NAME ), GetInfo( id, INFO_AUTHID ), GetInfo( id, INFO_IP ));
				bug_log[id] = false;
			}
		}
		set_task( 0.1, "BlockSpecbugVGui", id );    
	}
}

public ShowProtection( id )
	{
	if( flood[ id ] )
		{
		server_print("%L", LANG_PLAYER, "ROM_Admin_Chat_Flood_Log", GetString(g_Cvar[Tag]), GetInfo( id, INFO_NAME ), GetInfo( id, INFO_AUTHID ), GetInfo( id, INFO_IP ));
		if( GetNum( g_Cvar[plug_warn] ) == 1 )
			{
			#if AMXX_VERSION_NUM < 183
				ColorChat( id, GREY, "%L", LANG_PLAYER, "ROM_Admin_Chat_Flood", '^3', GetString(g_Cvar[Tag]), '^4');
			#else
				client_print_color( id, print_team_grey, "%L", LANG_PLAYER, "ROM_Admin_Chat_Flood", GetString(g_Cvar[Tag]) );
			#endif
		}
		if( GetNum( g_Cvar[plug_log] ) == 1 )
			LogCommand( "%L", LANG_PLAYER, "ROM_Admin_Chat_Flood_Log", GetString(g_Cvar[Tag]), GetInfo( id, INFO_NAME ), GetInfo( id, INFO_AUTHID ), GetInfo( id, INFO_IP ));
		flood[ id ] = false;
		
	}
}

public ChatMsgShow( id )
	{
	#if AMXX_VERSION_NUM < 183
		ColorChat( id, GREY, "^3%s :^4 Acest server este protejat de ^3%s^4 versiunea ^3%s^4 .", GetString(g_Cvar[Tag]), Plugin_name, Version );
	#else
		client_print_color( id, print_team_grey, "^3%s :^4 Acest server este protejat de ^3%s^4 versiunea ^3%s^4 .", GetString(g_Cvar[Tag]), Plugin_name, Version );
	#endif
}

public CleanResFiles() 
	{ 
	new szMapsFolder[] = "maps"; 
	new const szResExt[] = ".res"; 
	new szResFile[64], iLen; 
	new dp = open_dir(szMapsFolder, szResFile, charsmax(szResFile)); 
	
	if( !dp ) 
		{ 
		return; 
	} 
	
	new szFullPathFileName[128]; 
	do 
	{ 
		iLen = strlen(szResFile);
		if( iLen > 4 && equali(szResFile[iLen-4], szResExt) ) 
			{ 
			if( TrieKeyExists(g_tDefaultRes, szResFile) ) 
				{ 
				continue;
			} 
			
			formatex(szFullPathFileName, charsmax(szFullPathFileName), "%s/%s", szMapsFolder, szResFile); 
			write_file(szFullPathFileName, "/////////////////////////////////////////////////////////////^n", 0); 
		} 
	} 
	while( next_file(dp, szResFile, charsmax(szResFile)) );
	
	close_dir(dp);
} 

LoadAdminLogin( )
{
	new path[ 64 ];
	get_localinfo( "amxx_configsdir", path, charsmax( path ) );
	format( path, charsmax(path), "%s/%s", path, GetString( g_Cvar [ admin_login_file ] ) );
	
	new file = fopen( path, "r+" );
	
	if ( !file )
		{
		server_print("%L",LANG_PLAYER, "ROM_File_Not_Found", GetString(g_Cvar[Tag]), GetString(g_Cvar[admin_login_file]) );
		if( GetNum( g_Cvar[plug_log] ) == 1 )
			LogCommand( "%L",LANG_PLAYER, "ROM_File_Not_Found", GetString(g_Cvar[Tag]), GetString(g_Cvar[admin_login_file]) );
		return;
	}
	
	new text[ 121 ], name[ MAX_NAME_LENGTH ], pass[ 32 ], acc[ 26 ], flags[ 6 ];
	for ( admin_number = 0; !feof( file ); ++admin_number )
		{
		fgets( file, text, charsmax( text ) );
		
		trim( text );
		
		if( ( text[ 0 ] == ';' ) || !strlen( text ) || ( text[ 0 ] == '/' ) )
			{
			continue;
		}
		
		if( parse( text, name, charsmax( name ), pass, charsmax( pass ), acc, charsmax( acc ), flags, charsmax( flags ) ) != 4 )
			{
			continue;
		}
		
		copy( loginName[ admin_number ], charsmax( loginName[ ] ),  name );
		copy( loginPass[ admin_number ], charsmax( loginPass[ ] ),  pass );
		copy( loginAccs[ admin_number ], charsmax( loginAccs[ ] ),  acc );
		copy( loginFlag[ admin_number ], charsmax( loginFlag[ ] ),  flags );
		
		if( GetNum( g_Cvar[admin_login_debug] ) == 1 )
			server_print( "%L", LANG_PLAYER, "ROM_Admin_Debug", loginName[ admin_number ], loginPass[ admin_number ], loginAccs[ admin_number ], loginFlag[ admin_number ] );              
	}
	fclose( file );
}

GetAccess( const id, const userPass[] )
{
	static userName[ MAX_NAME_LENGTH ], acces;
	get_user_info( id, "name", userName, charsmax( userName ) );
	if( !(get_user_flags( id ) & ADMIN_CHAT ) )
		remove_user_flags( id );
	copy(last_pass[id], charsmax(last_pass[ ]), userPass);
	for( new i = 1; i <= admin_number; ++i )
		{
		if(  equali( loginName[ i ], userName ) )
			Name[ id ] = true;
		else
			Name[ id ] = false;
		if( equal( loginFlag[ i ], "f" ) && Name[ id ] )
			{
			if( equal( loginPass[ i ], userPass ) || Admin[ id ] )
				{
				Admin[ id ] = true;
				acces = read_flags( loginAccs[ i ] );
				set_user_flags( id, acces );
			}
			break;
		}
	}
}


public ReloadLogin(id, level, cid) 
	set_task(1.0, "reloadDelay");

public reloadDelay()
	{
	new players[ MAX_PLAYERS -1 ], pnum;
	get_players( players, pnum, "ch" );
	for( new i; i < pnum; ++i )
		if( Admin[i] )
		GetAccess(i, last_pass[i]);
}

public CvarFunc(id, level, cid) 
	{ 
	if( GetNum( g_Cvar[ motdfile ] ) == 1 )
		{
		new arg[32], arg2[32]; 
		
		read_argv(1, arg, charsmax(arg));
		read_argv(2, arg2, charsmax(arg2));
		
		if( equali(arg, "motdfile") && contain(arg2, ".ini") != -1 ) 
			{
			server_print("%L", LANG_PLAYER, "ROM_Motdfile_Log", GetString(g_Cvar[Tag]), GetInfo( id, INFO_NAME ), GetInfo( id, INFO_AUTHID ), GetInfo( id, INFO_IP ));
			console_print(id, "%s: %L", GetString(g_Cvar[Tag]), LANG_PLAYER, "ROM_Motdfile");
			if( GetNum( g_Cvar[plug_log] ) == 1 )
				LogCommand( "%L", LANG_PLAYER, "ROM_Motdfile_Log", GetString(g_Cvar[Tag]), GetInfo( id, INFO_NAME ), GetInfo( id, INFO_AUTHID ), GetInfo( id, INFO_IP ) );
			return PLUGIN_HANDLED; 
		}
	} 
	
	return PLUGIN_CONTINUE; 
}

LogCommand( const szMsg[ ], any:... )
{
	new szMessage[ 256 ], szLogMessage[ 256 ];
	vformat( szMessage, charsmax( szMessage ), szMsg , 2 );
	
	formatex( szLogMessage, charsmax( szLogMessage ), "L %s%s", GetTime( ), szMessage );
	
	write_file( g_szFile, szLogMessage, -1 );
}

GetInfo( id, const iInfo )
	{
	new szInfoToReturn[ 64 ];
	
	switch( iInfo )
	{
		case INFO_NAME:
		{
			static szName[ 32 ];
			get_user_name( id, szName, charsmax( szName ) );
			
			copy( szInfoToReturn, charsmax( szInfoToReturn ), szName );
		}
		case INFO_IP:
		{
			static szIp[ 32 ];
			get_user_ip( id, szIp, charsmax( szIp ), 1 );
			
			copy( szInfoToReturn, charsmax( szInfoToReturn ), szIp );
		}
		case INFO_AUTHID:
		{
			static szAuthId[ 35 ];
			get_user_authid( id, szAuthId, charsmax( szAuthId ) );
			
			copy( szInfoToReturn, charsmax( szInfoToReturn ), szAuthId );
		}
	}
	return szInfoToReturn;
}

GetTime( )
	{
	static szTime[ 32 ];
	get_time( " %H:%M:%S ", szTime ,charsmax( szTime ) );
	
	return szTime;
}

GetString( text )
	{
	static File[32]; 
	get_pcvar_string( text, File, charsmax( File ) );
	
	return File;
}

GetNum( text )
	{
	static num;
	num = get_pcvar_num(text);
	return num;
}

RegistersPrecache()
{
	g_Cvar[Tag]                   = register_cvar("rom_tag", "*ROM-Protect");
	g_Cvar[spec_bug]              = register_cvar("rom_spec-bug", "1");
	g_Cvar[admin_chat_flood]      = register_cvar("rom_admin_chat_flood", "1");
	g_Cvar[fake_players]          = register_cvar("rom_fake-players", "1");
	g_Cvar[fake_players_limit]    = register_cvar("rom_fake-players_limit", "3");
	g_Cvar[delete_custom_hpk]     = register_cvar("rom_delete_custom_hpk", "1");
	g_Cvar[delete_vault]          = register_cvar("rom_delete_vault", "1");
	g_Cvar[cmd_bug]               = register_cvar("rom_cmd-bug", "1");
	g_Cvar[advertise]             = register_cvar("rom_advertise","1");
	g_Cvar[advertise_time]        = register_cvar("rom_advertise_time", "120");
	g_Cvar[plug_warn]             = register_cvar("rom_warn", "1");
	g_Cvar[plug_log]              = register_cvar("rom_log", "1");
	g_Cvar[color_bug]             = register_cvar("rom_color-bug", "1");
	g_Cvar[admin_login]           = register_cvar("rom_admin_login", "1");
	g_Cvar[admin_login_file]      = register_cvar("rom_admin_login_file", "users_login.ini");
	g_Cvar[admin_login_debug]     = register_cvar("rom_admin_login_debug", "0");
	g_Cvar[utf8_bom]              = register_cvar("rom_utf8-bom", "1");
	g_Cvar[motdfile]              = register_cvar("rom_motdfile", "1");
	g_Cvar[anti_pause]            = register_cvar("rom_anti-pause", "1");
}

RegistersInit()
{
	register_plugin( Plugin_name, Version, "FioriGinal.Ro" );
	register_cvar("rom_protect", Version, FCVAR_SERVER | FCVAR_SPONLY);
	
	register_message(get_user_msgid( "ShowMenu" ), "OldStyleMenusTeammenu");
	register_message(get_user_msgid( "VGUIMenu" ), "VGuiTeammenu");
	
	register_clcmd("say", "HookChat");
	register_clcmd("say_team", "HookChat");
	register_clcmd("login", "CmdPass" );
	register_concmd("amx_cvar", "CvarFunc");
	register_concmd("amx_reloadadmins", "ReloadLogin");
	// Registering Language file by COOPER
	register_dictionary("rom_protect.txt");
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

WriteCFG( bool:exist )
	{
	if(exist)
		delete_file( cfg );
	new line[121];
	write_file( cfg, "// *ROM-Protect" , -1 );
	write_file( cfg, "// Plugin FREE anti-flood/bug-fix pentru orice server." , -1 );
	formatex(line, charsmax(line), "// Versiunea %s Bulit %d", Version, Built);
	write_file( cfg, line , -1 ); 
	write_file( cfg, "// Autor : lüxor # Dr.Fio & DR2.IND (+ eNd.) - SteamID (contact) : luxxxoor" , -1 );
	write_file( cfg, "// O productie FioriGinal.ro - site : www.fioriginal.ro" , -1 );
	write_file( cfg, "// Link forum de dezvoltare : http://forum.fioriginal.ro/amxmodx-plugins-pluginuri/rom-protect-anti-flood-bug-fix-t28292.html" , -1 );
	write_file( cfg, "// Link sursa : https://github.com/luxxxoor/ROM-Protect", -1);
	write_file( cfg, " " , -1 );
	write_file( cfg, " " , -1 );
	write_file( cfg, " " , -1 );
	write_file( cfg, "// Verificare daca CFG-ul a fost executat cu succes." , -1 );
	write_file( cfg, "echo ^"*ROM-Protect : Fisierul rom_protect.cfg a fost gasit. Incep protejarea serverului.^"" , -1 );
	write_file( cfg, "// Cvar      : rom_cmd-bug" , -1 );
	write_file( cfg, "// Scop      : Urmareste chatul si opeste bugurile de tip ^"%s^"/^"%s0^" care dau pluginurile peste cap." , -1 );
	write_file( cfg, "// Impact    : Serverul nu pateste nimic, insa playerii acestuia primesc ^"quit^" indiferent de ce client folosesc, iar serverul ramane gol." , -1 );
	write_file( cfg, "// Update    : Incepand cu versiunea 1.0.1s, pluginul protejeaza serverele si de noul cmd-bug bazat pe caracterul '#'. Pluginul blocheaza de acum '#' si '%' in chat si '#' in nume." , -1 );
	write_file( cfg, "// Update    : Incepand cu versiunea 1.0.3a, pluginul devine mai inteligent, si va bloca doar posibilele folosiri ale acestui bug, astfel incat caracterele '#' si '%' vor putea fi folosite, insa nu in toate cazurile." , -1 );
	write_file( cfg, "// Update    : Incepand cu versiunea 1.0.3s, pluginul incearca sa inlature bugul provotat de caracterul '+' in nume, acesta incercand sa deruteze playerii sau adminii (nu aparea numele jucatorului in meniuri)." , -1 );
	write_file( cfg, "// Valoarea 0: Functia este dezactivata." , -1 );
	write_file( cfg, "// Valoarea 1: Atacul este blocat. [Default]" , -1 );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_cmd-bug ^"%d^"", GetNum( g_Cvar[ cmd_bug ] ));
		write_file( cfg, line , -1 );
	}
	else
	write_file( cfg, "rom_cmd-bug ^"1^"" , -1 );
	write_file( cfg, " " , -1 );
	write_file( cfg, "// Cvar      : rom_spec-bug" , -1 );
	write_file( cfg, "// Scop      : Urmareste activitatea playerilor si opreste schimbarea echipei, pentru a opri specbug." , -1 );
	write_file( cfg, "// Impact    : Serverul primeste crash in momentul in care se apeleaza la acest bug." , -1 );
	write_file( cfg, "// Nota      : -" , -1 );
	write_file( cfg, "// Valoarea 0: Functia este dezactivata." , -1 );
	write_file( cfg, "// Valoarea 1: Atacul este blocat. [Default]" , -1 );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_spec-bug ^"%d^"", GetNum( g_Cvar [ spec_bug ] ));
		write_file( cfg, line , -1 );
	}
	else
	write_file( cfg, "rom_spec-bug ^"1^"" , -1 );
	write_file( cfg, " " , -1 );
	write_file( cfg, "// Cvar      : rom_admin_chat_flood" , -1 );
	write_file( cfg, "// Scop      : Urmareste activitatea playerilor care folosesc chat-ul adminilor, daca persoanele incearca sa floodeze acest chat sunt opriti fortat." , -1 );
	write_file( cfg, "// Impact    : Serverul nu pateste nimic, insa adminii primesc kick cu motivul : ^"reliable channel overflowed^"." , -1 );
	write_file( cfg, "// Nota      : -" , -1 );
	write_file( cfg, "// Valoarea 0: Functia este dezactivata." , -1 );
	write_file( cfg, "// Valoarea 1: Atacul este blocat. [Default]" , -1 );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_admin_chat_flood ^"%d^"", GetNum( g_Cvar [ admin_chat_flood ] ));
		write_file( cfg, line , -1 );
	}
	else
	write_file( cfg, "rom_admin_chat_flood ^"1^"" , -1 );
	write_file( cfg, "" , -1 );
	write_file( cfg, "// Cvar      : rom_fake-players" , -1 );
	write_file( cfg, "// Scop      : Urmareste persoanele conectate pe server si baneaza atunci cand numarul persoanelor cu acelasi ip il depaseste pe cel setat in cvarul rom_fake-players_limit." , -1 );
	write_file( cfg, "// Impact    : Serverul experimenteaza lag peste 200+ la orice jucator prezent pe server, cateodata chiar crash." , -1 );
	write_file( cfg, "// Nota      : Daca sunt mai multe persoane care impart aceasi legatura de internet pot fi banate ( 0 minute ), in acest caz ridicati cvarul : rom_fake-players_limit sau opriti rom_fake-players." , -1 );
	write_file( cfg, "// Valoarea 0: Functia este dezactivata." , -1 );
	write_file( cfg, "// Valoarea 1: Atacul este blocat prin ban 30 minute. [Default]" , -1 );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_fake-players ^"%d^"", GetNum( g_Cvar [ fake_players ] ));
		write_file( cfg, line , -1 );
	}
	else
	write_file( cfg, "rom_fake-players ^"1^"" , -1 );
	write_file( cfg, " " , -1 );
	write_file( cfg, "// Cvar      : rom_fake-players_limit ( Activat numai in cazul in care cvarul ^"rom_fake-players^" este setat pe 1 )" , -1 );
	write_file( cfg, "// Utilizare : Limiteaza numarul maxim de persoane de pe acelasi IP, blocand astfel atacurile tip fake-player." , -1 );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_fake-players_limit ^"%d^"", GetNum( g_Cvar [ fake_players_limit ] ));
		write_file( cfg, line , -1 );
	}
	else
	write_file( cfg, "rom_fake-players_limit ^"1^"" , -1 );
	write_file( cfg, " " , -1 );
	write_file( cfg, "// Cvar      : rom_delete_custom_hpk" , -1 );
	write_file( cfg, "// Scop      : La finalul fiecarei harti, se va sterge fisierul custom.hpk." , -1 );
	write_file( cfg, "// Impact    : Serverul experimenteaza probleme la schimbarea hartii, aceasta putand sa dureze si pana la 60secunde." , -1 );
	write_file( cfg, "// Nota      : -" , -1 );
	write_file( cfg, "// Valoarea 0: Functie este dezactivata." , -1 );
	write_file( cfg, "// Valoarea 1: Fisierul este sters. [Default]" , -1 );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_delete_custom_hpk ^"%d^"", GetNum( g_Cvar [ delete_custom_hpk ] ));
		write_file( cfg, line , -1 );
	}
	else
	write_file( cfg, "rom_delete_custom_hpk ^"1^"" , -1 );
	write_file( cfg, " " , -1 );
	write_file( cfg, "// Cvar      : rom_delete_vault " , -1 );
	write_file( cfg, "// Scop      : La finalul fiecarei harti, se va sterge fisierul vault.ini." , -1 );
	write_file( cfg, "// Impact    : Serverul experimenteaza probleme la schimbarea hartii, aceasta putand sa dureze si pana la 60secunde." , -1 );
	write_file( cfg, "// Nota      : -" , -1 );
	write_file( cfg, "// Valoarea 0: Functie este dezactivata." , -1 );
	write_file( cfg, "// Valoarea 1: Fisierul este sters si e setat ^"server_language en^" in vault.ini. [Default]" , -1 );
	write_file( cfg, "// Valoarea 2: Fisierul este sters si e setat ^"server_language ro^" in vault.ini." , -1 );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_delete_vault ^"%d^"", GetNum( g_Cvar [ delete_vault ] ));
		write_file( cfg, line , -1 );
	}
	else
	write_file( cfg, "rom_delete_vault ^"1^"" , -1 );
	write_file( cfg, " " , -1 );
	write_file( cfg, "// Cvar      : rom_advertise" , -1 );
	write_file( cfg, "// Efect     : Afiseaza un mesaj prin care anunta clientii ca serverul este protejat de *ROM-Protect." , -1 );
	write_file( cfg, "// Valoarea 0: Mesajele sunt dezactivate." , -1 );
	write_file( cfg, "// Valoarea 1: Mesajele sunt activate. [Default]" , -1 );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_advertise ^"%d^"", GetNum( g_Cvar [ advertise ] ));
		write_file( cfg, line , -1 );
	}
	else
	write_file( cfg, "rom_advertise ^"1^"" , -1 );
	write_file( cfg, " " , -1 );
	write_file( cfg, "// Cvar      : rom_advertise_time ( Activat numai in cazul in care cvarul ^"rom_advertise^" este setat pe 1 )" , -1 );
	write_file( cfg, "// Utilizare : Seteaza ca mesajul sa apara o data la (cat este setat cvarul) secunda/secunde. " , -1 );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_advertise_time ^"%d^"", GetNum( g_Cvar [ advertise_time ] ));
		write_file( cfg, line , -1 );
	}
	else
	write_file( cfg, "rom_advertise_time ^"120^"" , -1 );
	write_file( cfg, " " , -1 );
	write_file( cfg, "// Cvar      : rom_warn " , -1 );
	write_file( cfg, "// Efect     : Afiseaza mesaje prin care anunta clientii care incearca sa distube activitatea normala a serverului. " , -1 );
	write_file( cfg, "// Valoarea 0: Mesajele sunt dezactivate." , -1 );
	write_file( cfg, "// Valoarea 1: Mesajele sunt activate. [Default]" , -1 );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_warn ^"%d^"", GetNum( g_Cvar [ plug_warn ] ));
		write_file( cfg, line , -1 );
	}
	else
	write_file( cfg, "rom_warn ^"1^"" , -1 );
	write_file( cfg, " " , -1 );
	write_file( cfg, "// Cvar  : rom_log" , -1 );
	write_file( cfg, "// Efect : Permite sau nu plugin-ului sa ne creeze fisiere.log." , -1 );
	write_file( cfg, "// Valoarea 0: Functia este dezactivata." , -1 );
	write_file( cfg, "// Valoarea 1: Functia este activata." , -1 );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_log ^"%d^"", GetNum( g_Cvar [ plug_log ] ));
		write_file( cfg, line , -1 );
	}
	else
	write_file( cfg, "rom_log ^"1^"" , -1 );
	write_file( cfg, " " , -1 );
	write_file( cfg, "// Cvar      : rom_admin_login" , -1 );
	write_file( cfg, "// Scop      : Permite autentificarea adminilor prin comanda ^"login parola^" in consola (nu necesita setinfo)" , -1 );
	write_file( cfg, "// Impact    : Parolele adminilor sunt foarte usor de furat in ziua de astazi, e destul doar sa intri pe un server iar parola ta dispare." , -1 );
	write_file( cfg, "// Nota      : Adminele se adauga normal ^"nume^" ^"parola^" ^"acces^" ^"f^"." , -1 );
	write_file( cfg, "// Update    : Incepand de la versiunea 1.0.3a, comanda in chat !login sau /login dispare, deoarece nu era folosita." , -1 );
	write_file( cfg, "// Valoarea 0: Functie este dezactivata." , -1 );
	write_file( cfg, "// Valoarea 1: Adminele sunt protejate. [Default]" , -1 );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_admin_login ^"%d^"", GetNum( g_Cvar [ admin_login ] ));
		write_file( cfg, line , -1 );
	}
	else
	write_file( cfg, "rom_admin_login ^"1^"" , -1 );
	write_file( cfg, " " , -1 );
	write_file( cfg, "// Cvar  : rom_admin_login_file ( Activat numai in cazul in care cvarul ^"rom_admin_login^" este setat pe 1 )" , -1 );
	write_file( cfg, "// Efect : Selecteaza fisierul de unde sa fie citite adminele cu flag ^"f^"" , -1 );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_admin_login_file ^"%s^"", GetString( g_Cvar [ admin_login_file ] ));
		write_file( cfg, line , -1 );
	}
	else
	write_file( cfg, "rom_admin_login_file ^"users_login.ini^"" , -1 );
	write_file( cfg, " " , -1 );
	write_file( cfg, "// Cvar  : rom_admin_login_debug ( Activat numai in cazul in care cvarul ^"rom_admin_login^" este setat pe 1 )" , -1 );
	write_file( cfg, "// Efect : In cazul in care adminele nu se incarca corect acesta va printa in consola serverului argumentele citite (nume - parola - acces - flag)" , -1 );
	write_file( cfg, "// Valoarea 0: Functie este dezactivata. [Default]" , -1 );
	write_file( cfg, "// Valoarea 1: Argumentele sunt printate in consola. " , -1 );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_admin_login_debug ^"%d^"", GetNum( g_Cvar [ admin_login_debug ] ));
		write_file( cfg, line , -1 );
	}
	else
	write_file( cfg, "rom_admin_login_debug ^"0^"" , -1 );
	write_file( cfg, " " , -1 );
	write_file( cfg, "// Cvar      : rom_utf8-bom" , -1 );
	write_file( cfg, "// Scop      : Verifica fiecare fisier .res in maps, si daca descopera caractere UTF8-BOM le elimina." , -1 );
	write_file( cfg, "// Impact    : Serverul da crash cu eroarea : Host_Error: PF_precache_generic_I: Bad string." , -1 );
	write_file( cfg, "// Nota      : Eroarea apare doar la versiunile de HLDS 6***." , -1 );
	write_file( cfg, "// Valoarea 0: Functie este dezactivata." , -1 );
	write_file( cfg, "// Valoarea 1: Fisierul este decontaminat. [Default]" , -1 );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_utf8-bom ^"%d^"", GetNum( g_Cvar [ utf8_bom ] ));
		write_file( cfg, line , -1 );
	}
	else
	write_file( cfg, "rom_utf8-bom ^"1^"" , -1 );
	write_file( cfg, " " , -1 );
	write_file( cfg, "// Cvar      : rom_tag " , -1 );
	write_file( cfg, "// Utilizare : Seteaza tag-ul pluginului. (Numele acestuia)" , -1 );
	write_file( cfg, "// Nota      : Incepand de la versiunea 1.0.2s, pluginul *ROM-Protect devine mult mai primitor si te lasa chiar sa ii schimbi numele." , -1 );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_tag ^"%s^"", GetString( g_Cvar [ Tag ] ));
		write_file( cfg, line , -1 );
	}
	else
	write_file( cfg, "rom_tag ^"*ROM-Protect^"" , -1 );
	write_file( cfg, " " , -1 );
	write_file( cfg, "// Cvar      : rom_color-bug " , -1 );
	write_file( cfg, "// Scop      : Urmareste chatul si opeste bugurile de tip color-bug care alerteaza playerii si adminii." , -1 );
	write_file( cfg, "// Impact    : Serverul nu pateste nimic, insa playerii sau adminii vor fi alertati de culorile folosite de unul din clienti." , -1 );
	write_file( cfg, "// Nota      : - " , -1 );
	write_file( cfg, "// Valoarea 0: Functia este dezactivata." , -1 );
	write_file( cfg, "// Valoarea 1: Bug-ul este blocat. [Default]" , -1 );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_color-bug ^"%d^"", GetNum( g_Cvar [ color_bug ] ));
		write_file( cfg, line , -1 );
	}
	else
	write_file( cfg, "rom_color-bug ^"1^"" , -1 );
	write_file( cfg, " " , -1 );
	write_file( cfg, "// Cvar      : rom_motdfile " , -1 );
	write_file( cfg, "// Scop      : Urmareste activitatea adminilor prin comanda amx_cvar si incearca sa opreasca modificare cvarului motdfile intr-un fisier .ini." , -1 );
	write_file( cfg, "// Impact    : Serverul nu pateste nimic, insa adminul care foloseste acest exploit poate fura date importante din server, precum lista de admini, lista de pluginuri etc ." , -1 );
	write_file( cfg, "// Nota      : Functia nu blocheaza deocamdata decat comanda amx_cvar." , -1 );
	write_file( cfg, "// Valoarea 0: Functia este dezactivata." , -1 );
	write_file( cfg, "// Valoarea 1: Bug-ul este blocat. [Default]" , -1 );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_motdfile ^"%d^"", GetNum( g_Cvar [ motdfile ] ));
		write_file( cfg, line , -1 );
	}
	else
	write_file( cfg, "rom_motdfile ^"1^"" , -1 );
	write_file( cfg, " " , -1 );
	write_file( cfg, "// Cvar      : rom_anti-pause " , -1 );
	write_file( cfg, "// Scop      : Urmareste ca pluginul de protectie ^"ROM-Protect^" sa nu poata fi pus pe pauza de catre un raufacator." , -1 );
	write_file( cfg, "// Impact    : Serverul nu mai este protejat de plugin, acesta fiind expus la mai multe exploituri." , -1 );
	write_file( cfg, "// Nota      : -" , -1 );
	write_file( cfg, "// Valoarea 0: Functia este dezactivata." , -1 );
	write_file( cfg, "// Valoarea 1: Bug-ul este blocat. [Default]" , -1 );
	if(exist)
		{
		formatex(line, charsmax(line), "rom_anti-pause ^"%d^"", GetNum(g_Cvar[anti_pause]) );
		write_file( cfg, line , -1 );
	}
	else
	write_file( cfg, "rom_anti-pause ^"1^"" , -1 );
	write_file( cfg, " " , -1 );
}

WriteLang( bool:exist )
	{
	if(exist)
		delete_file( lang );
	new line[121];
	write_file( lang, "// *ROM-Protect" , -1 );
	write_file( lang, "// Plugin FREE anti-flood/bug-fix pentru orice server." , -1 );
	formatex(line, charsmax(line), "// Versiunea %s Bulit %d", Version, Built);
	write_file( lang, line , -1 ); 
	write_file( lang, "// Autor : lüxor # Dr.Fio & DR2.IND (+ eNd.) - SteamID (contact) : luxxxoor" , -1 );
	write_file( lang, "// O productie FioriGinal.ro - site : www.fioriginal.ro" , -1 );
	write_file( lang, "// Link forum de dezvoltare : http://forum.fioriginal.ro/amxmodx-plugins-pluginuri/rom-protect-anti-flood-bug-fix-t28292.html" , -1 );
	write_file( lang, "// Link sursa : https://github.com/luxxxoor/ROM-Protect", -1);
	write_file( lang, " ", -1 );
	write_file( lang, " ", -1 );
	write_file( lang, " ", -1 );
	write_file( lang, "[en]", -1);
	write_file( lang, " ", -1 );
	write_file( lang, "ROM_Update_Cfg = %s : Am actualizat fisierul configurator : rom_protect.cfg.", -1 );
	write_file( lang, "ROM_Update_Lang = %s : Am actualizat fisierul LANG : rom_protect.txt.", -1 );
	#if AMXX_VERSION_NUM < 183
		write_file( lang, "ROM_Fake_Players = %c%s :%cS-a observat un atac de Fake-Players. Tentativa blocata.", -1 );
		write_file( lang, "ROM_Fake_Players_Punish = %c%s :%cAtac identificat cu IP : %s. IP banat 30 minute.", -1 );
	#else
		write_file( lang, "ROM_Fake_Players = ^3%s :^4S-a observat un atac de Fake-Players. Tentativa blocata.", -1 );
		write_file( lang, "ROM_Fake_Players_Punish = ^3%s :^4Atac identificat cu IP : %s. IP banat 30 minute.", -1 );
	#endif
	write_file( lang, "ROM_Fake_Players_Log = %s : Atac blocat de ^"Fake-Players^" de la IP : %s .", -1 );
	#if AMXX_VERSION_NUM < 183
		write_file( lang, "ROM_Plugin_Pause = %c%s :%cS-a depistat o incercare a opririi pluginului de protectie. Operatiune oprita.", -1 );
	#else
		write_file( lang, "ROM_Plugin_Pause = ^3%s :^4S-a depistat o incercare a opririi pluginului de protectie. Operatiune oprita.", -1 );
	#endif
		write_file( lang, "ROM_Plugin_Pause_Log = %s : S-a depistat o incercare a opririi pluginului de protectie %s. Operatiune oprita.", -1 );
	#if AMXX_VERSION_NUM < 183 ROM_Admin_Wrong_Name_Print
		write_file( lang, "ROM_Admin_Wrong_Name = %c%s :%cNume incorect.", -1 );
	#else
		write_file( lang, "ROM_Admin_Wrong_Name = ^3%s :^4Nume incorect.", -1 );
	#endif
	write_file( lang, "ROM_Admin_Wrong_Name_Print = %s :Nume incorect.", -1 );
	#if AMXX_VERSION_NUM < 183
		write_file( lang, "ROM_Admin_Wrong_Pass = %c%s :%cParola incorecta.", -1 );
	#else
		write_file( lang, "ROM_Admin_Wrong_Pass = ^3%s :^4Parola incorecta.", -1 );
	#endif
	write_file( lang, "ROM_Admin_Wrong_Pass_Print = %s :Nume incorect.", -1 );
	#if AMXX_VERSION_NUM < 183
		write_file( lang, "ROM_Admin_Loaded = %c%s :%cAdmin incarcat.", -1 );
	#else
		write_file( lang, "ROM_Admin_Loaded = ^3%s :^4Admin incarcat.", -1 );
	#endif
	write_file( lang, "ROM_Admin_Loaded_Print = %s :Admin incarcat.", -1 );
	#if AMXX_VERSION_NUM < 183
		write_file( lang, "ROM_Cmd_Bug = %c%s :%cAi incercat sa creezi CMD_BUG. Tentativa blocata.", -1 );
	#else
		write_file( lang, "ROM_Cmd_Bug = ^3%s :^4Ai incercat sa creezi CMD_BUG. Tentativa blocata.", -1 );
	#endif	
	write_file( lang, "ROM_Cmd_Bug_Log = %s : %s [ %s | %s ] a incercat sa foloseasca ^"CMD_BUG^" ca sa strice buna functionare a serverului.", -1 );
	#if AMXX_VERSION_NUM < 183
		write_file( lang, "ROM_Color_Bug = %c%s :%cAi incercat sa creezi COLOR_BUG. Tentativa blocata.", -1 );
	#else
		write_file( lang, "ROM_Color_Bug = ^3%s :^4Ai incercat sa creezi COLOR_BUG. Tentativa blocata.", -1 );
	#endif
	write_file( lang, "ROM_Color_Bug_Log = %s : %s [ %s | %s ] a incercat sa foloseasca ^"COLOR_BUG^" ca sa alerteze playerii sau adminii.", -1 );
	#if AMXX_VERSION_NUM < 183
		write_file( lang, "ROM_Spec_Bug = %c%s :%cAi incercat sa creezi SPEC_BUG. Tentativa blocata.", -1 );
	#else
		write_file( lang, "ROM_Spec_Bug = ^3%s :^4Ai incercat sa creezi SPEC_BUG. Tentativa blocata.", -1 );
	#endif
	write_file( lang, "ROM_Spec_Bug_Log = %s : %s [ %s | %s ] a incercat sa foloseasca ^"SPEC_BUG^" ca sa strice buna functionare a serverului.", -1 );
	#if AMXX_VERSION_NUM < 183
		write_file( lang, "ROM_Admin_Chat_Flood = %c%s :%cAi incercat sa creezi ADMIN_CHAT_FLOOD. Tentativa blocata.", -1 );
	#else
		write_file( lang, "ROM_Admin_Chat_Flood = ^3%s :^4Ai incercat sa creezi ADMIN_CHAT_FLOOD. Tentativa blocata.", -1 );
	#endif
	write_file( lang, "ROM_Admin_Chat_Flood_Log = %s : %s [ %s | %s ] a incercat sa foloseasca ^"ADMIN_CHAT_FLOOD^" ca sa strice buna functionare a serverului.", -1 );	
	write_file( lang, "ROM_File_Not_Found = %s : Fisierul %s nu exista.", -1 );	
	write_file( lang, "ROM_Admin_Debug = Nume : %s - Parola : %s - Acces : %s - Flag : %s", -1 );
	#if AMXX_VERSION_NUM < 183
		write_file( lang, "ROM_Motdfile = %c%s :%cAi incercat sa furi informatii din acest server, comanda ta a fost blocata.", -1 );	
	#else
		write_file( lang, "ROM_Motdfile = ^3%s :^4Ai incercat sa furi informatii din acest server, comanda ta a fost blocata.", -1 );
	#endif
	write_file( lang, "ROM_Motdfile_Log = %s : %s [ %s | %s ] a incercat sa foloseasca cvarul motdfile ca sa fure informatii din acest server.", -1 );	
}

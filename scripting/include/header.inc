// From float header :

#pragma rational Float


// From amxconst header :

#define MAX_PLAYERS          32

#define MAX_NAME_LENGTH      32

#define LANG_SERVER          0

#define LANG_PLAYER          -1

#define ADMIN_USER           (1<<25)

#define PLUGIN_CONTINUE      0  

#define PLUGIN_HANDLED       1 

#define ADMIN_CHAT           (1<<8)

#if ROM_PROTECT_AMXX == 183
	enum
	{
		print_team_default = 0,
		print_team_grey = -1,
		print_team_red = -2,
		print_team_blue = -3,
	};
#endif

enum
{
	print_notify = 1,
	print_console,
	print_chat,
	print_center,
	print_radio     /* Counter-Strike only */
};


// From string hearder :

#define charsmax(%1) (sizeof(%1)-1)

native format(output[], len, const format[], any:...);

native formatex(output[], len, const format[], any:...);

native contain(const source[], const string[]);

native containi(const source[],const string[]);

native equal(const a[],const b[],c=0);

native equali(const a[],const b[],c=0);

native strlen(const string[]);

native copy(dest[],len,const src[]);

stock split(const szInput[], szLeft[], pL_Max, szRight[], pR_Max, const szDelim[])
{
	new iEnd = contain(szInput, szDelim);
	new iStart = iEnd + strlen(szDelim);

	//If delimiter isnt in Input just split the string at max lengths
	if (iEnd == -1)
	{
		iStart = copy(szLeft, pL_Max, szInput);
		copy(szRight, pR_Max, szInput[iStart]);
		return;
	}

	//If delimter is in Input then split at input for max lengths
	if (pL_Max >= iEnd)
		copy(szLeft, iEnd, szInput);
	else
		copy(szLeft, pL_Max, szInput);

	copy(szRight, pR_Max, szInput[iStart]);

	return;
}

native num_to_str(num,string[],len);

native isalpha(ch);

native trim(text[]);

native parse(const text[], ... );

native str_to_num(const string[]);

native Float:str_to_float(const string[]);

native vformat(buffer[], len, const fmt[], vararg);


// From file header :

native write_file(const file[],const text[],line = -1);

native file_exists(const file[]);

native dir_exists(const dir[]);

native mkdir(const dirname[]);

native fopen(const filename[],const mode[]);

native feof(file);

native fgets(file, buffer[], maxlength);

native unlink(const filename[]);

native open_dir(dir[], firstfile[], length);

native next_file(dirh, buffer[], length);

native delete_file(const file[]);

native close_dir(dirh);

native fclose(file);


// From lang header :

native register_dictionary(const filename[]);


// From messages header :

native get_msg_arg_string(argn, szReturn[], iLength);

native get_msg_arg_int(argn);

native is_user_alive(index);

native register_message(iMsgId, const szFunction[]);

native message_begin(dest, msg_type, const origin[3] = {0,0,0}, player = 0);

native write_byte(x);

native write_string(const x[]);

native message_end();


// From message_const header :

#if ROM_PROTECT_AMXX < 183
	#define	MSG_ONE                     1 
	
	#define	MSG_ALL                     2 

#endif


// From celltrie header :

native Trie:TrieCreate();

native TrieSetCell(Trie:handle, const key[], any:value, bool:replace = true);

native bool:TrieKeyExists(Trie:handle, const key[]);


// From cvars header :
	
#define FCVAR_NONE           0
	
native register_cvar(const name[], const string[], flags = FCVAR_NONE, Float:fvalue=0.0);
	
native query_client_cvar(id, const cvar[], const resultFunc[], paramlen=0, const params[]="");
	
native get_pcvar_num(pcvar);

native Float:get_pcvar_float(pcvar);

native get_pcvar_string(pcvar, string[], maxlen);

#define FCVAR_SERVER         4
#define FCVAR_SPONLY         64

// From amxmodx header :

native get_localinfo(const info[], output[], len);

native get_time(const format[], output[], len);

native get_mapname(name[], len);

native server_cmd(const command[], any:...);

native server_print(const message[], any:...);

native client_print(index, type, const message[], any:...);

#if ROM_PROTECT_AMXX == 183
	native client_print_color(index, sender, const message[], any:...);
#endif

native set_task(Float:time, const function[], id=0, const any:parameter[]="", len=0, const flags[]="", repeat=0);

native get_user_name(index, name[], len);

native set_user_info(index, const info[], const value[]);

native get_user_info(index, const info[], output[], len);

native get_players(players[MAX_PLAYERS], &num, const flags[]="", const team[]="");

native is_user_bot(index);

native get_user_ip(index, ip[], len, without_port=0);

native set_user_flags(index, flags=-1, id=0);

native get_user_flags(index, id=0);

native remove_user_flags(index, flags=-1, id=0);

native is_user_connected(index);

native read_argv(id, output[], len);

native read_args(output[], len);

native remove_quotes(text[]);

native console_print(id, const message[], any:...);

native get_user_userid(index);

native read_flags(const flags[]);

native get_user_authid(index, authid[], len);

native register_plugin(const plugin_name[], const version[], const author[]);

native register_concmd(const cmd[], const function[], flags=-1, const info[]="", FlagManager=-1);

native register_clcmd(const client_cmd[], const function[], flags=-1, const info[]="", FlagManager=-1);

native get_user_msgid(const name[]);

#if ROM_PROTECT_AMXX <= 183
native get_maxplayers();

native get_user_team(index, team[]="", len=0);

native Float:get_gametime();
#endif


// From amxmisc header :

stock is_user_admin(id)
{
	new __flags=get_user_flags(id);
	return (__flags>0 && !(__flags&ADMIN_USER));
}

stock get_basedir(name[],len)
{
	return get_localinfo("amxx_basedir",name,len);
}

stock get_configsdir(name[],len)
{
	return get_localinfo("amxx_configsdir",name,len);
}


// From fakemeta header :

native get_pdata_int(_index, _Offset, _linuxdiff = 5, _macdiff = 5);

native set_pdata_int(_index, _Offset, _Value, _linuxdiff = 5, _macdiff = 5);

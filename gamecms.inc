#if !defined MAX_PLAYERS
	#define MAX_PLAYERS	32
#endif

stock SiteUrl[33]; //example: http://site.com


enum _:AdminInfo
{
	AdminId,
	AdminAuthId[33],
	AdminPassword[33],
	AdminServiceFlags[33],
	AdminType[5],
	AdminExpired[32],
	AdminReason[33],
	AdminActive,
	AdminServiceId,
	AdminServiceName[33],
	AdminServiceTime
};

/*
	��������� ������ ��������� ������
	
	@id - id ������
	@Data - ������ � ������� ��������� ������
		Data[0] - ���������� "�������"
		Data[1] - ���������� ������� �� ������
		Data[2] - ������� �� ������
		Data[3] - ���������� ����� ������ ���������
*/
native get_forum_data (id, Data[4], String[], Len)


/*
	��������� ���� ��������� ������
	
	@id - id ������
	@szDate - ���� ��������� ����� ������ � ������� ����-��-��
*/
native days_left_info (id, szDate[], iLen)


/*
	���������� ������� ���������� ������
	
	@id - id ������
	@szReason - ������� ���������� ������
*/
native check_admin_active (id, szReason[], iLen)


/*
	������������������ ����� 0/1
	
	@id - id ������
*/
native is_registered_user (id)


/*
	��������� ���������� � ������� �������� ������������������� ������
	
	@id - id ������
*/
native Float:get_user_shilings (id)


/*
	��������� ������� �������� ������������������� ������
	
	@id - id ������
	@Float:iData - ����� �������� �������
*/
native Float:set_user_shilings (id, Float:iData)


/*
	����������� ��� ������ ������������������� ������
	
	@id - id ������
*/
forward registered_user_connected(id)


/*
	����������� ��� ������ ������������������� ����������
	
	@id - id ������
	const szLogin[] - ��� ������ �� �����
	const SITE_URL[] - ����� ����� (���� "cms_url") ��� ������ ���������������� Motd
*/
forward birthday_boy_connect(id, const szLogin[], const SITE_URL[])


/*
	����������� ��� ������������� ��
	
	Handle:sqlTuple - ������������ ������ � ���������� � ��
*/
forward init_database(Handle:sqlTuple)


/*
	����������� ��� ��������� ������������� ��.
	����� ����������, ������ ���������������.
*/
forward api_error()


/*
	��������� ������ ���� ��������� �� ������� �������
	
	@Array:handle - ���������� ������� � �������
*/
native Array:get_alladmins_data ()


/*
	��������� ������ ���������������� �������
	
	@Trie:handle - ���������� ������� � �������
*/
native Trie:get_admin_data ()


/*
	��������� ������ � ���� ��������� ���. �������
	
	@Array:handle - ���������� ������� � �������
*/
native Array:get_purchased_services()


/*
	��������� ������ � ��������� ���. ������� ������
	
	@szAuth[] - steamID ������
	@Array:handle - ���������� ������� � �������
*/
native Array:get_user_services(szAuth[], len)


/*
	��������� �������� � ��� �� ��
	
	@id - id ������
	prefix[] - ������� ������ � ����
	type - ��� ��������:
	1- ������ �������
	2- ������� ������ (�����, ��� � �.�.)
*/
forward set_user_prefix(id, prefix[], type)


/*
	����� �����, ����������� ������� �� ���� �������� �������
	
	@index - ������ ������
*/
native get_user_gametime (index)


/*
	��������� ������ �� ID ������
	
	@aID - ID �������������� � �� �����
	@Trie:handle - ���������� ������� � �������
*/
native Trie:get_admin_info(aID)


/*
	��������� ID ������
	
	@index - ������ ������
*/
native get_AdminID (index)


/*
	��������� �������������� �������� ������� � �� �����
*/
native get_serverID ()

/*
	����������� ��� ������ ������ ������ (����������� ������)
	
	@id - id ������
	const szName[] - ��� ������
	adminID - ID ������ � �� �����
	Flags - Bitflag value- �������� ������
*/
forward admin_connect(id, const szName[], adminID, Flags)


stock get_id_key(index)
{
	new id_key[6]
	num_to_str(index, id_key, charsmax(id_key))
	
	return id_key
}


stock mysql_escape_string(string[],len)
{
	replace_all(string, len, "&#039;", "'")
	replace_all(string, len, "&lt;", "<")
	replace_all(string, len, "&gt;", ">")
	replace_all(string, len, "&quot;", "^"")	//"
	replace_all(string, len, "&amp;", "&")
}

stock mysql_insert_string(string[],len)
{
	replace_all(string, len, "'", "&#039;")
	replace_all(string, len, "<", "&lt;")
	replace_all(string, len, ">", "&gt;")
	replace_all(string, len, "^"", "&quot;")	//"
	replace_all(string, len, "&", "&amp;")
}

stock SQL_Error(const error[], errornum, failstate)
{
	switch(failstate)
	{
		case TQUERY_CONNECT_FAILED:
		{
			log_amx("[Error] ������ ��� ����������: %s (%d)", error, errornum);
			return 1;
		}
			
		case TQUERY_QUERY_FAILED:
		{
			log_amx("[Error] ������ ��� �������: %s (%d)", error, errornum);
			return 1;
		}	 
	}
	
	return 0
}

stock ExplodeString(Output[][], Max, Size, Input[], Delimiter)
{
    new Idx, l = strlen(Input), Len
    do Len += (1 + copyc( Output[Idx], Size, Input[Len], Delimiter))
    while( (Len < l) && (++Idx < Max))
    return Idx
}
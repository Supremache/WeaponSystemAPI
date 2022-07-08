#include <amxmodx>
#include <amxmisc>
#include <cromchat>
#include <reapi>

#define SETTING_RESOURCES "WeaponAPI.ini"

const MAX_HANDLE_LENGTH = 32;
const MAX_FILE_LENGTH = 512;

enum ( += 1 )
{
	WEAPON_INVALID = -1,
	WEAPON_AVAILABLE,
	WEAPON_UNAVAILABLE,
	WEAPON_DONT_SHOW
}

enum
{
	SECTION_PRIMARY,
	SECTION_SECONDARY,
	MAX_SECTION
	
} new g_iMenuSection[ MAX_PLAYERS + 1 ], g_iMenuPages[ MAX_PLAYERS + 1 ][ MAX_SECTION ], g_iMenuItems[ MAX_PLAYERS + 1 ][ 10 ], g_iMenuTimer[MAX_PLAYERS + 1];

enum _:WeaponData
{
	Weapon_Section,
	Weapon_Handle[ MAX_HANDLE_LENGTH ],
	Weapon_Reference[ MAX_HANDLE_LENGTH ],
	Weapon_Name[ MAX_NAME_LENGTH ],
	Weapon_RealName[ MAX_NAME_LENGTH ],
	Weapon_ViewModel[ MAX_RESOURCE_PATH_LENGTH ],
	Weapon_PlayerModel[ MAX_RESOURCE_PATH_LENGTH ],
	Weapon_WorldModel[ MAX_RESOURCE_PATH_LENGTH ],
	Weapon_Level,
	Weapon_AdminFlags,
	Weapon_VIPFlags
	
}; new Array:g_aWeapons, eWeapons[WeaponData], g_iDefaultWeapons[MAX_SECTION] = { -1, ... }, g_szWeaponText[MAX_NAME_LENGTH], bool:g_bWeaponsGiven[MAX_PLAYERS + 1];

enum _:WeaponForwards
{
	Weapon_Result,
	Weapon_Select_Pre,
	Weapon_Select_Post
	
}; new g_iForward[ WeaponForwards ];

enum _:WeaponCvars
{
	Weapon_BuyTime,
	Weapon_He,
	Weapon_Smoke,
	Weapon_Flash
	
}; new g_iWeaponCvar[ WeaponCvars ];

new g_iSelectWeapon[ MAX_PLAYERS + 1 ][ MAX_SECTION ],
	bool:g_bAutoSelect[ MAX_PLAYERS + 1 ],
	g_iTotalWeapons;

public plugin_precache( ) 
{
	register_plugin( "Weapons System API", "1.0", "Supremache" );
	register_cvar("WeaponsSystemAPI", "1.0", FCVAR_SERVER | FCVAR_SPONLY | FCVAR_UNLOGGED );
	
	g_aWeapons = ArrayCreate( WeaponData );
	DefineDefaultWeapon( );
}

DefineDefaultWeapon( )
{
	DefineWeapon( SECTION_SECONDARY, "weapon_glock18", "", "Glock 18C" );
	DefineWeapon( SECTION_SECONDARY, "weapon_usp", "", "USP .45 ACP Tactical" );
	DefineWeapon( SECTION_SECONDARY, "weapon_p228", "", "P228 Compact" );
	g_iDefaultWeapons[ SECTION_SECONDARY ] = DefineWeapon( SECTION_SECONDARY, "weapon_deagle", "", "Desert Eagle .50 AE" );
	DefineWeapon( SECTION_SECONDARY, "weapon_elite", "", "Dual Elite Berettas" );
	DefineWeapon( SECTION_SECONDARY, "weapon_fiveseven", "", "FiveseveN" );

	DefineWeapon( SECTION_PRIMARY, "weapon_galil", "", "IMI Galil" );
	DefineWeapon( SECTION_PRIMARY, "weapon_famas", "", "Famas" );
	DefineWeapon( SECTION_PRIMARY, "weapon_ak47", "", "AK-47 Kalashnikov" );
	g_iDefaultWeapons[ SECTION_PRIMARY ] = DefineWeapon( SECTION_PRIMARY, "weapon_m4a1", "", "M4A1 Carbine" );
	DefineWeapon( SECTION_PRIMARY, "weapon_sg552", "", "SG-552 Commando" );
	DefineWeapon( SECTION_PRIMARY, "weapon_aug", "", "Steyr AUG A1" );
	DefineWeapon( SECTION_PRIMARY, "weapon_scout", "", "Schmidt Scout" );
	
	DefineWeapon( SECTION_PRIMARY, "weapon_m3", "", "M3 Super 90" );
	DefineWeapon( SECTION_PRIMARY, "weapon_xm1014", "", "XM1014 M4" );

	DefineWeapon( SECTION_PRIMARY, "weapon_mac10", "", "Ingram MAC-10" );
	DefineWeapon( SECTION_PRIMARY, "weapon_tmp", "", "Schmidt TMP" );
	DefineWeapon( SECTION_PRIMARY, "weapon_mp5navy", "", "MP5 Navy" );
	DefineWeapon( SECTION_PRIMARY, "weapon_ump45", "", "UMP 45" );
	DefineWeapon( SECTION_PRIMARY, "weapon_p90", "", "ES P90" );
}

public plugin_init( )
{
	CC_SetPrefix( "^4[WeaponSystem]" );
	register_dictionary( "WeaponSystem.txt" );
	
	RegisterHookChain( RG_CWeaponBox_SetModel, "@CWeaponBoxSetModel" );
	RegisterHookChain( RG_CBasePlayerWeapon_DefaultDeploy, "@CBasePlayerWeaponDeploy" );
	
	#if !defined _zombieplague_included
	RegisterHookChain( RG_CBasePlayer_Spawn, "@CBasePlayer_Spawn", true );
	#endif
	
	bind_pcvar_num( create_cvar( "buy_time", "60", .description = "Weapon menu countdown time." ), g_iWeaponCvar[ Weapon_BuyTime ] );
	bind_pcvar_num( create_cvar( "give_HE_nade", "1", .description = "Give the player a he grenade after they get the weapons." ), g_iWeaponCvar[ Weapon_He ] );
	bind_pcvar_num( create_cvar( "give_SM_nade", "1", .description = "Give the player a smoke grenade after they get the weapons" ), g_iWeaponCvar[ Weapon_Smoke ] );
	bind_pcvar_num( create_cvar( "give_FB_nade", "1", .description = "Give the player a flash grenade after they get the weapons" ), g_iWeaponCvar[ Weapon_Flash ] );
	
	g_iForward[ Weapon_Select_Pre ] = CreateMultiForward( "weapon_select_pre", ET_CONTINUE, FP_CELL, FP_CELL )
	g_iForward[ Weapon_Select_Post ] = CreateMultiForward( "weapon_select_post", ET_IGNORE, FP_CELL, FP_CELL )
	
	register_clcmd( "say /weapon", "WeaponMenu" );
	register_clcmd( "say_team /weapon", "WeaponMenu" );
	
	register_menu( "WeaponsMenu", -1, "WeaponHandler" );
}

public plugin_end( )
{
	ArrayDestroy( g_aWeapons );
}

public client_connect( id )
{
	g_iMenuSection[ id ] = SECTION_PRIMARY;
	g_iSelectWeapon[ id ] = g_iDefaultWeapons;	
}

@CBasePlayerWeaponDeploy( iWeapon, szViewModel[ ], szWeaponModel[ ] )
{
	if( is_nullent( iWeapon ) )
	{
		return;
	}

	new id = get_member( iWeapon, m_pPlayer );
	
	if( !is_user_connected( id ) )
	{
		return;
	}
	
	for ( new i = 0; i < MAX_SECTION; i++ )
	{
		if( g_iSelectWeapon[ id ][ i ] == WEAPON_INVALID )
		{
			continue;
		}

		ArrayGetArray( g_aWeapons, g_iSelectWeapon[ id ][ i ], eWeapons )
		
		if( get_member( iWeapon, m_iId ) == rg_get_weapon_info( eWeapons[ Weapon_Handle ] ) )
		{
			if( eWeapons[ Weapon_ViewModel ][ 0 ] != EOS )
			{
				SetHookChainArg( 2, ATYPE_STRING, eWeapons[ Weapon_ViewModel ] );
			}
			
			if( eWeapons[ Weapon_PlayerModel ][ 0 ] != EOS )
			{
				SetHookChainArg( 3, ATYPE_STRING, eWeapons[ Weapon_PlayerModel ] );
			}
		}
	}
}

@CWeaponBoxSetModel( iWeaponBox, szModel[ ] )
{
	if( is_nullent( iWeaponBox ) )
	{
		return;
	}
	
	new id = get_entvar( iWeaponBox, var_owner );

	for (new iWeaponID, InventorySlotType:iWeapon = PRIMARY_WEAPON_SLOT; iWeapon <= PISTOL_SLOT; iWeapon++ )
	{
		iWeaponID = get_member( iWeaponBox, m_WeaponBox_rgpPlayerItems, iWeapon );

		if ( is_nullent( iWeaponID ) )
			continue;

		for ( new i = 0; i < MAX_SECTION; i++ )
		{
			if( g_iSelectWeapon[ id ][ i ] == WEAPON_INVALID )
			{
				continue;
			}
	
			ArrayGetArray( g_aWeapons, g_iSelectWeapon[ id ][ i ], eWeapons )
			
			if( get_member( iWeaponID, m_iId ) == rg_get_weapon_info( eWeapons[ Weapon_Handle ] ) )
			{
				if( eWeapons[ Weapon_WorldModel ][ 0 ] != EOS )
				{
					SetHookChainArg( 2, ATYPE_STRING, eWeapons[ Weapon_WorldModel ] );
				}
			}
		}
		break;
	}
}

#if !defined _zombieplague_included
@CBasePlayer_Spawn( id )
{
	if ( !is_user_alive( id ) )
		return;

	g_bWeaponsGiven[ id ] = false;
	 
	g_iMenuTimer[ id ] = g_iWeaponCvar[ Weapon_BuyTime ];

	if( g_bAutoSelect[ id ] )
	{
		new szWeapon[ 128 ];
		FillFields( id, szWeapon, charsmax( szWeapon ) );			
		FillWeaponSelection( id );
		CC_SendMessage( id, "%L", id, "AUTO_SELECTED", szWeapon );	
	}
	else WeaponMenu( id );
}
#else
public zp_user_humanid_post( id )
{
	g_bWeaponsGiven[ id ] = false;
	
	g_iMenuTimer[ id ] = g_iWeaponCvar[ Weapon_BuyTime ];
	
	if( g_bAutoSelect[ id ] )
	{
		new szWeapon[ 128 ];
		FillFields( id, szWeapon, charsmax( szWeapon ) );			
		FillWeaponSelection( id );
		CC_SendMessage( id, "%L", id, "AUTO_SELECTED", szWeapon );
	}
	else WeaponMenu( id );
}
#endif

public WeaponMenu( id )
{
	#if defined _zombieplague_included
	if( zp_get_user_zombie( id ) )
	{
		CC_SendMessage( id, "%L", id, "HUMAN_ONLY" );
		goto @Destroy;
	}						
	#endif
	
	if( !task_exists( id ) && !g_bWeaponsGiven[ id ] && g_iMenuTimer[ id ] )
	{
		set_task( 1.0, "OnTaskWeaponMenu", id, .flags = "a", .repeat = g_iMenuTimer[ id ] )
	}

	new Array:iItemsToAdd = ArrayCreate( );

	for ( new i; i < g_iTotalWeapons; i++ )
	{
		ArrayGetArray( g_aWeapons, i, eWeapons )

		if( g_iMenuSection[ id ] != eWeapons[ Weapon_Section ] )
		{
			continue;
		}
		
		ExecuteForward( g_iForward[ Weapon_Select_Pre ], g_iForward[ Weapon_Result ], id, i );
		
		if ( g_iForward[ Weapon_Result ] >= WEAPON_DONT_SHOW )
		{
			continue;
		}
		
		ArrayPushCell( iItemsToAdd, i );
	}
	
	new iSize = ArraySize( iItemsToAdd );
	
	if( !iSize )
	{
		switch( g_iMenuSection[ id ] )
		{
			case SECTION_PRIMARY: CC_SendMessage( id, "%L", id, "NOT_REGISTRED_PRIM" ), g_iMenuSection[ id ] = SECTION_SECONDARY
			case SECTION_SECONDARY: CC_SendMessage( id, "%L", id, "NOT_REGISTRED_SEC" ), g_iMenuSection[ id ] = SECTION_PRIMARY
			default: CC_SendMessage( id, "%L", id, "NOT_REGISTRED_YET" )
		}
		goto @Destroy;
	}
	
	const iPerPage = 7;
	new iPageSize = floatround( iSize / float( iPerPage ), floatround_ceil)
	new iPage = clamp( g_iMenuPages[ id ][ g_iMenuSection[ id ] ], 0, iPageSize - 1 )
	new iPosition = iPage * iPerPage
	new szWeapon[ 128 ], szTemp[ 64 ], szMenu[ MAX_MENU_LENGTH ], iLen, iKey, iItemID
				
	iLen = formatex( szMenu, charsmax( szMenu ), "\y%L", id, g_iMenuSection[ id ] == SECTION_PRIMARY ? "MENU_PRIMARY_TITLE" : "MENU_SECONDARY_TITLE" )

	if( iPageSize > 1 )
	{
		iLen += formatex( szMenu[ iLen ], charsmax( szMenu ) - iLen, " \d%d/%d", iPage + 1, iPageSize )
	}
	
	iLen += formatex( szMenu[ iLen ], charsmax( szMenu ) - iLen, "^n\r• %L: %i", id, "MENU_TIMER", g_iMenuTimer[ id ] )
	
	
	iLen += copy( szMenu[ iLen ], charsmax( szMenu ) - iLen, "^n^n" )

	arrayset( g_iMenuItems[ id ], -1, sizeof( g_iMenuItems[ ] ) )
		
	for( new i = iPosition, iLimit = min( iSize, iPosition + iPerPage ); i < iLimit; i++)
	{
		g_szWeaponText[ 0 ] = WEAPON_AVAILABLE;
		
		iItemID = ArrayGetCell( iItemsToAdd, i )
		
		ArrayGetArray( g_aWeapons, iItemID, eWeapons )

		szTemp[ 0 ] = EOS;
		
		ExecuteForward( g_iForward[ Weapon_Select_Pre ], g_iForward[ Weapon_Result ], id, i );
				
		g_iMenuItems[ id ][ iKey ] = iItemID;
		
		if( !( ( get_user_flags( id ) & eWeapons[ Weapon_AdminFlags ] ) == eWeapons[ Weapon_AdminFlags ] ) )
		{
			formatex( szTemp, charsmax( szTemp ), " \r%L", id, "ADMIN_ONLY" );
		}
		#if defined _ze_levels_included 
		else if( eWeapons[ Weapon_Level ] && ze_get_user_level( id ) < eWeapons[ Weapon_Level ] )
		{
			formatex( szTemp, charsmax( szTemp ), " \r%L", id, "UNAVAILABLE_LEVEL", eWeapons[ Weapon_Level ] );
		}
		#endif 
		#if defined _ze_vip_included 
		else if( !( ( ze_get_vip_flags( id ) & eWeapons[ Weapon_VIPFlags ] ) == eWeapons[ Weapon_VIPFlags ] ) )
		{
			formatex( szTemp, charsmax( szTemp ), " \r%L", id, "VIP_ONLY" );
		}
		#endif
		
		if( g_iForward[ Weapon_Result ] >= WEAPON_UNAVAILABLE )
		{
			iLen += formatex( szMenu[ iLen ], charsmax( szMenu ) - iLen, "\d%d. %s%s%s^n", ++iKey, eWeapons[ Weapon_Name ], ( g_iSelectWeapon[ id ][ eWeapons[ Weapon_Section ] ] == iItemID ) ? " \y*" : szTemp, g_szWeaponText );
		}
		else iLen += formatex( szMenu[ iLen ], charsmax( szMenu ) - iLen, "\r%d.\w %s%s%s^n", ++iKey, eWeapons[ Weapon_Name ], ( g_iSelectWeapon[ id ][ eWeapons[ Weapon_Section ] ] == iItemID ) ? " \y*" : szTemp, g_szWeaponText );
	}
	
	ArrayDestroy( iItemsToAdd );
	
	for( new i = iKey; i <= iPerPage; i++ )
	{
		iLen += copy( szMenu[ iLen ], charsmax( szMenu ) - iLen, "^n" )
	}

	if( iPage > 0 )
	{
		iLen += formatex( szMenu[ iLen ], charsmax( szMenu ) - iLen, "^n\r8. \w%L", id, "MENU_BACK" )
	}
	else 
	{
		new iWeapons = FillFields( id, szWeapon, charsmax( szWeapon ), true );
		
		switch( g_iMenuSection[ id ] )
		{
			case SECTION_PRIMARY: 
			{
				if( iWeapons ) iLen += formatex( szMenu[ iLen ], charsmax( szMenu ) - iLen, "^n\r8. \w%L [ %s ]", id, "GET_SELECT_FIELD", szWeapon )
				else iLen += formatex( szMenu[ iLen ], charsmax( szMenu ) - iLen, "^n\r8. \w%L", id, "GET_SELECT_FIELD", szWeapon )
			}
			case SECTION_SECONDARY:
			{
				if( g_bAutoSelect[ id ] && iWeapons ) iLen += formatex( szMenu[ iLen ], charsmax( szMenu ) - iLen, "^n\r8. \w%L [ %s ]", id, "AUTO_SELECT_FIELD", szWeapon )
				else iLen += formatex( szMenu[ iLen ], charsmax( szMenu ) - iLen, "^n\r8. \w%L [ \rOff\w ]", id, "AUTO_SELECT_FIELD" )
			}
			default: iLen += formatex( szMenu[ iLen ], charsmax( szMenu ) - iLen, "^n\r8. \d%L", id, "MENU_BACK" )
		}
	}
		
	if( iPageSize > 1 )
	{
		iLen += formatex( szMenu[ iLen ], charsmax( szMenu ) - iLen, "^n\r9. %s%L", ( iPage < iPageSize - 1 ) ? "\w" : "\d", id, "MENU_NEXT" )
	}
	else iLen += copy( szMenu[ iLen ], charsmax( szMenu ) - iLen, "^n" )

	iLen += formatex( szMenu[ iLen ], charsmax( szMenu ) - iLen, "^n\r0. \w%L", id, "MENU_EXIT" )
	
	g_iMenuPages[ id ][ g_iMenuSection[ id ] ] = iPage;
	show_menu( id, -1, szMenu, -1, "WeaponsMenu" );
	@Destroy:
	return PLUGIN_HANDLED;
}

public WeaponHandler( id, iKey )
{
	if( iKey != 9 )
	{
		new iItem = g_iMenuItems[ id ][ iKey ];
				
		switch( iKey )
		{
			case 7:
			{
				if( g_iMenuPages[ id ][ g_iMenuSection[ id ] ] )
				{
					g_iMenuPages[ id ][ g_iMenuSection[ id ] ]--;
				}
				else
				{
					switch( g_iMenuSection[ id ] )
					{
						case SECTION_PRIMARY:
						{
							if( !is_user_alive( id ) )
							{
								CC_SendMessage( id, "%L", id, "ALVIE_ONLY" );
								goto @Destroy;
							}
							
							#if defined _zombieplague_included
							if( zp_get_user_zombie( id ) )
							{
								CC_SendMessage( id, "%L", id, "HUMAN_ONLY" );
								goto @Destroy;
							}						
							#endif
							
							if( g_bWeaponsGiven[ id ] )
							{
								CC_SendMessage( id, "%L", id, "ALREAY_SELECTED" );
							}
							else if( !g_iMenuTimer[ id ] )
							{
								CC_SendMessage( id, "%L", id, "TIMER_END" );
							}
							else return FillWeaponSelection( id );
						}
						case SECTION_SECONDARY:
						{
							new szWeapon[ 128 ];
							FillFields( id, szWeapon, charsmax( szWeapon ) );
							
							switch( g_bAutoSelect[ id ] )
							{
								case false:
								{
									g_bAutoSelect[ id ] = true;
									CC_SendMessage( id, "%L", id, "ENABLE_AUTO_SELECT", szWeapon )
								}
								case true:
								{
									g_bAutoSelect[ id ] = false;
									CC_SendMessage( id, "%L", id, "DISABLE_AUTO_SELECT", szWeapon )
								}
							}
						}
					}
				}
			}
			case 8: g_iMenuPages[ id ][ g_iMenuSection[ id ] ]++;
			default:
			{
				if( 0 <= iItem < g_iTotalWeapons )
				{
					new szTemp[ 64 ];
					ArrayGetArray( g_aWeapons, iItem, eWeapons )
					
					if( !( ( get_user_flags( id ) & eWeapons[ Weapon_AdminFlags ] ) == eWeapons[ Weapon_AdminFlags ] ) )
					{
						formatex( szTemp, charsmax( szTemp ), "%L", id, "ADMIN_ONLY" );
					}
					
					#if defined _crxranks_included
					else if( eWeapons[ Weapon_Level ] && crxranks_get_user_level( id ) < eWeapons[ Weapon_Level ] )
					{
						formatex( szTemp, charsmax( szTemp ), "%L", id, "UNAVAILABLE_LEVEL", eWeapons[ Weapon_Level ] );
					}
					#endif 
					
					#if defined _vip_included
					else if( !( ( get_vip_vip( id ) & eWeapons[ Weapon_VIPFlags ] ) == eWeapons[ Weapon_VIPFlags ] ) )
					{
						formatex( szTemp, charsmax( szTemp ), "%L", id, "VIP_ONLY" );
					}
					#endif
		
					if( szTemp[ 0 ] != EOS )
					{
						CC_SendMessage( id, "%L", id, "UNAVAILABLE_SELECT", szTemp )
					}
					else
					{
						g_iSelectWeapon[ id ][ g_iMenuSection[ id ] ] = iItem;
						g_iMenuSection[ id ] = ( g_iMenuSection[ id ] == SECTION_PRIMARY ) ? SECTION_SECONDARY : SECTION_PRIMARY;
						g_iMenuPages[ id ][ g_iMenuSection[ id ] ] = 0;
					}
				}
			}
		}
		WeaponMenu( id );
	}
	else remove_task( id );
	@Destroy:
	return PLUGIN_HANDLED;
}

public OnTaskWeaponMenu( id )
{
	if( !is_user_connected( id ) )
	{
		remove_task(id);
		return;
	}
	
	g_iMenuTimer[ id ]--;
	
	if( !is_user_alive( id ) /*|| g_bWeaponsGiven[ id ]*/ || !g_iMenuTimer[ id ] )
	{
		remove_task( id );

		show_menu( id, 0, "", 0 );

		return;
	}
	
	WeaponMenu( id );
}

FillWeaponSelection( const id )
{
	if( g_iWeaponCvar[ Weapon_He ] )
	{
		rg_give_item( id, "weapon_hegrenade" );
	}

	if( g_iWeaponCvar[ Weapon_Smoke ] )
	{
		rg_give_item( id, "weapon_smokegrenade" );
	}
	
	if( g_iWeaponCvar[ Weapon_Flash ] )
	{
		rg_give_item( id, "weapon_flashbang" )
	}
		
	remove_task( id );
	
	g_bWeaponsGiven[ id ] = true;
	
	for ( new i = 0, iItem, WeaponIdType:iWeaponID, iMaxAmmo1, iMaxAmmo2, iAmmoType; i < MAX_SECTION; i++ )
	{
		if( g_iSelectWeapon[ id ][ i ] == WEAPON_INVALID )
		{
			continue;
		}
		
		ArrayGetArray( g_aWeapons, g_iSelectWeapon[ id ][ i ], eWeapons )
			
		ExecuteForward( g_iForward[ Weapon_Select_Pre ], g_iForward[ Weapon_Result ], id, g_iSelectWeapon[ id ][ i ] )

		if( g_iForward[ Weapon_Result ] >= WEAPON_UNAVAILABLE )
		{
			continue;
		}
		
		if( SECTION_PRIMARY <= i <= SECTION_SECONDARY )
		{
			if( eWeapons[ Weapon_Reference ][ 0 ] != EOS )
			{
				iItem = rg_give_custom_item( id, eWeapons[ Weapon_Handle ], GT_REPLACE , g_iSelectWeapon[ id ][ i ] );

				if( !is_nullent( iItem ) )
				{
					iMaxAmmo1 = rg_get_iteminfo( iItem, ItemInfo_iMaxAmmo1 );

					if( iMaxAmmo1 != WEAPON_INVALID )
					{
						iAmmoType = get_member( iItem, m_Weapon_iPrimaryAmmoType );

						if( iAmmoType != WEAPON_INVALID )
							set_member( id, m_rgAmmo, iMaxAmmo1, iAmmoType );
					}

					iMaxAmmo2 = rg_get_iteminfo( iItem, ItemInfo_iMaxAmmo2 );

					if( iMaxAmmo2 != WEAPON_INVALID )
					{
						iAmmoType = get_member( iItem, m_Weapon_iSecondaryAmmoType );

						if( iAmmoType != WEAPON_INVALID )
							set_member( id, m_rgAmmo, iMaxAmmo2, iAmmoType );
					}
				}
			}
			else
			{
				iItem = rg_give_item( id, eWeapons[ Weapon_Handle ] );

				if( !is_nullent( iItem ) )
				{
					if( rg_get_iteminfo( iItem, ItemInfo_iMaxClip ) != WEAPON_INVALID )
					{
						iWeaponID = get_member( iItem, m_iId );

						set_member(id, m_rgAmmo, rg_get_weapon_info( iWeaponID, WI_MAX_ROUNDS ), rg_get_weapon_info( iWeaponID, WI_AMMO_TYPE ) );
					}
				}
			}
		}

		ExecuteForward( g_iForward[ Weapon_Select_Post ], g_iForward[ Weapon_Result ], id, g_iSelectWeapon[ id ][ i ] );
	}
	
	return true;
}

// Return the selections names from the sections
FillFields( const id, szOutPut[ ], iSi, bool:bMenu = false )
{
	new iSeletcedSize;
		
	for ( new i = 0; i < MAX_SECTION; i++ )
	{
		if( g_iSelectWeapon[ id ][ i ] != WEAPON_INVALID )
		{
			ArrayGetArray( g_aWeapons, g_iSelectWeapon[ id ][ i ], eWeapons )
			
			if( bMenu ) add( szOutPut, iSi, fmt( "%s\y%s\w", iSeletcedSize ? " \w+ " : "", eWeapons[ Weapon_Name ] ) )
			else add( szOutPut, iSi, fmt( "%s^4%s^1", iSeletcedSize ? " ^3+ " : "", eWeapons[ Weapon_Name ] ) )
			
			iSeletcedSize++;
		}
	}
	
	return iSeletcedSize;
}

public plugin_natives( )
{
	register_library( "weapon_system" )
	register_native( "register_weapon", "_RegisterWeapon" )
	register_native( "weapon_si", "_WeaponSi" )
	register_native( "weapon_force", "_WeaponForce" )
	register_native( "get_selected_weapon", "_GetWeaponSelection" )
	register_native( "get_weapon_name", "_GetWeaponName" )
	register_native( "find_weapon", "_FindWeaponID" )
	register_native( "show_weapon_menu", "_ShowWeaponMenu" )
	register_native( "is_auto_buy", "_IsAutoBuy" )
	register_native( "disable_auto_buy", "_DisableAutoBuy" )
	register_native( "is_default_weapon", "_IsDefaultWeapon" )
	register_native( "set_default_weapon", "_SetDefaultWeapon" )
	register_native( "add_weapon_text", "_AddWeaponText" )
	register_native( "is_valid_weapon", "_IsValidWeapon" )
}

public _IsValidWeapon( iPlugin, iParams )
{
	return 0 <= get_param( 1 ) < g_iTotalWeapons;
}

public _WeaponSi( iPlugin, iParams )
{
	return g_iTotalWeapons;
}

public _AddWeaponText( iPlugin, iParams )
{
	static szText[ MAX_NAME_LENGTH ];
	get_string( 2, szText, charsmax( szText ) );
	add( g_szWeaponText, charsmax( g_szWeaponText ), szText );
}

public _SetDefaultWeapon( iPlugin, iParams )
{
	new iWeaponID = get_param( 1 );
	
	if( iWeaponID < 0 || iWeaponID >= g_iTotalWeapons )
	{
		log_error( AMX_ERR_NATIVE, "[Weapon] Invalid weapon id (%d)", iWeaponID );
		return;
	}
	
	ArrayGetArray( g_aWeapons, iWeaponID, eWeapons );
	
	g_iDefaultWeapons[ eWeapons[ Weapon_Section ] ] = iWeaponID;
}

public _IsDefaultWeapon( iPlugin, iParams )
{
	new iWeaponID = get_param( 1 );
	
	if( iWeaponID < 0 || iWeaponID >= g_iTotalWeapons )
	{
		log_error( AMX_ERR_NATIVE, "[Weapon] Invalid weapon id (%d)", iWeaponID );
		return WEAPON_INVALID;
	}
	
	ArrayGetArray( g_aWeapons, iWeaponID, eWeapons );
	
	return ( g_iDefaultWeapons[ eWeapons[ Weapon_Section ] ] == iWeaponID );
}

public _ShowWeaponMenu( iPlugin, iParams )
{
	new Identity = get_param( 1 );
	
	if( !is_user_connected( Identity ) )
	{
		log_error(AMX_ERR_NATIVE, "[Weapon] Invalid Player (%d)", Identity )
		return 0;
	}
	
	return WeaponMenu( Identity );
}

public _DisableAutoBuy( iPlugin, iParams )
{
	new Identity = get_param( 1 );
	
	if( !is_user_connected( Identity ) )
	{
		log_error(AMX_ERR_NATIVE, "[Weapon] Invalid Player (%d)", Identity )
		return 0;
	}
				
	return g_bAutoSelect[ Identity ] = false;
}

public _IsAutoBuy( iPlugin, iParams )
{
	new Identity = get_param( 1 );
	
	if( !is_user_connected( Identity ) )
	{
		log_error(AMX_ERR_NATIVE, "[Weapon] Invalid Player (%d)", Identity )
		return 0;
	}
				
	return g_bAutoSelect[ Identity ];
}

public _WeaponForce( iPlugin, iParams )
{
	new Identity = get_param( 1 );
	
	if( !is_user_connected( Identity ) )
	{
		log_error(AMX_ERR_NATIVE, "[Weapon] Invalid Player (%d)", Identity )
		return 0;
	}
	
	new iWeaponID = get_param( 2 );
	
	if( iWeaponID < 0 || iWeaponID >= g_iTotalWeapons )
	{
		log_error( AMX_ERR_NATIVE, "[Weapon] Invalid weapon id (%d)", iWeaponID );
		return WEAPON_INVALID;
	}
	
	ExecuteForward( g_iForward[ Weapon_Select_Post ], g_iForward[ Weapon_Result ], Identity, iWeaponID );
							
	return 1;
}

public _GetWeaponSelection( iPlugin, iParams )
{
	new Identity = get_param( 1 );
	
	if( !is_user_connected( Identity ) )
	{
		log_error(AMX_ERR_NATIVE, "[Weapon] Invalid Player (%d)", Identity );
		return 0;
	}
				
	return g_iSelectWeapon[ Identity ][ clamp( get_param( 2 ), SECTION_PRIMARY, SECTION_SECONDARY ) ] ;
}

public _GetWeaponName( iPlugin, iParams )
{
	new iWeaponID = get_param( 1 );
	
	if( iWeaponID < 0 || iWeaponID >= g_iTotalWeapons )
	{
		log_error( AMX_ERR_NATIVE, "[Weapon] Invalid weapon id (%d)", iWeaponID );
		return;
	}
	
	ArrayGetArray( g_aWeapons, iWeaponID, eWeapons );
		
	set_string( 2, eWeapons[ Weapon_Name ], get_param( 3 ) )
}

public _FindWeaponID( iPlugin, iParams )
{
	new szHandle[ MAX_HANDLE_LENGTH ];
	get_string( 1, szHandle, charsmax( szHandle ) )
	
	new iWeaponID = ArrayFindString( g_aWeapons, szHandle );

	/*
	for( new iWeaponID; iWeaponID < g_iTotalWeapons; iWeaponID++ )
	{
		ArrayGetArray( g_aWeapons, iWeaponID, eWeapons );
		
		if( equali( szWeaponName, eWeapons[ Weapon_Name ] ) )
			return iWeaponID;
	}*/
	
	return ( iWeaponID != WEAPON_INVALID ) ? iWeaponID : 0;
}

public _RegisterWeapon( iPlugin, iParams )
{
	eWeapons[ Weapon_Section ] = get_param( 1 );
	get_string( 2, eWeapons[ Weapon_Handle ], charsmax( eWeapons[ Weapon_Handle ] ) );
	get_string( 3, eWeapons[ Weapon_Reference ], charsmax( eWeapons[ Weapon_Reference ] ) );
	get_string( 4, eWeapons[ Weapon_Name ], charsmax( eWeapons[ Weapon_Name ] ) );
	copy( eWeapons[ Weapon_RealName ], charsmax( eWeapons[ Weapon_RealName ] ), eWeapons[ Weapon_Name ] );
	get_string( 5, eWeapons[ Weapon_ViewModel ], charsmax( eWeapons[ Weapon_ViewModel ] ) );
	get_string( 6, eWeapons[ Weapon_PlayerModel ], charsmax( eWeapons[ Weapon_PlayerModel ] ) );
	get_string( 7, eWeapons[ Weapon_WorldModel ], charsmax( eWeapons[ Weapon_WorldModel ] ) );
	eWeapons[ Weapon_Level ] = get_param( 8 );
	eWeapons[ Weapon_AdminFlags ] = get_param( 9 );
	eWeapons[ Weapon_VIPFlags ] = get_param( 10 );
	
	return DefineWeapon
	( 
		eWeapons[ Weapon_Section ], eWeapons[ Weapon_Handle ], eWeapons[ Weapon_Reference ], eWeapons[ Weapon_Name ],\
		eWeapons[ Weapon_ViewModel ], eWeapons[ Weapon_PlayerModel ], eWeapons[ Weapon_WorldModel ],\
		eWeapons[ Weapon_Level ], eWeapons[ Weapon_AdminFlags ], eWeapons[ Weapon_VIPFlags ]
	)	
}

PrecacheWeapon( szPatch[ ], iPatchSize )
{
	static const szExt[ ] = ".mdl";

	if( !szPatch[ 0 ] )
	{
		return WEAPON_UNAVAILABLE;
	}
	
	copy( szPatch, iPatchSize, fmt( "models/%s%s", szPatch, IsExtensionExist( szPatch, szExt ) ? "" : szExt ) );

	if( !file_exists( szPatch ) )
	{
		log_amx( "[Weapon] Error model ^"%s^" not found!", szPatch );
		return WEAPON_INVALID;
	}

	return precache_model( szPatch );
}

IsExtensionExist( const szPatch[ ], const szExtension[ ] )
{
	return equal( szPatch[ strlen( szPatch ) - strlen( szExtension ) ], szExtension );
}

DefineWeapon( iSection, szHandle[ MAX_HANDLE_LENGTH ], szReference[ MAX_HANDLE_LENGTH ], szName[ MAX_NAME_LENGTH ], szViewModel[ MAX_RESOURCE_PATH_LENGTH ] = "", szPlayerModel[ MAX_RESOURCE_PATH_LENGTH ] = "", szWorldModel[ MAX_RESOURCE_PATH_LENGTH ] = "", iLevel = 0, iAdminFlag = ADMIN_ALL, iVIPFlag = 0 )
{
	eWeapons[ Weapon_Section ] = iSection;
	eWeapons[ Weapon_Handle ] = szHandle;
	eWeapons[ Weapon_Reference ] = szReference;
	eWeapons[ Weapon_Name ] = szName;
	eWeapons[ Weapon_RealName ] = szName;
	eWeapons[ Weapon_ViewModel ] = szViewModel;
	eWeapons[ Weapon_PlayerModel ] = szPlayerModel;
	eWeapons[ Weapon_WorldModel ] = szWorldModel;
	eWeapons[ Weapon_Level ] = iLevel;
	eWeapons[ Weapon_AdminFlags ] = iAdminFlag;
	eWeapons[ Weapon_VIPFlags ] = iVIPFlag;

	if( ArrayFindString( g_aWeapons, eWeapons[ Weapon_RealName ] ) != WEAPON_INVALID )
	{
		log_amx( "[Weapon] Weapon already registered: %s", szName )
		return WEAPON_INVALID;
	}
	
	if( strlen( eWeapons[ Weapon_Handle ] ) < 7 )
	{
		log_amx( "[Weapon] Invalid handle: %s", eWeapons[ Weapon_Handle ] )
		return WEAPON_INVALID;
	}	
							
	if( eWeapons[ Weapon_ViewModel ][ 0 ] != EOS )
	{
		PrecacheWeapon( eWeapons[ Weapon_ViewModel ], charsmax( eWeapons[ Weapon_ViewModel ] ) )
	}
	
	if( eWeapons[ Weapon_PlayerModel ][ 0 ] != EOS )
	{
		PrecacheWeapon( eWeapons[ Weapon_PlayerModel ], charsmax( eWeapons[ Weapon_PlayerModel ] ) )
	}
	
	if( eWeapons[ Weapon_WorldModel ][ 0 ] != EOS )
	{
		PrecacheWeapon( eWeapons[ Weapon_WorldModel ], charsmax( eWeapons[ Weapon_WorldModel ] ) )
	}

	if( !DefineFile( 0, eWeapons[ Weapon_RealName ] ) )
	{
		DefineFile( 1, eWeapons );
	}
	
	ArrayPushArray( g_aWeapons, eWeapons );	

	g_iTotalWeapons++;
	return g_iTotalWeapons - 1;
}

bool:DefineFile( iType, szRealName[ ] )
{
	new iFilePointer, szFilename[ MAX_FILE_LENGTH ], bool:bWeaponExists

	formatex( szFilename[ get_configsdir( szFilename, charsmax( szFilename ) ) ], charsmax( szFilename ), "/%s", SETTING_RESOURCES );

	switch( iType )
	{
		case 0:
		{
			iFilePointer = fopen( szFilename, "rt" );
			
			if( iFilePointer )
			{
				new szData[ MAX_FILE_LENGTH ], szValue[ 160 ], szKey[ 32 ];
				
				while( fgets( iFilePointer, szData, charsmax( szData ) ) )
				{
					if( szData[ 0 ] == '[' )
					{
						copyc( szData, charsmax( szData ), szData[ 1 ], ']' )
						if( equali( szRealName, szData ) )
						{
							bWeaponExists = true;
							break;
						}
					}
				}
				
				if( !bWeaponExists )
				{
					while( fgets( iFilePointer, szData, charsmax( szData ) ) )
					{
						trim( szData );
	
						switch( szData[ 0 ] )
						{
							case EOS, '#', '/', ';': continue;
							default:
							{
								strtok( szData, szKey, charsmax( szKey ), szValue, charsmax( szValue ), '=' )
								trim( szKey ); trim( szValue );
	
								if( !szValue[ 0 ] || !szKey[ 0 ] )
								{
									break;
								}
								
								if( equal( szKey, "SECTION" ) )
								{
									switch( szValue[ 0 ] )
									{
										case EOS, 'P', 'p': eWeapons[ Weapon_Section ] = SECTION_PRIMARY
										case 'S', 's': eWeapons[ Weapon_Section ] = SECTION_SECONDARY
										default: eWeapons[ Weapon_Section ] = clamp( str_to_num( szValue ) - 1, SECTION_PRIMARY, SECTION_SECONDARY );
									}
								}
								else if( equal( szKey, "NAME" ) )
								{
									copy( eWeapons[ Weapon_Name ], charsmax( eWeapons[ Weapon_Name ] ), szValue );
								}
								else if( equal( szKey, "HANDLE" ) )
								{
									copy( eWeapons[ Weapon_Handle ], charsmax( eWeapons[ Weapon_Handle ] ), szValue );
								}
								else if( equal( szKey, "REFERENCE" ) )
								{
									copy( eWeapons[ Weapon_Reference ], charsmax( eWeapons[ Weapon_Reference ] ), szValue );
								}
								else if( equal( szKey, "VIEW_MODEL" ) )
								{
									copy( eWeapons[ Weapon_ViewModel ], charsmax( eWeapons[ Weapon_ViewModel ] ), szValue );
								}
								else if( equal( szKey, "PLAYER_MODEL" ) )
								{
									copy( eWeapons[ Weapon_PlayerModel ], charsmax( eWeapons[ Weapon_PlayerModel ] ), szValue );
								}
								else if( equal( szKey, "WORLD_MODEL" ) )
								{
									copy( eWeapons[ Weapon_WorldModel ], charsmax( eWeapons[ Weapon_WorldModel ] ), szValue );
								}
								else if( equal( szKey, "LEVEL" ) )
								{
									eWeapons[ Weapon_Level ] = str_to_num( szValue );
								}
								else if( equal( szKey, "FLAG" ) )
								{
									eWeapons[ Weapon_AdminFlags ] = read_flags( szValue );
								}
								else if( equal( szKey, "VIP_FLAG" ) )
								{
									eWeapons[ Weapon_VIPFlags ] = read_flags( szValue );
								}
								else if( equal( szKey, "DEFAULT" ) )
								{
									switch( szValue[ 0 ] )
									{
										case 'T', 't', '1': g_iDefaultWeapons[ eWeapons[ Weapon_Section ] ] = g_iTotalWeapons
									}
								}
							}
						}
					}
				}			
				fclose( iFilePointer );
			}
		}
		case 1:
		{
			iFilePointer = fopen( szFilename, "at" )
			
			if( iFilePointer )
			{
				new szFlag[ 32 ];

				fprintf( iFilePointer, "%s[%s]", g_iTotalWeapons == 0 ? "" : "^n^n", eWeapons[ Weapon_RealName ] )

				if( SECTION_PRIMARY <= eWeapons[ Weapon_Section ] < MAX_SECTION )
				{
					fprintf( iFilePointer, "^nSECTION = %s", eWeapons[ Weapon_Section ] == SECTION_PRIMARY ? "Primary" : "Secondry" )
				}
				
				if( eWeapons[ Weapon_Name ][ 0 ] != EOS )
				{
					fprintf( iFilePointer, "^nNAME = %s", eWeapons[ Weapon_Name ] );
				}
				
				if( eWeapons[ Weapon_Handle ][ 0 ] != EOS )
				{
					fprintf( iFilePointer, "^nHANDLE = %s", eWeapons[ Weapon_Handle ] );
				}
				
				if( eWeapons[ Weapon_Reference ][ 0 ] != EOS )
				{
					fprintf( iFilePointer, "^nREFERENCE = %s", eWeapons[ Weapon_Reference ] );
				}
				
				if( eWeapons[ Weapon_ViewModel ][ 0 ] != EOS )
				{
					fprintf( iFilePointer, "^nVIEW_MODEL = %s", eWeapons[ Weapon_ViewModel ] );
				}
				
				if( eWeapons[ Weapon_PlayerModel ][ 0 ] != EOS )
				{
					fprintf( iFilePointer, "^nPLAYER_MODEL = %s", eWeapons[ Weapon_PlayerModel ] );
				}
				
				if( eWeapons[ Weapon_WorldModel ][ 0 ] != EOS )
				{
					fprintf( iFilePointer, "^nWORLD_MODEL = %s", eWeapons[ Weapon_WorldModel ] );
				}
				
				if( eWeapons[ Weapon_Level ] )
				{
					fprintf( iFilePointer, "^nLEVEL = %i", eWeapons[ Weapon_Level ] );
				}
				
				if( eWeapons[ Weapon_AdminFlags ] )
				{
					get_flags( eWeapons[ Weapon_AdminFlags ], szFlag, charsmax( szFlag ) )
					fprintf( iFilePointer, "^nFLAG = %s", szFlag );
				}
				
				if( eWeapons[ Weapon_VIPFlags ] )
				{
					get_flags( eWeapons[ Weapon_VIPFlags ], szFlag, charsmax( szFlag ) )
					fprintf( iFilePointer, "^nVIP_FLAG = %s", szFlag );
				}
				
				if( g_iDefaultWeapons[ eWeapons[ Weapon_Section ] ] == g_iTotalWeapons )
				{
					fprintf( iFilePointer, "^nDEFAULT = true" );
				}
				
				fclose( iFilePointer );
			}
		}
	}
	return bWeaponExists;
}

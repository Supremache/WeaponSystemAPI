#if defined _weapon_system_included
    #endinput
#endif

#define _weapon_system_included

const MAX_HANDLE_LENGTH = 32;

enum
{
	SECTION_PRIMARY,
	SECTION_SECONDARY,
	MAX_SECTION
}

enum ( += 1 )
{
	WEAPON_INVALID = -1,
	WEAPON_AVAILABLE,
	WEAPON_UNAVAILABLE,
	WEAPON_DONT_SHOW
}

native register_weapon( iSection, const szHandle[ ], const szReference[ ], const szName[ ], const szViewModel[ ], const szPlayerModel[ ], const szWorldModel[ ], iLevel = 0, iAdminFlag = ADMIN_ALL, iVIPFlag = 0 )
native add_weapon_text( const szText[ ], any:... );
native weapon_size( );
native is_valid_weapon( const iWeaponID )
native weapon_force( id, iWeaponID )
native get_selected_weapon( id, iWeaponSection )
native get_weapon_name( iWeaponID, const szWeaponName[ ], iSize )
native get_weapon_id( const szWeaponName[ ] )
native show_weapon_menu( id )
native is_auto_buy_enabled( id )
native disable_auto_buy( id )
native is_default_weapon( iWeaponID )
native set_default_weapon( iWeaponID )
forward weapon_select_pre( id , iWeapon )

forward weapon_select_post( id , iWeapon )

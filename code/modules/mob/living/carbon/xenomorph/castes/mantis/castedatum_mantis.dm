/datum/xeno_caste/mantis
	caste_name = "Mantis"
	display_name = "Mantis"
	upgrade_name = ""
	caste_desc = ""
	wound_type = ""
	base_strain_type = /mob/living/carbon/xenomorph/mantis
	caste_type_path = /mob/living/carbon/xenomorph/mantis

	tier = XENO_TIER_MINION
	upgrade = XENO_UPGRADE_BASETYPE

	// *** Melee Attacks *** //
	melee_damage = 20
	melee_ap = 5

	// *** Speed *** //
	speed = -0.6

	// *** Plasma *** //
	plasma_max = 500 //2 ravages
	plasma_gain = 20

	// *** Health *** //
	max_health = 150

	// *** Flags *** //
	caste_flags = CASTE_DO_NOT_ALERT_LOW_LIFE|CASTE_IS_A_MINION
	can_flags = CASTE_CAN_BE_GIVEN_PLASMA|CASTE_CAN_RIDE_CRUSHER
	caste_traits = null

	// *** Defense *** //
	soft_armor = list(MELEE = 15, BULLET = 5, LASER = 5, ENERGY = 0, BOMB = 0, BIO = 0, FIRE = 5, ACID = 0)

	minimap_icon = "xenominion"

	actions = list(
		/datum/action/ability/xeno_action/xeno_resting,
		/datum/action/ability/activable/xeno/ravage/slow,
	)

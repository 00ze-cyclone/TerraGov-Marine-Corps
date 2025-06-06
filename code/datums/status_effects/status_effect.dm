//Status effects are used to apply temporary or permanent effects to mobs. Mobs are aware of their status effects at all times.
//This file contains their code, plus code for applying and removing them.
//When making a new status effect, add a define to status_effects.dm in __DEFINES for ease of use!

/datum/status_effect
	///Used for screen alerts
	var/id = "effect"
	///How long the status effect lasts in DECISECONDS. Enter -1 for an effect that never ends unless removed through some means
	var/duration = -1
	///How many deciseconds between ticks, approximately. Leave at 10 for every second
	var/tick_interval = 10
	///The mob affected by the status effect.
	var/mob/living/owner
	///How many of the effect can be on one mob, and what happens when you try to add another
	var/status_type = STATUS_EFFECT_UNIQUE
	///If defined, this text will appear when the mob is examined - to use he, she etc. use "SUBJECTPRONOUN" and replace it in the examines themselves
	var/examine_text
	///the alert thrown by the status effect, contains name and description
	var/alert_type = /atom/movable/screen/alert/status_effect
	///the alert itself, if it exists
	var/atom/movable/screen/alert/status_effect/linked_alert = null

/datum/status_effect/New(list/arguments)
	on_creation(arglist(arguments))

/datum/status_effect/proc/on_creation(mob/living/new_owner, ...)
	if(new_owner)
		owner = new_owner
	if(owner)
		LAZYADD(owner.status_effects, src)
	if(!owner || !on_apply())
		qdel(src)
		return
	if(duration != -1)
		duration = world.time + duration
	tick_interval = world.time + tick_interval
	if(alert_type)
		var/atom/movable/screen/alert/status_effect/A = owner.throw_alert(id, alert_type)
		A.attached_effect = src //so the alert can reference us, if it needs to
		linked_alert = A //so we can reference the alert, if we need to
	START_PROCESSING(SSfastprocess, src)
	return TRUE

/datum/status_effect/Destroy()
	STOP_PROCESSING(SSfastprocess, src)
	linked_alert = null
	if(owner)
		owner.clear_alert(id)
		LAZYREMOVE(owner.status_effects, src)
		on_remove()
		owner = null
	return ..()

/datum/status_effect/process(delta_time)
	if(!owner)
		qdel(src)
		return
	if(tick_interval < world.time)
		tick(delta_time)
		tick_interval = world.time + initial(tick_interval)

	check_duration()

//Called whenever the buff is applied; returning FALSE will cause it to autoremove itself
/datum/status_effect/proc/on_apply()
	return TRUE

///Called every tick
/datum/status_effect/proc/tick(delta_time)

//Called whenever the buff expires or is removed; do note that at the point this is called, it is out of the owner's status_effects but owner is not yet null
/datum/status_effect/proc/on_remove()

///Refreshed the duration
/datum/status_effect/proc/refresh()
	var/original_duration = initial(duration)
	if(original_duration == -1)
		return
	duration = world.time + original_duration

///clickdelay/nextmove modifiers!
/datum/status_effect/proc/nextmove_modifier()
	return 1

/datum/status_effect/proc/nextmove_adjust()
	return 0

/// Use this for manually checking if the effect should've ended, when FASTPROCESSING just isn't fast enough
/datum/status_effect/proc/check_duration()
	if(duration != -1 && duration < world.time)
		qdel(src)
		return TRUE
	return FALSE

////////////////
// ALERT HOOK //
////////////////

/atom/movable/screen/alert/status_effect
	name = "Curse of Mundanity"
	desc = "You don't feel any different..."
	var/datum/status_effect/attached_effect

/atom/movable/screen/alert/status_effect/Destroy()
	. = ..()
	attached_effect = null

//////////////////
// HELPER PROCS //
//////////////////

/mob/living/proc/apply_status_effect(effect, ...) //applies a given status effect to this mob, returning the effect if it was successful
	. = FALSE
	var/datum/status_effect/S1 = effect
	LAZYINITLIST(status_effects)
	for(var/datum/status_effect/S in status_effects)
		if(S.id == initial(S1.id) && S.status_type)
			if(S.status_type == STATUS_EFFECT_REPLACE)
				qdel(S)
			else if(S.status_type == STATUS_EFFECT_REFRESH)
				S.refresh()
				return
			else
				return
	var/list/arguments = args.Copy()
	arguments[1] = src
	S1 = new effect(arguments)
	. = S1

/mob/living/proc/remove_status_effect(effect) //removes all of a given status effect from this mob, returning TRUE if at least one was removed
	. = FALSE
	if(status_effects)
		var/datum/status_effect/S1 = effect
		for(var/datum/status_effect/S in status_effects)
			if(initial(S1.id) == S.id)
				qdel(S)
				. = TRUE

/mob/living/proc/has_status_effect(effect) //returns the effect if the mob calling the proc owns the given status effect
	. = FALSE
	if(status_effects)
		var/datum/status_effect/S1 = effect
		for(var/datum/status_effect/S in status_effects)
			if(initial(S1.id) == S.id)
				return S

/mob/living/proc/has_status_effect_list(effect) //returns a list of effects with matching IDs that the mod owns; use for effects there can be multiple of
	. = list()
	if(status_effects)
		var/datum/status_effect/S1 = effect
		for(var/datum/status_effect/S in status_effects)
			if(initial(S1.id) == S.id)
				. += S

/mob/living/proc/remove_all_status_effect()
	. = 0
	for(var/i in status_effects)
		.++
		qdel(i)

//////////////////////
// STACKING EFFECTS //
//////////////////////

/datum/status_effect/stacking
	id = "stacking_base"
	duration = -1 //removed under specific conditions
	alert_type = null

	/// If status should be removed due to being under one stack
	var/consumed_on_fadeout = TRUE
	/// How many stacks are accumulated, also is # of stacks that target will have when first applied
	var/stacks = 0
	/// Deciseconds until ticks start occuring, which removes stacks (first stack will be removed at this time plus tick_interval)
	var/delay_before_decay
	/// Deciseconds between decays once decay starts
	tick_interval = 10
	/// How many stacks are lost per tick (decay trigger)
	var/stack_decay = 1
	/// Special effects trigger when stacks reach this amount
	var/stack_threshold
	/// Stacks cannot exceed this amount
	var/max_stacks
	/// If status should be removed once threshold is crossed
	var/consumed_on_threshold = TRUE
	/// Set to true once the threshold is crossed, false once it falls back below
	var/threshold_crossed = FALSE
	var/overlay_file
	var/underlay_file
	/// States in .dmi must be given a name followed by a number which corresponds to a number of stacks. put the state name without the number in these state vars
	var/overlay_state
	/// The number is concatonated onto the string based on the number of stacks to get the correct state name
	var/underlay_state
	var/mutable_appearance/status_overlay
	var/mutable_appearance/status_underlay

/// What happens when threshold is crossed
/datum/status_effect/stacking/proc/threshold_cross_effect()

/// Runs if status is deleted due to threshold being crossed
/datum/status_effect/stacking/proc/stacks_consumed_effect()

/// Runs if status is deleted due to being under one stack
/datum/status_effect/stacking/proc/fadeout_effect()

/// Runs every time tick() causes stacks to decay
/datum/status_effect/stacking/proc/stack_decay_effect()

/datum/status_effect/stacking/proc/on_threshold_cross()
	threshold_cross_effect()
	if(consumed_on_threshold)
		stacks_consumed_effect()
		qdel(src)

/datum/status_effect/stacking/proc/on_threshold_drop()

/datum/status_effect/stacking/proc/can_have_status()
	return owner.stat != DEAD

/datum/status_effect/stacking/proc/can_gain_stacks()
	return owner.stat != DEAD

/datum/status_effect/stacking/tick(delta_time)
	if(!can_have_status())
		qdel(src)
	else
		add_stacks(-stack_decay)
		stack_decay_effect()

/datum/status_effect/stacking/proc/add_stacks(stacks_added)
	if(stacks_added > 0 && !can_gain_stacks())
		return FALSE
	owner.cut_overlay(status_overlay)
	owner.underlays -= status_underlay
	stacks += stacks_added
	if(stacks > 0)
		if(stacks >= stack_threshold && !threshold_crossed) //threshold_crossed check prevents threshold effect from occuring if changing from above threshold to still above threshold
			threshold_crossed = TRUE
			on_threshold_cross()
			if(consumed_on_threshold)
				return
		else if(stacks < stack_threshold && threshold_crossed)
			threshold_crossed = FALSE //resets threshold effect if we fall below threshold so threshold effect can trigger again
			on_threshold_drop()
		if(stacks_added > 0)
			tick_interval += delay_before_decay //refreshes time until decay
		stacks = min(stacks, max_stacks)
		status_overlay.icon_state = "[overlay_state][stacks]"
		status_underlay.icon_state = "[underlay_state][stacks]"
		owner.add_overlay(status_overlay)
		owner.underlays += status_underlay
	else if(consumed_on_fadeout)
		fadeout_effect()
		qdel(src) //deletes status if stacks fall under one

/datum/status_effect/stacking/on_creation(mob/living/new_owner, stacks_to_apply)
	. = ..()
	if(.)
		add_stacks(stacks_to_apply)

/datum/status_effect/stacking/on_apply()
	if(!can_have_status())
		return FALSE
	status_overlay = mutable_appearance(overlay_file, "[overlay_state][stacks]")
	status_underlay = mutable_appearance(underlay_file, "[underlay_state][stacks]")
	var/icon_height = owner.get_cached_height()
	status_overlay.pixel_x = -owner.pixel_x
	status_overlay.pixel_y = FLOOR(icon_height * 0.25, 1)
	status_overlay.transform = matrix() * (icon_height/world.icon_size) //scale the status's overlay size based on the target's icon size
	status_underlay.pixel_x = -owner.pixel_x
	status_underlay.transform = matrix() * (icon_height/world.icon_size) * 3
	status_underlay.alpha = 40
	owner.add_overlay(status_overlay)
	owner.underlays += status_underlay
	return ..()

/datum/status_effect/stacking/Destroy()
	if(owner)
		owner.cut_overlay(status_overlay)
		owner.underlays -= status_underlay
	QDEL_NULL(status_overlay)
	return ..()

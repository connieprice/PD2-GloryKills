PlayerStateExecution = PlayerStateExecution or class(PlayerStandard)

--[[
local inherits_list = {
	save
	_on_menu_active_changed
	in_air
	get_fwd_ray
	get_equipped_weapon
	_check_action_night_vision
	set_night_vision_state
	_get_swap_speed_multiplier
on_ladder() 
shooting() 
is_shooting_count()
running() 
ducking()
_is_meleeing
in_melee

function PlayerStateExecution:get_fire_weapon_direction()
function PlayerStateExecution:get_fire_weapon_position()
function PlayerStateExecution:is_switching_stances() end
function PlayerStateExecution:_is_underbarrel_attachment_active(weapon_unit) end
function PlayerStateExecution:_is_cash_inspecting(t) end
function PlayerStateExecution:set_stance_switch_delay(delay) end
function PlayerStateExecution:_is_charging_weapon() end
function PlayerStateExecution:_is_deploying_bipod() end
function PlayerStateExecution:_is_using_bipod() end
function PlayerStateExecution:_is_reloading() end
function PlayerStateExecution:is_equipping() end
function PlayerStateExecution:is_deploying() end
function PlayerStateExecution:in_steelsight()
function PlayerStateExecution:is_second_sight_on()
function PlayerStateExecution:is_reticle_aim()
function PlayerStateExecution:second_sight_use_steelsight_unit()
function PlayerStateExecution:_get_interaction_speed() end

function PlayerStateExecution:_projectile_repeat_allowed() end

function PlayerStateExecution:_update_fwd_ray() end
function PlayerStateExecution:get_animation(anim) end
function PlayerStateExecution:set_animation_state(state_name) end
function PlayerStateExecution:current_anim_state_name() end
function PlayerStateExecution:_show_tap_to_interact_text(text_id, int_obj) end
function PlayerStateExecution:_clear_tap_to_interact() end

function PlayerStateExecution:_toggle_gadget(weap_base) end
function PlayerStateExecution:_get_projectile_throw_offset() end
function PlayerStateExecution:_chk_tap_to_interact_enable(t, int_timer, int_obj, ...) end
function PlayerStateExecution:_changing_weapon() end

function PlayerStateExecution:_create_on_controller_disabled_input() end
function PlayerStateExecution:_upd_nav_data() end

function PlayerStateExecution:_can_stand(ignored_bodies) end
function PlayerStateExecution:_can_run_directional() end


function PlayerStateExecution:_is_throwing_projectile() end
function PlayerStateExecution:in_throw_projectile() end
function PlayerStateExecution:_is_throwing_grenade() end

function PlayerStateExecution:_interacting() end
function PlayerStateExecution:_get_walk_headbob() end
function PlayerStateExecution:get_zoom_fov(stance_data) end
function PlayerStateExecution:_on_zipline() end
function PlayerStateExecution:get_movement_state() end
function PlayerStateExecution:_melee_repeat_allowed() end
function PlayerStateExecution:_does_deploying_limit_movement() end

function PlayerStateExecution:is_network_move_allowed() end
function PlayerStateExecution:_stance_entered(unequipped) end
function PlayerStateExecution:update_fov_external() end
function PlayerStateExecution:_need_to_play_idle_redirect() end
function PlayerStateExecution:_get_melee_charge_lerp_value(t, offset) end


function PlayerStateExecution:_check_step(t) end
function PlayerStateExecution:_check_action_throw_projectile(t, input) end
function PlayerStateExecution:_check_action_throw_grenade(t, input) end
function PlayerStateExecution:_check_action_use_ability(t, input) end
function PlayerStateExecution:_check_tap_to_interact_tap(t, int_timer, int_obj) end
function PlayerStateExecution:_check_tap_to_interact_toggle_hold(t, int_timer, int_obj) end
function PlayerStateExecution:_check_tap_to_interact_toggle_timer(t, int_timer, int_obj) end
function PlayerStateExecution:_check_tap_to_interact_inputs(t, pressed, released, holding) end
function PlayerStateExecution:_check_action_interact(t, input) end
function PlayerStateExecution:_check_action_change_equipment(t, input) end
function PlayerStateExecution:_check_action_weapon_firemode(t, input) end
function PlayerStateExecution:_check_action_weapon_gadget(t, input) end
function PlayerStateExecution:_check_action_melee(t, input) end
function PlayerStateExecution:_check_melee_special_damage(col_ray, character_unit, defense_data, melee_entry) end
function PlayerStateExecution:_check_action_reload(t, input) end
function PlayerStateExecution:_check_use_item(t, input) end
function PlayerStateExecution:_check_change_weapon(t, input) end
function PlayerStateExecution:_check_action_equip(t, input) end
function PlayerStateExecution:_check_action_jump(t, input) end
function PlayerStateExecution:_check_action_zipline(t, input) end
function PlayerStateExecution:_check_action_deploy_bipod(t, input) end
function PlayerStateExecution:_check_action_deploy_underbarrel(t, input) end
function PlayerStateExecution:_check_action_cash_inspect(t, input) end
function PlayerStateExecution:_check_action_run(t, input) end
function PlayerStateExecution:_check_action_ladder(t, input) end
function PlayerStateExecution:_check_action_duck(t, input) end
function PlayerStateExecution:_check_action_steelsight(t, input) end
function PlayerStateExecution:_check_action_primary_attack(t, input, params) end
function PlayerStateExecution:_check_stop_shooting() end

function PlayerStateExecution:_add_unit_to_char_table(char_table, unit, unit_type, interaction_dist, interaction_through_walls, tight_area, priority, my_head_pos, cam_fwd, ray_ignore_units, ray_types) end
function PlayerStateExecution:_get_interaction_target(char_table, my_head_pos, cam_fwd, secondary) end
function PlayerStateExecution:_get_intimidation_action(prime_target, char_table, amount, primary_only, detect_only, secondary) end
function PlayerStateExecution:_get_unit_intimidation_action(intimidate_enemies, intimidate_civilians, intimidate_teammates, only_special_enemies, intimidate_escorts, intimidation_amount, primary_only, detect_only, secondary) end


function PlayerStateExecution:_interupt_action_steelsight(t) end
function PlayerStateExecution:_interupt_action_melee(t) end
function PlayerStateExecution:_interupt_action_running(t) end
function PlayerStateExecution:_interupt_action_ducking(t, skip_can_stand_check) end
function PlayerStateExecution:_interupt_action_cash_inspect(t) end
function PlayerStateExecution:_interupt_action_interact(t, input, complete) end
function PlayerStateExecution:_interupt_action_charging_weapon(t) end
function PlayerStateExecution:_interupt_action_reload(t) end
function PlayerStateExecution:_interupt_action_ladder(t, input) end
function PlayerStateExecution:_interupt_action_use_item(t, input, complete) end
function PlayerStateExecution:_interupt_action_throw_projectile(t) end
function PlayerStateExecution:_interupt_action_throw_grenade(t, input) end
function PlayerStateExecution:interupt_interact() end

function PlayerStateExecution:_do_action_throw_projectile(t, input, drop_projectile) end
function PlayerStateExecution:_switch_equipment() end
function PlayerStateExecution:say_line(sound_name, skip_alert) end
function PlayerStateExecution:_play_melee_sound(melee_entry, sound_id, variation) end
function PlayerStateExecution:apply_slowdown(slow_mul, prevents_running) end
function PlayerStateExecution:start_deploying_bipod(bipod_deploy_duration) end
function PlayerStateExecution:_chk_action_stop_shooting(new_action) end
function PlayerStateExecution:_perform_jump(jump_vec) end
function PlayerStateExecution:set_running(running) end
function PlayerStateExecution:discharge_melee() end
function PlayerStateExecution:_do_action_melee(t, input, skip_damage) end
function PlayerStateExecution:_do_action_intimidate(t, interact_type, sound_name, skip_alert) end
function PlayerStateExecution:_play_distance_interact_redirect(t, variant) end
function PlayerStateExecution:_break_intimidate_redirect(t) end
function PlayerStateExecution:_play_interact_redirect(t) end
function PlayerStateExecution:_break_interact_redirect(t) end
function PlayerStateExecution:_calc_melee_hit_ray(t, sphere_cast_radius) end
function PlayerStateExecution:_do_melee_damage(t, bayonet_melee, melee_hit_ray, melee_entry, hand_id) end
function PlayerStateExecution:_perform_sync_melee_damage(hit_unit, col_ray, damage) end
function PlayerStateExecution:_play_equip_animation() end
function PlayerStateExecution:_play_unequip_animation() end

function PlayerStateExecution:_upd_stance_switch_delay(t, dt) end
function PlayerStateExecution:get_melee_damage_result(attack_data) end
function PlayerStateExecution:get_bullet_damage_result(attack_data) end
function PlayerStateExecution:inventory_clbk_listener(unit, event) end
function PlayerStateExecution:weapon_recharge_clbk_listener() end
function PlayerStateExecution:tweak_data_clbk_reload() end


function PlayerStateExecution:_start_action_steelsight(t, gadget_state) end
function PlayerStateExecution:_start_action_running(t) end
function PlayerStateExecution:_start_action_ducking(t) end
function PlayerStateExecution:_start_action_equip(redirect, extra_time) end
function PlayerStateExecution:_start_action_throw_projectile(t, input) end
function PlayerStateExecution:_start_action_throw_grenade(t, input) end
function PlayerStateExecution:_start_action_interact(t, input, timer, interact_object) end
function PlayerStateExecution:_start_action_use_item(t) end
function PlayerStateExecution:_start_action_intimidate(t, secondary) end
function PlayerStateExecution:_start_action_zipline(t, input, zipline_unit) end
function PlayerStateExecution:_start_action_ladder(t, ladder_unit) end
function PlayerStateExecution:_start_action_reload_enter(t) end
function PlayerStateExecution:_start_action_reload(t) end
function PlayerStateExecution:_start_action_melee(t, input, instant) end
function PlayerStateExecution:_start_action_unequip_weapon(t, data) end
function PlayerStateExecution:_start_action_equip_weapon(t) end
function PlayerStateExecution:_start_action_charging_weapon(t, no_redirect) end
function PlayerStateExecution:_start_action_jump(t, action_start_data) end

function PlayerStateExecution:_update_check_actions(t, dt, paused) end
function PlayerStateExecution:_update_movement(t, dt) end
function PlayerStateExecution:_update_network_position(t, dt, cur_pos, pos_new) end
function PlayerStateExecution:update_check_actions_paused() end
function PlayerStateExecution:_update_melee_timers(t, input) end
function PlayerStateExecution:_update_reload_timers(t, dt, input) end
function PlayerStateExecution:_update_steelsight_timers(t, dt) end
function PlayerStateExecution:_update_use_item_timers(t, input) end
function PlayerStateExecution:_update_foley(t, input) end
function PlayerStateExecution:_update_crosshair_offset(t) end
function PlayerStateExecution:_update_omniscience(t, dt) end
function PlayerStateExecution:_update_running_timers(t) end
function PlayerStateExecution:_update_charging_weapon_timers(t, dt) end
function PlayerStateExecution:_update_equip_weapon_timers(t, input) end
function PlayerStateExecution:_update_throw_projectile_timers(t, input) end
function PlayerStateExecution:_update_throw_grenade_timers(t, input) end
function PlayerStateExecution:_update_interaction_timers(t) end
function PlayerStateExecution:_update_network_jump(pos, is_exit) end
function PlayerStateExecution:_update_zipline_timers(t, dt) end

function PlayerStateExecution:_end_action_zipline(t) end
function PlayerStateExecution:_end_action_use_item(valid) end
function PlayerStateExecution:_end_action_running(t) end
function PlayerStateExecution:_end_action_ducking(t, skip_can_stand_check) end
function PlayerStateExecution:_end_action_interact() end
function PlayerStateExecution:_end_action_steelsight(t) end
function PlayerStateExecution:_end_action_ladder(t, input) end
function PlayerStateExecution:_end_action_charging_weapon(t, no_redirect) end


function PlayerStateExecution:_update_ground_ray() end
function PlayerStateExecution:_calculate_standard_variables(t, dt) end
function PlayerStateExecution:send_reload_interupt() end
function PlayerStateExecution:_get_dir_str_from_vec(fwd, dir_vec) end
function PlayerStateExecution:set_animation_weapon_hold(name_override) end
function PlayerStateExecution:get_weapon_hold_str() end

}
--]]

function PlayerStateExecution:init(unit,...)
	PlayerStateExecution.super.init(self,unit,...)
	self._ext_camera = unit:camera()
--	self:set_animation_state("standard")

	
end

function PlayerStateExecution:enter(state_data,enter_data,...)
	-- hide viewmodel
	-- start anim
	
	PlayerStateExecution.super.enter(self,state_data,enter_data,...)
	GloryKills.set_viewmodel_visible(self,false)
end

function PlayerStateExecution:_enter(enter_data,...)
	PlayerStateExecution.super._enter(self,enter_data,...)
end

function PlayerStateExecution:exit(state_data,...)
	self._state_data.melee_attack_wanted = nil
	self._state_data.melee_attack_allowed_t = nil
	
	PlayerStateExecution.super.exit(self,state_data,...)	
	
	GloryKills.set_viewmodel_visible(self,true)
	
	if alive(GloryKills.unit) then
		GloryKills.unit:set_position(Vector3(0,0,-10000))
	end
end

function PlayerStateExecution:update(t,dt)
	
end

function PlayerStateExecution:pre_destroy(...)
	PlayerStateExecution.super.pre_destroy(self,...)
end


----------------------------------


function PlayerStateExecution:_action_interact_forbidden() 
	return true
end

function PlayerStateExecution:interaction_blocked()
	return true
end

function PlayerStateExecution:bleed_out_blocked()
	return true
end

function PlayerStateExecution:_get_input(t, dt, paused) 
	return {}
end

function PlayerStateExecution:_determine_move_direction()
	return
end

function PlayerStateExecution:_get_max_walk_speed(t, force_run)
	return 0
end

function PlayerStateExecution:_activate_mover(mover, velocity) end
function PlayerStateExecution:_chk_floor_moving_pos(pos) end
function PlayerStateExecution:force_input(inputs, release_inputs) end
function PlayerStateExecution:_upd_attention() end
function PlayerStateExecution:_find_pickups(t) end
function PlayerStateExecution:push(vel) end

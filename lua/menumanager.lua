GloryKills = {
	
	fp_unit = nil, -- the fp unit
	unit = nil, -- the 3p unit
	head_obj = nil, -- object
	delayed_events = {}
}
GloryKills.HUSK_NAMES = {
	wild = "units/pd2_dlc_wild/characters/npc_criminals_wild_1/player_criminal_wild_husk",
	joy = "units/pd2_dlc_joy/characters/npc_criminals_joy_1/player_criminal_joy_husk"
}
-- copied this from third person mod. thanks hoppip
function GloryKills:spawn_third_unit(unit)
	local SETTING_IMMERSIVE_FIRST_PERSON = true
	local SETTING_CUSTOM_WEAPONS = false
	local SETTING_START_IN_THIRD_PERSON = false
	
	local unit_ids = Idstring("unit")
	
	
	local player = unit or managers.player:local_player()
	if not player then
		return
	end
	local player_peer = player:network():peer()
	local player_movement = player:movement()
	local pos = player_movement:m_pos()
	local rot = player_movement:m_head_rot()
	local char_id = player_peer:character_id() -- returns "locked" in some cases? not sure why, so this will be the fallback
	
	--[[
	-- get ai name for this character
	local char_name = managers.criminals:character_name_by_peer_id(player_peer:id())
	for _,data in pairs(tweak_data.criminals.characters) do 
		if data.name == CriminalsManager.convert_new_to_old_character_workname(char_name) then
			char_id = data.static_data.ai_character_id
			break
		end
	end
	--]]
	
	-- get the 3p unit for this ai
	local unit_name = self.HUSK_NAMES[char_id] or tweak_data.blackmarket.characters[char_id].npc_unit:gsub("(.+)/npc_", "%1/player_") .. "_husk"
	local unit_name_ids = Idstring(unit_name)

	if not DB:has(unit_ids, unit_name_ids) then
		self.fp_unit = nil
		self.unit = nil
		return
	end

	self.fp_unit = player
	self.unit = alive(self.unit) and self.unit or World:spawn_unit(unit_name_ids, pos, rot)
	self.head_obj = self.unit:get_object(Idstring("Head"))
	Network:detach_unit(self.unit)

	-- The third person unit should be destroyed whenever the first person unit is destroyed
	player:base().pre_destroy = function (_self, ...)
		if alive(self.unit) then
			World:delete_unit(self.unit)
		end
		PlayerBase.pre_destroy(_self, ...)
	end

	local unit_base = self.unit:base()
	local unit_movement = self.unit:movement()
	local unit_inventory = self.unit:inventory()
	local unit_sound = self.unit:sound()

	-- Hook some functions
	unit_base.pre_destroy = function (self, unit)
		self._unit:movement():pre_destroy(unit)
		self._unit:inventory():pre_destroy(self._unit)
		UnitBase.pre_destroy(self, unit)
	end

	-- No contours
	self.unit:contour().add = function () end

	-- No revive SO
	unit_movement._register_revive_SO = function () end
	unit_movement.set_need_assistance = function (self, need_assistance) self._need_assistance = need_assistance end
	unit_movement.set_need_revive = function (self, need_revive) self._need_revive = need_revive end

	local look_vec_modified = Vector3()
	unit_movement.update = function (_self, ...)
	--[[
		HuskPlayerMovement.update(_self, ...)
		if alive(self.fp_unit) then
			-- correct aiming direction so that lasers are approximately the same in first and third person
			mvector3.set(look_vec_modified, self.fp_unit:camera():forward())
			mvector3.rotate_with(look_vec_modified, Rotation(self.fp_unit:camera():rotation():z(), 1))
			_self:set_look_dir_instant(look_vec_modified)
		end
	--]]
	end

--	unit_movement.play_redirect = function(self,redirect_name,at_time)
--		if not foobar then GloryKills:Print("play_redirect",redirect_name,debug.traceback()) end
--	end

	unit_movement.play_state = function(self,state_name,at_time)
--		if not foobar then GloryKills:Print("play_state",state_name,debug.traceback()) end
	end

	unit_movement.sync_action_walk_nav_point = function (_self, pos, speed, action)
		_self._movement_path = _self._movement_path or {}
		_self._movement_history = _self._movement_history or {}

		local state = alive(self.fp_unit) and self.fp_unit:movement():current_state()
		if not state then
			return
		end

		local path_len = #_self._movement_path
		pos = pos or path_len > 0 and _self._movement_path[path_len].pos or mvector3.copy(_self:m_pos())

		local type = state._state_data.on_zipline and "zipline" or (not state._gnd_ray or state._is_jumping) and "air" or "ground"

		local node = {
			pos = pos,
			speed = speed or 1,
			type = type,
			action = {action}
		}
		table.insert(_self._movement_path, node)
		table.insert(_self._movement_history, node)
		local len = #_self._movement_history
		if len > 1 then
			_self:_determine_node_action(#_self._movement_history, node)
		end
		for i = 1, #_self._movement_history - tweak_data.network.player_path_history, 1 do
			table.remove(_self._movement_history, 1)
		end
	end

	local hide_vec = Vector3(0, 0, -10000)
	unit_movement.set_position = function (_self, pos)
		if false then -- if alive(self.fp_unit) and self.fp_unit:camera():first_person() then
			_self._unit:set_position(hide_vec)
		else
			-- partial fix for movement sync, not perfect as it overrides some movement animations like jumping
			pos = alive(self.fp_unit) and self.fp_unit:movement():m_pos() or pos
			_self._unit:set_position(pos)
			mvector3.set(_self._m_pos, pos)
		end
	end

	unit_movement.set_head_visibility = function (self, visible)
		self._obj_visibilities = self._obj_visibilities or {}
		local char_name = managers.criminals:character_name_by_unit(self._unit)
		local new_char_name = managers.criminals.convert_old_to_new_character_workname(char_name)
		-- Disable head and hair objects - many thanks for being inconsistent with naming your objects, Overkill
		local try_names = { "g_vest_neck", "g_head", "g_head_%s", "g_%s_mask_off", "g_%s_mask_on", "g_hair", "g_%s_hair", "g_hair_mask_on", "g_hair_mask_off" }
		local obj, key
		for _, v in ipairs(try_names) do
			obj = char_name and self._unit:get_object(Idstring(v:format(char_name))) or new_char_name and self._unit:get_object(Idstring(v:format(new_char_name)))
			if obj then
				key = obj:name():key()
				self._obj_visibilities[key] = self._obj_visibilities[key] or obj:visibility()
				obj:set_visibility(visible and self._obj_visibilities[key])
			end
		end
		self._mask_visibility = self._mask_visibility or self._unit:inventory()._mask_visibility
		self._unit:inventory():set_mask_visibility(visible and self._mask_visibility)
	end

	unit_inventory.set_mask_visibility = function (self, state)
		HuskPlayerInventory.set_mask_visibility(self, not SETTING_CUSTOM_WEAPONS and state)
	end

	-- adjust weapon switch to support custom weapons
	local default_weaps = { "wpn_fps_pis_g17_npc", "wpn_fps_ass_amcar_npc" }
	unit_inventory._perform_switch_equipped_weapon = function (_self, weap_index, blueprint_string, cosmetics_string, peer)
		self._checked_weapons = self._checked_weapons or {}
		if not self._checked_weapons[weap_index] then
			local equipped = self.fp_unit:inventory():equipped_unit()
			local checked_weap = {
				name = equipped:base()._factory_id and equipped:base()._factory_id .. "_npc" or "wpn_fps_ass_amcar_npc",
				cosmetics_string = cosmetics_string or _self:cosmetics_string_from_peer(peer, checked_weap.name),
				blueprint_string = blueprint_string or equipped:blueprint_to_string()
			}

			local factory_weapon = tweak_data.weapon.factory[checked_weap.name]
			if not factory_weapon or factory_weapon.custom and not SETTING_CUSTOM_WEAPONS then
				local weapon = tweak_data.weapon[managers.weapon_factory:get_weapon_id_by_factory_id(equipped:base()._factory_id or "wpn_fps_ass_amcar_npc")]
				local based_on = weapon and weapon.based_on and tweak_data.weapon[weapon.based_on]
				local based_on_name = based_on and tweak_data.upgrades.definitions[weapon.based_on] and tweak_data.upgrades.definitions[weapon.based_on].factory_id
				local new_name = based_on_name and based_on.use_data.selection_index == weapon.use_data.selection_index and (based_on_name .. "_npc") or weapon and default_weaps[weapon.use_data.selection_index] or default_weaps[1]

				--ThirdPerson:log("Replaced custom weapon " .. checked_weap.name .. " with " .. new_name)

				checked_weap.name = new_name
				checked_weap.blueprint_string = managers.weapon_factory:blueprint_to_string(checked_weap.name, managers.weapon_factory:get_default_blueprint_by_factory_id(checked_weap.name))
				checked_weap.cosmetics_string = "nil-1-0"
			end

			self._checked_weapons[weap_index] = checked_weap
		end

		local checked_weap = self._checked_weapons[weap_index]
		if checked_weap then
			_self:add_unit_by_factory_name(checked_weap.name, true, true, checked_weap.blueprint_string, checked_weap.cosmetics_string)
		end
	end

	-- We don't want our third person unit to make any sound, so we're plugging empty functions here
	unit_sound.say = function () end
	unit_sound.play = function () end
	unit_sound._play = function () end

	-- Setup some stuff
	unit_inventory:set_melee_weapon(player_peer:melee_id(), true)

	self.unit:damage():run_sequence_simple(managers.blackmarket:character_sequence_by_character_id(player_peer:character_id(), player_peer:id()))

	unit_movement:set_character_anim_variables()
	if SETTING_IMMERSIVE_FIRST_PERSON then
		unit_movement:set_head_visibility(false)
	end

	local level_data = managers.job and managers.job:current_level_data()
	if level_data and level_data.player_sequence then
		self.unit:damage():run_sequence_simple(level_data.player_sequence)
	end

	-- Call missed events
	local handler = managers.network and managers.network._handlers and managers.network._handlers.unit
	if handler then
		for _, v in ipairs(self.delayed_events) do
			if handler[v.func] then
				handler[v.func](handler, self.unit, unpack(v.params))
			end
		end
		self.delayed_events = {}
	end

	--[[
	if SETTING_START_IN_THIRD_PERSON then
		player:camera():set_third_person()
	else
		player:camera()._toggled_fp = true
	end
	--]]

	-- Unregister from groupai manager so it doesnt count as an actual criminal
	managers.groupai:state():unregister_criminal(self.unit)

end

function GloryKills.set_viewmodel_visible(state,visible)
	local fp = state._camera_unit
	fp:set_visible(visible)
	if not visible then
		fp:base():hide_weapon()
	else
		fp:base():show_weapon()
	end
	for unit_id, unit_entry in pairs(fp:spawn_manager():spawned_units()) do
		if alive(unit_entry.unit) then
			unit_entry.unit:set_visible(visible)
		end
	end
end

function GloryKills:Print(...)
	if _G.Print then _G.Print(...) end
end

--[[
local mvec_1 = Vector3()
local mvec_2 = Vector3()
function GloryKills.copdamage_execution(self,attack_data)
	if self._dead or self._invulnerable then
		return
	end

	if PlayerDamage.is_friendly_fire(self, attack_data.attacker_unit) then
		return "friendly_fire"
	end

	if self:chk_immune_to_attacker(attack_data.attacker_unit) then
		return
	end

	local result = nil
	local is_civlian = CopDamage.is_civilian(self._unit:base()._tweak_table)
	local is_gangster = CopDamage.is_gangster(self._unit:base()._tweak_table)
	local is_cop = not is_civlian and not is_gangster
	local head = self._head_body_name and attack_data.col_ray.body and attack_data.col_ray.body:name() == self._ids_head_body_name
	local damage = attack_data.damage

	if attack_data.attacker_unit and attack_data.attacker_unit == managers.player:player_unit() then
		local critical_hit, crit_damage = self:roll_critical_hit(attack_data, damage)

		if critical_hit then
			managers.hud:on_crit_confirmed()

			damage = crit_damage
			attack_data.critical_hit = true
		else
			managers.hud:on_hit_confirmed()
		end

		if tweak_data.achievement.cavity.melee_type == attack_data.name_id and not CopDamage.is_civilian(self._unit:base()._tweak_table) then
			managers.achievment:award(tweak_data.achievement.cavity.award)
		end
	end

	damage = damage * (self._marked_dmg_mul or 1)

	if self._unit:movement():cool() then
		damage = self._HEALTH_INIT
	end

	local damage_effect = attack_data.damage_effect
	local damage_effect_percent = 1
	damage = self:_apply_damage_reduction(damage)
	damage = math.clamp(damage, self._HEALTH_INIT_PRECENT, self._HEALTH_INIT)
	local damage_percent = math.ceil(damage / self._HEALTH_INIT_PRECENT)
	damage = damage_percent * self._HEALTH_INIT_PRECENT
	damage, damage_percent = self:_apply_min_health_limit(damage, damage_percent)

	if self._immortal then
		damage = math.min(damage, self._health - 1)
	end

	if self._health <= damage then
--		if self:check_medic_heal() then
--			result = {
--				type = "healed",
--				variant = attack_data.variant
--			}
--		else
			damage_effect_percent = 1
			attack_data.damage = self._health
			result = {
				type = "death",
				variant = attack_data.variant
			}

			self:die(attack_data)
			self:chk_killshot(attack_data.attacker_unit, "melee", false, attack_data.name_id)
--		end
	else
		attack_data.damage = damage
		damage_effect = math.clamp(damage_effect, self._HEALTH_INIT_PRECENT, self._HEALTH_INIT)
		damage_effect_percent = math.ceil(damage_effect / self._HEALTH_INIT_PRECENT)
		damage_effect_percent = math.clamp(damage_effect_percent, 1, self._HEALTH_GRANULARITY)
		local result_type = attack_data.shield_knock and self._char_tweak.damage.shield_knocked and "shield_knock" or attack_data.variant == "counter_tased" and "counter_tased" or attack_data.variant == "taser_tased" and "taser_tased" or attack_data.variant == "counter_spooc" and "expl_hurt" or self:get_damage_type(damage_effect_percent, "melee") or "fire_hurt"
		result = {
			type = result_type,
			variant = attack_data.variant
		}

		self:_apply_damage_to_health(damage)
	end

	attack_data.result = result
	attack_data.pos = attack_data.col_ray.position
	local dismember_victim = false
	local snatch_pager = false

	if result.type == "death" then
		if self:_dismember_condition(attack_data) then
			self:_dismember_body_part(attack_data)

			dismember_victim = true
		end

		local data = {
			name = self._unit:base()._tweak_table,
			stats_name = self._unit:base()._stats_name,
			head_shot = head,
			weapon_unit = attack_data.weapon_unit,
			name_id = attack_data.name_id,
			variant = attack_data.variant
		}

		managers.statistics:killed_by_anyone(data)

		if attack_data.attacker_unit == managers.player:player_unit() then
			self:_comment_death(attack_data.attacker_unit, self._unit)
			self:_show_death_hint(self._unit:base()._tweak_table)
			managers.statistics:killed(data)

			if not is_civlian and managers.groupai:state():whisper_mode() and managers.blackmarket:equipped_mask().mask_id == tweak_data.achievement.cant_hear_you_scream.mask then
				managers.achievment:award_progress(tweak_data.achievement.cant_hear_you_scream.stat)
			end

			mvector3.set(mvec_1, self._unit:position())
			mvector3.subtract(mvec_1, attack_data.attacker_unit:position())
			mvector3.normalize(mvec_1)
			mvector3.set(mvec_2, self._unit:rotation():y())

			local from_behind = mvector3.dot(mvec_1, mvec_2) >= 0

			if is_cop and Global.game_settings.level_id == "nightclub" and attack_data.name_id and attack_data.name_id == "fists" then
				managers.achievment:award_progress(tweak_data.achievement.final_rule.stat)
			end

			if is_civlian then
				managers.money:civilian_killed()
			elseif math.rand(1) < managers.player:upgrade_value("player", "melee_kill_snatch_pager_chance", 0) then
				snatch_pager = true
				self._unit:unit_data().has_alarm_pager = false
			end
		end
	end

	self:_check_melee_achievements(attack_data)

	local hit_offset_height = math.clamp(attack_data.col_ray.position.z - self._unit:movement():m_pos().z, 0, 300)
	local variant = nil

	if result.type == "shield_knock" then
		variant = 1
	elseif result.type == "counter_tased" then
		variant = 2
	elseif result.type == "expl_hurt" then
		variant = 4
	elseif snatch_pager then
		variant = 3
	elseif result.type == "taser_tased" then
		variant = 5
	elseif dismember_victim then
		variant = 6
	elseif result.type == "healed" then
		variant = 7
	else
		variant = 0
	end

	local body_index = self._unit:get_body_index(attack_data.col_ray.body:name())

	self:_send_melee_attack_result(attack_data, damage_percent, damage_effect_percent, hit_offset_height, variant, body_index)
	self:_on_damage_received(attack_data)

	result.attack_data = attack_data

	return result
end
--]]
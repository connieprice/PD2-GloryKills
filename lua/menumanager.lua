GloryKills = {
	
	fp_unit = nil, -- the fp unit
	unit = nil, -- the 3p unit
	head_obj = nil, -- object
	delayed_events = {},
	_character_visual_state = {}
}
GloryKills.HUSK_NAMES = {
	wild = "units/pd2_dlc_wild/characters/npc_criminals_wild_1/player_criminal_wild_husk",
	joy = "units/pd2_dlc_joy/characters/npc_criminals_joy_1/player_criminal_joy_husk"
}
GloryKills.ALLOWED_PLAYER_STATES = {
	standard = true,
	carry = true,
	execution = false, -- custom obviously
	
	empty = false,
	mask_off = false,
	bleed_out = false,
	fatal = false,
	arrested = false,
	tased = false,
	incapacitated = false,
	clean = false,
	civilian = false,
	bipod = false,
	driving = false,
	jerry2 = false,
	jerry1 = false,
	player_turret = false
}

-- copied this from third person mod. thanks hoppip
function GloryKills:spawn_third_unit(unit,character_name,visual_seed)

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
	local unit_name = self.HUSK_NAMES[char_id] or tweak_data.blackmarket.characters[char_id].npc_unit .. "_husk"
	--]]
	
	-- get the 3p unit
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

	unit_movement.set_head_visibility = function (_self, visible)
		_self._obj_visibilities = _self._obj_visibilities or {}
		local char_name = managers.criminals:character_name_by_unit(_self._unit)
		local new_char_name = managers.criminals.convert_old_to_new_character_workname(char_name)
		-- Disable head and hair objects - many thanks for being inconsistent with naming your objects, Overkill
		local try_names = { "g_vest_neck", "g_head", "g_head_%s", "g_%s_mask_off", "g_%s_mask_on", "g_hair", "g_%s_hair", "g_hair_mask_on", "g_hair_mask_off" }
		local obj, key
		for _, v in ipairs(try_names) do
			obj = char_name and _self._unit:get_object(Idstring(v:format(char_name))) or new_char_name and _self._unit:get_object(Idstring(v:format(new_char_name)))
			if obj then
				key = obj:name():key()
				_self._obj_visibilities[key] = _self._obj_visibilities[key] or obj:visibility()
				obj:set_visibility(visible and _self._obj_visibilities[key])
			end
		end
		_self._mask_visibility = _self._mask_visibility or _self._unit:inventory()._mask_visibility
		_self._unit:inventory():set_mask_visibility(visible and _self._mask_visibility)
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
	
	
	
	
	
	local bm_mgr = managers.blackmarket
-- for whatever reason, the outfit string parses incorrectly for me, and honestly it's unnecessary work anyway
--	local loadout = managers.blackmarket:unpack_henchman_loadout_string(outfit_string)
--	local player_style = loadout and loadout.player_style or managers.blackmarket:get_default_player_style()
--	local suit_variation = loadout and loadout.suit_variation or "default"
--	local glove_id = loadout and loadout.glove_id or managers.blackmarket:get_default_glove_id()
	local visual_state = {
		armor_skin = tostring(bm_mgr:equipped_armor_skin() or "none"),
		armor_id = tostring(bm_mgr:equipped_armor(true) or "level_1"),
		visual_seed = visual_seed,
		player_style = tostring(bm_mgr:equipped_player_style()),
		suit_variation = tostring(bm_mgr:get_suit_variation()),
		glove_id = tostring(bm_mgr:equipped_glove_id()),
		mask_id = tostring(bm_mgr:equipped_mask().mask_id)
	}
	self:upd_visual_state(character_name,visual_state)
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

function GloryKills:upd_visual_state(character_name,visual_state) -- based on CriminalsManager:update_character_visual_state() and CriminalsManager.set_character_visual_state()
-- the reason for replacing it is so that this doesn't interfere with the character data
	local unit = self.unit
	
	local ids_unit = Idstring("unit")
	local _prev_visual_state = self._character_visual_state
	visual_state = visual_state or {}
	
	local visual_seed = visual_state.visual_seed or _prev_visual_state.visual_seed or CriminalsManager.get_new_visual_seed()
	local mask_id = visual_state.mask_id or _prev_visual_state.mask_id
	local armor_id = visual_state.armor_id or _prev_visual_state.armor_id or "level_1"
	local armor_skin = visual_state.armor_skin or _prev_visual_state.armor_skin or "none"
	local deployable_id = false

	if visual_state.deployable_id ~= nil then
		deployable_id = visual_state.deployable_id
	elseif _prev_visual_state.deployable_id then
		deployable_id = _prev_visual_state.deployable_id
	end
	
	local crim_mgr = managers.criminals
	
	local player_style = crim_mgr:active_player_style() or managers.blackmarket:get_default_player_style()
	local suit_variation = nil
	local user_player_style = visual_state.player_style or _prev_visual_state.player_style or managers.blackmarket:get_default_player_style()

	if not crim_mgr:is_active_player_style_locked() and user_player_style ~= managers.blackmarket:get_default_player_style() then
		player_style = user_player_style
		suit_variation = visual_state.suit_variation or _prev_visual_state.suit_variation or "default"
	end

	local glove_id = visual_state.glove_id or _prev_visual_state.glove_id or managers.blackmarket:get_default_glove_id()
	local character_visual_state = {
		is_local_peer = false,
		visual_seed = visual_seed,
		player_style = player_style,
		suit_variation = suit_variation,
		glove_id = glove_id,
		mask_id = mask_id,
		armor_id = armor_id,
		armor_skin = armor_skin,
		deployable_id = deployable_id
	}
	self._character_visual_state = character_visual_state


	if player_style then
		local unit_name = tweak_data.blackmarket:get_player_style_value(player_style, character_name, "third_unit")

		if unit_name then
			managers.dyn_resource:load(ids_unit, Idstring(unit_name), managers.dyn_resource.DYN_RESOURCES_PACKAGE, nil)
--			crim_mgr:safe_load_asset(character, unit_name, "player_style")
		end
	end

	if glove_id then
		local unit_name = tweak_data.blackmarket:get_glove_value(glove_id, character_name, "unit", player_style, suit_variation)

		if unit_name then
			managers.dyn_resource:load(ids_unit, Idstring(unit_name), managers.dyn_resource.DYN_RESOURCES_PACKAGE, nil)
--			crim_mgr:safe_load_asset(character, unit_name, "glove_id")
		end
	end

	if deployable_id then
		local deployable_tweak_data = tweak_data.equipments[deployable_id]
		local style_name = deployable_tweak_data.visual_style

		if style_name then
			local unit_name = tweak_data.blackmarket:get_player_style_value(style_name, character_name, "third_unit")

			if unit_name then
				managers.dyn_resource:load(ids_unit, Idstring(unit_name), managers.dyn_resource.DYN_RESOURCES_PACKAGE, nil)
--				crim_mgr:safe_load_asset(character, unit_name, "deployable_id")
			end
		end
	end

	CriminalsManager.set_character_visual_state(unit, character_name, character_visual_state)
--[[
	self._character_visual_state = {
		is_local_peer = false,
		visual_seed = visual_seed,
		player_style = user_player_style,
		suit_variation = suit_variation,
		glove_id = glove_id,
		mask_id = mask_id,
		armor_id = armor_id,
		armor_skin = armor_skin,
		deployable_id = deployable_id
	}
--]]
end

local mrot1 = Rotation()
local mrot2 = Rotation()
local mrot3 = Rotation()
local mrot4 = Rotation()
local mvec1 = Vector3()
local mvec2 = Vector3()
local mvec3 = Vector3()
local mvec4 = Vector3()
local mvec1 = Vector3()

local orig_update_rot = Hooks:GetFunction(FPCameraPlayerBase,"_update_rot")
function FPCameraPlayerBase:_update_rot(axis, unscaled_axis)
	if self._animate_pitch then
		self:animate_pitch_upd()
	end

	local t = managers.player:player_timer():time()
	local dt = t - (self._last_rot_t or t)
	self._last_rot_t = t
	local data = self._camera_properties
	local new_head_pos = mvec2
	local new_shoulder_pos = mvec1
	local new_shoulder_rot = mrot1
	local new_head_rot = mrot2

	self._parent_unit:m_position(new_head_pos)
	mvector3.add(new_head_pos, self._head_stance.translation)

	self._input.look = axis 
	self._input.look_multiplier = self._parent_unit:base():controller():get_setup():get_connection("look"):get_multiplier()
	local stick_input_x, stick_input_y = self._look_function(axis, self._input.look_multiplier, dt, unscaled_axis)
	local look_polar_spin = data.spin - stick_input_x
	local look_polar_pitch = math.clamp(data.pitch + stick_input_y, -85, 85)
	local player_state = managers.player:current_state()

	if self._limits then
		if self._limits.spin then
			local d = (look_polar_spin - self._limits.spin.mid) / self._limits.spin.offset
			d = math.clamp(d, -1, 1)
			look_polar_spin = data.spin - math.lerp(stick_input_x, 0, math.abs(d))
		end

		if self._limits.pitch then
			local d = math.abs((look_polar_pitch - self._limits.pitch.mid) / self._limits.pitch.offset)
			d = math.clamp(d, -1, 1)
			look_polar_pitch = data.pitch + math.lerp(stick_input_y, 0, math.abs(d))
			look_polar_pitch = math.clamp(look_polar_pitch, -85, 85)
		end
	end

	if not self._limits or not self._limits.spin then
		look_polar_spin = look_polar_spin % 360
	end

	local look_polar = Polar(1, look_polar_pitch, look_polar_spin)
	local look_vec = look_polar:to_vector()
	local cam_offset_rot = mrot3

	mrotation.set_look_at(cam_offset_rot, look_vec, math.UP)

	if self._animate_pitch == nil then
		mrotation.set_zero(new_head_rot)
		mrotation.multiply(new_head_rot, self._head_stance.rotation)
		mrotation.multiply(new_head_rot, cam_offset_rot)

		data.pitch = look_polar_pitch
		data.spin = look_polar_spin
	end

	self._output_data.position = new_head_pos

	if self._p_exit then
		self._p_exit = false
		self._output_data.rotation = self._parent_unit:movement().fall_rotation

		mrotation.multiply(self._output_data.rotation, self._parent_unit:camera():rotation())

		data.spin = self._output_data.rotation:y():to_polar().spin
	else
		self._output_data.rotation = new_head_rot or self._output_data.rotation
	end

	if self._camera_properties.current_tilt ~= self._camera_properties.target_tilt then
		self._camera_properties.current_tilt = math.step(self._camera_properties.current_tilt, self._camera_properties.target_tilt, 150 * dt)
	end

	if self._camera_properties.current_tilt ~= 0 then
		self._output_data.rotation = Rotation(self._output_data.rotation:yaw(), self._output_data.rotation:pitch(), self._output_data.rotation:roll() + self._camera_properties.current_tilt)
	end

	mvector3.set(new_shoulder_pos, self._shoulder_stance.translation)
	mvector3.add(new_shoulder_pos, self._vel_overshot.translation)
	mvector3.rotate_with(new_shoulder_pos, self._output_data.rotation)
	mvector3.add(new_shoulder_pos, new_head_pos)
	mrotation.set_zero(new_shoulder_rot)
	mrotation.multiply(new_shoulder_rot, self._output_data.rotation)
	mrotation.multiply(new_shoulder_rot, self._shoulder_stance.rotation)
	mrotation.multiply(new_shoulder_rot, self._vel_overshot.rotation)

	if player_state == "driving" then
		self:_set_camera_position_in_vehicle()
	elseif player_state == "jerry1" or player_state == "jerry2" then
		mrotation.set_zero(cam_offset_rot)
		mrotation.multiply(cam_offset_rot, self._parent_unit:movement().fall_rotation)
		mrotation.multiply(cam_offset_rot, self._output_data.rotation)

		local shoulder_pos = mvec3
		local shoulder_rot = mrot4

		mrotation.set_zero(shoulder_rot)
		mrotation.multiply(shoulder_rot, cam_offset_rot)
		mrotation.multiply(shoulder_rot, self._shoulder_stance.rotation)
		mrotation.multiply(shoulder_rot, self._vel_overshot.rotation)
		mvector3.set(shoulder_pos, self._shoulder_stance.translation)
		mvector3.add(shoulder_pos, self._vel_overshot.translation)
		mvector3.rotate_with(shoulder_pos, cam_offset_rot)
		mvector3.add(shoulder_pos, self._parent_unit:position())
		self:set_position(shoulder_pos)
		self:set_rotation(shoulder_rot)
		self._parent_unit:camera():set_position(self._parent_unit:position())
		self._parent_unit:camera():set_rotation(cam_offset_rot)
	elseif player_state == "bipod" then
		local movement_state = self._parent_unit:movement():current_state()

		self:set_position(movement_state._shoulder_pos or new_shoulder_pos)
		self:set_rotation(new_shoulder_rot)
		self._parent_unit:camera():set_position(movement_state._camera_pos or self._output_data.position)
		self._parent_unit:camera():set_rotation(self._output_data.rotation)
	elseif player_state == "player_turret" then
		self:set_position(new_shoulder_pos)
		self:set_rotation(new_shoulder_rot)
		self._parent_unit:camera():set_position(self._output_data.position)
		self._parent_unit:camera():set_rotation(self._output_data.rotation)
	else
		self:set_position(new_shoulder_pos)
		self:set_rotation(new_shoulder_rot)
		self._parent_unit:camera():set_position(self._output_data.position)
		self._parent_unit:camera():set_rotation(self._output_data.rotation)
	end
	
	local player = managers.player:local_player()
	if alive(player) then
		local mov_ext = player:movement()
		local state_name = mov_ext and mov_ext:current_state_name()
		if state_name == "execution" then
			if alive(GloryKills.unit) then
				local obj = GloryKills.unit:get_object(Idstring("eyeAim"))
				mvector3.set(mvec1,obj:rotation():z())
				local p = mvec1:to_polar()
				
				self._camera_properties.pitch = p.pitch
				self._camera_properties.spin = p.spin
			end
		end
	end
	
end



--]]


--[[
function FPCameraPlayerBase:update(unit, t, dt)
	if self._tweak_data.aim_assist_use_sticky_aim then
		self:_update_aim_assist_sticky(t, dt)
	end

	if _G.IS_VR and self._hmd_tracking and not self._block_input then
		self._output_data.rotation = self._base_rotation * VRManager:hmd_rotation()
	end

	if not _G.IS_VR then
		if USE_THIRD then
			
		else
			self._parent_unit:base():controller():get_input_axis_clbk("look", callback(self, self, "_update_rot"))
		end
	end

	self:_update_stance(t, dt)
	self:_update_movement(t, dt)

	if managers.player:current_state() ~= "driving" then
		self._parent_unit:camera():set_position(self._output_data.position)
		self._parent_unit:camera():set_rotation(self._output_data.rotation)
	else
		self:_set_camera_position_in_vehicle()
	end

	if _G.IS_VR then
		self:_update_fadeout(self._output_data.mover_position, self._output_data.position, self._output_data.rotation, t, dt)
		self._parent_unit:camera():update_transform()
	end

	if self._fov.dirty then
		self._parent_unit:camera():set_FOV(self._fov.fov)

		self._fov.dirty = nil
	end

	if alive(self._light) then
		local weapon = self._parent_unit:inventory():equipped_unit()

		if weapon then
			local object = weapon:get_object(Idstring("fire"))
			local pos = object:position() + object:rotation():y() * 10 + object:rotation():x() * 0 + object:rotation():z() * -2

			self._light:set_position(pos)
			self._light:set_rotation(Rotation(object:rotation():z(), object:rotation():x(), object:rotation():y()))
			World:effect_manager():move_rotate(self._light_effect, pos, Rotation(object:rotation():x(), -object:rotation():y(), -object:rotation():z()))
		end
	end
end
--]]









-- these aren't currently used

function FPCameraPlayerBase:anim_execution_slap(...)

end
function FPCameraPlayerBase:anim_execution_punchthroat(...)

end
function FPCameraPlayerBase:anim_execution_grab(...)

end
function FPCameraPlayerBase:anim_execution_generic(s)
	GloryKills:Print("Animation callback:",s)
end
function FPCameraPlayerBase:anim_execution_kill(...)
	local player = managers.player:local_player()
	local mov_ext = alive(player) and player:movement()
	local state = mov_ext and mov_ext:current_state()
	if state then 
		mov_ext:change_state("standard")
	end
end

function FPCameraPlayerBase:anim_start_execution(...)
	GloryKills:Print("FPCameraPlayerBase:anim_start_execution()")
--	managers.player:local_player():movement():change_state("standard")
end

function FPCameraPlayerBase:anim_stop_execution(...)
	GloryKills:Print("FPCameraPlayerBase:anim_stop_execution()")
	managers.player:local_player():movement():change_state("standard")
end




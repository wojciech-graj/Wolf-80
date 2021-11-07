-- title: FPS-80
-- author: Wojciech Graj
-- desc: Raycast FPS game
-- script: lua
-- input: gamepad

function g_math_sign(x)
	return x>0 and 1 or x<0 and -1 or 0
end

function g_entity_move(self, speed)
	local math_floor = math.floor
	local math_sign = g_math_sign
	local math_min = math.min
	local math_max = math.max

	local sign_speed = math_sign(speed)

	if mget(
		math_max(math_min(math_floor(self.pos_x + self.dir_x * speed + sign_speed * math_sign(self.dir_x) * 0.25), g_LEVEL_WIDTH - 1), 0),
		math_floor(self.pos_y)) == 0 then
		self.pos_x = self.pos_x + self.dir_x * speed
	end
	if mget(
		math_floor(self.pos_x),
		math_max(math_min(math_floor(self.pos_y + self.dir_y * speed + sign_speed * math_sign(self.dir_y) * 0.25), g_LEVEL_HEIGHT - 1), 0)) == 0 then
		self.pos_y = self.pos_y + self.dir_y * speed
	end
end

Weapon = {
	ui_tex_idx = 0,
	ammo = 0,
	weapon_texture_y = 0,
	textures_x = {},
	raise_time = 0,
	shoot_time = 0,
	reload_time = 0,
	double_spread_angle = 0,
	min_dmg = 0,
	max_dmg = 0,
	n_pellets = 0,
	range_sqr = 0,
}
Weapon.__index = Weapon

-- Weapon States:
-- 0: raise
-- 1: lower
-- 2: ready
-- 3: shoot
-- 4: reload

function Weapon.new(ui_tex_idx, ammo, texture_y, textures_x, raise_time, shoot_time, reload_time, spread_angle, min_dmg, max_dmg, n_pellets, range)
	local self = setmetatable({}, Weapon)
	self.ui_tex_idx = ui_tex_idx
	self.ammo = ammo
	self.texture_y = texture_y
	self.textures_x = textures_x
	self.raise_time = raise_time
	self.shoot_time = shoot_time
	self.reload_time = reload_time
	self.double_spread_angle = spread_angle * 2
	self.min_dmg = min_dmg
	self.max_dmg = max_dmg
	self.n_pellets = n_pellets
	self.range_sqr = range * range
	return self
end

function g_ray_entity_collides(rel_pos_x, rel_pos_y, dir_x, dir_y, hitbox_rad)
	if (rel_pos_x * dir_x + rel_pos_y * dir_y) / math.sqrt(rel_pos_x * rel_pos_x + rel_pos_y * rel_pos_y) > 0 then --in front
		local dist_perp = math.abs(dir_x * rel_pos_y - dir_y * rel_pos_x)
		if dist_perp < hitbox_rad then
			return true
		end
	end
	return false
end

-- Target Types
-- 0: Player
-- 1: Enemies
function Weapon:shoot(entity, target_type)
	local math_cos = math.cos
	local math_sin = math.sin
	local math_random = math.random
	local math_floor = math.floor
	local math_abs = math.abs
	local ray_entity_collides = g_ray_entity_collides

        sfx(0)

	self.ammo = self.ammo - 1

	for _=1,self.n_pellets do
		local angle = (math_random() - 0.5) * self.double_spread_angle
		local dir_x = entity.dir_x * math_cos(angle) - entity.dir_y * math_sin(angle)
		local dir_y = entity.dir_x * math_sin(angle) + entity.dir_y * math_cos(angle)
		local damage = math_floor(math_random(self.min_dmg, self.max_dmg))

		local map_x = math_floor(entity.pos_x)
		local map_y = math_floor(entity.pos_y)
		local delta_dist_x = math_abs(1 / dir_x)
		local delta_dist_y = math_abs(1 / dir_y)

		local step_x
		local side_dist_x
		if dir_x < 0 then
			step_x = -1
			side_dist_x = (entity.pos_x - map_x) * delta_dist_x
		else
			step_x = 1
			side_dist_x = (map_x + 1.0 - entity.pos_x) * delta_dist_x
		end

		local step_y
		local side_dist_y
		if dir_y < 0 then
			step_y = -1
			side_dist_y = (entity.pos_y - map_y) * delta_dist_y
		else
			step_y = 1
			side_dist_y = (map_y + 1.0 - entity.pos_y) * delta_dist_y
		end

		-- DDA
		local side
		while true do
			if side_dist_x < side_dist_y then
				side_dist_x = side_dist_x + delta_dist_x
				map_x = map_x + step_x
				side = 0
			else
				side_dist_y = side_dist_y + delta_dist_y
				map_y = map_y + step_y
				side = 1
			end
			tile_data = mget(map_x, map_y)
			if tile_data > 0
				and tile_data // 16 < 8 then --if more than half-height
				break
			end
		end

		local wall_dist
		if side == 0 then
			wall_dist = side_dist_x - delta_dist_x
		else --side == 1
			wall_dist = side_dist_y - delta_dist_y
		end
		local wall_dist_x = dir_x * wall_dist
		local wall_dist_y = dir_y * wall_dist
		local wall_dist_sqr = wall_dist * wall_dist

		local max_dist_sqr = math.min(wall_dist_sqr, self.range_sqr)

		if target_type == 0 then
			local player = g_player
			local rel_pos_x = player.pos_x - entity.pos_x
			local rel_pos_y = player.pos_y - entity.pos_y
			local dist_sqr = rel_pos_x * rel_pos_x + rel_pos_y * rel_pos_y
			if dist_sqr < max_dist_sqr
				and ray_entity_collides(rel_pos_x, rel_pos_y, dir_x, dir_y, player.hitbox_rad) then
				player:damage(damage * g_ENEMY_WEAPON_SCALING[g_settings.difficulty])
			end
		else --target_type == 1
			local enemies = g_enemies
			local closest_enemy
			local closest_enemy_dist_sqr = 9999
			for _,enemy in pairs(enemies) do
				if enemy ~= nil then
					local rel_pos_x = enemy.pos_x - entity.pos_x
					local rel_pos_y = enemy.pos_y - entity.pos_y
					local dist_sqr = rel_pos_x * rel_pos_x + rel_pos_y * rel_pos_y
					if closest_enemy_dist_sqr > dist_sqr
						and ray_entity_collides(rel_pos_x, rel_pos_y, dir_x, dir_y, enemy.hitbox_rad) then
						closest_enemy = enemy
						closest_enemy_dist_sqr = dist_sqr
					end
				end
			end

			if closest_enemy_dist_sqr < max_dist_sqr then
				closest_enemy:damage(damage * g_WEAPON_SCALING[g_settings.difficulty])
				local dist = math.sqrt(closest_enemy_dist_sqr) - 0.1
				hitmarker_set(
					entity.pos_x + dir_x * dist,
					entity.pos_y + dir_y * dist,
					1
				)
			elseif wall_dist_sqr == max_dist_sqr then
				if side == 0 then
					local dx = step_x * -0.1
					hitmarker_set(entity.pos_x + wall_dist_x + dx, entity.pos_y + wall_dist_y + dx * dir_y / dir_x, 0)
				else --side == 1
					local dy = step_y * -0.1
					hitmarker_set(entity.pos_x + wall_dist_x + dy * dir_x / dir_y, entity.pos_y + wall_dist_y + dy, 0)
				end
			end
		end
	end
end

Item = {
	id = 0,
	pos_x = 0,
	pos_y = 0,
	type = 0,
	value = 0,
	sprite = nil,
}
Item.__index = Item

-- Item types
-- 0: Health
-- 1: Ammo pistol
-- 2: Ammo shotgun
-- 3: Key

-- Keys
-- 1: Gold
-- 2: Silver
function Item.new(id, pos_x, pos_y, type, value)
	local self = setmetatable({}, Item)
	self.id = id
	self.pos_x = pos_x
	self.pos_y = pos_y
	self.type = type
	self.value = value
	if type == 3 then
		self.sprite = Sprite.new(pos_x, pos_y, 69 + value, 8, 4, 0.75)
	else
		self.sprite = Sprite.new(pos_x, pos_y, 64 + 2 * type, 4, 4, 0.75)
	end
	return self
end

function Item:process(_delta)
	local player = g_player
	local rel_pos_x = player.pos_x - self.pos_x
	local rel_pos_y = player.pos_y - self.pos_y
	local dist_sqr = rel_pos_x * rel_pos_x + rel_pos_y * rel_pos_y
	if dist_sqr < 0.04 then
		if self.type == 0 then
			player.health = player.health + self.value
		elseif self.type == 1 then
			local weapon = g_WEAPONS[2]
			weapon.ammo = weapon.ammo + self.value
		elseif self.type == 2 then
			local weapon = g_WEAPONS[3]
			weapon.ammo = weapon.ammo + self.value
		else --self.type == 3
			player.keys[self.value] = 1
		end
		g_items[self.id] = nil
	end
end

Hitmarker = {
	visible = false,
	timer = 0,
	sprite = nil,
}
Hitmarker.__index = Hitmarker

function Hitmarker.new()
	local self = setmetatable({}, Hitmarker)
	self.sprite = Sprite.new(0, 0, 0, 6, 6, 0)
	return self
end

-- Hitmarker types
-- 0: wall
-- 1: enemy
function hitmarker_set(pos_x, pos_y, type)
	for _,hitmarker in pairs(g_hitmarkers) do
		if not hitmarker.visible then
			hitmarker.timer = 0
			hitmarker.visible = true
			hitmarker.sprite.pos_x = pos_x
			hitmarker.sprite.pos_y = pos_y
			hitmarker.sprite.tex_id = 59 + type
			break
		end
	end
end

function Hitmarker:process(delta)
	if self.visible then
		self.timer = self.timer + delta
		if self.timer > 200 then
			self.visible = false
		end
	end
end

Player = {
	pos_x = 0,
	pos_y = 0,
	dir_x = -1,
	dir_y = 0,
	plane_x = 0,
	plane_y = 0.8,
	speed_move = 0.003,
	weapon_idx = 1,
	weapon_state = 0,
	weapon_timer = 0,
	health = 100,
	hitbox_rad = 0.4,
	move = g_entity_move,
	keys = {
		[1] = 0,
		[2] = 0,
	}
}
Player.__index = Player

function Player.new(pos_x, pos_y)
	local self = setmetatable({}, Player)
	self.pos_x = pos_x
	self.pos_y = pos_y
	return self
end

function Player:rotate(delta)
	local speed = g_settings.turn_speed * delta
	local old_dir_x = self.dir_x
	local math_cos = math.cos
	local math_sin = math.sin
	self.dir_x = self.dir_x * math_cos(speed) - self.dir_y * math_sin(speed)
	self.dir_y = old_dir_x * math_sin(speed) + self.dir_y * math_cos(speed)
	local old_plane_x = self.plane_x
	self.plane_x = self.plane_x * math_cos(speed) - self.plane_y * math_sin(speed)
	self.plane_y = old_plane_x * math_sin(speed) + self.plane_y * math_cos(speed)
end

function Player:damage(value)
	if self.health > 0 then
		self.health = self.health - value
		if self.health <= 0 then
			g_game_state = 2
			g_timer = 0
		end
	end
end

function Player:process(delta)
	self.weapon_timer = self.weapon_timer + delta

	local weapon = g_WEAPONS[self.weapon_idx]

	if btn(2) then
		self:rotate(delta)
	elseif btn(3) then
		self:rotate(-delta)
	end
	if btn(0) then
		self:move(self.speed_move * delta)
	elseif btn(1) then
		self:move(-self.speed_move * delta)
	end
	if btnp(4) then
		if self.weapon_state == 2 then
			self.weapon_state = 1
			self.weapon_timer = 0
		end
	elseif btnp(5) and self.weapon_state == 2 and weapon.ammo > 0 then
		self.weapon_state = 3
		self.weapon_timer = 0
		weapon:shoot(self, 1)
	end

	if self.weapon_state == 0 then
		if self.weapon_timer >= weapon.raise_time then
			self.weapon_state = 2
		end
	elseif self.weapon_state == 1 then
		if self.weapon_timer >= weapon.raise_time then
			self.weapon_state = 0
			self.weapon_timer = 0
			self.weapon_idx = self.weapon_idx % 3 + 1
		end
	elseif self.weapon_state == 3 then
		if self.weapon_timer >= weapon.shoot_time then
			if weapon.reload_time == 0 then
				self.weapon_state = 2
			else
				self.weapon_state = 4
				self.weapon_timer = 0
			end
		end
	elseif self.weapon_state == 4 then
		if self.weapon_timer >= weapon.reload_time then
			self.weapon_state = 2
		end
	end
end

Sprite = {
	pos_x = 0,
	pos_y = 0,
	tex_id = 0,
	scl_horiz = 1,
	scl_vert = 1,
	offset_vert = 0, --from 0.5 (floor) to -0.5 (ceiling)
	screen_offset_vert = 0,
	screen_width = 0,
	screen_height = 0,
	dist = 0, --Distance to player (negative if not in viewing triangle)
	screen_x = 0,
	draw_start_y = 0,
	draw_end_y = 0,
	draw_start_x = 0,
	draw_end_x = 0,
}
Sprite.__index = Sprite

function Sprite.new(pos_x, pos_y, tex_id, scl_horiz, scl_vert, offset_vert)
	local self = setmetatable({}, Sprite)
	self.pos_x = pos_x
	self.pos_y = pos_y
	self.tex_id = tex_id
	self.scl_horiz = scl_horiz
	self.scl_vert = scl_vert
	self.offset_vert = offset_vert
	return self
end

function Sprite:process(inv_det)
	local SCREEN_WIDTH = g_SCREEN_WIDTH
	local SCREEN_HEIGHT = g_SCREEN_HEIGHT
	local SCREEN_HALF_HEIGHT = SCREEN_HEIGHT / 2
	local player = g_player
	local math_abs = math.abs

	local rel_x = self.pos_x - player.pos_x
	local rel_y = self.pos_y - player.pos_y
	self.dist = math.sqrt(rel_x * rel_x + rel_y * rel_y)
	local trans_y = inv_det * (player.plane_x * rel_y - player.plane_y * rel_x)
	if trans_y <= 0 then
		self.dist = -self.dist
		return
	end
	local trans_x = inv_det * (player.dir_y * rel_x - player.dir_x * rel_y)
	self.screen_x = math.floor((SCREEN_WIDTH * 0.5) * (1 + trans_x / trans_y))
	self.screen_width = math_abs(SCREEN_HEIGHT / trans_y) / self.scl_horiz
	self.draw_start_x = self.screen_x - self.screen_width // 2
	if self.draw_start_x < 0 then
		self.draw_start_x = 0
	elseif self.draw_start_x >= SCREEN_WIDTH then
		self.dist = -self.dist
		return
	end
	self.draw_end_x = self.screen_x + self.screen_width // 2
	if self.draw_end_x >= SCREEN_WIDTH then
		self.draw_end_x = SCREEN_WIDTH - 1
	elseif self.draw_end_x < 0 then
		self.dist = -self.dist
		return
	end
	self.screen_height = math_abs(SCREEN_HEIGHT / trans_y) / self.scl_vert
	self.screen_offset_vert = SCREEN_HALF_HEIGHT * self.offset_vert // trans_y
	self.draw_start_y = SCREEN_HALF_HEIGHT - self.screen_height // 2 + self.screen_offset_vert
	if self.draw_start_y < 0 then
		self.draw_start_y = 0
	end
	self.draw_end_y = SCREEN_HALF_HEIGHT + self.screen_height // 2 + self.screen_offset_vert
	if self.draw_end_y >= SCREEN_HEIGHT then
		self.draw_end_y = SCREEN_HEIGHT - 1
	end
end

function Sprite:set_enemy_tex(tex_id)
	self.tex_id = tex_id
	self.scl_horiz = 48 / g_SPRITE_SIZES[tex_id][1]
end

Enemy = {
	id = 0,
	pos_x = 0,
	pos_y = 0,
	dir_x = -1,
	dir_y = 0,
	state = 0,
	timer = 0,
	tex_ids = {},
	sprite = nil,
	weapon = nil,
	health = 0,
	activate_dist_sqr = 0,
	shoot_dist_sqr = 0,
	die_time = 0,
	speed_move = 0,
	hitbox_rad = 0,
	pain_time = 0,
	pain_chance = 0,
}
Enemy.__index = Enemy

g_enemy_pistol_tex_ids = {192, 194, 195, 196, 198, 200, 202, 204, 96, 206, 76}
g_enemy_shotgun_tex_ids = {128, 130, 131, 132, 134, 136, 138, 140, 100, 142, 78}

-- Enemy types
-- 0: pistol
-- 1: shotgun

-- Enemy states
-- 0: neutral
-- 1: raise
-- 2: ready
-- 3: shoot
-- 4: reload
-- 5: die
-- 6: hurt

-- Enemy sprites
-- 01: forward
-- 02: left
-- 03: right
-- 04: back
-- 05: raise
-- 06: ready
-- 07: shoot
-- 08: die
-- 09: corpse
-- 10: walk
-- 11: pain

function Enemy.new(id, type, pos_x, pos_y, angle)
	local self = setmetatable({}, Enemy)

	self.id = id
	self.pos_x = pos_x
	self.pos_y = pos_y
	self.activate_dist_sqr = 64
	self.shoot_dist_sqr = 16

	self.dir_x = math.cos(angle)
	self.dir_y = math.sin(angle)

	if type == 0 then
		self.tex_ids = g_enemy_pistol_tex_ids
		self.sprite = Sprite.new(pos_x, pos_y, 0, 1, 1.5, 0.25)
		self.weapon = g_ENEMY_WEAPONS[1]
		self.health = 30
		self.die_time = 1000
		self.speed_move = 0.002
		self.hitbox_rad = 0.3
		self.pain_time = 170
		self.pain_chance = 0.7
	elseif type == 1 then
		self.tex_ids = g_enemy_shotgun_tex_ids
		self.sprite = Sprite.new(pos_x, pos_y, 0, 1, 1.5, 0.25)
		self.weapon = g_ENEMY_WEAPONS[2]
		self.health = 60
		self.die_time = 1000
		self.speed_move = 0.0015
		self.hitbox_rad = 0.3
		self.pain_time = 210
		self.pain_chance = 0.61
	end
	return self
end

function Enemy:move(speed)
	g_entity_move(self, speed)
	self.sprite.pos_x = self.pos_x
	self.sprite.pos_y = self.pos_y
end

function Enemy:process(delta)
	local player = g_player
	local rel_pos_x = player.pos_x - self.pos_x
	local rel_pos_y = player.pos_y - self.pos_y
	self.dist_sqr = rel_pos_x * rel_pos_x + rel_pos_y * rel_pos_y
	local angle = math.atan2(
		self.dir_x * rel_pos_y - self.dir_y * rel_pos_x,
		self.dir_x * rel_pos_x + self.dir_y * rel_pos_y)
	local abs_angle = math.abs(angle)

	self.timer = self.timer + delta
	if self.state == 0 then
		if self.dist_sqr <= 1
			or (abs_angle <= 0.5235988 --30 deg
			and self.activate_dist_sqr >= self.dist_sqr) then
			self.state = 1
			self.timer = 0
			self.sprite:set_enemy_tex(self.tex_ids[5])
		else
			local tex_idx
			if abs_angle <= 0.785398163397 then --pi / 4
				tex_idx = 1
			elseif abs_angle >= 2.35619449019 then --3 * pi / 4
				tex_idx = 4
			elseif angle > 0 then
				tex_idx = 2
			else
				tex_idx = 3
			end
			self.sprite:set_enemy_tex(self.tex_ids[tex_idx])
		end
	elseif self.state == 1 then
		if self.timer >= self.weapon.raise_time then
			self.state = 2
			self.sprite:set_enemy_tex(self.tex_ids[6])
		end
	elseif self.state == 2 then
		local math_floor = math.floor
		local math_abs = math.abs

		local inv_mag = 1 / math.sqrt(self.dist_sqr)
		self.dir_x = rel_pos_x * inv_mag
		self.dir_y = rel_pos_y * inv_mag

		local map_x = math_floor(self.pos_x)
		local map_y = math_floor(self.pos_y)
		local delta_dist_x = math_abs(1 / self.dir_x)
		local delta_dist_y = math_abs(1 / self.dir_y)

		local step_x
		local side_dist_x
		if self.dir_x < 0 then
			step_x = -1
			side_dist_x = (self.pos_x - map_x) * delta_dist_x
		else
			step_x = 1
			side_dist_x = (map_x + 1.0 - self.pos_x) * delta_dist_x
		end

		local step_y
		local side_dist_y
		if self.dir_y < 0 then
			step_y = -1
			side_dist_y = (self.pos_y - map_y) * delta_dist_y
		else
			step_y = 1
			side_dist_y = (map_y + 1.0 - self.pos_y) * delta_dist_y
		end

		-- DDA LOS check
		local side
		while true do
			if side_dist_x < side_dist_y then
				side_dist_x = side_dist_x + delta_dist_x
				map_x = map_x + step_x
				side = 0
			else
				side_dist_y = side_dist_y + delta_dist_y
				map_y = map_y + step_y
				side = 1
			end
			tile_data = mget(map_x, map_y)
			if tile_data > 0
				and tile_data // 16 < 8 then --if more than half-height
				break
			end
		end

		local wall_dist_sqr
		if side == 0 then
			wall_dist_sqr = side_dist_x - delta_dist_x
		else --side == 1
			wall_dist_sqr = side_dist_y - delta_dist_y
		end
		wall_dist_sqr = wall_dist_sqr * wall_dist_sqr

		if self.shoot_dist_sqr < self.dist_sqr --player too far
			or wall_dist_sqr < self.dist_sqr then --player not visible
			self:move(self.speed_move * delta)

			local tex_idx
			if self.timer // 500 % 2 == 0 then --TODO:un-hardcode
				tex_idx = 6
			else
				tex_idx = 10
			end
			self.sprite:set_enemy_tex(self.tex_ids[tex_idx])
		else
			self.state = 3
			self.timer = 0
			self.weapon:shoot(self, 0)
			self.sprite:set_enemy_tex(self.tex_ids[7])
		end
	elseif self.state == 3 then
		if self.timer >= self.weapon.shoot_time then
			self.state = 4
			self.timer = 0
			self.sprite:set_enemy_tex(self.tex_ids[6])
		end
	elseif self.state == 4 then
		if self.timer >= self.weapon.reload_time then
			self.state = 2
		end
	elseif self.state == 5 then
		if self.timer >= self.die_time then
			self.sprite.tex_id = self.tex_ids[9]
			self.sprite.scl_horiz = 1
			self.sprite.scl_vert = 4
			self.sprite.offset_vert = 0.75
			g_enemies[self.id] = nil
			table.insert(g_sprites, self.sprite)
		end
	elseif self.state == 6 then
		if self.timer >= self.pain_time then
			self.state = 2
			self.sprite:set_enemy_tex(self.tex_ids[6])
		end
	end
end

function Enemy:damage(value)
	if self.health > 0 then
		self.health = self.health - value
		if self.health <= 0 then
			self.sprite:set_enemy_tex(self.tex_ids[8])
			self.state = 5
			self.timer = 0
		else
			if (not (self.state == 6))
				and math.random() < self.pain_chance then
				self.state = 6
				self.timer = 0
				self.sprite:set_enemy_tex(self.tex_ids[11])
			elseif self.state == 0 then
				self.state = 2
				self.sprite:set_enemy_tex(self.tex_ids[6])
			end
		end
	end
end

Door = {
	map_x = 0,
	map_y = 0,
	opening = false,
	closed = true,
	type = 1,
	tex_id = 0,
	height = 0,
	timer = 0,
}
Door.__index = Door

function Door.new(map_x, map_y, tex_id, type)
	local self = setmetatable({}, Door)
	self.map_x = map_x
	self.map_y = map_y
	self.tex_id = tex_id
	self.type = type
	return self
end

function Door:process(delta)
	if self.closed then
		if self.opening then
			self.timer = self.timer + delta
			if self.timer > 100 then
				if self.height == 15 then
					self.closed = false
					mset(self.map_x, self.map_y, 0)
				else
					self.timer = 0
					self.height = self.height + 1
					mset(self.map_x, self.map_y, self.tex_id + 16 * self.height)
				end
			end
		else
			local player = g_player
			if player.keys[self.type] == 1 then
				local rel_pos_x = player.pos_x - self.map_x - 0.5
				local rel_pos_y = player.pos_y - self.map_y - 0.5
				local dist_sqr = rel_pos_x * rel_pos_x + rel_pos_y * rel_pos_y
				if dist_sqr < 2.0 then
					self.opening = true
				end
			end
		end
	end
end

function g_get_tex_pixel(offset, id, x, y)
	return peek4(offset + 0x40 * (id + 16 * (y // 8) + x // 8) + 0x8 * (y % 8) + (x % 8))
end

function init()
	g_SCREEN_WIDTH = 240
	g_SCREEN_HEIGHT = 120
	g_LEVEL_WIDTH = 128
	g_LEVEL_HEIGHT = 48
	g_SPRITE_SIZES = {
		[0]=  {16,16},
		[2]=  {16,16},
                [4]=  {16,16},
                [6]=  {16,16},
                [8]=  {16,16},
		--Enemy pistol
		[192]={16,32},
		[194]={8 ,32},
		[195]={8 ,32},
		[196]={16,32},
		[198]={16,32},
		[200]={16,32},
		[202]={16,32},
		[204]={16,32},
		[96]= {32,16},
		[206]={16,32},
		[76]= {16,32},
		--Enemy shotgun
		[128]={16,32},
		[130]={8 ,32},
		[131]={8 ,32},
		[132]={16,32},
		[134]={16,32},
		[136]={16,32},
		[138]={16,32},
		[140]={16,32},
		[100]={32,16},
		[142]={16,32},
		[78]= {16,32},
		--Items
		[64]= {16,16},
		[66]= {16,16},
		[68]= {16,16},
		[70]= {8 ,16},
		[71]= {8 ,16},
		--Hitmarkers
		[59]= {8, 8 },
		[60]= {8, 8 },
	}
	g_TEX_MAP = {
		[1]=1,
		[2]=3,
		[3]=5,
		[4]=7,
		[5]=9,
		[6]=11,
		[7]=13,
                [8]=33,
                [9]=35,
                [10]=37,
                [11]=39,
                [12]=41,
                [13]=43,
	}
	g_player = Player.new(10, 7)
	g_prev_time = 0
	g_sprites = {
		Sprite.new(8.5, 5.5, 2, 2, 1, 0.125),
                Sprite.new(45.5, 27.5, 6, 2, 2, -0.5),
                Sprite.new(40, 14, 6, 2, 2, -0.5),
                Sprite.new(38.5, 27.5, 0, 2, 2, 0.5),
                Sprite.new(32.5, 18.5, 8, 1, 1, 0),
                Sprite.new(32.5, 21.5, 8, 1, 1, 0),
                Sprite.new(36.5, 15.5, 4, 2, 2, 0.5),
                Sprite.new(62.5, 17.5, 6, 2, 2, -0.5),
                Sprite.new(71.5, 17.5, 6, 2, 2, -0.5),
                Sprite.new(80.5, 17.5, 6, 2, 2, -0.5),
                Sprite.new(89.5, 17.5, 6, 2, 2, -0.5),
                Sprite.new(98.5, 17.5, 6, 2, 2, -0.5),
                Sprite.new(107.5, 17.5, 6, 2, 2, -0.5),
                Sprite.new(62.5, 25.5, 6, 2, 2, -0.5),
                Sprite.new(71.5, 25.5, 6, 2, 2, -0.5),
                Sprite.new(80.5, 25.5, 6, 2, 2, -0.5),
                Sprite.new(89.5, 25.5, 6, 2, 2, -0.5),
                Sprite.new(98.5, 25.5, 6, 2, 2, -0.5),
                Sprite.new(107.5, 25.5, 6, 2, 2, -0.5),
	}
	g_WEAPONS = {
		Weapon.new(204, 1e9, 107, {234, 228},      300, 250, 0  , 0.05, 2, 20, 1, 1 ),
		Weapon.new(200, 0  , 113, {234, 228},      350, 350, 0  , 0.05, 5, 15, 1, 32),
		Weapon.new(196, 0  , 113, {222, 216, 210}, 400, 350, 350, 0.12, 5, 15, 7, 32),
	}
	g_ENEMY_WEAPONS = {
		Weapon.new(0, 99999999, 0, nil, 0, 350, 0  , 0.4, 3, 15, 1, 32),
		Weapon.new(0, 99999999, 0, nil, 0, 350, 350, 0.4, 3, 15, 3, 32),
	}
        g_ENEMY_WEAPON_SCALING = {
                [1] = 0.65,
                [2] = 1.0,
                [3] = 1.35,
        }
        g_WEAPON_SCALING = {
                [1] = 1.2,
                [2] = 1.0,
                [3] = 0.9,
        }
	g_enemies = {
		[1]=Enemy.new(1, 0, 8.5, 10.5, 1.57),
                [2]=Enemy.new(2, 0, 23.5, 16.5, 1.57),
                [3]=Enemy.new(3, 0, 23.5, 23.5, -1.57),
                [4]=Enemy.new(4, 0, 45.5, 26.5, 1.57),
                [5]=Enemy.new(5, 0, 45.5, 28.5, -1.57),
                [6]=Enemy.new(6, 1, 43.5, 14.5, 3.14),
                [7]=Enemy.new(7, 0, 50.5, 13.5, 0),
                [8]=Enemy.new(8, 0, 47.5, 13.5, 0),
                [9]=Enemy.new(9, 0, 76, 15.5, 1.57),
                [10]=Enemy.new(10, 1, 67, 15.5, 1.57),
                [11]=Enemy.new(11, 0, 85, 15.5, 1.57),
                [12]=Enemy.new(12, 1, 94, 15.5, 1.57),
                [13]=Enemy.new(13, 0, 103, 15.5, 1.57),
                [14]=Enemy.new(14, 0, 76, 27.5, -1.57),
                [15]=Enemy.new(15, 1, 67, 27.5, -1.57),
                [16]=Enemy.new(16, 0, 85, 27.5, -1.57),
                [17]=Enemy.new(17, 1, 94, 27.5, -1.57),
                [18]=Enemy.new(18, 0, 103, 27.5, -1.57),
                [19]=Enemy.new(19, 1, 95.5, 21.5, 3.14),
                [20]=Enemy.new(20, 0, 55.5, 19.5, 1.57),
	}
	g_items = {
		[1]= Item.new(1,  45.5, 27.5, 3, 2),
		[2]= Item.new(2,  59.5, 27.5, 3, 1),
                [3]= Item.new(3,  10.5, 13.5, 0, 35),
                [4]= Item.new(4,  6.5,  13.5, 1, 15),
                [5]= Item.new(5,  36.5, 27.5, 2, 4),
                [6]= Item.new(6,  45.5, 6.5,  0, 15),
                [7]= Item.new(7,  47.5, 13.5, 2, 2),
                [8]= Item.new(8,  56.5, 6.5,  2, 2),
                [9]= Item.new(9,  55.5, 21.5, 0, 25),
                [10]=Item.new(10, 40.5, 27.5, 1, 15),
                [11]=Item.new(11, 37.5, 14.5, 1, 15),
                [12]=Item.new(12, 60.5, 21.5, 0, 50),
                [13]=Item.new(13, 65.5, 21.5, 1, 20),
                [14]=Item.new(14, 70.5, 21.5, 2, 6),
	}
	g_doors = {
		Door.new(110, 21, 6, 1),
		Door.new(57,  21, 7, 2),
	}
	g_NUM_HITMARKERS = 7
	g_hitmarkers = {}
	for i=1,g_NUM_HITMARKERS do
		g_hitmarkers[i] = Hitmarker.new()
	end
	g_timer = 0
	g_settings = {
		floor_ceil = false,
		interlace = 2, --disabled=g_interlace>=2
		difficulty = 2,
		debug = false,
		turn_speed = 0.003,
		selected_setting = 0,
		sprite = 0,
	}
	g_pause_text = {
		[true]="ON",
		[false]="OFF",
		[1]="EASY",
		[2]="NORM",
		[3]="HARD",
	}
	-- Game States
	-- 1: Alive
	-- 2: Dead
	-- 3: Paused
	g_game_state = 1

	math.randomseed(tstamp())
end

init()
function TIC()
	local t = time()
	local delta = t - g_prev_time --msec since last frame
	g_prev_time = t

	g_timer = g_timer + delta

	local game_state = g_game_state

	if btnp(7) then
		if game_state == 1 then
			g_game_state = 3
			g_timer = 0
			g_settings.selected_setting = 0
		elseif game_state == 3 then
			g_game_state = 1
		end
	end

	if game_state == 1 then
		game_process(delta)
	elseif game_state == 2 then
		death_process(delta)
	elseif game_state == 3 then
		pause_process(delta)
	end
end

function death_process(delta)
	if g_timer >= 3000 then
		reset()
	end

	local dist = math.floor(g_timer * 0.0272)
	for i=0,7 do
		spr(328, i * 32, dist, 0, 1, 0, 0, 4, 1)
	end
end

function pause_process(delta)
	local settings = g_settings
	local pause_text = g_pause_text

	if g_timer >= 750 then
		settings.sprite = (settings.sprite + 1) % 2
		g_timer = 0
	end

	map(226, 91, 14, 11, 64, 20)
	print("Interlacing", 72, 40)
	print("Floor&Ceil", 72, 52)
	print("Difficulty", 72, 64)
	print("Turn Speed", 72, 76)
	print("Debug", 72, 88)

	if btnp(0) then
		settings.selected_setting = math.max(0, settings.selected_setting - 1)
	elseif btnp(1) then
		settings.selected_setting = math.min(4, settings.selected_setting + 1)
	end

	local setting_change = 0
	if btnp(2) then
		setting_change = -1
	elseif btnp(3) then
		setting_change = 1
	end

	if setting_change ~= 0 then
		if settings.selected_setting == 0 then
			if settings.interlace < 2 then
				settings.interlace = 2
			else
				settings.interlace = 0
			end
		elseif settings.selected_setting == 1 then
			settings.floor_ceil = not settings.floor_ceil
		elseif settings.selected_setting == 2 then
			settings.difficulty = math.min(3, math.max(1, settings.difficulty + setting_change))
		elseif settings.selected_setting == 3 then
			settings.turn_speed = math.max(0, settings.turn_speed + setting_change * 0.001)
		else --settings.selected_setting == 4
			settings.debug = not settings.debug
		end
	end

	print(pause_text[settings.interlace < 2], 142, 40)
	print(pause_text[settings.floor_ceil], 142, 52)
	print(pause_text[settings.difficulty], 142, 64)
	print(math.floor(settings.turn_speed * 1000), 142, 76)
	print(pause_text[settings.debug], 142, 88)

	local selected_setting_y = 38 + 12 * settings.selected_setting

	spr(317 + settings.sprite, 134, selected_setting_y, 0)
	spr(317 + settings.sprite, 165, selected_setting_y, 0, 1, 1)
end

function game_process(delta)
	local SCREEN_WIDTH = g_SCREEN_WIDTH
	local SCREEN_HEIGHT = g_SCREEN_HEIGHT
	local SCREEN_HALF_HEIGHT = SCREEN_HEIGHT // 2
	local TEX_WIDTH = 16
	local TEX_HEIGHT = 16
	local SPRITE_SIZES = g_SPRITE_SIZES
	local TEX_MAP = g_TEX_MAP
	local player = g_player
	local sprites = g_sprites
	local enemies = g_enemies
	local items = g_items
	local hitmarkers = g_hitmarkers
	local doors = g_doors
	local settings = g_settings
	local WEAPON_X = 111
	local WEAPON_Y = 72
	local get_tex_pixel = g_get_tex_pixel
	local math_floor = math.floor
	local math_abs = math.abs

	local start_vline
	local step_vline
	if settings.interlace >= 2 then
		start_vline = 0
		step_vline = 1
		cls(0)
	else
		start_vline = (settings.interlace + 1) % 2
		settings.interlace = start_vline
		step_vline = 2
		for x=start_vline,SCREEN_WIDTH-1,step_vline do
			for y=0,SCREEN_HEIGHT-1 do
				pix(x, y, 0)
			end
		end
	end

	-- game logic
	t = time()

	player:process(delta)

	for _,enemy in pairs(enemies) do
		if enemy ~= nil then
			enemy:process(delta)
		end
	end
	for _,item in pairs(items) do
		if item ~= nil then
			item:process(delta)
		end
	end
	for _,hitmarker in pairs(hitmarkers) do
		hitmarker:process(delta)
	end
	for _,door in pairs(doors) do
		door:process(delta)
	end

	local t_temp = time()
	local t_logic = t_temp - t
	t = t_temp

	-- drawing
	local inv_det = 1 / (player.plane_x * player.dir_y - player.dir_x * player.plane_y)
	local visible_sprites = {}
	for _,sprite in pairs(sprites) do
		sprite:process(inv_det)
		if sprite.dist > 0 then
			visible_sprites[#visible_sprites+1] = sprite
		end
	end
	for _,enemy in pairs(enemies) do
		if enemy ~= nil then
			local sprite = enemy.sprite
			sprite:process(inv_det)
			if sprite.dist > 0 then
				visible_sprites[#visible_sprites+1] = sprite
			end
		end
	end
	for _,item in pairs(items) do
		if item ~= nil then
			local sprite = item.sprite
			sprite:process(inv_det)
			if sprite.dist > 0 then
				visible_sprites[#visible_sprites+1] = sprite
			end
		end
	end
	for _,hitmarker in pairs(hitmarkers) do
		if hitmarker.visible then
			local sprite = hitmarker.sprite
			sprite:process(inv_det)
			if sprite.dist > 0 then
				visible_sprites[#visible_sprites+1] = sprite
			end
		end
	end

	table.sort(visible_sprites, function(a,b) return a.dist < b.dist end)
	local num_visible_sprites = #visible_sprites

	--draw weapon
	local weapon = g_WEAPONS[player.weapon_idx]
	if player.weapon_state == 0 then
		map(weapon.textures_x[1], weapon.texture_y, 6, 6, WEAPON_X, WEAPON_Y + 48 * (1 - player.weapon_timer / weapon.raise_time))
	elseif player.weapon_state == 1 then
		map(weapon.textures_x[1], weapon.texture_y, 6, 6, WEAPON_X, WEAPON_Y + 48 * player.weapon_timer / weapon.raise_time)
	elseif player.weapon_state == 2 then
		map(weapon.textures_x[1], weapon.texture_y, 6, 6, WEAPON_X, WEAPON_Y)
	elseif player.weapon_state >= 3 then
		map(weapon.textures_x[player.weapon_state - 1], weapon.texture_y, 6, 6, WEAPON_X + 2, WEAPON_Y + 2)
	end

	-- draw HUD
	map(210, 134, 25, 2, 0, 120)
	map(235, 134 - 2 * player.keys[1], 1, 1, 200, 120)
	map(235, 135 - 2 * player.keys[2], 1, 1, 200, 128)
	map(236, 128 + 2 * player.weapon_idx, 4, 2, 208, 120)
	font(math.floor(player.health), 19, 124)
	local weapon_ammo
	if player.weapon_idx == 1 then
		weapon_ammo = ':'
	else
		weapon_ammo = weapon.ammo
	end
	font(weapon_ammo, 69, 124)

	-- draw walls and sprites
	for x=start_vline,SCREEN_WIDTH-1,step_vline do
		local camera_x = 2 * x / SCREEN_WIDTH - 1
		local ray_dir_x = player.dir_x + player.plane_x * camera_x
		local ray_dir_y = player.dir_y + player.plane_y * camera_x
		local map_x = math_floor(player.pos_x)
		local map_y = math_floor(player.pos_y)
		local delta_dist_x = math_abs(1 / ray_dir_x)
		local delta_dist_y = math_abs(1 / ray_dir_y)

		local step_x
		local side_dist_x
		if ray_dir_x < 0 then
			step_x = -1
			side_dist_x = (player.pos_x - map_x) * delta_dist_x
		else
			step_x = 1
			side_dist_x = (map_x + 1.0 - player.pos_x) * delta_dist_x
		end

		local step_y
		local side_dist_y
		if ray_dir_y < 0 then
			step_y = -1
			side_dist_y = (player.pos_y - map_y) * delta_dist_y
		else
			step_y = 1
			side_dist_y = (map_y + 1.0 - player.pos_y) * delta_dist_y
		end

		local current_sprite = 1
		local not_hit_full_wall = true
		local prev_draw_start = SCREEN_HEIGHT
		while not_hit_full_wall do
			-- DDA
			local side
			local tile_data
			while true do
				if side_dist_x < side_dist_y then
					side_dist_x = side_dist_x + delta_dist_x
					map_x = map_x + step_x
					side = 0
				else
					side_dist_y = side_dist_y + delta_dist_y
					map_y = map_y + step_y
					side = 1
				end
				tile_data = mget(map_x, map_y)
				if tile_data > 0 then
					break
				end
			end

			local perp_wall_dist
			if side == 0 then
				perp_wall_dist = side_dist_x - delta_dist_x
			else
				perp_wall_dist = side_dist_y - delta_dist_y
			end

			--draw sprites
			for sprite_idx=current_sprite,num_visible_sprites do
				local sprite = visible_sprites[sprite_idx]
				if sprite.dist >= perp_wall_dist then
					break
				end
				current_sprite = sprite_idx + 1
				if x >= sprite.draw_start_x and x <= sprite.draw_end_x then
					local sprite_size = SPRITE_SIZES[sprite.tex_id]
					local a = sprite_size[2] / sprite.screen_height
					local sprite_tex_x = math_floor((x - (sprite.screen_x - sprite.screen_width / 2)) * sprite_size[1] / sprite.screen_width) % sprite_size[1]
					for y=sprite.draw_start_y,sprite.draw_end_y do
						local tex_y = math_floor((y - sprite.screen_offset_vert - SCREEN_HALF_HEIGHT + sprite.screen_height / 2) * a) % sprite_size[2]
						local color = get_tex_pixel(0xC000, sprite.tex_id, sprite_tex_x, tex_y)
						if color > 0 and pix(x, y) == 0 then
							pix(x, y, color)
						end
					end
				end
			end

			--draw wall
			local tile_height = tile_data // 16 / 16 -- 0=full height, 1=no height
			if tile_height == 0 then
				not_hit_full_wall = false
			end

			local line_height = SCREEN_HEIGHT // perp_wall_dist
			local draw_start = SCREEN_HALF_HEIGHT + math_floor(line_height * (tile_height - 0.5)) + 1
			if draw_start < 0 then
				draw_start = 0
			elseif draw_start >= SCREEN_HEIGHT then
				draw_start = SCREEN_HEIGHT - 1
			end
			local draw_end = SCREEN_HALF_HEIGHT + line_height // 2 - 1
			if draw_end > prev_draw_start then
				draw_end = prev_draw_start
			elseif draw_end >= SCREEN_HEIGHT then
				draw_end = SCREEN_HEIGHT - 1
			end

			local wall_x
			if side == 0 then
				wall_x = player.pos_y + perp_wall_dist * ray_dir_y
			else
				wall_x = player.pos_x + perp_wall_dist * ray_dir_x
			end
			wall_x = wall_x - math_floor(wall_x)

			local tex_id = TEX_MAP[tile_data % 16]
			local tex_x = math_floor(wall_x * TEX_WIDTH)

			local step_tex = TEX_HEIGHT / line_height
			local testart_vline = (draw_start - SCREEN_HALF_HEIGHT + line_height * 0.5) * step_tex

			for y=draw_start,draw_end do
				if pix(x, y) == 0 then
					local tex_y = math_floor(testart_vline + step_tex * (y - draw_start)) % TEX_HEIGHT
					pix(x, y, get_tex_pixel(0x8000, tex_id, tex_x, tex_y))
				end
			end

			--draw top of variable-height walls
			if tile_height > 0.5 then
				if side_dist_x < side_dist_y then
					perp_wall_dist = (map_x + step_x - player.pos_x + (1 - step_x) * 0.5) / ray_dir_x
				else
					perp_wall_dist = (map_y + step_y - player.pos_y + (1 - step_y) * 0.5) / ray_dir_y
				end
				line_height = SCREEN_HEIGHT // perp_wall_dist
				local top_draw_start = SCREEN_HALF_HEIGHT + math_floor(line_height * (tile_height - 0.5))
				if top_draw_start >= SCREEN_HEIGHT then
					top_draw_start = SCREEN_HEIGHT - 1
				end
				local row_distance_part = (2 * tile_height - 1) * SCREEN_HALF_HEIGHT
				for y=top_draw_start,draw_start - 1 do
					if pix(x, y) == 0 then
						local row_distance = row_distance_part / (y - SCREEN_HALF_HEIGHT)
						local floor_x = player.pos_x + row_distance * ray_dir_x
						local floor_y = player.pos_y + row_distance * ray_dir_y
						tex_x = math_floor(TEX_WIDTH * floor_x) % TEX_WIDTH
						local tex_y = math_floor(TEX_HEIGHT * floor_y) % TEX_HEIGHT
						pix(x, y, get_tex_pixel(0x8000, tex_id, tex_x, tex_y))
					end
				end
				prev_draw_start = top_draw_start
			else
				prev_draw_start = draw_start
			end
		end
	end

	t_temp = time()
	local t_wall_sprite = t_temp - t
	t = t_temp

	--draw floor + ceiling
	if settings.floor_ceil then
		local ray_dir_x0 = player.dir_x - player.plane_x
		local ray_dir_y0 = player.dir_y - player.plane_y
		local ray_dir_x1 = player.dir_x + player.plane_x
		local ray_dir_y1 = player.dir_y + player.plane_y
		for y=SCREEN_HALF_HEIGHT,SCREEN_HEIGHT-1 do
			local row_distance = SCREEN_HALF_HEIGHT / (y - SCREEN_HALF_HEIGHT)
			local floor_step_x = row_distance * (ray_dir_x1 - ray_dir_x0) / SCREEN_WIDTH
			local floor_step_y = row_distance * (ray_dir_y1 - ray_dir_y0) / SCREEN_WIDTH
			local floor_x = player.pos_x + row_distance * ray_dir_x0 + start_vline * floor_step_x
			local floor_y = player.pos_y + row_distance * ray_dir_y0 + start_vline * floor_step_y
			floor_step_x = floor_step_x * step_vline
			floor_step_y = floor_step_y * step_vline
			for x=start_vline,SCREEN_WIDTH-1,step_vline do
				local tex_x = math_floor(TEX_WIDTH * floor_x) % TEX_WIDTH
				local tex_y = math_floor(TEX_HEIGHT * floor_y) % TEX_HEIGHT

				--draw floor
				if pix(x, y) == 0 then
					pix(x, y, get_tex_pixel(0x8000, 3, tex_x, tex_y)) --[CONST]
				end

				--draw ceiling
				if pix(x, SCREEN_HEIGHT - y - 1) == 0 then
					pix(x, SCREEN_HEIGHT - y - 1, get_tex_pixel(0x8000, 5, tex_x, tex_y)) --[CONST]
				end

				floor_x = floor_x + floor_step_x
				floor_y = floor_y + floor_step_y
			end
		end
	end

	t_temp = time()
	local t_floor = t_temp - t

	if settings.debug then
		print(string.format("FPS %d\n#SPR %d\nLOGIC %.1f\nWALL&SPR %.1f\nFLR&CEIL %.1f",
			math_floor(1000 / delta), num_visible_sprites, t_logic, t_wall_sprite, t_floor), 0, 0, 5)
	end
end

-- <TILES>
-- 001:ffffffffccedfccceeeefceeefeffeeffffffffffccddeeefceeeeeefeeeefef
-- 002:ffffffffdcdefcdceeeefceeefeffeeefffffffffcccdcedfceeeeeefeeeefef
-- 003:aaaaaaaaa8989989a99aaaa9a8aaaaaaa9aaaaaaa9aaaaaaa8aaaaaaa99aaaaa
-- 004:aaaaaaaa9899898a9aaaa99aaaaaaa8aaaaaaa9aaaaaaa9aaaaaaa8aaaaaa99a
-- 005:444444444444444e443444443333333344443444444434e44444344433333333
-- 006:4344444443444444434434443333333344434444444444444434444433333333
-- 007:fe656766e5777dde577dddef7ddddeffedddeffffeeeff56ddff6567ddf5677d
-- 008:e6567d7f6767ddefdddddefeeddeeffffeeff57f7dff6667def567ddeff67ddd
-- 009:ffccccccfffeddddcfffedddccfffeddcdcfffedcddcfffecdddcfffcddddcff
-- 010:cccccfffdddddcffddddddcfdddddddfdddddddfdddddddfeddddddffedddddf
-- 011:3cccccc433ccccc4333cccc433333333333344443333444f333344ff333344ff
-- 012:3cccccc33ccccc3c3cccc3cc33333ccc44443cccf4443cccff443cccff443ccc
-- 013:eccccccdeecccccdeeeccccdeeeeeeeeeeeeddddeeeedddfeeeeddffeeeeddff
-- 014:ecccccceecccccececcccecceeeeecccddddecccfdddecccffddecccffddeccc
-- 015:0cdd00000cdde0000cddde0000cddde0000dddde0000dddd00000ddd000000dd
-- 017:ffffffffccedfccceeeefceeefeffeeffffffffffccddeeefceeeeeefeeeefef
-- 018:ffffffffdcdefcdceeeefceeefeffeeefffffffffcccdcedfceeeeeefeeeefef
-- 019:a99aaaaaa8aaaaaaa9aaaaaaa9aaaaaaa8aaaaaaa99aaaa9a8989989aaaaaaaa
-- 020:aaaaa99aaaaaaa8aaaaaaa9aaaaaaa9aaaaaaa8a9aaaa99a9899898aaaaaaaaa
-- 021:444443434444444343444443333333334443444444434e444443444433333333
-- 022:444444344e444444444444443333333344444344444444444444444433333333
-- 023:def6dddeeffeddef566eddf576ddeef6dddddff6ddddeffedeeeffffefff656e
-- 024:fffedddd565feeee6665ff5667ddf676ddddf567dddef6ddeeefffedfff656fe
-- 025:cdddddcfcddddddccdddddddcdddddddcdddddddfdddddddffddddddffffffff
-- 026:ffeddddffffedddfcfffeddfdcfffedfddcfffefdddcffffddddcfffffffffff
-- 027:3443444f4333444f3333444433334444333333333334444c3344444c3444444c
-- 028:f444333cf4443cc344443ccc44443ccc33333ccc344443cc3444443c34444443
-- 029:eddedddfdeeedddfeeeeddddeeeeddddeeeeeeeeeeeddddceedddddceddddddc
-- 030:fdddeeecfdddecceddddecccddddeccceeeeeccceddddeccedddddecedddddde
-- 031:000000000000000000000000ee000000ffe00000defe0000ffefe000dddefe00
-- 033:c888889c9c8888c989c88c88889cc888889cc88888c99c888c8889c8c888889c
-- 034:c888889c9c8888c989c88c88889cc888889cc88888c99c888c8889c8c888889c
-- 035:3322443343322443443322442443322422443322322443323322443343322443
-- 036:2244332232244332332244334332244344332244244332242244332232244332
-- 037:fcddceefcfeeeefcdefeefcddeeffcddceeffcddeefccfeeefcddefefcdddeef
-- 038:fcddceefcfeeeefcdefeefcddeeffcddceeffcddeefccfeeefcddefefcdddeef
-- 039:3331114422222221331114444433333323222224344443331111112222444443
-- 040:4411112211222333444114221113333443342222111144332222211133333322
-- 041:fffffffffcfcfcfcffffffffcedcedcecedcedcecedcedcecedcedcecedcedce
-- 042:ffffffffcfcfcfcfffffffffdcedcedcdcedcedcdcedcedcdcedcedcdcedcedc
-- 043:5552252555252525552525255525252255522522555555555555522555555525
-- 044:5252225522555255225522555255525552522255555555555255555525255555
-- 047:0000000000000000000000000000000000000000ee000000dde00000ddde0000
-- 049:c888889c9c8888c989c88c88889cc888889cc88888c99c888c8889c8c888889c
-- 050:c888889c9c8888c989c88c88889cc888889cc88888c99c888c8889c8c888889c
-- 051:4433224424433224224433223224433233224433433224434433224424433224
-- 052:3322443343322443443322442443322422443322322443323322443343322443
-- 053:fcddceefcfeeeefcdefeefcddeeffcddceeffcddeefccfeeefcddefefcdddeef
-- 054:fcddceefcfeeeefcdefeefcddeeffcddceeffcddeefccfeeefcddefefcdddeef
-- 055:4333222211111444222233334444111222222244333444111111133322222211
-- 056:2224444441112211332233222111444444222333111444223222211111144442
-- 057:cedcedcecedcedcecedcedcecedcedcecedcedcefffffffffcfcfcfcffffffff
-- 058:dcedcedcdcedcedcdcedcedcdcedcedcdcedcedcffffffffcfcfcfcfffffffff
-- 059:5555522555555525555555555255525225252525252525252525252552552525
-- 060:2525555552555555555555555522552225525252252252522552525225225522
-- 063:dddfee00ddddffe0ddddddfe0ddddddf00dddddd000ddddd0000dddd00000ddd
-- 072:88888888aaaaaaaa999999999ffff9999fffff9f9ff9ff9f9ff9ff9f9ff9ff9f
-- 073:88888888aaaaaaaa99999999fff99ff9ffff9ff9f9ff9ff9f9ff9ff9ffff9ff9
-- 074:88888888aaaaaaaa99999999ff99ffffff9fffffff9ff999ff9ff999ff9ffff9
-- 075:88888888aaaaaaaa999999999fffff999fffff999ff999999ff999999ffff999
-- 076:9999999999999999999999999999999999999999999999999999999999999999
-- 077:999999a8999999a8999999a8999999a8999999a8999999a8999999a8999999a8
-- 078:888888888bbbbbaa8b9999998b9999998b9999998b9999998a9999998a999999
-- 079:000000ee000000ef00000efd00000edf000000e4000004440000044400000044
-- 088:9fffff9f9ffff99f9ff9999f9ff9999f9ff9999f999999999999999999999999
-- 089:ffff9ff9f9ff9ff9f9ff9ff9f9ff9ffff9ff99ff999999999999999999999999
-- 090:ff99ffffff9999ffff9999ffff9ffffff99ffff9999999999999999999999999
-- 091:9ffff9999ff999999ff999999fffff999fffff99999999999999999999999999
-- 092:88888888aaaaaaa8999999a8999999a8999999a8999999a8999999a8999999a8
-- 093:8a9999998a9999998a9999998a9999998a9999998a9999998a9999998a999999
-- 094:8a9999998a9999998a9999998a9999998a9999998a9999998aaaaaaa88888888
-- 095:0000004400000000000000000000000000000000000000000000000000000000
-- 096:00000000000000000000000000000000e0000000fe000000efe00000eefe0000
-- 097:0000000000000000000000000000000000000000f0000000ef000000eef00000
-- 098:000000000000000e0000000e0000000e00000000000000000000000000000000
-- 099:ef000000eef00000eeef0000eeeef000eeeeef00eeeeeef00ddeeeef00ddeeee
-- 100:000000000000000e0000000e0000000e00000000000000000000000000000000
-- 101:ef000000eef00000eeef0000eeeef000eeeeef00eeeeeef00ddeeeef00ddeeee
-- 102:00000000000000000000000000000000000000000000000000000000f0000000
-- 103:deeeefe0eeddddddddd7777e4477777744477777444777774337777734377777
-- 104:d0000000d0000000dd7000007777000077777000777770007777770077777700
-- 105:3447777744447777444447774444444704444447004444ff00004fff000000ff
-- 106:000000000000000000000000000000000000000000000000000000000000000f
-- 107:00000000000f000000fff0000deeef00ffdddeffeeffeddeeeeefffddddeeeef
-- 108:00000000000000000000000000000000f0000000effff000deeeeffffddeeeee
-- 109:000000000000000000000000000000000000000000000000fff0eeeeeeefee5e
-- 110:000000000000000000000000000000000000000000000000000eeee0000e5ee0
-- 111:4444440044444440444444444444444444444444444444444444444444444444
-- 112:deefe000ddeefe00dddeefe0ddddeefedddddeefddddddeedddddddfcdddddde
-- 113:00000000000000000000000000000000e0000000fe000000ffee0000ffffe000
-- 114:deefe000ddeefe00dddeefe0ddddeefedddddeefddddddeeddddddde0ddddddd
-- 115:00dddeee000ddeee0000ddee00000dde000003dd0000033d0000033300000333
-- 116:0000000000000000000000000000000000000000000000000000000000000004
-- 117:00dddeee003ddeee0033ddee00333dde003333dd0443333d4443333344433333
-- 118:ef000000eef00000eedf0000eeedf000eeeedf00deeeddf0ddeedddfdddeeddd
-- 119:000000000000000000000000000000000000000000000000f0000000df000000
-- 120:7777777077777770777777777777777777744444744444444444444444444444
-- 121:0000000000000000000000000000000040000000444000004444000044444000
-- 122:0000000e0000000e000000fe000000fe0000000e0000000e0000000e0000000f
-- 123:dddddeeeeeddddeeeeeffddeddeeeeddedddeeffeedddeefeeedddeeeeeeeddd
-- 124:edddddffeedddfeeeeeddfeeeeeeefeedeeeefeefdeeefeeffffefeeeeeeefee
-- 125:deeeeeeeedefffffeedfffffeeedeeeeeeedeeeeeeeeddddeeeeddddeeeedddd
-- 126:eeeeeee0fffffff0fffffff0eeeeeeeeeeeeeeeeddeedddddffddddddffddddd
-- 127:00000000000000000000000000000000ee000000de000000dde00000dde00000
-- 128:0ddddddf00dddddd000cdddd0000cddd00000def0000000e0000000d0000000e
-- 129:effffe00feffffe0fefffffefeefffedfeeeedddfedddefeeddeff77eef77777
-- 130:00cddddd000cdddd0000dddd00000ddd000000cd000000cd0000000c00000000
-- 131:0000443300044433004444330044773300777773000777770007777700007777
-- 132:0000000400000007000000000000000000000000000000000000000000000000
-- 133:4773333377773333777773337777773307777773077777777777777777777777
-- 134:dddeeeddddddeeddddddeeed7dddeeef77deeeef77eeeeff77eeeeff77deeeff
-- 135:ddf00000ddff0000fffff000ffffff00ffffff00ffffff00fffffff0ffffffff
-- 136:4444444404444444044444440044444400044444000444440000444400000444
-- 137:00000222000022340000334c0000334c00000344000000340000000300000000
-- 138:22220000ccf30000cddf0000dddef000deeeef00eeeeeef03ddeeeef00ddeeee
-- 139:eeeeeedd0eeeeeee00feeeee000feeee0000ffee000000ff0000000f00000000
-- 140:ddeddfefddeddfefeeeddfefeeedddffeeedddfefeeddddffefeddddfffeeddd
-- 141:ffeffdddffeffeddefeffeddeeeffeddeeeffeddfffefedddddefedddddeeedd
-- 142:ddffededddfeeefdddfeeeedddfeeeedddfeeeedddfeeeeeddfeefeeddfeefee
-- 143:ddd00000dddf0000ddef0000ddef0000ddef0000ddef0000fdee0000fdee0000
-- 144:000000000000c0000000cd000000cde00000cddf0000cdde0000cddd0000cddd
-- 145:0f477777044477770444477704444e7704443fee044434fe0444344e0043344f
-- 146:0000000000000000000000000000000000000000000000000000000000000004
-- 147:0000777700077777000777770004777700444777044444774444444444444444
-- 148:0000000000000004000000040000004400000444000004440000444400044444
-- 149:4777777744777777444777774444477744444440444444004444440044444000
-- 150:77fdeeff77fdeeff77efdeef00efdeef00eefdee00eefdee000eeede000eeeee
-- 151:ffffffffffffffffffffffffffffffffffffffffffffffffefffffffefffffff
-- 152:00000000f0000000ff000000ff000000fff00000ffff0000ffff0000ffff0000
-- 153:0000000000000000000000000000000000000000000000000000000000000004
-- 154:00dddeee003ddeee0033ddee00333dde003333dd0443333d4443333344433333
-- 155:0000000000000000000000000000000000000000000000000000000000c00000
-- 156:0ffeeedd0effeeed0efefeee0efeffee0ef44eff0ef44eef00eff777000e7777
-- 157:dddeeedddddeeedddddeeeddeedfeeddeeeffeddfeeffeddffeffedd7ffffedd
-- 158:dffeefeedfffeeeedfffeeeedfffeeeedfffeeeedfffeeeedfffeeeedfffeeee
-- 159:efee0000effe0000effe0000effe0000effef000eefef000eefef000eefee700
-- 160:00000cdd00000cdd000000cd000000cd0000000d0000000d0000000000000000
-- 161:0033444400044444000444440000444400000444000000440000004400000004
-- 162:0000004400000444000044440004444400444444044444444444444444444444
-- 163:4444444444444444444444444444444044444440444444004444440044444400
-- 164:0004444400444444044444440444444444444444444444444444444444444444
-- 165:4444400044444000444400004444000044440000444000004440000044400000
-- 166:0000feee0000ffee00000ffe00000fff000000ff000000f0000000f4000000f4
-- 167:eeffffffeefffff3eeefff33ffff333300f3333344f3333344f3333340333333
-- 168:fff3000033330000333330004433300044443300444773303447773037777777
-- 170:0222222002223322023333442233344423334444233444442334444423344444
-- 171:00000000222e000044eee0004cddde00eecccdeeddeedcdeddddeefdcccddeef
-- 172:0004777700447777044477770444477744444777444444774444444700444447
-- 173:77fffedd777ffedd77777fff7777777777777777777777777777777777777777
-- 174:dfffeeeedfffeeeeffffffee7777777777777777777777777777777777777777
-- 175:eefee770eeeee770eeee77707777777077777770777777707777770077777700
-- 176:00000000000000000d000000dd000000dd000000ed777700ed77777777777777
-- 177:0000000000000000000000000000000000000000000000007000000077000000
-- 178:4444444444444444444444444444444444444444444444444444444444444444
-- 179:4444400044444000444440004444000044440000444000004440000044000000
-- 180:4444444444444444444444444444444444444444444444444444444444444444
-- 181:4440000044000000440000004400000044000000400000004000000000000000
-- 182:000000ff000000ff0000000f0000000f00000000000000000000000000000000
-- 183:003333330333333303333333f3333333ff3333330f3333330033333300033333
-- 184:3777777737777777333777773337777733337777333377773333777733337777
-- 185:0000000070000000770000007777000077777000777777007777444077444440
-- 186:3344444d3334444d033344ed033334ed0033333d0000333d0000033d0000000f
-- 187:ccccdeeeddcccceedddeedceccdddedddcccddefddccceefeeecdddeeeeffddd
-- 188:0044444700044447004444470044444400444444000444440004444400044444
-- 189:7777777777777777777777777777777777777777777777744777774447777444
-- 190:7777777777777777777777777444444444444444444444444444444444444444
-- 191:7777770077777700777777004477770044447770444444704444444444444444
-- 192:77777777777777777777777777777777f7777777ef777777eef77777eeef7777
-- 193:7770000077777000777777007777777777777777777777777777777777777777
-- 194:33deeedd333deedd333deeed333deeef333eeeef333eeeff733eeeff773eeeff
-- 195:ddf00000ddff0000fffff000ffffff00ffffff00ffffff00fffffff0ffffffff
-- 196:88888888bbbbbaaab9999999b9999999b9999999b999ffffa9ffffffa9ffffff
-- 197:88888888aaaaaaaa999999999999ff999fffffffffffffffffffffffffff99ff
-- 198:88888888aaaaaaaa9999999999999999fffffffffffffffffffffffffffff999
-- 199:88888888aaaaaaa8999999a8999999a8fffff9a8fffff9a8ffff99a8999999a8
-- 200:88888888bbbbbaaab9999999b999999fb9999fffb999ffffa99fffffa9ffffff
-- 201:88888888aaaaaaaa99999999f9999999ffffffffffffffffffffffffffffffff
-- 202:88888888aaaaaaaa9999999999999999ffffffffffffffffffffffffffffffff
-- 203:88888888aaaaaaa8999999a899ff99a8fffff9a8fffff9a8ffff99a8ff9999a8
-- 204:888888888aaaaaaa8a9999998a9999998a9999998a9999998a9fffff8a9fffff
-- 205:88888888aaaaaaaa999999999999999999999999f9ffff9fffffffffffffffff
-- 206:88888888aaaaaaaa999999999999999999999999fff9ffffffffffffffffffff
-- 207:88888888aaabbbbb9999999b9999999b9999999b9ffff99bffffff9afffff99a
-- 208:feeef7774feeef7744feeeff44feeeee444feeee4444e0004444000044000000
-- 209:7777777777777777f7777444ef74444400044444000444440000444400000444
-- 210:77fdeeff77fdeeff77efdeef77efdeef77eefdee77eefdee777eeede400eeeee
-- 211:ffffffffffffffffffffffffffffffffffffffffffffffffefffffffefffffff
-- 212:a9ffffffa9ffffffa99fff99a9999999a9999999a9999999aaaaaaaa88888888
-- 213:fff9ff999999999999999999999999999999999999999999aaaaaaaa88888888
-- 214:fffff9999999999999999999999999999999999999999999aaaaaaaa88888888
-- 215:0000000d00000000000000000000000000000000000000000000000000000000
-- 216:a999ffffa9999fffa999ffffa99fffffa99fffffa9999999aaaaaaaa88888888
-- 217:fff9f9f9ffffff99fff99999fff99999ff99999999999999aaaaaaaa88888888
-- 218:999999999999999999999999999999999999999999999999aaaaaaaa88888888
-- 219:999999a8999999a8999999b8999999b8999999b8999999b8aabbbbb888888888
-- 220:8a9fffff8a9fffff8b9999998b9999998b9999998b9999998bbbbbaa88888888
-- 221:fffffffffffffffff9ffffff999999999999999999999999aaaaaaaa88888888
-- 222:fffffffffffffffffffff999999999999999999999999999aaaaaaaa88888888
-- 223:fff9999af999999a9999999a9999999a9999999a9999999aaaaaaaaa88888888
-- 224:88888888aaaaaaaa999999999999999999999999999999999999999999999999
-- 225:888888888bbbbbaa8b9999998b9999998b99ff9f8b99ff9f8a99ff9f8a99ffff
-- 226:88888888aaaaaaaa9999999999999999f9ffff99f9fffff9f9ff99f9f9ff99f9
-- 227:88888888bbbbbaaab9999999b9999999b999fff9b99fffffa99ff9ffa99ff9ff
-- 228:88888888aaaaaaaa99999999999999999ff9ff9f9fffff9f9fffff9f9fffff9f
-- 229:88888888aaaaaaaa9999999999999999f9ff99ffffff9fffffff9ff9ffff9ff9
-- 230:88888888aaaaaaaa9999999999999999f9999999ff999999ff999999ff999999
-- 231:88888888bbbbbaaab9999999b9999999b99ff999b99ff999a99ff999a99ff999
-- 232:88888888aaaaaaaa99999999999999999ff9ff9f9ff9ff9f9ff9ff9f9ff9ff9f
-- 233:88888888aaaaaaaa9999999999999999f9999999f9999999f9999999f9999999
-- 234:88888888bbbbbaaab9999999b9999999b999ffffb99fffffa99ff999a99ffff9
-- 235:88888888aaaaaaaa999999999999999999ffff999fffff9f9ff9999f9ff9999f
-- 236:88888888aaaaaaaa9999999999999999fff99fffffff9ffff9ff9ff9f9ff9ff9
-- 237:88888888aaaaaaaa9999999999999999f99fffffff9fffff9f9ff9999f9ffff9
-- 238:88888888bbbbbaaab9999999b9999999b9999999b9999999a9999999a9999999
-- 239:88888888bbbbbaaab9999999b9999999b9999499b9444949a9499499a9999999
-- 240:999999999999999999999999999999999999999999999999aaaaaaaa88888888
-- 241:8a99ff9f8a99ff9f8a99ff9f8a99ff9f8a9999998a9999998aaaaaaa88888888
-- 242:f9fffff9f9ffff99f9ff9999f9ff99999999999999999999aaaaaaaa88888888
-- 243:a99fffffa99ff9ffa99ff9ffa99ff9ffa9999999a9999999aaaaaaaa88888888
-- 244:9f9f9f9f9f9f9f9f9f999f9f9f999f9f9999999999999999aaaaaaaa88888888
-- 245:9f9f9ff99f9f9ff9999f9fff999f99ff9999999999999999aaaaaaaa88888888
-- 246:ff999999ff999999ff999999f99999999999999999999999aaaaaaaa88888888
-- 247:a99ff999a99ff999a99fffffa99fffffa9999999a9999999aaaaaaaa88888888
-- 248:9fffff9f99fff99f99fff99f999f999f9999999999999999aaaaaaaa88888888
-- 249:f9999999f9999999ffff9999ffff99999999999999999999aaaaaaaa88888888
-- 250:a999ffffa99999ffa99fffffa99ffff9a9999999a9999999aaaaaaaa88888888
-- 251:9ff9999f9ff9999f9fffff9f99ffff999999999999999999aaaaaaaa88888888
-- 252:f9ff9ffff9ff9fffffff9ff9fff99ff99999999999999999aaaaaaaa88888888
-- 253:ff9ffff9f99ff999ff9fffffff9fffff9999999999999999aaaaaaaa88888888
-- 254:a9999999a9999999a9999999a9999999a9999999a9999999aaaaaaaa88888888
-- 255:a9999999a9999d99a9ddd9d9a9d99d99a9999999a9999999aaaaaaaa88888888
-- </TILES>

-- <SPRITES>
-- 000:0000eeee00ff66660f666c6606ff66660666eeee0f6666660ff6666606ffeeee
-- 001:eeee00006666dd00666666d06666dd60eeee6660666666d066666dd0eeeedd60
-- 002:0000000002200000020000020c00000c0c00000c0c00000c4440003404000003
-- 003:000000002200000220000022c00000c0c00000c0c00000c04400044440000040
-- 004:0000000000000000033333333333333302222222000000ff000000df000000de
-- 005:0000000000000000333333303333333222222220ff000000ff000000ff000000
-- 006:0000000300320003032003030c2020030c00c0340c00c0340c00403044004340
-- 007:400000004000000340002032400320c2440c00c0440c00c0040400c004440044
-- 008:0000007700007665000766560075666600756667000666730007766300000703
-- 009:7550000077557000576666005665766075565560377656703066660030077000
-- 016:066feeee0f6666660ff6666606ffeeee066feeee0f66666600ff66660000eeee
-- 017:eeeed660666666d066666dd0eeeedd60eeeed660666666d06666dd00eeee0000
-- 018:0400000303440003000344430000000300000003000000030000033400003444
-- 019:4000004040004430444430004000000040000000400000004440000044440000
-- 020:000000de000000de000000de000000de000000de000000de0000ddee000ddeee
-- 021:ef000000ef000000ef000000ef000000ef000000ef000000eff00000eeff0000
-- 022:0400444004444000000000000000000000000000000000000000000000000000
-- 023:0444004000044440000000000000000000000000000000000000000000000000
-- 024:000000030000000300000aa30000aaf30000aff30000aaff00000aaa00000aaa
-- 025:30000000300000003aa000003f8800003ff80000ff9800009980000099800000
-- 048:0fff0000fffff000ff0ff000ff0ff000ff0ff000ff0ff000fffff0000fff0000
-- 049:00ff00000fff0000ffff000000ff000000ff000000ff0000fffff000fffff000
-- 050:0fff0000fffff000f00ff000000ff00000ff00000ff00000fffff000fffff000
-- 051:ffff0000fffff000000ff000fffff000fffff000000ff000fffff000ffff0000
-- 052:00fff0000ffff000ff0ff000ff0ff000fffff000fffff000000ff000000ff000
-- 053:fffff000fffff000ff000000ffff00000ffff000000ff000fffff000ffff0000
-- 054:0ffff000fffff000ff000000ffff0000fffff000ff0ff000fffff0000fff0000
-- 055:fffff000fffff00000fff00000ff00000fff00000ff00000fff00000ff000000
-- 056:0fff0000fffff000ff0ff000fffff000fffff000ff0ff000fffff0000fff0000
-- 057:0fff0000fffff000ff0ff000fffff0000ffff000000ff0000ffff0000fff0000
-- 058:000000000ffffff0ffffffffff0ff0ffffffffff0ffffff00000000000000000
-- 059:00000000000ff00000feef000feddef00feddef000feef00000ff00000000000
-- 060:0000200002020000002220200222220020222202002222200222020022020020
-- 061:0000000000000ff0000ffff00ffffff00ffffff0000ffff000000ff000000000
-- 062:0000000000000ee0000eeee00eeeeee00eeeeee0000eeee000000ee000000000
-- 064:00000000000effff00deffff0ddeeeee0ddddddd0fffffff0fdddddd0f3deeee
-- 065:00000000ffffe000ffffed00eeeeedd0ddddddd0fffffff0ddddddf0eeeed3f0
-- 066:000000000000000000000000000000000000000000000d340000fd340000fedd
-- 067:0000000000000000000000000000000000000000333d0000333df000dddef000
-- 070:0000000000000000000000000033300003444300343034303400043034303430
-- 071:00000000000000000000000000ddd0000dcccd00dcd0dcd0dc000cd0dcd0dcd0
-- 072:2222222222222222222200222200002222000222220002222000022200000022
-- 073:2222222222222220222222002222220022222200220220002002000000020000
-- 074:2222222222222222022222220222220202222202002220020020200000002000
-- 075:2222222222222222222222022222200202222002002220000002200000020000
-- 076:000dddd0000deeee00deeeee000244ee20044444002244462000046500000e65
-- 077:000000000000000000000000e000000065000000555500005555550055576650
-- 078:00000000000000000000000000000000000000000000000a020000aa0000000a
-- 079:0000000000000000000000000000000000000000a90000009fff00009ff00020
-- 080:0fe3effe0fde33ff0fddeee20fddddd20fddd2220feee2220feeeee20ffffff2
-- 081:effe3ef0ff33edf02eeeddf02dddddf0222dddf0222eeef02eeeeef02ffffff0
-- 082:0000feee0000fefe0000fefe0000fefe0000fefe0000fefe0000feee0000ffff
-- 083:eeeef000eefef000fefef000fefef000fefef000fefef000feeef000fffff000
-- 084:0000000004440444044404440333033303430343022202220222022202220222
-- 085:0000000004440444044404440333033303430343022202220222022202220222
-- 086:0344430000343000003430000034300000344300003430000034430000033000
-- 087:0dcccd0000dcd00000dcd00000dcd00000dccd0000dcd00000dccd00000dd000
-- 092:00000e6500005e66000056e60005567e000560660055606e0055606605560067
-- 093:555776556556706566667065e6667044fff77044eefff0006667700066666000
-- 094:000000020000200402000004000aaeec00aaaafa0aaa99f9aaa8999faaaa3eee
-- 095:22200000444020003340002011c00000a9990000aaa99900aa99999099988990
-- 097:00000000000000000000000000000000000000000000000000eee000ddeeed00
-- 108:4400006744000666000000560000055600005567000055670000557700005666
-- 109:7776670066667700665660006556600065567000555570005555700065556700
-- 110:0a93eeee0933448f00044488000098880000a9990000aaa90000aaa90000aaa9
-- 111:eedd8898dddddd88f34448888844888088888800889880008999880099aa9800
-- 112:00000000000000000000000600044777024422ee2000eeee000eeeef000eeff0
-- 113:deeeee670666677766555555ee655556eef667ffef777feef77700ee00000000
-- 114:ff000000725600005625550066726655e7726666eff22222eeef2200eeee0000
-- 115:0000000000000000000000006600000066444000220000000000000000000000
-- 116:0000000000000000000044890004ee880024eee82222eee800000eef000000ee
-- 117:000044409222222292aa22aa999a229998998288f8888222f800022200000000
-- 118:0000000020000000aa8aa98e999f98ee888898ee8888feee0000fee200000000
-- 119:0000000000000000e0000000e000000000000000000000000000000000000000
-- 124:0000066600000eee00000eef00000eff00000eef00000eef0000eeff00000000
-- 125:f6566670f066ff00f06feff0f0feef00000eef000000eff00000eef0000eeff0
-- 126:0000aaa9000aaa90000aa99800009888000088ff0000888f0000088f0000888f
-- 127:9aaa980009aa988009999980008888000888f0000888f0000088ff0000ffff00
-- 128:0000000000000000000000000000000a00000aaa000009990000002200000044
-- 129:000000000000000000000000af000000fff00000ff0000002200000044000000
-- 130:00000000000000000000000000000000000aa90000a9999000a9449900224440
-- 131:000000000000000000000000000000000a900000aaa99000aa99990044422000
-- 132:000000000000000000000000000000aa00000a9900000a990000004400000044
-- 133:00000000000000000000000090000000fff00000fff000004400000044000000
-- 134:000000000000000000000000000000000000000a00000aa90000009900000022
-- 135:00000000000000000000000000000000a90000009ff00000ff00000022000000
-- 136:0000000000000000000000000000000900000aa90000aa9f00000a9f00000222
-- 137:00000000000000000000000000000000f0000000ff000000f000000020000000
-- 138:0000000000000000000000000000000900000aa90000aa9f00000a9f00000222
-- 139:00000000000000000000000000000000f0000000ff000000f000000020000000
-- 142:00000000000000000000000000000000000000000000009a0000009900000002
-- 143:00000000000000000000000000000000aaf00000a9ff00009ff0000022200000
-- 144:0000004300000e3400aae9c10aa9e99a0a99ee99aa9998e8aa9988e8aaa9888e
-- 145:3400000043e000001c999900aaaaaa90aa9aa9909999999988898899888888d0
-- 146:0034444000434440000ffff000dea9900eeaa9890eaaaa980faaa99800f99998
-- 147:4444300044434000eeef0000f99ed0009aa9ef00aa998800aa998800a9998800
-- 148:00000044000000ff000aaaa900aaa9990aaa9999aa989998aa888988a99f888f
-- 149:44000000ff00000098ff0000998f990098f899908f888a99f88899a9f88f9a99
-- 150:000000440000004300000ec1000aae9900aaae9a0aaa9ee90aa988e90a9988ff
-- 151:44000000340000001ce0000099980000a9998000aaa980009aaa980088899980
-- 152:00000444000004330000ec11000ae89900ae88990aaee9990a99e9990a9add99
-- 153:4000000040000000c90000009aa9000099a900009aa90000aaa90000aaaa8000
-- 154:00000444000004330000ec11000ae89900ae88990aaee9990a99e2990a9a4332
-- 155:4000000040000000c90000009aa9000099a900009aa90000aaa90000aaaa8000
-- 156:0000000a000000aa02000a220000004400220de42020de44000deeff00dd9288
-- 157:a800000298800000228002004400000044202002f29292002299299022299449
-- 158:0000000400000994000aaffc00aa9f8800a998f800aa38ff00933d8f00943ed8
-- 159:444000003340000011c90000999990009aaa990099aaa900f99aa900f99aa900
-- 160:99aa33dd099a348800a44488000044ff000099880000999800009a980000aa98
-- 161:dddddddd834443008f444000fffff00088880000899800009aa900009aa90000
-- 162:ddf9999844a9a99844aa999800a999980aaaa9980aaa9a9800aaaa9800aaa980
-- 163:998aaadd9888aa44a9888444a9998800aa998800aaa99800aa999000aaa98000
-- 164:998f8fff08ffeeef000999990009a9990009aa980009aa98000aaa98000aaa98
-- 165:888f8898ffffff009988800099988000899800009a9800009aa900009aa90000
-- 166:0998dddd08933eee0084483400044484000a9988000aa99800aa999800aa9998
-- 167:ddee9980eeee8800443880004488000089980000999800009a9990009aa98000
-- 168:0aaade9909a8de890084444800844448000a988800aaa98900aa998900a99989
-- 169:9aa980009a98800099880000888000009988000099980000aa990000aaa90000
-- 170:0a223c3209a823290084424800844448000a988800aaa98900aa998900a99989
-- 171:2aa980009a98800099880000888000009988000099980000aa990000aaa90000
-- 172:9dd922284448222e44988229440092290000a998000aaa98020aaa98000aaa98
-- 173:ff998844e888800499880000999900209aa900009aaa90009aaa902089999000
-- 174:009448dd0000083d000009840000099400000999000009aa000009aa00000aaa
-- 175:f89aa900d89aa900ddaa98004899800098888000a9888000a9988000a9998000
-- 176:0000aa98000aa998000a99880000ffff000088ff0000fff0000088f0000f8ff0
-- 177:9aa900008aa980008a998000ffff0000f88f00000f8f0000088f0000088ff000
-- 178:00aa998000aaa99800aa99880008fff000088ff000008ff000888ff00fffffff
-- 179:99888000a99880009888800088fff00008fff000088f000088ffff0088fffff0
-- 180:000aa998000aaa98000099880000ffff0000ffff0000ffff00008ff0000ffff0
-- 181:999900009aa90000899f0000ffff0000ffff0000fff800000ff800000ffff000
-- 182:0aaaa98000a998000088888000888f8000088f000008ff800088ff000088f000
-- 183:9aaa800099a9900089998000f88f0000f88f00000fff0000088800000888f000
-- 184:0999908900999809008fff0f0088ff00000fff0000888f000088f00000000000
-- 185:aaa900009998800099980000888f0000f88f00000fff0000f88f0000088ff000
-- 186:0999908900999809008fff0f0088ff00000fff0000888f000088f00000000000
-- 187:aaa900009998800099980000888f0000f88f00000fff0000f88f0000088ff000
-- 188:00aaa99000aa9980008888800088f800008880000088f0000f88f0000ffff000
-- 189:0f8ff00008888000008888f000088ff00008fff0000fff000000000000000000
-- 190:00000aaa000009aa0000089900000888000008880000088f000008880000088f
-- 191:aa898000a9888000ffff0000ff8f0000ff880000f0880000ff000000ff000000
-- 192:000000dd00000dde00000d2200000d440000004300000f340000eed30006e666
-- 193:ee000000eee0000022e0000044e000003400000043f00000366f000065556600
-- 194:00dddd000eeeedd0022eeed004444ee00034440000444ff000dfffff0ef55667
-- 195:00dddd000ddeeee00deee2200ee44440004443000ff44400ffeffd00766e5f60
-- 196:000000dd00000ddd00000dee00000eee0000004400055eee0055566e00566677
-- 197:de000000eee00000eee00000eee0000044000000efe65000eee665006e776500
-- 198:0000000d000000dd000000d2000000d400000004000000d300005dee005566e6
-- 199:dee00000eeee0000222e0000444e000033400000443e000033eed00066655550
-- 200:000000dd00000dde00000d2200000d44000000fd000566fe0065554407766444
-- 201:ee000000eee0000022e0000044e00000d4000000e46665003445567034466670
-- 202:000000dd00000dde00000d2200000d420000002c000566f20065554207766444
-- 203:ee000000dde0000022e0000034e0000043000000336665002445567034466670
-- 204:0000eee0000eeeee000eedff000edfff000efff3000efff30000003300000033
-- 205:00000000d0000000f0000002f000002033333000344200024444420066f44000
-- 206:0000000d000000dd000000d20000000400000004000000e300006eee000566d6
-- 207:dde00000eeee0000222e0000444000003340000044360000e666560066655560
-- 208:00555e65005656e60556556e056765560567f5550567feec0567ffee05676555
-- 209:565555605655555066557550ee6675507efe7650deeef650eefff65075567650
-- 210:0e7565670666555700e65557006e667700df657f00df555f0055557700547777
-- 211:7656f7607555e6607555ff0077667f00f756fc00f555fc007755550077774500
-- 212:055755660557766f055677ff0557fff7056eedde0567edde0567655506675555
-- 213:ff757550f6677650e66766506e777650eeff7650eefff6505556765055567660
-- 214:055666ee57777f6f55700f6656700ffe57700fff44446566044d5556004fd566
-- 215:66555655e6656655fed66665cdfff776cdfeff65777666666756664467666440
-- 216:007777430006667e00066667000056770000fffc0000fffc0006666700066667
-- 217:34466670e5777000fe667000eff67000dfff0000dfff00007667700076667000
-- 218:007777430006667e00066667000056770000fffc0000fffc0006666700066667
-- 219:34466670e5777000fe667000eff67000dfff0000dfff00007667700076667000
-- 220:0020000600000005000000660000202600200022000000e50000055500000555
-- 221:556f0002555500005565744067777440667f0440567220005562000055672002
-- 222:000566de0005566e000555660005556d0005554d000556440000666600000666
-- 223:66555760e66557606f665760e6f66760e6f66760fffff6606f66760076667000
-- 224:0447665500477777000755660006555e00065556000655660006555600007566
-- 225:75567440777774007656700075566000e5556000e55560007555600075567000
-- 226:0044447700744ff0006676670055556700555670005556700055557000055567
-- 227:774444000ff44700766766007655550007655500076555000755550076555000
-- 228:004755550047777700066667000656660006556700055567000555770006677e
-- 229:6555740077777400765670007555600075556000755560007756600076776000
-- 230:0000ed7700000d76000066660000655600006555000655660006556700075667
-- 231:7777777067666670676656707765557070755560707555607066667000766770
-- 232:0066666700655667006555770065557700555670065566700655677006566700
-- 233:7666700076656700775557000655570007555700066555700765577000665770
-- 234:0066666700655667006555770065557700555670065566700655677006566700
-- 235:7666700076656700775557000655570007555700066555700765577000665770
-- 236:0000766600007765000006650000067600000667000066660006556f0006566e
-- 237:666702005677000055670002555600006655700055777000f6577000ef770000
-- 238:0000555600005555000055770000656700000667000066670000077700000eee
-- 239:7666670076556700655567006555600065556000655560006556700076577000
-- 240:000076670000efff0000eeef0000eeef0000eee000000ee00000eee0000eeee0
-- 241:765670000efff0000eeef0000eeef0000eeef0000eee00000eeee0000eeee000
-- 242:00065667000eeef0000eeef0000eeef00000ef00000eef000eeeeef0eeeffff0
-- 243:766560000feee0000feee0000feee00000fe000000fee0000feeeee00ffffeee
-- 244:0000677e0000eefe0000eefe0000eff00000eff0000eeef0000eeff00000ef00
-- 245:76670000eeef0000eeff00000eff00000fff00000fffe0000fffe00000ff0000
-- 246:00077777000feef0000feef0000eeef000feef0000feef000feeef000feeee00
-- 247:0077677000feee0000feef0000feee00000eee00000eef00000eeef0000eeef0
-- 248:0e667f000e667f000feee0000feee0000fee00000eee0000eeee0000eeee0000
-- 249:00f6670000feee0000feef00000eee00000feef00000eee00000eeef0000ffff
-- 250:0e667f000e667f000feee0000feee0000fee00000eee0000eeee0000eeee0000
-- 251:00f6670000feee0000feef00000eee00000feef00000eee00000eeef0000ffff
-- 252:00ff66ee00eefeee0eeefeeefeeff0eeeeef00eeeeef000eefff00000eeff000
-- 253:eff00000e0000000f0000000ef000000ef000000ef0000000000000000000000
-- 254:000000ff000000ee000000ee000000ee000000ee000000000000000000000000
-- 255:77676000f7667000feeff000feee00000eee00000eef0000eeee0000eeee0000
-- </SPRITES>

-- <MAP>
-- 000:000000000000004040400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 001:000000000040404444444040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 002:000000404044444848484444404000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 003:000040444448484c4c4c4848444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 004:00004044484c4c4e4e4e4c4c484440000000000000000000000000000000000000000000000000000000000000000000000000909090909090900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 005:004044484c4e4e0000004e4e4c4844400000000000000000000000000000000000000000000000000000000090909000000000900000000000909000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 006:004044484c4e00000000004e4c4844400000000000000000000000000000000000000000000000000000000090009090909090900090909000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 007:4044484c4e000000000000004e4c48444000000000000000000000000000000000000000000000000000000090000000000000000090000090009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 008:4044484c4e000000cd0000004e4c48444000000000000000000000000000000000000000000000000000000090909090900090900090909090009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 009:4044484c4e000000000000004e4c48444000000000000000000000000000000000000000000000000000000000000000900090000000000000009000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 010:10484c4e0000000000000000004e4c481000000000000000000000000000000000000000000000101010101010109090900090900090909090909000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 011:104c4e00000000000000000000004e4c1000000000000000000000000000000000000000000010000000000000000000000000000090000000004040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 012:104e000000000000000000000000004e1000000000000000000000000000000000000010101010000010101010109090900090900090000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 013:100000000000000000000000000000001000000000000000000000000000000000001000000000000000000000109000900000900090000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 014:001000000000000000000000000000000010000000000000000000000000000000001000000000000000000000109000909090900090000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 015:00100000000000000000000000000000001000000000a0a0a0a0000000000000000010000000000000000000001090000000000000900000004000000000c00000000000000000c00000000000000000c00000000000000000c00000000000000000c00000000000000000c0000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 016:00001000000000000000000000000000000010000000a00000a000000000000000001000000000000000000000109090909090909090000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 017:000010000000000000000000000000000000001010101000001010101080808080808010101010000010101010000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 018:000000100000000000000000000000000000000000000000000000001000000000000080808080000080808080000000000000000050505050400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 019:000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000808080808080808050000050400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 020:000000000010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050bcbc50a0a0a1a1a2a2a3a3a4a4a5a5a6a6a7a7a8a8a9a9aaaaababacacadadaeaeafaf00000000000000000000000000000000000000000040a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 021:00000000000000101000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 022:000000000000000000101010101010101010101010101000001010101080808080808080808080000080808080808080808080808050505050a0a0a1a1a2a2a3a3a4a4a5a5a6a6a7a7a8a8a9a9aaaaababacacadadaeaeafaf00000000000000000000000000000000000000000040a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 023:00000000000000000000000000000000000000000000a00000a000000000000000000010101010000010101010101000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 024:00000000000000000000000000000000000000000000a0a0a0a000000000000000001000000000000000000000000010000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 025:00000000000000000000000000000000000000000000000000000000000000000000100000000000000000b000000010000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 026:00000000000000000000000000000000000000000000000000000000000000000000100000000000000000b000000010000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 027:00000000000000000000000000000000000000000000000000000000000000000000100000000000000000b0000000100000000000000000004000000000c00000000000000000c00000000000000000c00000000000000000c00000000000000000c00000000000000000c0000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 028:00000000000000000000000000000000000000000000000000000000000000000000100000000000000000b000000010000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 029:00000000000000000000000000000000000000000000000000000000000000000000100000000000000000b000000010000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 030:000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000010000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 031:000000000000000000000000000000000000000000000000000000000000000000001010101010101010101010101010000000000000000000004040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 091:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e40e0e0e0e8494a4b40e0e0e0ec5
-- 092:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d5c4c4c4c48595a5b5c4c4c4c4d4
-- 093:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d5c4c4c4c4c4c4c4c4c4c4c4c4d4
-- 094:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d5c4c4c4c4c4c4c4c4c4c4c4c4d4
-- 095:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d5c4c4c4c4c4c4c4c4c4c4c4c4d4
-- 096:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d5c4c4c4c4c4c4c4c4c4c4c4c4d4
-- 097:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d5c4c4c4c4c4c4c4c4c4c4c4c4d4
-- 098:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d5c4c4c4c4c4c4c4c4c4c4c4c4d4
-- 099:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d5c4c4c4c4c4c4c4c4c4c4c4c4d4
-- 100:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d5c4c4c4c4c4c4c4c4c4c4c4c4d4
-- 101:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e50f0f0f0f0f0f0f0f0f0f0f0fbd
-- 107:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b900000000091600000000
-- 108:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f0f20000000a2706000000
-- 109:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007df3f1e200002807170000
-- 110:0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f4768600000008180b1b
-- 111:0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f5968797000000190c1c
-- 112:0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000088f60000001a0d1d
-- 113:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000026366600000098a866000000465666000000aabac6d6e600a6b6c6d6e600
-- 114:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000376777000099a967770000475767770000abbbc7d7e7f7a7b7c7d7e7f7
-- 115:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000382c3c000048586878000048586878000000b8c8d8e8f800b8c8d8e8f8
-- 116:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000029392d3d89004959697989004959697989000000c9d9e9f90000c9d9e9f9
-- 117:0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3a6a7a8a004a5a6a7a8a9a4a5a6a7a8a9a0000cadaeafa0000cadaeafa
-- 118:0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002b3b6b7b8b9b4b5b6b7b8b9b4b5b6b7b8b9b0000cbdbebfb0000cbdbebfb
-- 130:0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ccdcecfc
-- 131:0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cdddedfd
-- 132:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000fe8c9cacbc
-- 133:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ff8d9dadbd
-- 134:0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001e2e0e0e0e3e4e5e6e0e0e7e8e9e0e0eaebecede0e0e0e0eeeee4c5c6c7c
-- 135:0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001f2f0f0f0f3f4f5f6f0f0f7f8f9f0f0fafbfcfdf0f0f0f0fefef4d5d6dbd
-- </MAP>

-- <WAVES>
-- 000:ffffff000000ffffff00000000ffffff
-- 001:01134556779abbcdedbba97765433211
-- 002:026acdffda74211269bdeeeeb8643110
-- </WAVES>

-- <SFX>
-- 000:1192215121202110211031203141317141c17121a121d123f123f150f180f110f110f11ff11ff11ff12ff11ff10ff10ff11ff11ff110f100f100f101800000000000
-- </SFX>

-- <SCREEN>
-- 000:4444444444333333333344444444444eeeeeee4444444444444444444433333333333333333333444444444444444444444444444444444444444444444444444444444443333333333333333333344444444444444444444eeeeeeeeee44444444443333333333344444444333333333333333333334444
-- 001:3333334444333333333334444444444eeeeeeeeee44444444444444444444444333333333333333333344444444444444444444444444444444444444444444444444444444444333333333333333333344444444444444444444eeee4444444444333333333344444444444444433333333333333333334
-- 002:33333333333333333333344444444444eeeeeeeee4444444444444444444444444444433333333333333333334444444444444444444444444444444444444444444444444444433333333333333333333333444444444444444444444444444333333333344444444444444444444433333333333333333
-- 003:43333333333333333333344444444444444444eee4444444444444444444444444444444444433333333333333333334444444444444444444444444444444444444444444443333333333433333333333333333334444444444444444444433333333344444444444444444444444444433333333333333
-- 004:444444443333333333333333334444444444444444444444444444444444444444444444444444443333333333333333333344444444444444444444444444444444444444333333333344444443333333333333333333444444444444433333333334444444444444444444444444444444433333333333
-- 005:444444444444444333333333333333333444444444444444444444444444444444444444444444433333333333333333333333333344444444444444444444444444444443333333334444444444444433333333333333333344444433333333334444444444444444444444444444444444444433333333
-- 006:eeee44444444444444444433333333333333333344444444444444444444444444444444444444433333333344444333333333333333333444444444444444444444444333333333444444444444444444444333333333333333333333333334444444444444444444444444444444444444444444443333
-- 007:eeee444444444444444444444444443333333333333333344444444444444444444444444444444444333334444444444443333333333333333334444444444444444333333333444444444e4444444444444444433333333333333333334444444444444444444444444444444444444444444444444443
-- 008:444ee444444444444444444444444444444443333333333333333344444444444444444444444444444444444444444444444444433333333333333333444444444333333333444444444eeeeeeee44444444444444444333333333333333334444444444443333344444444444444444444444444444444
-- 009:444444444444444444444444444444444444444444443333333333333333344444444444444444444444444444444444444444444444444333333333333333334433333333444444444eeeeeeeee444444444444444444444433333333333333333444443333333334444444444444444444444444444444
-- 010:334444444444444444444444444444444444444444444444444333333333333333334444444444444444444444444444444444444444444444444333333333333333333344444444444444eeee44444444444444444444444444444333333333333333333333334444444444444444444444444444444444
-- 011:333333333344444444444444444444444444444444444444444444444433333333333333333444444444444444444444444444444444444444444444444333333333333333344444444444444444444444444444444444444444444443333333333333333334444444444444444444444444444444444444
-- 012:444333333333333333444444444444444444444444444444444444444444444444333333333333333444444444444444444444444444444444444444444444444333333333333333344444444444444444444444444444444444443333333334333333333333333344444444444444444444444444444444
-- 013:444444444443333333333333333444444444444444444444444444444444444444333333333333333333333344444444443333334444444444444444444444444443333333333333333333444444444444444444444444444444433333344444444433333333333333334444444444444444444444444444
-- 014:444444444444444444443333333333333334444444444444444444444444444443333333344444443333333333333334433333333444444444444444444444444333333334444333333333333333444444444444333444444444444444444444444444444333333333333333444444444444444444444444
-- 015:444444444444444444444444444433333333333333344444444444444444444444444444444444444444444333333333333333344444444444444444444444444444333444444433333333333333333334444433333334444444444444444444444444444444433333333333333344444444333333344444
-- 016:444444444444444444eeeee4444444444433333333333333333444444444444444444444444444444444444444444443333333333333344444444444444444444444444444443333333344443333333333333333334444444444444444444444444444444444444444333333333333333333333444444444
-- 017:3334444444444444444eeeeeee4444444433333334444433333333333333444444444444444444444444444444444444444444333333333333334444444444444444444444333333344444444444443333333333333344444444444444444444444444444444444444444443333333333333344444444444
-- 018:333333333333344444444444444444444433333334444444444444333333333333334444444444444444444444444444444444444433333333333333333444444444444333333334444444444444444444443333333333333344444444444444444444444444444444444444444333333333333334444444
-- 019:333333444333333333333344444444444433333334444444444444444444444333333333333344444444444444444444444444444333333344443333333333333344433333334444444eeeeeee44444444444444443333333333333444444444444444444444444444444444444444443333333333333444
-- 020:333333344444444444433333333333334433333334444444444444444444444444444443333333333333444444444444444444433333334444444444444433333333333333444444444444e44444444444444444444444443333333333333444444444444444444444444444444433333334333333333333
-- 021:43333333444444ee444444444444433333333333334444444444444444444444444444444444444433333333333334444444443333334444444eee44444444444443333333333334444444444444444444444444444444443333333333333333334444444444444444444444333333444444444443333333
-- 022:343333333444444eeeeeee4444444444444444433333333333344433333334444444444444444444444444443333333333333333333444444eeeeeee44444444444444444433333333333344444444444444444444444443333444444444333333333333444444444443333333444444e444444444444333
-- 023:333333333333444444444444444444444444444444444444333333333333344444444444444444444444444444444444433333333333344444444444444444444444444444444444433333333333344444444444444444444444444444444444433333333333334333333444444eeeeeee44444444444444
-- 024:444444444433333333333334444444444444444444444443333333444443333333333344444444444444444444444444444444444333333333333444444444444444444444444444444444443333333333334444444444444444444444444444444444433333333333344444444444444444444444444444
-- 025:444444444443333334444443333333333344444443333344444444444444444444443333333333334444444443344444444444444444444444333333333334444444444444444444444444444443333333333333333444444443334444444444444444444443333333333333344444444444444444444443
-- 026:344444444444444444444444333333444433333333333334444444444444444444444444444444333333333333333344444444444444444444444444444333333333334444444444444444444444334444444443333333333333344444444444444444443333444444333333333333444444333334444444
-- 027:4433333333333444444444443333334444444444444443333333333344444444444444444444444444444444333333333334444444444444444eeeee444444333333333333333344444444444444444444444444444444333333333334444444444444444444433333344444433333333333444444444444
-- 028:444333334444444333333333333333444444eeeee44444444444444443333333333444444444444444444444444444443333333333333444444444444443333334444444444433333333334444444444444444444444444444333333333333334444444433333344444ee444444444433333333334444444
-- 029:444433333344444eee44444444443333333333444444444444444444444444433333333333333344444444444444443333334444444433333333334443333344444444444444444444443333333333444444444444444433333444444444433333333333444444444ee44444444444444444433333333334
-- 030:4333333333344444444444444444444444444444333333333344444444444444444444444444444333333333344443333344444eeeee444444444433333333334444443334444444444444444444433333333334433333444444eeeee4444444444433333333334444444444444444444433333444433333
-- 031:44444444444444433333333334444444444444444444444444444333333333444444444444444444444444444433333333334444444444444444444444444333333333333444444444444444444444444444433333333334444444444444444444444444444333333333444444444444444444444444444f
-- 032:33433333444444444444444444444333333333444444444444444444333344444333333333433333444444444444443333344433333333344444443344444444444444444433333333344444444444444444444444444433333333344444444444444444444444443333333333344444444344444fffffff
-- 033:4444444433333333344444444444eeee44444333344333333333444444444444444444444444443333333334444444444444433333444444433333333344444444444444444444444444333333334444444444444444444444444443333333344444444444444444444444444333333333ffffffffffffff
-- 034:444444444444444333344443333333334444433334444444444444444333333334444444444444444333334444433333333333344344eeee44444444444433333333444444444444444444444444333333333344444444444433333444444443333333334444444444444444444fffffffffffffffffffff
-- 035:444444433333333433334444eeeee44444444443333333344433334444444444444444433333333433334444eeee444443224443334433344444443344444443334444433333333444444444333344444444444433333333344444444444444444444444333333334444ffffffffffffffffffffffffcccc
-- 036:44444333444444444444433333333334444444444444443333444433333333444444444444444444444443333333344443224444434444444444333333344444444444444444444444433333334444444444444444444443333333333444444444444444444444ffffffffffffffffffffccccdddddccccc
-- 037:4444444444333333334444444444443333444444333333344444444444444444444443333333344444444444444444433243333333444444422433224444444433333333444444444444444444333333333334333344444444444444444333333334433ffffffffffffffffffffeeddddcccccdddddccccc
-- 038:11333334444444433334444444443333333444444444444444444444333333344444444444444433334443333333444cc2332244434444433223cc22444444444444443333444333333343333444eeee44444444433333334444444444444444fffffffffffffffffffffffffeeeeddddcccccdddddcccce
-- 039:11144444444444444443333333444444444444444444443333333444444444444444444443333333444444e44444444cc2442233334434433224cc22444444433333344444444444444444444433333344444444444444444444333333ffffffffffffffffcccddddcccfffffeeeeddddcccceeeeeeeeeee
-- 040:2112244444444333333344444444444e444444333333344444444444444444443333333444444444444443334433333cc344cc433444444cc443cc3334333444444444444444433333344444444444443344443333333333444fffffffffffffffffcccccccccddddcccfffffeeeeddeeeeeeeeeeeeeeeee
-- 041:22322334443333334444443333444444443333333444444444444444443333334444443334444444443333334444444cc444cc433444443cc444cc444444333444333333444433344dddddee44433333344444444444fffffffffffffffffddeeeeccccccccccddddcccfffffeeeeeeeeeeeeeeeeeeeeeee
-- 042:22332331133333333444444444333444333334444334444444444433333344444344444444444333333444444444444cc433cc333444443cc444cc444433333334444444444433344dddddee44444444444444ffffffffffffffffcccfffdddeeeeccccccccccdeeecccfffffeeeeeeeeeeeeeeeeeeeffff
-- 043:42333221144333334444443344444444333333444444444444444333333444444444443344433333444433344444444cc3334443344444444334cc33333333444eee44444443333dddddeeeeee44444fffffffffffffcccddccccccccfffdddeeeeceeeeeeeeeeeeecccfffffeeeeeeeeeffffeeeeefffff
-- 044:41433222244144433333333444444444444333334444444444334444333333344444444334443333344433444444444cc3334443334444444444cc3334444444444444333333344dddddeeeeeeffffffffffffffeeddcccddccccccccfffeeeeeeeeeeeeeeeeeeeeecccfffffffffeeeefffffeeeeefffff
-- 045:41422322211124444444443333333444ee44444443333333344444444444333333444ee444444443333344444444444444334434443344444444444434444344444444433333444ddeeeeeeeeefffffcccddccffeeddcccdeeeeeeeccfffeeeeeeeeeeeeeeeeeeeeeeeefffffffffeeeefffffeeeeefffff
-- 046:13422311211234433334444443334444333334444444444444333344444444443333333344443344444443333444444444434444433444444ee444443333444444444444433ffffddeeeeeeeeeeeccccccddccffeeeeeeeeeeeeeeeccfffeeeeeeefffeeeeeeeeeeeeeefffffffffeeeefffffeeefffffff
-- 047:133323114442333334444444444443333444444334444333344444444444433334444334444443333444444444444334444444444443444444444444444443333444ffffffffffdeeeeeeeeeeeeeccceeeeeccffeeeeeeeeeeeeeeeeeffffffeeeefffeeeeeeeeeeeeeeffffffffffffffffffffffffffff
-- 048:1333443144412fffffffffffffffff4333443344e444443334444444444433334444e44334433334444444444433344444444444433344444444444333344ffffffffffccdcfeedeeeeeeeeeeeeeeeeeeeeeccffeeeefffeefffeeeeeffffffeeeefffeeeeffffffffffffffffffffffffffffffffffffff
-- 049:3423443333412cdfffffffffffffffffffffffffffffffffffffffffffff44444333444444444333334444433444333444444444433344444444443ffffffffffcfdeccccdcfeeeee4444444eeeeeeeeeeeeeeffffeefffeefffeeeeeffffffffffffffffffffffffffffffffffffffffffffffffffffffe
-- 050:3422233333133cddccccccceeeddffcccccccddccdddeeffccddcccccceeffffffffffffffffffffffddefffff4444444333334334444433fffffffcdcfedcdcccfdeeeeeecfeeeee4444444ffeeffeeeeeeeeffffeefffefffffffffffffffffffffffffffffffffffffffffffffffcccccccfffffeeeee
-- 051:3422232224133ceeeeeeeeeeeeeeffccceeeeeeeeeeeeeffccddcccccceeddffcccccddccddeffccdddeeeeeddffffffffffffffffffffffdccfdeccdcfeeeeeecfeeeeeeec5555eeeeeeeffee6655eeeeffffffffffffffffffffffffffffffffffffffffffffeeecccdddddcccccccccccccfffffeeeee
-- 052:1142232224342eeeeeeeeeeeeeeeffccceeeeeeeeeeeeeffcceeeeeeeeeeeeffceeeeeeeeeeeffccdd222eeeddfcccccddcddeffcdcccceddccfeeeeecfeeeeeeeffefeeee555556666eeeeeee66665fffffffffffffffffffffffffffdddddcccccccfffddddeeeecccdddddcccccccccccccfffffeeeee
-- 053:1143344424342eeeeeeeeffeeeffffeeeeeffeeffeeeffffeeeeeeeeffeeeeffceeeeeeeeeeeffcced444eeeeefcceeeeeeeeeffceeeeceeeeefeeeeeeffefefeeffefefff555556666eeeeeee66665ffffffffffccccccffeeeeeeeeddddddcccccccfffddddeeeecccdddddcccccccccccccfffffeeeee
-- 054:1143344433113fffffffffffffffffeeeeeffeeffeeeffffeeeeeeeeffeeffffeeeffeeffeefffeeeefd4feefffeeeffeefeefffeeeeeefeefeffeeeeeffefffffffffffff566666677766ee7777665fddeeccddcccccccffeeeeeeeeddddddcccccccfffddddeeeeeeeeeeeeeeeeeeeecccccfffffeeeee
-- 055:2211114433113ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff566fe46665ffffffffffffffffeeeefffffffffffffffffffffffccfdde566666677766ee7777665fddeeccddcccccccffeeeeeeeeeeeeeeeeeecccfffeeeeeeeeeeeeeeeeeeeeeeeecccccfffffeeeee
-- 056:2211111112221ceedddffcccccddddeeeeeeeffcccccccddcceeddffccccddddeeeeeffccccfff655544445567fffffffffffffffffffffffffddcfdecdcccfeeeddccfd555775555666ffff775577555eeeeeeeeeeecccffeeeeeeeeeeeeeeeeeecccfffeeeeeeeeeeeeeeeeeeeeeeeecccccfffffeeeee
-- 057:2211111112221eeeeeeffcceeeeeeeeeeeeeeffcceeeecddcceeddffccccddddeeeeeffcccccd7766444446667deeeeeffccccddcedddcccfeeddcfdeceeecfeeeeeecfe555775555666ffff775577555eeeeeeeeeeecccffeeeeeeeeeeeeeeeeeecccfffeeeeeeeefffeeeeeeeeeeeeeeeeeeffffffffff
-- 058:3332224443332eeeeeeffcceeeeeeeeeeeeeeffcceeeeeeeeeeeeeffcceeeeeeeeeeeffcceeeee777743446667eeeeeeffceeeeeeeeeeeeefeeeeefeeeeeecfeeeeeecfe55577776666fff66667777655feeffeeeeeeeeefffffeeeffeeeeeeeeeeeeefffffffeeeefffeeeeeeeeeeeeeeeeeeffffffffff
-- 059:3332224443332feefffffeeeeeeeeefffeeffffeeeeeeeeeffeeffffeeeeeeeefeeffffeeeeeeef6667e5777eeeffeffffeeeeeefeffffeeffeeeeffefeeeeffefeeeeff55577776666fff66667777655feeffeeeeeeeeefffffeeeffeeeeeeeeeeeeefffffffeeeefffeeeeeeeeeeeeeeeeeeffffffffff
-- 060:2444433222244ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff66667e667ffffffffffffffffffffffffffffffffffffffffffffffff555667777fffee66667766655ffffffffffffffffffffffffffffffffffffffffffffefffffffffffffffffffffffeffffffffff
-- 061:2444433222244fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff5677ff67ffffffffffffffffffffffffffffffffffffffffffffffff55577ffffff766ee777777655fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 062:2444433222241cddccccccceeeddffcccccccddccdddeeffccddcccccceeddffcccccddccddeffccfffcfffeddfcccccddcddeffcdcccceddccfdeccdcfedcdcccfdeccc55577ffffff766ee777777655fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 063:1121111144111cddccccccceeeddffcccccccddccdddeeffcceeeeeeeeeeeeffceeeeeeeeeeeffccfffcfffeeefcceeeeeeeeeffceeeeceeeeefeeeeecfedcdcccfdeccc556eeeeddddeeeeeffff77655cddccffeeddcccddccccccccfffdddeeeeccccccccccdffffffffffffffffffffffffffffffffff
-- 064:1121111144112ceeeeeeeeeeeeeeffccceeeeeeeeeeeeeffcceeeeeeeeeeeeffceeeeeeeeeefffe666676677fffeeeffeefeefffeeeeeefeefefeeeeecfeeeeeecfeeeee556eeeeddddeeeeeffff77655cddccffeeddcccddccccccccfffdddeeeeccccccccccddddcccfffffeeeeddddcccccdddddccccc
-- 065:1121122333322eeeeeeeeffeeeffffeeeeeffeeffeeeffffeeeeeeeeffeeffffeeeffeeffeefff6666676667ffffffffffffffffffffffffefeffeeeeeffefefeeffeeee55677eeddddeeeeeffffff655eeeccffeeeeeeeeeeeccccccfffdddeeeeccccccccccddddcccfffffeeeeddddcccccdddddccccc
-- 066:2232222333324eeeeeeeeffeeeffffeeeeeffeeffeeeffffffffffffffffffffffffffffffffff65566766567ffffffffffffffffedddfffffffffffffffefefeeffefee55677eeddddeeeeeffffff655eeeccffeeeeeeeeeeeeeeeccfffeeeeeeeeeeeeeeeeeedddcccfffffeeeeddddcccccdddddccccc
-- 067:2232222312114fffffffffffffffffffffffffffffffffffffffffffffffddddeeeeeffcccccdd65557775557ddeeeeeffccccddcedddcccfeeddcfffffffffffffffffe5567766555555555556677655eeeeefffeeeeeeeeeeeeeeccfffeeeeeeeeeeeeeeeeeeeeecccfffffeeeeeeeeeeeeeeeeddccccc
-- 068:2234444112113ffedddffcccccddddeeeeeeeffcccccccddcceeddffccccddddeeeeeffcccceee65557765557eeeeeeeffceeeeeeeeeeeeefeeddcfdecdcccfeefffffff5567766555555555556677655eeeeeffffeefffeefffeeeeefffeeeeeeeeeeeeeeeeeeeeecccfffffeeeeeeeeeeeeeeeeeeeeeee
-- 069:1144444114423ceedddffcccccddddeeeeeeeffcccccceeeeeeeeeffcceeeeeeeeeeeffcceeeee55567f75557eeffeffffeeeeeefaaaafeefeeeeefeeedcccfeeeddccfd6667755555555555556677666fffffffffeefffeefffeeeeeffffffeeeefffeeeeeeeeeeecccfffffeeeeeeeeeeeeeeeeeeeeeee
-- 070:1144422224422eeeeeeffcceeeeeeeeeeeeeeffcceeeeeeeeeeeeeffcceeeeeefeeffffeeee996556678665557aaaaa9aa9998aaaaaaaa8899aeeefeeeeeecfeeeeeccfdde477555555566555555774fffffffffffffffffffffeeeeeffffffeeeefffeeeeeeeeeeeeeefffffffffeeeeeeeeeeeeeeeeeee
-- 071:1133322224142eeefffffeeeeeeeeefffeeffffeeeeeeaa9988aaaa99aaaaaaaaaa9999aaaaaa655677a765577aaaaaaaaaaaaaaaaaaaaa89aaaa99aaaeeeeffeeeeecfeee477555555566555555774fddffffffffffffffffffffffffffffffeeefffeeeeeeeeeeeeeefffffffffeeeefffffeeeeeffffe
-- 072:2233322441141fe998aaaa99aaaaaaaaaaa999988aaaaaaaa988aaaa98aaaaaaaaaaaaaaaaaaa65667aa86657799aaaaaaaaa8899aaaaaaaa8889999aaaa89aaafeeeefeee477777777777777777774fddeeccddccccffffffffffffffffffffffffffffffffffeeeeeefffffffffeeeefffffeeeeefffff
-- 073:2233233441121aaaaaaaa8899aaaaaaaaaaaaaaaaaaaaaaa99999aaaaa89aaaaaaaaaaaa99998e667faaaf6678aaaa9999aaaaaaaaaaaaaaaaaaaaaaaaf988aaaaa99aaffe477777777777777777774fddeeccddcccccccffeeeeefffffffffffffffffffffffffffffffffffffffeeeefffffeeeeefffff
-- 074:22422334332248aaaaa99999aaaaaaaaaaaaaaaaaaaaaaaaa99888aaaaaaaaaaa8999aaaaaaaae667faaafeeeaa88aaaaa9999aaaaaaaaaaaaaaaaaaafffaa8899aaaaaaaaa6666666677766556677ffeeeeeeeeeccccccffeeeeeeeeddddddcfffffffffffffffffffffffffffffffffffffffffeefffff
-- 075:1442211133244aaaaa88999aa89999aaaaaaaaaa89999aaaa9aa888aaaaa999aaaaaaaaaaaaaafeeeaaaafeefaaaaa998aaaaa999dd9889aaaaaaaaadeeef8aaaaaaaaaaa996666666677766556677ffeeeeeeeeeeeecccffeeeeeeeeddddddcccccccfffddddeffffffffffffffffffffffffffffffffff
-- 076:14411111311aaaaa888999aaaaaaaaaaaaaaaaaaaaaaaaaaaa999999aaaaa888aaaaaaaaaaaaafeee999aaeee99aaaaaaaaaaaaadccd9999aaaaaaaffdddefffaaaaaaaaaaa6655666667755555566ffffeeffeeeeeecccffeeeeeeeeedddddcccccccfffddddeeeecccddddffffffffffffffffffffffff
-- 077:1211111221aaaa999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa988aaaaaa9999998889aaaaafeeaaa999feefaaaaaaaaaaa99dcddcda988aaaaaaeeffeddeeffffaaaaaaa66556666677555555668889eeffeeeeeecccffeeeeeeeeeeeeeeeeeecccfffddddeeeecccdddddcccccccccffffffffffffff
-- 078:22112222aaaaa999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa998889aaaaaaaaaaaa888999aaaaaaaeeeaaaaaaaeeeaaaaaaaaaaaa9dc99cdaaaaaa888aeeeefffddeeeeffffff9eeee556eeee55555566aaaaaaa8899eeeeeefffffeeeeeeeeeeeeeeecccfffeeeeeeeecccdddddcccccccccccccfffffeffff
-- 079:221422aaaaa9988aaaaaaaaaaa998889aaaaaaaaaaaaa9998889999999aaaaaaa999aaaaaaaaeeeeaaaaaaaeeefaaaaaaaaaaaaadccda999aaaaaafdddeeeeffddeeeeeeeefee5e556e5ee55555566a9aa8888aaaaaa9999ffffeeeffeeeeeeeeeecccfffeeeeeeeeeeedddddcccccccccccccfffffeeeee
-- 080:2444aaaaaa888aaaaaaaaaaaaa988889999999aaaaaaaaaaaaaaaaaa999aaaaaaa9999999aaaeeeeaaaaaaaffffaaaaaaaaaaaaaaddaa9999888aaedddddeeeedddddffdeeeeeeeeeeeeee55555566aaaaaaaaaaa888aaaaaaa999effeeeeeeeeeeeccfffeeeeeeeeeeeeeeeeeeeeeecccccccfffffeeeee
-- 081:144aaaaa8888999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa9999999aaaaaaa8889aaaaaaaaaaaaaaaaaaaaa99999aa889999ddaaaaaaaaaaaeeeddddeeeedddfeeedeffffffffffff77556666aaaaaaaaaaaaa99999888aaaaaaa999eeeeeeeeefffffffeeeeeeeeeeeeeeeeeeeecccccfffffeeeee
-- 082:1aaaaa8888aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa9999aaaaaaaa888aaaaaaaaaaaa9999888aaaaaaaaaaaaaadd9999888a99feeeeffddeeeeddfeeeedffffffffffff77556666aaaaaaaaaaaaaaaaaaaaaaa9999aaaaaaaa889eefffffffeeeefffeeeeeeeeeeeeecccccfffffeeeee
-- 083:aaaaa9998aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa8888aaaaaaaa8888999aaaaaaaaaaaaaaaa899999999aaadcdaaaaaaaaafeddeeeeddeeeeefeeeeedeeeeeeeeeeee6777766aaaaaaaaaaaaaaaaaaaaaaaaaaa9999999aaaaaaaa8afffeeeefffeeeeeeeeeeeeecccccfffffeeeee
-- 084:aaa999999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa999988888aaaaaaaaaaaaaaaa98888999aaaaaaaaaaaaaaaaaadcdaaaaaaaaaaeedddeeffdeeeefeeeeedeeeeeeeeeeeeee77766aaaaaaaaaaaaaaaaaaaaaaaaaa98888899aaaaaaaaaaaaaaaa8fffeeeeeeeeeeeeeeccccfffffeeeee
-- 085:aa8888aaaaaaaaaaaaaaaaaaaaaaaaaa99999aaa899999999aaaaaaaaaaaaaaaaaaaaaaa889999999aaaaaaaaaaaaaaaaaaaaaaaaadaaaaaaaaaaaeeedddeeffdeeefeeeeeeddddddeeddddde677aaaaaaaaaaaaa99999999988888aaaaaaaaaaaaaaaaa88888aaaaaaaaa99eeeeeeeeeeeeeeffffffeeee
-- 086:99999aaaaaaaaaaaaaaaaaaaaa88999999aaaaaaaaaaaaaaaaaa888999998999aaaaaaaaaa8888aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaeeeedddeeffffefeeeeeedddddffddddddde77aaaaaaaaa999998888aaaaaaaaaaaaaaaaa999999888aa999999988aaaaaaaaa999eeeeeeeffffffffff
-- 087:88999999aaa889999999aaaaaaaaaaaaaaaaaa888999999aaaaaaaaaaaaa88888aaaaaaaaaa99999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaafeeeeedddeeeeefeeeeeedddddffdddddddeff999998888aaaaaaaaaaaaaaaaaa999999888aaaaaaaaaaaaaaaaaaaaa99999aaaaaaaaa98effffffffff
-- 088:889999aaaaaaaaaaaaaaaaaaa88999999999aaaaaaaaaaaaaaaaaaaaaaaaa99999aaaaaaaaaa8888899999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaeeeeeeddddeddfefffeffdddddffededdddffaaaaaaaaaaaaaaaaaaa999998888a999999999aaaaaaaaaaaaaaaaaaaaaaaaa99988aaaaaaaaaa99ffff
-- 089:aaaaaaaaaaa9999999999aaaaa9999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa88888aaaaaaaaaa9999999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaeeeeeeeddeddfefffeffeddddfeeefddddffaaaaaaaaaaa998888899aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa999999aaaaaaaaa
-- 090:9999888aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa9999999999aaaaaaaaaa888888aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa999feeeeeeeeddfefefeffeddddfeeeedddeffaaaaaaa88888999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa9999999999aaa
-- 091:999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa99999999988aaaaaaaaaaa99999aaaaaaaaaaaaaaaaaaaaaaaaaaaa999999999feeeeeeedddffeeeffeddddfeeeedddeffaaaaaaaaaaa999988aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa88
-- 092:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa888999aaaaaaaaaaa999999aaaaaaaaaaaaaaaaaaaaaaa8888899999aaaffeeeeedddfeeeeffeddddfeeeedddeff9999aaaaaaaaaaa888999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 093:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa99999aaaaaaaaaaaa888888a99999aaaaaa999999999998aaaaaaaaaaaaafffeeddddffffefeddddfeeeeeddeffaa888888aaaaaaaaaaa999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 094:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa999888aaaaaaaaaaaa99999999999988888899aaaaaaaaaaaaaaaaaaaaaa9ffefedddddddefeddddfeefeefdeefeeaaa999999aaaaaaaaaaaa999888aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 095:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa888899aaaaaaaaaaaaa888888999aaaaaaaaaaaaaaaaaaaaaaa8888899999fffeeddddddeeeddddfeefeefdeefeeaaaaaaa999999aaaaaaaaaaaa8888899999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 096:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa999999999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa999999999888aaa9999ffeeedddddeeedddffeefeeefeefeeaaaaaaaaaa9888888aaaaaaaaaaaaa999999999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 097:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa9999998888888aaaaaaaaaaaaaaaaaaaaaaaaaaa888888999999aaaaaaaaaaaaaaaeffeeeddddeeedddfffeeeeeffefeeaaaaaaaaaaaaaa8889999aaaaaaaaaaaaa99999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 098:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa9888888999999aaaaaaaaaaaaaaaaaaaaaaaaaa889999999888aaaaaaaaaaaaaaaaaaaaaaaefefeeedddeeedddfffeeeeeffefaaaaaaaaaaaaa9999999999999aaaaaaaaaaaaaa888888aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 099:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa99aaaaaaaaaaa9999999999888aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa8888889999999aaaaaaaaaaaaaaaaaaaaaaaaaefeffeeeedfeedddfffeeeeeffefaaaaaaaaaaaaaaaa99999999999999aaaaaaaaaaaaaa8899999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 100:aaaaaaaaaaaaaaaaaaaaaa999999999999aa8888899999999aaaaaaaaaaaaaaaaaaaaaaaaaaa8aaaaaaaaaaaaaa999999999999aaaaaaaaaaaaaaaaaaaaaaaaaef44effeeeffedddfffeeeeeffefaaaaaaaaaaaaaaaaaaa999999998888888aaaaaaaaaaaaaa9999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 101:aaaaaaaaaaaaaaaaaaaa99999999999999888888aaaaaaaaaaaaaaaaaaaaaaaaaaaa998888888aaaaaaaaaaaaaaa9998888aaaaaaaaaaaaaaaaaaaaaaaaaaaaaef44eeffeeffedddfffeeeeeefefaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa8888889aaaaaaaaaaaaaaa9999999aaaaaaaaaaaaaaaaaaaaaaaaa
-- 102:aaaaaaaaaaaaaaaaa88999999999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaa888899999998889999aaaaaaaaaaaaaaa88888888aaaaaaaaaaaaaaaaaaaaaaaaaaaaeff777ffeffedddfffeeeeeefefaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa9999999aaaaaaaaaaaaaaa9998888aaaaaaaaaaaaaaaaaaaaa
-- 103:aaaaaaaa999888888899999aaaaaaaaaaaaaaaaaaaaaaaaaaaa9999988888888999999999999999aaaaaaaaaaaaaaa89999999aaaaaaaaaaaaaaaaaaaaaaaaaaaae77777ffffedddfffeeeeeefee7aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa99999999aaaaaaaaaaaaaaa888888889999999aaaaaaaa9
-- 104:99999999998888aaaaaaaaaaaaaaaaaaaaaaaaaaaaa999999999999998aaaaaaa999999998888888aaaaaaaaaaaaaaaa9999999aaaaaaaaaaaaaaaaaaaaaaaaaaa4777777fffedddfffeeeeeefee77aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa9999999aaaaaaaaaaaaaaaa99999999999999998888
-- 105:99999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa888888999999999aaaaaaaaaaaaaaaaaaaaaaa88888889aaaaaaaaaaaaaaaa99999999aaaaaaaaaaaaaaaaaaaaaaaa447777777ffedddfffeeeeeeeee77aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa98888888aaaaaaaaaaaaaaaa9999999899999999
-- 106:aaaaaaaaaaaaaaaaaaaaaaaaaaa999999888888889aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa99999999aaaaaaaaaaaaaaaa99999988aaaaaaaaaaaaaaaaaaaaaa444777777777fffffffffeeeeee777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa88888888aaaaaaaaaaaaaaaa888888889999
-- 107:aaaaaaaaaaaaaaaaaa9999999999999998aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa999999999aaaaaaaaaaaaaaaa888888888aaaaa999aaaaaaaaaaaa444477777777777777777777777777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa899999999aaaaaaaaaaaaaaaa8888888a
-- 108:aaaaaaaaaa88888899999999999999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa999999999aaaaaaaaaaaaaaaaa88888899999999999aaaaaaaaa4444477777777777777777777777777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa9999999999999999aaaaaaaaaaaaaaaaaaaaa
-- 109:aa9999988888888999999999999999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa999999998aaaaaaaaaaaaaaaaa99999999999999999aaaaaaaa4444447777777777777777777777777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa99999999998888888aaaaaaaaaaaaaaaaa
-- 110:99999988888aaaa999999999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa98888888aaaaaaaaaaaaaaaaaa999999999999999999aaaaaa444444477777777777777777777777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa999999999888888888aaaaaaaaaaaaa
-- 111:999aaaaaaaaaaa999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa888888888aaaaaaaaaaaaaaaaaa999999999999999999aaaaaaa4444477777777777777777777777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa88889999999998888aaaaaaaaaaaaaaa
-- 112:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa888899999aaaaaaaaaaaaaaaaaaa99999999999aaaaaaaaaaaa4444477777777777777777777777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa99988888888899999aaaaaaaaaaaaaaaaaaa
-- 113:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa999999999999aaaaaaaaaaaaaaaaaaa999988888aaaaaaaaaaaaaa444477777777777777777777777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa999999999988888888aaaaaaaaaaaaaaaaaaaaaa
-- 114:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa9999999999999999999aaaaaaaaaaaaaaaaaaa888888888aaaaaaaaaaaa4444477777777777777777777777aaaaaaaaaaaaaaaaaaaaa999999aaaaaaaaaaaa999999999999999998aaaaaaaaaaaaaaaaaaaaaaaaaa
-- 115:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa99999999999999999999aaaaaaaaaaaaaaaaaaa8888888888aaaaaaaaaa4444447777777774444444447777aaaaaaaaaaaaaaaaa9999999999999aaaaa8888899999999999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 116:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa99999999999999999999aaaaaaaaaaaaaaaaaaa8889999999aaaaaaaaa44444477777777444444444444777aaaaaaaaaaaa9999999999999999999988888888899999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 117:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa999999999999999999888aaaaaaaaaaaaaaaaaaaa9999999999aaaaaaaa4444477777774444444444444447aaaaaaaaaaaaaa99999999999999999999888888888899aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 118:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa99999999999888888888aaaaaaaaaaaaaaaaaaaaa9999999999aaaaaaa44444477777444444444444444444aaaaaaaaaaaaaaa99999999999999999999988888aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa9
-- 119:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa999999aaaaa8888888888aaaaaaaaaaaaaaaaaaaaa99999999999aaaaa44444477774444444444444444444aaaaaaaaaaaaaaaaaa99999999999999999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa8889
-- 120:888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
-- 121:8bbbbbaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbaaabbbbbaaabbbbbaaaaaaaaaaaaaaaaaaaaaaaaaa8
-- 122:8b99999999999999999999999999999999999999b99999999999999999999999999999999999999999999999b999999999999999999999999999999999999999b999999999999999999999999999999999999999999999999999999999999999b9999999b9999999b99999999999999999999999999999a8
-- 123:8b99999999999999999999999999999999999999b99999999999999999999999999999999999999999999999b999999999999999999999999999999999999999b999999999999999999999999999999999999999999999999999999999999999b9999999b9999999b999999ff99999999999999999ff99a8
-- 124:8b99ff9ff9ffff999999fff9999ff99999999999b999fff99ff9ff9ff9ff99fff99999fff999999999999999b99ff9999ff9ff9ff99999999999999999999999b999ffff99ffff99fff99ffff99fffff99999999999999999999999999999999b9999999b9999999b9999ffffffffffffffffffffffff9a8
-- 125:8b99ff9ff9fffff9999fffff99fff99999999999b99fffff9fffff9fffff9fffff999fffff99999999999999b99ff9999ff9ff9ff99999999999999999999999b99fffff9fffff9fffff9fffff9fffff99999999999999999999999999999999b9999999b9999999b999fffffffffffffffffffffffff9a8
-- 126:8a99ff9ff9ff99f9999ff9ff9ffff99999999999a99ff9ff9fffff9fffff9ff9ff999ff9ff99999999999999a99ff9999ff9ff9ff99999999999999999999999a99ff9999ff9999ff9ff9ff99f9ff99999999999999999999999999999999999a9999999a9999999a99fffffffffffffffffffffffff99a8
-- 127:8a99fffff9ff99f9999fffff999ff99999999999a99ff9ff9fffff9fffff9ff9ff999fffff99999999999999a99ff9999ff9ff9ff99999999999999999999999a99ffff99ff9999ff9ff9ff99f9ffff999999999999999999999999999999999a9999999a9999999a9ffffffffffffffffffffffff9999a8
-- 128:8a99ff9ff9fffff9999fffff999ff99999999999a99fffff9f9f9f9f9f9f9ff9ff999fffff99999999999999a99ff9999fffff9ff99999999999999999999999a999ffff9ff9999ff9ff9fffff9ffff999999999999999999999999999999999a9999999a9999999a999fffffff9f9f999999999999999a8
-- 129:8a99ff9ff9ffff99999ff9ff999ff99999999999a99ff9ff9f9f9f9f9f9f9ff9ff999ff9ff99999999999999a99ff99999fff99ff99999999999999999999999a99999ff9ff9999ff9ff9ffff99ff99999999999999999999999999999999999a9999999a9999999a9999fffffffff9999999999999999a8
-- 130:8a99ff9ff9ff9999999fffff9fffff9999999999a99ff9ff9f999f9f999f9fffff999fffff99999999999999a99fffff99fff99fffff99999999999999999999a99fffff9fffff9fffff9ff9ff9fffff99999999999999999999999999999999a9999999a9999999a999fffffff9999999999999999999b8
-- 131:8a99ff9ff9ff99999999fff99fffff9999999999a99ff9ff9f999f9f999f99fff99999fff999999999999999a99fffff999f999fffff99999999999999999999a99ffff999ffff99fff99ff9ff9fffff99999999999999999999999999999999a9999999a9999999a99ffffffff9999999999999999999b8
-- 132:8a99999999999999999999999999999999999999a99999999999999999999999999999999999999999999999a999999999999999999999999999999999999999a999999999999999999999999999999999999999999999999999999999999999a9999999a9999999a99fffffff99999999999999999999b8
-- 133:8a99999999999999999999999999999999999999a99999999999999999999999999999999999999999999999a999999999999999999999999999999999999999a999999999999999999999999999999999999999999999999999999999999999a9999999a9999999a99999999999999999999999999999b8
-- 134:8aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbb8
-- 135:888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
-- </SCREEN>

-- <PALETTE>
-- 000:1a1c2c5d275db13e53ef7d57ffcd75a7f07038b76425717929366f3b5dc941a6f673eff7f4f4f494b0c2566c86333c57
-- </PALETTE>

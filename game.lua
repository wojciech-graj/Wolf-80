-- title: Raycast FPS game
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
				player:damage(damage)
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
				closest_enemy:damage(damage)
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
                        local door = g_DOORS[self.value]
                        mset(door[1], door[2], 0)
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
	speed_rot = 0.0015,
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
	local speed = self.speed_rot * delta
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
	self.health = self.health - value
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
	elseif btnp(6) and self.weapon_state == 2 and weapon.ammo > 0 then
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

function Enemy.new(id, type, pos_x, pos_y)
	local self = setmetatable({}, Enemy)
	self.id = id
	self.pos_x = pos_x
	self.pos_y = pos_y
	self.activate_dist_sqr = 64
	self.shoot_dist_sqr = 16
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

function g_get_tex_pixel(offset, id, x, y)
	return peek4(offset + 0x40 * (id + 16 * (y // 8) + x // 8) + 0x8 * (y % 8) + (x % 8))
end

function init()
	g_SCREEN_WIDTH = 240
	g_SCREEN_HEIGHT = 120
	g_LEVEL_WIDTH = 24
	g_LEVEL_HEIGHT = 24
	g_DEBUG = true
	g_SPRITE_SIZES = {
		[0]=  {16,16},
		[2]=  {16,16},
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
	}
	g_player = Player.new(22, 12)
	g_prev_time = 0
	g_sprites = {
		Sprite.new(12, 13, 0, 2, 2, 0.5),
		Sprite.new(12.5, 12.5, 0, 2, 2, 0.5),
		Sprite.new(13, 13, 0, 2, 2, 0.5),
		Sprite.new(18.5, 6.5, 2, 2, 1, 0.125),
	}
	g_WEAPONS = {
		Weapon.new(204, 99999999, 107, {234, 228},      300, 250, 0  , 0.05, 2, 20, 1, 1 ),
		Weapon.new(200, 50      , 113, {234, 228},      350, 350, 0  , 0.00, 5, 15, 1, 32), --TODO
		Weapon.new(196, 20      , 113, {222, 216, 210}, 400, 350, 350, 0.12, 5, 15, 7, 32),
	}
	g_ENEMY_WEAPONS = {
		Weapon.new(0, 99999999, 0, nil, 0, 350, 0  , 0.4, 3, 15, 1, 32),
		Weapon.new(0, 99999999, 0, nil, 0, 350, 350, 0.4, 3, 15, 3, 32),
	}
	g_enemies = {
		[1]=Enemy.new(1, 1, 16.6, 13),
	}
	g_items = {
		[1]=Item.new(1, 19, 12, 0, 20),
		[2]=Item.new(2, 19, 13, 1, 10),
		[3]=Item.new(3, 19, 14, 2, 5),
		[4]=Item.new(4, 19, 15, 3, 1),
		[5]=Item.new(5, 19, 16, 3, 2),
	}
        g_DOORS = {
                [1]={18,3},
                [2]={17,13},
        }
	g_NUM_HITMARKERS = 7
	g_hitmarkers = {}
	for i=1,g_NUM_HITMARKERS do
		g_hitmarkers[i] = Hitmarker.new()
	end
	g_settings = {
		floor_ceil = true,
		interlace = 2, --disabled=g_interlace>=2
	}

	math.randomseed(tstamp())
end

init()
function TIC()
	local t = time()
	local delta = t - g_prev_time --msec since last frame
	g_prev_time = t

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

	if btnp(5) then
		settings.floor_ceil = not settings.floor_ceil
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
	font(player.health, 19, 124)
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

	if g_DEBUG then
		print(string.format("FPS %d\n#SPR %d\nLOGIC %.1f\nWALL&SPR %.1f\nFLR&CEIL %.1f",
			math_floor(1000 / delta), num_visible_sprites, t_logic, t_wall_sprite, t_floor), 0, 0, 5)
	end
end

-- <TILES>
-- 001:ffffffffccedfccceeeefceeefeffeeffffffffffccddeeefceeeeeefeeeefef
-- 002:ffffffffdcdefcdceeeefceeefeffeeefffffffffcccdcedfceeeeeefeeeefef
-- 003:aaaaaaaaa8989989a99aaaa9a8aa8aaaa9a898aaa9aa8aaaa8aaaaaaa99aaaaa
-- 004:aaaaaaaa9899898a9aaaa99aaaa8aa8aaa898a9aaaa8aa9aaaaaaa8aaaaaa99a
-- 005:fffffeeefffeefffffeffffffefffffffeffffffefffffffefffffffefffffff
-- 006:eeeffffffffeeffffffffeffffffffefffffffeffffffffefffffffefffffffe
-- 007:3444444433444444333444443333444433333444333333443333333433333333
-- 008:4444444344444433444443334444333344433333443333334333333333333333
-- 009:7777777777666677766666677666666776666667766666677766667777777777
-- 010:7777777777666677766666677666666776666667766666677766667777777777
-- 011:3cccccc433ccccc4333cccc433333333333344443333444f333344ff333344ff
-- 012:3cccccc33ccccc3c3cccc3cc33333ccc44443cccf4443cccff443cccff443ccc
-- 013:eccccccdeecccccdeeeccccdeeeeeeeeeeeeddddeeeedddfeeeeddffeeeeddff
-- 014:ecccccceecccccececcccecceeeeecccddddecccfdddecccffddecccffddeccc
-- 015:0cdd00000cdde0000cddde0000cddde0000dddde0000dddd00000ddd000000dd
-- 017:ffffffffccedfccceeeefceeefeffeeffffffffffccddeeefceeeeeefeeeefef
-- 018:ffffffffdcdefcdceeeefceeefeffeeefffffffffcccdcedfceeeeeefeeeefef
-- 019:a99aaaaaa8aaaaaaa9aa8aaaa9a898aaa8aa8aaaa99aaaa9a8989989aaaaaaaa
-- 020:aaaaa99aaaaaaa8aaaa8aa9aaa898a9aaaa8aa8a9aaaa99a9899898aaaaaaaaa
-- 021:efffffffefffffffeffffffffefffffffeffffffffeffffffffeeffffffffeee
-- 022:fffffffefffffffefffffffeffffffefffffffeffffffefffffeefffeeefffff
-- 023:3333333333333334333333443333344433334444333444443344444434444444
-- 024:3333333343333333443333334443333344443333444443334444443344444443
-- 025:7777777777666677766666677666666776666667766666677766667777777777
-- 026:7777777777666677766666677666666776666667766666677766667777777777
-- 027:3443444f4333444f3333444433334444333333333334444c3344444c3444444c
-- 028:f444333cf4443cc344443ccc44443ccc33333ccc344443cc3444443c34444443
-- 029:eddedddfdeeedddfeeeeddddeeeeddddeeeeeeeeeeeddddceedddddceddddddc
-- 030:fdddeeecfdddecceddddecccddddeccceeeeeccceddddeccedddddecedddddde
-- 031:000000000000000000000000ee000000ffe00000defe0000ffefe000dddefe00
-- 047:0000000000000000000000000000000000000000ee000000dde00000ddde0000
-- 063:dddfee00ddddffe0ddddddfe0ddddddf00dddddd000ddddd0000dddd00000ddd
-- 079:000000ee000000ef00000efd00000edf000000e4000004440000044400000044
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
-- 000:0000eeee00ff22220f222c2202ff22220222eeee0f2222220ff2222202ffeeee
-- 001:eeee00002222dd00222222d02222dd20eeee2220222222d022222dd0eeeedd20
-- 002:0000000002200000020000020c00000c0c00000c0c00000c4440003404000003
-- 003:000000002200000220000022c00000c0c00000c0c00000c04400044440000040
-- 016:022feeee0f2222220ff2222202ffeeee022feeee0f22222200ff22220000eeee
-- 017:eeeed220222222d022222dd0eeeedd20eeeed220222222d02222dd00eeee0000
-- 018:0400000303440003000344430000000300000003000000030000033400003444
-- 019:4000004040004430444430004000000040000000400000004440000044440000
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
-- 064:00000000000effff00deffff0ddeeeee0ddddddd0fffffff0fdddddd0f3deeee
-- 065:00000000ffffe000ffffed00eeeeedd0ddddddd0fffffff0ddddddf0eeeed3f0
-- 066:000000000000000000000000000000000000000000000d340000fd340000fedd
-- 067:0000000000000000000000000000000000000000333d0000333df000dddef000
-- 070:0000000000000000000000000033300003444300343034303400043034303430
-- 071:00000000000000000000000000ddd0000dcccd00dcd0dcd0dc000cd0dcd0dcd0
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
-- 000:101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 001:100000000000000000000000000000001010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 002:100000000000000000000000000000001000000000001010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 003:100000000000000000000000000000001010601010001010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 004:100000000000000000000000000000001000000010001010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 005:1000005d1d5d1d5d1d5d0000000000001000000010001010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 006:1000001d5a1a5a1a5a1d0000000000001000000010001010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 007:1000005d1a5616561a5d0000000000001000000010001010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 008:1000001d5a1650165a1d00000000000010181c1810001010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 009:1000005d1a5616561a5d0000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 010:1000001d5a1a5a1a5a1d0000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 011:1000005d1d5d1d5d1d5d0000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 012:100000000000000000000000000000000010000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 013:100000000000000000000000000000000070000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 014:100000500050005000000000000000000010000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 015:100000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 016:100000500050005000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 017:100000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 018:100000500050005000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 019:100000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 020:10000000000000004f4e4d4c4b4a49484746454443424110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 021:100000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 022:100000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 023:101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 107:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b900000000091600000000
-- 108:00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f0f20000000a2706000000
-- 109:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007df3f1e200002807170000
-- 110:0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f476860000b308180b1b
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

-- <SCREEN>
-- 000:eeeeeeeeeeeeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeeeeeeeeeeeeeeeeeeeeeffffffffffffeeffffffffffffffffffffffffffffffffffffeeeeefffffffeeeeeeeeeeeeeeeeeeeeeeeeeffffffffffffffffffffffffffff
-- 001:eeeeeeeeeeeeefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeeeeeeeeeeeeeeeeeeeeffffffffeeeeeefffffffffffffffffffffffffffffffeeeeeeeeeeffeeeeeeeeeeeeeeeeeeeeeeeeefffffffffffffffffffffffffffffff
-- 002:eeeeeeeeeeeefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeeeeeeeeeeeeeeeeeeeefffeeeeeeeeeeffffffffffffffffffffffffffeeeeeeeeeeeeffeeeeeeeeeeeeeeeeeeeeeefffffffffffffffffffffffffffffffffff
-- 003:eeeeeeeeeeeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeeeeeeeeeeeeeeeeeefeeeeeeeeeeeeefffffffffeeeeefffffffeeeeeeeeeeeefffffffeeeeeeeeeeeeeeeeeffffffffffffffffffffffffffffffffffffff
-- 004:eeeeeeeeeeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeeeeeeeeeeeefffffffeeeeeeeeeeeeeffffeeeeeeeeeffeeeeeeeeeeeeffffffffffffeeeeeeeeeeeefffffffffffffffffffffffffffffffffffffffff
-- 005:eeeeeeeeeeefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeeeeeeefffffffffffeeeeeeeeeeeefeeeeeeeeeeeffeeeeeeeeeffffffffffffffffeeeeeeefffffffffffffffffffffffffffffffffffffffffffff
-- 006:eeeeeeeeeeefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeeefffffffffffffffeeeeeeeffffffeeeeeefffffffeeeefffffffffffffffffffffeeffffffffffffffffffffffffffffffffffffffffffffffff
-- 007:eeeeeeeeeefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeffffffffffffffffffffeeffffffffffefffffffffffffffffffffffffffffffffeeefffffffffffffffffffffffffffffffffffffffffffffffff
-- 008:eeeeeeeeeefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeefffffffffffffffffffffffffffffffffffffffffffffff
-- 009:ffffeeeeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeeeffffffffffffffffffffffffffffffffffffffffffffffff
-- 010:ffffffffeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeeeeffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeeeefffffffffffffffffffffffffffffffffffffffffffffffffff
-- 011:ffffffffeeeeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeeeeeffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeeefffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 012:ffffffffeeeeeeeeeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeeeeffffffffffffffffffffffffffffffffffffffffffffffeeeeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 013:ffffffffeeeeeeeeeefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeffffffffffffffffffffffffffffffffffffffffffffffffffefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 014:fffffffeeeeeeeeeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffffffffffffffffffffffffffffffffffffffffffffffeeeeeefffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 015:fffffffffffeeeeefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeefffffffffffffffffffffffffffffffffffffffffffeeeeeeeeefffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 016:ffffffffffffffffefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeefffffffffffffffffffffffffffffffffffffffffffffeeefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 017:fffffffffffffffeeeeeeefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeffffffffffffffffffffffffffffffffffffffffffffffeeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 018:fffffffffffffffffeeeeeeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeefffffffffffffffffffffffffffffffffffffffffeeeeeeeeeefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 019:fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeefffffffffffffffffffffffffffffffffffffffffeeeeeeeeeefffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 020:ffffffffffffffffffffffeeeeeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeeffffffffffffffffffffffffffffffffffffffffffffffeeeeeefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 021:ffffffffffffffffffffffffeeeeeeeeeefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeefffffffffffffffffffffffffffffffffffffffffffffffffffeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 022:ffffffffffffffffffffffffffffffeeeeeeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeefffffffffffffffeeefffffeeeeffffeeeeeefffffffffffeeeeeeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 023:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeffffffffeeeeeeeeffeeeeeeeffeeeeeeeeefffffeeeeeeeeeeeeeefffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 024:fffeeefffffeeeeffffeeeeefffffffffffeeeeeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeeeeeeeefeeeeeeeefffffffffffffffffeeeeeeeffeeeeeeeeeeeeeeeeeefffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 025:fffeeeeeeefffeeeeefffeeeeeeeeeffffeeeeeeeeeeeeefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeeeeeeeeffffffeefffffffffffffffffffffffffffffffffeeeeeeeeeeeeeeeeeffffffffffffffffffffffffffffffffffffffffffffffffffffeee
-- 026:eeeeeeeeeefffffffffffffffffeeeeeefffeeeeeeeeeeeeeeeeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeeeeeeeefffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeeeeeeeeeefffffffffffffffffffffffffffffffffffffffffffeeeeeeeee
-- 027:eeffffffffffffffffffffffffffffffffffffffffeeeeeeeeeeeeeeeeffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeeeeeeeefffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeeeeeeeeefffffeeefffffffffffffffffffeeeeeeffeeeeeeeeeeeeeef
-- 028:efffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeeeeeeeeefffffffffffffffffffffffffffffffffffffffeeeeeeeeeeeeeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeeeeeefffeeeeeeeefffeeeeeffeeeeeeeeffffffeeeeeeeefffffff
-- 029:efffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeeeeeeeeeffeeeeeefffffffffffffffeeeeeeefeeeeeeeeeeeeefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeefffffffffffeeeeffffeeefffffeefffffffffffffefffffffffffff
-- 030:efffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeefffffffeeeeeeeeeeeeeefeeeeeefffffffffeeeefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeffffffffffffffffffffffffffffffffffffffeeeeeeefffffffffffff
-- 031:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeffffffffffffffffffffffffffffffffffffffffeeeefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeffffffffffffffffffffffffffffffeeeeeefffffffffffffffffff
-- 032:effffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeefffffffffffffffffffffffffffffffeeeeeefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeffffffffffffffffffffffffffffffffeeefffffffffffffffffffffff
-- 033:eeeeeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeffffffffffffffffffffffffffffffeeffffffffffffffffffffffffff
-- 034:fffeefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeefffffffffffffffffffffffffffeeeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeefffffffffffffffffffffffffffeeeeeeeffffffffffffffffffffffffff
-- 035:fffffeeeeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeefffffffffffffffffffffffffffeeeeeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeffffffffffffffffffffffffffffffffeeeffffffffffffffffffffffffffff
-- 036:ffffffffffeeeefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeeefffffffffffffffffffffffffffffffeeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeffffffffeeeeffeeeeefeeeeeffffffeeeeeeeffffffffffffffffffffffffffff
-- 037:fffffffffffffffffeeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffeefffffffffeeeefeeeeefeeeeeffffffeeeeeeefffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeeeefeeeefffffffffffffffeeffffeeeeeeeeeeeeffffffffffffffffffffffffff
-- 038:eefeeeeeeeeeeefffffeeeeeeefffffffffffffffffffffffffffffffffffffffffffffffeeeeeeeeeeffeeeeffffffffffffffeeffffeeeeeeeeeeeeffffffffffffffffffffffffffffffffffffffeeeeeeeeeeefffffffffffffffffffffffffffffffffffeeeeeeeeeeeefffffffffffffffffffffff
-- 039:eefffffffffffffffefffffeeeeeeeeeeeefffffffffffffffffffffffffffffffffffeeeeeeeeeefffffffffffffffffffffffffffffffffffeeeeeeeeeeeefffffefffffffffffffffeefffeeeeeeeeeefffffffffffffffffffffffffffffffffffffffffffffeeeeeeeffffeeeeeefeeeeeeeeeeffff
-- 040:fffffffffffffffffffffffffffffffffeeeeeeeeeeeffeeefffffffffffffeeeefeeeeeeeeeefffffffffffffffffffffffffffffffffffffffffffffeeeeeffffffeeeefeeeeffeeeffffffffeeffffffffffffffffffffffffffffffffffffffffffffffffffeeefffffffffffffffffffffffffffeee
-- 041:ffffffffffffffffffffffffffffffffffffffffffeefffffffffeffffeffffefffffffffeffffffffffffffffffffffffffffffffffffffffffffffffeeeeeeffffffffffffffffffffffeeeeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeefffff
-- 042:ffffffffffffffffffffffffffffffffffffffffffffffeeeeefffffffffffffffffffffeeffffffffffffffffffffffffffffffffffffffffffffffffffffeeeffffffffffffffffffffeeeefffffffffffffffffffffffffffffffffffffffffffffffffffeeffffffffffffffffffffffeeeeffffffff
-- 043:eefffffffffffffffffffffffffffffffffffffffffffffffffeeffffffffffffffffffffffeffffffffffffffffffffffffffffffffffffffffffffffffeeeeefffffffffffffffffffffeeeeeffffffffffffffffffffffffffffffffffffffffffffeffffffffffffffffffeffffffffeefffffffffff
-- 044:ffffeeeeeffffffffffffffffffffffffffffffffffffffffffeeefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeeffffeeeeefeeefeeeeeffeeeeeeeffffffffffffffffffffffffffffffffffffeeeeeeeeefffeffffffffffffffffffeeeeeeeeefffffffff
-- 045:eefeeeeffffeeeeefffffffffffffffffffffffffffffffffffeeeeeeeeeffeefffffffffffeffffeeeeeeeeeffffffffffffffffffffffffffffeeeeeeeefffffffffffffffffffffffffffeeeeeeeeefffffffffffffffffefffeeeeeeeefffffffffffffffffffffffffffffffffffeeeeeefffeeeefe
-- 046:ffffffffffffffffffffeeeeeeeeeffffffffffffffffeffeeeeeeeefffffffffffffffffffffffffffffffffeeeeeefffeeeefeeefeeeeffffeeeeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeefffffffffffffffffffffffffffffffffffffffeeeefffffffffffff
-- 047:fffffffffffffffffffffffffffffffeeffffffffffffffffffffeeeefffffffffffffffffffffffffffffffffffffeeeffffffffffffffffffefffffffffffffffffffffffffffffffffffffffffeeefffffffffffffffffeefffffffffffffffffffffffffffffffffffffffffeefffffffffffffffffe
-- 048:ffffffffffffffffffffffffffffffffffffffeffffffffffffffffffffffffffffffffffffffffffffffffffffffffeeeefffffffffffffffffeeeeffffffffffffffffffffffffffffffffffffffffffefffeffefffffffeffffffffffffffffffffffffffffffffffeeeeeffeeefffefffeeeeeeeeeee
-- 049:fffffffffffffffffffffffffffffffffffffffeeeefffeeeffeefeeeefeeeeeeffffffffffffffffffffffffffffeeeeeeefffffffffffffffffeeeeeeeefffffffffffffffffffffeeeeeeeffffffffffffffffffffffffeeeeeeeffeefffffffffeefeeeeeeefffffffffffffffffffffffffffffeeee
-- 050:fffffffffffffffeeeeeeeffeffffffffeeeeeeeeeeffffffffffffffffffffffffffffeeeffffeeeeeefeefffffeffffffffffffffffffffffffffffffffeefffffffffffffffffeeeffffffffffffffffffffffffffffffffeeeffffffffffffffffffffffffffffffffffffffffffffffffffeeefffff
-- 051:fffffffffffffffffffffffffffeffffffffffffffeefffffffffffffffffffffffffffffffffefffffffffffffffffffffffffffffffffffffffffffffffeeefffffffffffffffeeefffffffffffffffffffffffffffffffffffffffeffefffffefffffffffffffffffffffffffffffeeeefeeeffffffee
-- 052:ffeeffffffffffffffffffffffffffeeeeffeeefffffeeeeeeeeeffffffffffffffffffffffeeeeeffffffffffffffffeeeeeeffffffffffffffffffeeeeefffffffffffffffffffffeeeeeefeeffffffeeeeeeeeefffffffffffffffffffffffffeeefffeefeefeeffffeffffffffffffffffffffffffff
-- 053:fffffffffffffffffffffffffffffffffeffffffffffffffffffffffffffeeefffffffffffeeeffffffffffffffffffffffffffffeffffffffffffeefffffffffffffffffffffffffffffefffffffffffffefffffffffffffffffffffffffffeeefffffffffffffeeffffffffffffffffffffffffffeffff
-- 054:ffffffffffffffffffffffffeffffeefefeefffeeffffffffffffffffffffffeeeeeeeffffffeffeeeeeffffffffffffffffffeeeeffffffffffffffffeeeeefffffffffffffeeeeefffffffffffffffffffeeeeefeeffefeeefeeeefffffffffffffffffffffffeffffffffffffffefffffffffffffffff
-- 055:fffffffffffffeeeffffffffffeeffffffffffffffffffffffffffffffffffffefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffeefffffffffffeeeffffffffffffffffffffffffffeffffefffeefffffffffffffffffffffeeefeeffeffeeeeeeefffffffffffffffffeeeee
-- 056:ffeeeeefffffffffffeeeeffffffffffffffffeeeeeeeffffeefeeeffffffffffffffffffffffffefeffffffffffffffffffffffffffeeefffffffffeefffffffffffffffffffffffffffffffffefffffffffffffffffffffffeffffffffffffffffffffffffffffffffeeffffffffffeeffffffffffffff
-- 057:fffffffffffffffeeeefefffffffeeeefffffffffffffeeeeffffffffffffeeeeffffffffffeeeffffffffffffffffeeefeefefeffeeffffffffffffffffffffffffffffffefffffffffffffffffffeeffffffffefffffffffffffffffffffeffffffffeeffffffffffffffffffffffffffffffeffffffff
-- 058:ffffffffffffeeeeffffffffeeeefffffffffffeeeffffffff77ffeeeeffffffefeeeffffffffffffffeeefeeeeefffefffffffffffffffffffffffffffefffffffffffffffffeefffffffeffffffffffffffffffeefffffffefffffffffffffffffffffffffffeefffffffffffffffffefffffffffeffff
-- 059:feefeeefeffeffffffffffffffffffffffffefffffff77777777777777777777777777777ffffffffffffeffffffffffffffffffffffffeffffffffffffffffeffffffffefffffffffffffffffffefeffeffffffffffffffeefefffeeeeefffffffffffeeefffffffffeeeeffffffffeeeffffffffffffee
-- 060:ffffffeefeffefeefffffffffffeeeffffffee777fff66776777766666677777766666777ffffffffffefeee777777777ffffffffefffffffefffffffffffffeffffffeffffffffffffffeffffffeffffffffffffffeffffffefffffffffffffefffffffffffffffffffffeffeeeefeefffffffffffeeeef
-- 061:fffeeffffffffeeffffffeeffffffffffe676777766666766677666666666776666666677ffffeffff7667766677766667777666677ffffffffffffffffffffeffffffefffffffffffffeeeffeffffffffffeeeffffeefffffffffeefffffffeeffffffeeeffffffffeeeeffefefffffffffffefffffffff
-- 062:eefffffffeeeffeeefffffffff776777666766766666667666776666666667766666666777776666776666766677666666776666667fff776777667776667776667fffeefffffeeffffffeeffffffeeffffeefffffffffefeefffffffffffffffffefffffffffffffffffffffccdcccedffcccddcdeffcdc
-- 063:efcdcccedfcccdffffffffffff766676666766766666667666776666666667766666666776766666676666766677666666776666667766766676666776666766667ffffffffffeeeefffffffeffffeefffffeffffffffffffffffffcdecdcccefcccdcdefcdcccedfcccdcdefcceeeeeeffceeeeeeeffcee
-- 064:efceeeeeefceeeeeefceeeeeef766676666766766666667666776666666667766666666776766666676666766677666666776666667666666676666776666766666fffffffffffffffffffddfdccdfcdcefdccefceeeefceeeefceeeeeceeeeefceeeeeffeeeefeffeefefeffeeeeefefffeefeefefffeee
-- 065:fffffffffffffffeffeeeefeff766676666766766666667666776666666667766666666776766666676666766677666666776666667666666676666776666766666eceeeeeefeeefeeeeceeefeefffeefffeefefefefffeeefffefefffffffffffffffffffffffffffffffffffffffffffffffffffffffff
-- 066:cdcedfccddeeefcccdcedfccdd766676666767777666667767777666666777777666667776766666677667766677766667777666677666666676666776666766666fffffffffffffffffffffffffffffffffffcdeefccdcdfcddeefccccedfccdeeefcccdcedfccddeeefcccdccedfccdddeeeffcccddced
-- 067:eeeeefceeeeeefceeeeeefceee766777667777777777777777777777777777777777777777776666777777777777777777777777777766766777667776667776667eeeceefeeefeeeeceeefeeeeceeefceeeeceeeefceeeefceeeefceeeeefceeeeefceeeeeefceeeeeefceeeeeeefceeeeeeeffceeeeeee
-- 068:eefeffeeeefeffffffffffffff777777eeeeeeeeeeeeeeee77777777eeeeeeeeeeee77777777777777eeeeeeeeeeeeeeeee77777777777777777777777777777777ffffffffffffffffffffffffffffffffffffffffffffffffffffeeefeffeeefeffeefffffffffffffffffffffffffffffffffffffffff
-- 069:efcdcccedfcccdcdefcdcccedf766777eeeeeeeeeeeeeeee77777777eeeeeeeeeeee77777777666677eeeeeeeeeeeeeeeee77666677766766777667776667776667ecccedcefcddfdccdccddfdccdfcdcefdccefccdcefccccdfccdcdecdcccefcccdcdefcdcccedfcccdcdefccdcccedffcccddcdeffcdc
-- 070:efceeeeeefceeeeeefceeeeeef76ffff2222222222222222dddd7fff222222222222ddd7767666ffff22222222222222222dddd6667666666676666776666766666fffffeeefeeefeeffefeefeefffeefffeefefceeeefceeeefceeeeeceeeeefceeeeeefceeeeeefceeeeeefcceeeeeeff4444333333333
-- 071:ffffffffffffffffffffffffff76ffff2222222222222222ddddf22222c222222222222dd67666ffff22222222222222222dddd6667666666676666776666766666eeeccefcdefcdedcdeefffffffffffffffffffffffffffffffffffff33333333334444ee4443333333333333344444443333333333344
-- 072:cdcedfccddeeefcccdcedfccddff222222cc2222222222222222dd2222c222222222222dd676ff222222cc22222222222222222dd67666666676666776666766666a9aaaaa98a898a89a8afee333444444443333333444444444333333333333333444444443333333444444444333333333333333334444
-- 073:eeeeefceeeeeef9aa99aaaaaa9ff222222cc2222222222222222ddff222222222222ddd22676ff222222cc22222222222222222dd67766766676666776666766667aa9aa9aaa8333333334444333333333444443334444444444443333344444444444333333333334444444444443333333333333444444
-- 074:8a8aa98a88aa9aa99aaa9aa99a22ffff2222222222222222dddd2222eeeeeeeeeeee2222277722ffff22222222222222222dddd22778a9aa6777667776667776668aaa9aaaaaaaaaa9aa898aa334444444444333344444444444433333444444444444433333333444444444444444333333333333444444
-- 075:aaaa98aaa8aa8aaa899aa88aa922ffff2222222222222222dddd2222eeeeeeeeeeee222229a822ffff22222222222222222dddd2277a98aaa9aaaaaaaaaaaaa89aaaaa8a8a8aaaaaaa88a998aaa89a89aaaaaaaa88a89aaaa444443334444444444444443333334444444444444444333333333344444444
-- 076:8aaa989a8aaa889aaaaaaaaaa8222222eeeeeeeeeeeeeeee22222222222222222222222dd888222222eeeeeeeeeeeeeeeee222222aaaa98aaa8aaaaaaaaaaaa8aaa8aaaa9aaaaaaaaaaaaa89aaa9998aaa889aaa8aaaa998aaa9aaa99aaa999aa99aaa9aa433444444444444444444443333334444444444
-- 077:99aa888aa999aaaa9aaaaa99aa222222eeeeeeeeeeeeeeee222222f222222222222222ddda88222222eeeeeeeeeeeeeeeee222222aaaaaa99aaaa98aaaa9aaaaaaaaaaaaaaaaa88aaaaaa98aa888aaaaaaaaa898a998aaaa889aa89aaaaaaaaaa8a8aa9aaaaaaa88aaaaaaaaaaaaaaaaa333344444444444
-- 078:999aaa8a8aaa999aaaa99aaaaaff222222222222222222222222ddf222222222222222ddd99aff2222222222222222222222222ddaaa8899aaaaaaaaaaaaa99aaaa989aaaa99aaaaaaaaaaaaaaaaaa88aaaaaaaa8aa8a8aaaaaaaaaa8888aa998aaaa8899aa99aaaaaaaaaaa898aa99aaaaaaa98aaaaaaaa
-- 079:88aaaaa89aa8a8aa99aaaa999aff222222222222222222222222ddffeeeeeeeeeeeeddd2299aff2222222222222222222222222ddaaa998aaaa8aaaa88aaaaaaaaaaaaaaaaa8a8aaa99aaaaaa899aa899aaaaaaaaaaaaa99aaa998aaaaaa99aa88a8aaaaaaaaaaaaaaaa98aaaa8aaaaa89aaaaaaaaaaaaaa
-- 080:aaaaaaaaaaaaa998aaaaaaaaaaffff22222222222222222222dddd2feeeeeeeeeeeedd222aaaffff222222222222222222222dddd8a8aaaaaaaaaaaaaaaaaa98aaaaa8aaaaa999aaaaaaaaaaaaaaaaaaaa99aaaa899998aaaaa98a99aaaa8aaaaaa99988aaaa99aa9aa99aaaaa9999aaaa998aaaa99aaaaa
-- 081:9aaaaaaaaaaaaaaaaaa9aa89aaffff22222222222222222222dddd2feeeeeeeeeeeedd222aaaffff222222222222222222222dddda889aa88888aaa889aaaaa899aa8aaaaa99aaaaa999aaaa8898aaaa9999aaaaaa99aa9a889aaaaa88999aaaaaaaaaaaaa9a899aaaaaa9999aaaaa999aaaaaaaaaaaaaaa
-- 082:aaaaaaaaaaa9aa999aaaaa999922ffffeeeeeeeeeeeeeeeedddd2222222222222222222dda8822ffffeeeeeeeeeeeeeeeeedddd229998aaaaaaa8899aaa899aaaaaaaaaaaaaaaa8988aaa999aaaaaaaaa998aa88a8aaaaaaaaaaaaaaaaaaaaa988aaaaa88aaaaaa999aaaaaaaaaaaaaaaaaaaaaaa99aaaaa
-- 083:aaaa988a99aaaaaaaaaaaaaaa922ffffeeeeeeeeeeeeeeeedddd22f222222222222222ddd99a22ffffeeeeeeeeeeeeeeeeedddd22aaaa88a88aaa988aaaaa998aaaaa999aaaaaa9999aaaaaa999aaaaaa999aaaaaa99999aaaaa8aa8aaaaa999888aaaaaa88999988aaaaa999aaaaaaaaaaaaaaaaaaaaaaa
-- 084:aaaaaaaaaaaaaaaaaaa88888aa2222ffeeeeeeeeeeeeeeeedd2222f222222222222222ddd8aa2222ffeeeeeeeeeeeeeeeeedd2222aaaaaaaaaaaaaaaaaaaa988aaaaaa88aaaaaaa999aaaaaaaaaaaaaaaaaaaaaaaaaaa999aaaaaa9999998aaaaaa9988a99aaaaaaaaaaaaaaaa999988aaaaa999aaaaaa99
-- 085:a8998aaaaaa9999aaaaaaa999a2222ffeeeeeeeeeeeeeeeedd2222ffeeeeeeeeeeeeddd22aaa2222ffeeeeeeeeeeeeeeeeedd2222aaaaaaaaaaaaaaaaaa9999aaaaaaa888aaaaaaa999aaaaaaaaaaaaaaaaaaaaaaaaaaaa8aaa8889aaaaaaaaaaa999aaaa888888aaaaaaaaaaaaaaaaaa8998aaa999888aa
-- 086:aaaaaa9998aaa9aaaaaaaaaaaaff222222222222222222222222dd2feeeeeeeeeeeedd222aaa2222ffeeeeeeeeeeeeeeeeedd2222aaaaaaaaa998aaaaaaaa988aaaaa8888888aaa888aaaaaaa988aaaaaa8998aaaaaaa9999aaaaaaa9999aaaaaaaaa999aaaaaaa999999aaaa888a88aaaaa99999888aaaa
-- 087:aa88998aaaaaaaaaaaaaaaaaaaff222222222222222222222222dd2feeeeeeeeeeeedd222aaaff2222222222222222222222222dda88aaaaaaaa8999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa999aaaaaaa89999998aaaaaaaa9988aa99aaaaaaaaaaaaaaaaaaa9999988aaaaaaa998aaa9aaa9999aaaaaaa
-- 088:9aaaaaaaaaaaaaaaaaaaaaaaaaffff22222222222222222222dddd22222222222222222ddaaaff2222222222222222222222222ddaaaaaaa9998aaaa8888888aaaaaaaaaaaaaaaaaaaaa89998aaaa9999888aaaaaaaaa889999aaaa889988aaaaaaaaaaaaaaaaaaaaa888a88aaaa8899aaaaaaaaaaaaaa98
-- 089:aaa888988aaaaaaa8999aaaaaaffff22222222222222222222ddddff222222222222ddd88888ffff222222222222222222222dddd9a8888aaaaaaaa8888a99aaaaaaaaaaaaaaaaaaaaaaaaaaaa9999aaaaaaaaa998899aaaaaaaa9999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa9888aaaaaaaaaaaaa
-- 090:99a8888aaaaaaaaa888999999a22ffffeeeeeeeeeeeeeeeedddd22ff222222222222dddaaaa9ffff222222222222222222222dddd88aaaaaa8889aaaaaaaa8888aaaaa8889988aaaaaaa8899aaaaaaaaa89999aaaaaaaaaaaa9999aaaaaaaa9999999aaaaaa88898888aaaa9999999988aaaaaaaaa9888a9
-- 091:aaaa88899aaaaaaaaaaaaaaaaa22ffffeeeeeeeeeeeeeeeedddd22aaeeeeeeeeeeee99aaaaaa22ffffeeeeeeeeeeeeeeeeedddd22aaaaaaaaa9999a8889aaaaaaaa98888a999a88899aaaaaaaaa8899999999aaaaa88888888aaaaaa9999999aaaaaaaaa9999aaaaaaaaaaaaa99998aaaaaaaaa99988aaaa
-- 092:99aaaaa899988aaaaaaaaaaaaa2222ffeeeeeeeeeeeeeeeedd222299eeeeeeeeeeeeaaa9999822ffffeeeeeeeeeeeeeeeeedddd22aaaaaaaaaaaaaaaaaaa98888aaaaaaaaa88aaaaaaaaaa89999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa9999aaaaaaaaa9999999998aaaaaaaaaa99888aa999a
-- 093:aaaaaaaaaaaaaaaaaaaaaaaaaa2222ffeeeeeeeeeeeeeeeedd2222aaaaaaaaaaaaaaaa9988aa2222ffeeeeeeeeeeeeeeeeedd2222aaaaaaaa88899888aaaaa99998888aaaaaaaaaa888889999aaaaa8999988aaaaaaaaaaaaaaaaaaaaaaaaaa888888888aaaa88999aaaaaaaaaaaaaaaaa998888aaaaaaaa
-- 094:999999aaaaaaaaaaaaaaaaaaaaff222222222222222222222222dd9999999998aaaaaaaaa9992222ffeeeeeeeeeeeeeeeeedd2222aaaaaaaaaaaaaaaaa999988aaaaaaaaaa888aaaaaaaaa88889aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa888aa8888aaaaa99999aaaaaaaaaaaaaaa8999999aaaaa
-- 095:8aaaaaaaaa899999aaaaaaaaaaff222222222222222222222222ddaaaaaaaa99999aaaaaaaaaff2222222222222222222222222ddaaaaa999999988888aaaaaaaaaaa88889999999888aaaaaaaaaa99988aaaa9aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa99999aaaaaaaaaaaa88888aaaaaaaaaa899
-- 096:99aaaaaaaaaaaaaaa999999aaaaaffff2222222222222222dddd998888aaaaaa888889aaaaaaff2222222222222222222222222ddaaaaa89999aaaaaaaaaaaa999999aaaaaaaaaaaaaaa99999aaaaaaaaaa9999999999aaaaaa88888a8888aaaaaaa999999999888aaaaaaaaaaa988888a9999988888aaaa
-- 097:88999999888889aaaaaaaaaaaa88ffff2222222222222222dddd8888aaaaaa99999999999aaaaaffff22222222222222222dddd999999aaaaaaaaaaaa999998aaaaaaaaaa88999988aaaaaaaa888899aaaaaaaaaaa88888aaaaaa8888898888aaaaaaaa888999aaaaaaaaaaaa899999aaaaaaaaaaaaaaaaa
-- 098:8889aaaaaaaaaaaaa999999aaaaaaaaaeeeeeeeeeeeeeeeeaaaaaaaaaaaaaaaa99aaaa889999aaffff22222222222222222ddddaaaaaaaaaaaaa888899999999aaaaaaaaa888aa8888aaaaaaaa99999999999aaaaaaaaaaa99999aaaaaaaaaaaaaaa999999aaaaaaaaaaaa999999aaaaaaaaaaaa8999988a
-- 099:aaaaaaaa998888aaaaaaaaaaaaaaaaaaeeeeeeeeeeeeeeeeaaaaaaaaaaaaaaaaaaaaaaaaa999998aaaeeeeeeeeeeeeeeeeeaaaaaaaaaaa999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa99aaaa889999aaaaaaaaaaa88889999999988888aaaaaaaaaaaaa8888899999999aaaaaaaaa888aaa
-- 100:8888999999aaaaaa888999888aaaaaaaeeeeeeeeeeeeeeeeaaaaaaaaaa888888a88888aaaaaa889999eeeeeeeeeeeeeeeeeaaaaa9888888aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa999999aaaaaaaaaaaa9888889aaaaaaaaaaaaa9999999aaaaaaaaaaaaaaaaaaaaaaaa
-- 101:99988aaaaaa888888888888aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa88999988aaaaaa9999999888888aaaaaaaaaaaaa88888999999aaaaaa88889988888aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa8888aa8888aaaaaaa888999aaaaaaaaaaaaaaaaaaaaaaaa8888889aaaaaaaaaaaaaaaaaaaaaaaaaa
-- 102:889999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa88aaaa888aaaaaaa8889999aaaaaaaaaaaaaaaaaaaaa9999999aaaaaaa888889988888aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa9999999aaaaaaa999999988888aaaaaaaaaaaaaaaa888999999aaaaaa8888889888888aaaaaaa
-- 103:999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa99999988aaaaaaaaaaaaaa8888aaaaaaaaaaaaa888889aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa8888aaa8888aaaaaaaa8999999aaaaaaaaaaaaaaaaaaaa899999999aaaaaaa8889999888aaaaaa
-- 104:8888888999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa99aaaaa8999999aaaaaaaaaaaaaaa9999998899999aaaaaaaaaaaaa9999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa9998888aaaaaaaaaaaaaaa8aaaaaaaaaaaaa9888888aaaaaa88aaaaa888aaa
-- 105:a9999999999999aaaaaaaa888888aa88888aaaaaaaaaa999999999988888aaaaaaaaaaaaaaaa888888899999999888888aaaaaaaaaaaaa9999888aaaa999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa9999999aaaaaaaaaaaaaaa9998888899aaaaaaaaaaaaa9999999aaaaaaaaaaaaa
-- 106:a9999998aaaaaaaaaaaaaa899999988aaaaaaaaaaaa99999999999aaaaaaaaaaaaaaaa99999999aaaaaaaaaaaaaaa9999999aaaaaaaaaaaaaa88899999999999aaaaaaaaaaaa88aaaaaa8aaaaaaaaaaaaaaa999999aa8888899aaaaaaaaaaaaaaaa888899999999999988aaaaaaaaaaaaaa9999999aaaaaa
-- 107:a88888889aaaaaaa88888889888888aaaaaaaaaa88888999aaaaaaaaaaaaaaaa88899999aaaaaaaa8aaaaaaaaaaaaaaa9999999aaaaaaaaaaaaaa99999999999aaaaaaaaaaa8888899888888aaaaaaaaa9999999999999988aaaaaaaaaaaaaaaa99998888aaa99999aa88888899aaaaaaaaaaaaaa8888888
-- 108:aa9999999aaaaaaaaaaaaaaa88aaaaaaaa99999888aaaaaaaaaaaaaaaa999888888aaaaaaaaa888888888888888aaaaaaa99888888aaaaaaaaaaaaaaa9998888aaaaaaaaaaaaa889999998aaaaaaaaaaaaaaa999999999aaaaaaaaaaaaaaaa99999999aaaaaaaaaaaaaaaaaaa99999999aaaaaaaaaaaaaa8
-- 109:aa99999999aaaaaaaaaaaaaaaaa999999999aaaaaaaaaaaaaaaaa9999999999aaaaaaaaaaaaaaa999999998aaaaaaaaaaaaaa88999999aaaaaaaaaaaaaaa88888999aaaaaaa8888888a8888888aaaaaaaa888888889aaaaaaaaaaaaaaaaa88888999aaaaaaaaa888aaaaa88aaaaaaaa99999998aaaaaaaaa
-- 110:aaa9888888aaa99999aaa888889999aaaaaaaaaaaaaaaaa88999999999999999aaaaaaaaa888888889888888aaaaaaaaaaa9999999999999aaaaaaaaaaaaaaa99999999aaaaaaaaaaaaaaaaaaaaaaaa999999988aaaaaaaaaaaaaaaaa999998888aaaaaaaaaaa888888998888888aaaaaaaaa88888888aaa
-- 111:aaa888999999999999988888aaaaaaaaaaaaaaaaa998888888a99999999aaaaaaaaaaaaaaaa88aaaaaa888aaaaaaaaaaaaa9999999999999888aaaaaaaaaaaaaaaa99999999aaaaaaaaaaaaaaaaa999999999aaaaaaaaaaaaaaaaaa999999999999aaaaaaaaaaaaaa8899999998aaaaaaaaaaaaaaaa89999
-- 112:aaa999998888999999aaaaaaaaaaaaaaaaaa999999998aaaaaaa99aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa9999999aa88888889aaaaaaaaaaaaaaaa98888888aa9999999aa888888999aaaaaaaaaaaaaaaaaaa889999999999999999aaaaaaaaa8888888898888888aaaaaaaaaaa99999
-- 113:aaaa8888888aaaaaaaaaaaaaaaaaaa999999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa899999999aaaaaaaaaaaaaaaaa8889999999999999888888aaaaaaaaaaaaaaaaaa988888888a999999999aaaaaaaaaaaaaaaa88aaaaaa888aaaaaaaaaaaaaa99
-- 114:aaaa8aaaaaaaaaaaaaaaaaaa8888889999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa999999999aaaaaaaaaaaaaaaaa9999998899999999aaaaaaaaaaaaaaaaaaa999999998aaaaaaa999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 115:aaaaaaaaaaaaaaaaaaa999888888aaaaaaaaaa88aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa999999988aaaaaaaaaaaaaaaaa8888888889aaaaaaaaaaaaaaaaaaa9999999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 116:aaaaaaaaaaaaa8999999999aaaaaaaaaa88888888a88888888aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa8aaaaaaaaaaaaaaaaaa888888888aaaaaaaaaaaaaaaaaa888aaaaaaaaaaaaaaaaaaaa8889999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 117:aaaaaaa88888888999999999aaaaaaaaa88889999988888aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa88888888aa8888888aaaaaaaaa888899999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa98888888889aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 118:aaaaaa8888889999999999aaaaaaaaaa88999999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa8888899998888888aaaaaaaaaa99999999998aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa9999999888aaaaaaaaaaa88888aaaaa8888aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 119:aaaaaa99999999999aaaaaaaaaa88888888999888888aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa9999999999aaaaaaaaaaa99999999998888888aaaaaaaaaaaaaaaaaaaaaaaaa8889999999999aaaaaaaaa8888888889888888888aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 120:aaaaaaa999988888aaaaaaaaaa8888888aaa88888888aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa8888889999988888aaaaaaaaaa99999999988888888aaaaaaaaaaaaaaaaaaaaa88888888889999999999aaaaaaaaa88899999998888aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 121:aaaaaaa8888888888aaaaaaaaaa8aaaaaaaaa88aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa88888888aa888888888aaaaaaaaaa999999999988aaaaaaaaaaaaaaaaaaaaaaaaaaaa8888899999999999aaaaaaaaaaa889999999988aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 122:aaaaaaaa8888999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa888aaaaaaa8888aaaaaaaaaaa88888999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa99999999999aaaaaaaaaaa888888889998888888aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 123:aaaaaaaa9999999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa88888888888aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa99999988888aaaaaaaaaa8888888aaa888888888aaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 124:aaaaaaaa99999999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa999999888888aaaaaaaaaaaaaaaaaaaaaaa88aaaaaaaaaaaaaaaaaaaaa8888888888aaaaaaaaaaa88aaaaaaaa888aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 125:aaaaaaaaa9999999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa999999999998aaaaaaaaaaaaaaaaaaaaaaa88888888aaaaaaaaaaaaaaaaaaaaa88888899999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 126:aaaaaaaaa99999988888aaaaaaa9999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa999999999999aaaaaaaaaaaaaaaaaaaaaaaa9988888888889aaaaaaaaaaaaaaaaaaaaaa8999999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 127:aaaaaaaaaa98888888888aa999999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa9aaaaaaaaaaa999999999999aaaaaaaaaaaaaaaaaaaaaaaa9999999988889999999aaaaaaaaaaaaaaaaaaaaaa99999999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 128:aaaaaaaaaa8888888899999999999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa999999aaaaaa888889999999aaaaaaaaaaaaaaaaaaaaaaaaa889999999999999999999999aaaaaaaaaaaaaaaaaaaaaa999999999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 129:aaaaaaaaaaa8889999999999999999999aaaaaaaaaaaaaaaaaaa8888aaaaaaaa888aaaaaaaaaaaaaaaaaaaaaa999999999999a888888888899aaaaaaaaaaaaaaaaaaaaaaaaa888888899999999999999999998888aaaaaaaaaaaaaaaaaaaaaaa99999999998aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
-- 130:aaaaaaaaaaa99999999999999999999999aaaaaaaaaaaaaa888888888aaaa8888888aaaaaaaaaaaaaaaaaa99999999999999999888888888aaaaaaaaaaaaaaaaaaaaaaaaa98888888888899999999999999888888888aaaaaaaaaaaaaaaaaaaaaaa999999888888aaaaaaa9999aaaaaaaaaaaaaaaaaaaaaa
-- 131:aaaaaaaaaaa99999999999999999999aaaaaaaaaaaaaaa888888888889888888888888aaaaaaaaaaaaa99999999999999999999998888aaaaaaaaaaaaaaaaaaaaaaaaaa9999988888888aaaa999999999aa888888888889aaaaaaaaaaaaaaaaaaaaaaaa88888888888aa9999999999aaaaaaaaaaaaaaaaaa
-- 132:aaaaaaaaaaaa999999999999999aaaaaaaaaaaaaaaaaaaa8888889999998888888aaaaaaaaaaaaaaaaa99999999999999999999999aaaaaaaaaaaaaaaaaaaaaaaaaa9999999999988aaaaaaaaa99999aaaaaaa888888999999aaaaaaaaaaaaaaaaaaaaaaaa888888888999999999999999aaaaaaaaaaaaaa
-- 133:aaaaaaaaaaaa999999999998aaaaaaaaaaaaaaaaaaaaaaaa889999999999888aaaaaaaaaaaaaaaaaaaaaa999999999999999999aaaaaaaaaaaaaaaaaaaaaaaaaaa9999999999999aaaaaaaaaaaaaaaaaaaaaaaaaa899999999999aaaaaaaaaaaaaaaaaaaaaaaa888889999999999999999999aaaaaaaaaaa
-- 134:aaaaaaaaaaaaa999999888888aaaaaaaaaaaaaaaaaaaaa8889999999999988aaaaaaaaaaaaaaaaaaaaaaaa99999999999999aaaaaaaaaaaaaaaaaaaaaaaaaaa99999999999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa999999999999aaaaaaaaaaaaaaaaaaaaaaaaa999999999999999999999999aaaaaaa
-- 135:aaaaaaaaaaaaa998888888888aaaaaaaaaaaaaaaaa888888889999998888888aaaaaaaaaaaaaaaaaaaaa8888999999999aaaaaaaaaaaaaaaaaaaaaaaaaaaa99999999999999aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa999999999999aaaaaaaaaaaaaaaaaaaaaaaaa99999999999999999999999aaaaa
-- </SCREEN>

-- <PALETTE>
-- 000:1a1c2c5d275db13e53ef7d57ffcd75a7f07038b76425717929366f3b5dc941a6f673eff7f4f4f494b0c2566c86333c57
-- </PALETTE>

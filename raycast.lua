-- title:  Raycast FPS
-- author: Wojciech Graj
-- desc:   Raycast test
-- script: lua
-- input: gamepad

function init()
	MAP_WIDTH = 24
	MAP_HEIGHT = 24
	ROT_SPEED = 0.001
	MOVE_SPEED = 0.003
	SCREEN_WIDTH = 240
	SCREEN_HEIGHT = 136
	FPS_COUNTER = true
	TEX_SIZES = {[1]={16,16}}
	pos_x = 22
	pos_y = 12
	dir_x = -1
	dir_y = 0
	plane_x = 0
	plane_y = 0.66
	prev_time = 0
end

function rotate(delta)
	local speed = 0.001 * delta
	local old_dir_x = dir_x
	dir_x = dir_x * math.cos(speed) - dir_y * math.sin(speed)
	dir_y = old_dir_x * math.sin(speed) + dir_y * math.cos(speed)
	local old_plane_x = plane_x
	plane_x = plane_x * math.cos(speed) - plane_y * math.sin(speed)
	plane_y = old_plane_x * math.sin(speed) + plane_y * math.cos(speed)
end

function move(delta)
	local speed = 0.003 * delta
	if mget(math.floor(pos_x + dir_x * speed), math.floor(pos_y)) == 0 then
		pos_x = pos_x + dir_x * speed
	end
	if mget(math.floor(pos_x), math.floor(pos_y + dir_y * speed)) == 0 then
		pos_y = pos_y + dir_y * speed
	end
end

function get_tex_pixel(offset, id, x, y)
	return peek4(offset + 0x40 * (id + 16 * (y // 8) + x // 8) + 0x8 * (y % 8) + (x % 8))
end

init()
function TIC()
	local t = time()
	local delta = t - prev_time --msec
	prev_time = t

	-- input
	if btn(2) then
		rotate(delta)
	elseif btn(3) then
		rotate(-delta)
	end
	if btn(0) then
		move(delta)
	elseif btn(1) then
		move(-delta)
	end

	-- draw
	cls(0)

	for x=0,SCREEN_WIDTH do
		local camera_x = 2 * x / SCREEN_WIDTH - 1
		local ray_dir_x = dir_x + plane_x * camera_x
		local ray_dir_y = dir_y + plane_y * camera_x
		local map_x = math.floor(pos_x)
		local map_y = math.floor(pos_y)
		local delta_dist_x = math.abs(1 / ray_dir_x)
		local delta_dist_y = math.abs(1 / ray_dir_y)

		local step_x
		local side_dist_x
		if ray_dir_x < 0 then
			step_x = -1
			side_dist_x = (pos_x - map_x) * delta_dist_x
		else
			step_x = 1
			side_dist_x = (map_x + 1.0 - pos_x) * delta_dist_x
		end

		local step_y
		local side_dist_y
		if ray_dir_y < 0 then
			step_y = -1
			side_dist_y = (pos_y - map_y) * delta_dist_y
		else
			step_y = 1
			side_dist_y = (map_y + 1.0 - pos_y) * delta_dist_y
		end

		local side
		local not_hit = true
		while not_hit do
			if side_dist_x < side_dist_y then
				side_dist_x = side_dist_x + delta_dist_x
				map_x = map_x + step_x
				side = 0
			else
				side_dist_y = side_dist_y + delta_dist_y
				map_y = map_y + step_y
				side = 1
			end
			if mget(map_x, map_y) > 0 then
				not_hit = false
			end
		end

		local perp_wall_dist
		if side == 0 then
			perp_wall_dist = (map_x - pos_x + (1 - step_x) / 2) / ray_dir_x
		else
			perp_wall_dist = (map_y - pos_y + (1 - step_y) / 2) / ray_dir_y
		end

		local line_height = math.floor(136 / perp_wall_dist)
		local draw_start = -line_height / 2 + SCREEN_HEIGHT / 2
		if draw_start < 0 then
			draw_start = 0
		end
		local draw_end = line_height / 2 + SCREEN_HEIGHT / 2
		if draw_end >= SCREEN_HEIGHT then
			draw_end = SCREEN_HEIGHT - 1
		end

		local wall_x
		if side == 0 then
			wall_x = pos_y + perp_wall_dist * ray_dir_y
		else
			wall_x = pos_x + perp_wall_dist * ray_dir_x
		end
		wall_x = wall_x - math.floor(wall_x)

		local tex_id = mget(map_x, map_y)
		local tex_size = TEX_SIZES[tex_id]
		local tex_x = math.floor(wall_x * tex_size[1])

		local step = tex_size[2] / line_height
		local tex_pos = (draw_start - SCREEN_HEIGHT / 2 + line_height / 2) * step

		for y=draw_start,draw_end do
			local tex_y = math.floor(tex_pos) % tex_size[2]
			pix(x, y, get_tex_pixel(0x8000, tex_id, tex_x, tex_y))
			tex_pos = tex_pos + step
		end
	end

	if FPS_COUNTER then
		print(math.floor(1000 / delta), 0, 0)
	end
end

-- <TILES>
-- 001:a33333333a33344333a33343333a33333333a33334333a33344333a33333333a
-- 002:1111111612211161121116111111611111161111116111211611122161111111
-- 017:aaaaaaa6abbaaa6aabaaa6aaaaaa6aaaaaa6aaaaaa6aaabaa6aaabba6aaaaaaa
-- 018:a77777777a77766777a77767777a77777777a77776777a77766777a77777777a
-- </TILES>

-- <SPRITES>
-- </SPRITES>

-- <MAP>
-- 000:101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 001:100000000000000000000000000000001010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 002:100000000000000000000000000000001000000000001010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 003:100000000000000000000000000000001010001010001010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 004:100000000000000000000000000000001000000010001010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 005:100000000000000000000000000000001000000010001010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 006:100000001010101010000000000000001000100010001010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 007:100000001000000010000000000000001000000010001010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 008:100000001000000010000000000000001010101010001010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 009:100000001000000010000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 010:100000001010101010000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 011:100000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 012:100000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 013:100000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 014:100000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 015:100000001000100010000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 016:100000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 017:100000001000100010000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 018:100000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 019:100000001000100010000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 020:100000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 021:100000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 022:100000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- 023:101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- </MAP>

-- <WAVES>
-- </WAVES>

-- <SFX>
-- </SFX>

-- <PALETTE>
-- 000:1a1c2c5d275db13e53ef7d57ffcd75a7f07038b76425717929366f3b5dc941a6f673eff7f4f4f494b0c2566c86333c57
-- </PALETTE>

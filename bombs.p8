pico-8 cartridge // http://www.pico-8.com
version 29
__lua__

function _init()
 mouse.init()
 bombs:init()
 t = 0
 _upd = run_upd
 _drw = run_drw
 score = 0
 _cpu = stat(1)
end

function run_upd()
 t += 1
 bombs:update()
 mouse.update()
end

-- a function to change to the game over state
function gameover()
 _upd = over_upd
 _drw = over_drw
end

function over_upd()
 if btn(2) then
  _init()
 end
end

function over_drw()
 cls()
 print("---game over---", 64-8*4, 64-8, 8)
 print("score: " ..score, 64-7*4, 64, 10)
 print("press ⬇️ to play again", 64-11*4, 64+10, 7)
end

function _update60()
 _upd()
end

function run_drw()
 cls()
 map(0,0,0,0, 16, 16)
 bombs:draw()
 print(score, 1, 1, 10)
 _cpu = stat(1) * 0.03 + _cpu * 0.97
 print(stat(1), 100, 1, 9)
 mouse.draw(mouse)
end

function _draw()
 _drw()
end
-->8
-- mouse --
local _hover_spr = 35
local _grab_spr = 37
local _default_spr = 33
local _spr = _default_spr
local _last = 0

mouse = {
	init = function()
		poke(0x5f2d, 1) --activate devkit
	 _last = stat(34)
	end,
	state = function()
		return stat(32),stat(33),stat(34)
	end,
	update = function()
	 local x = stat(32)
	 local y = stat(33)
	 local mb = stat(34)
	 if bombs:isbomb(x, y) then
	  if mb == 1 then
	   _spr = _grab_spr
	  else
	  	_spr = _hover_spr
	  end
	 else
	  _spr = _default_spr
	 end
	 
	 if last == 0 and mb == 1 then
	  bombs:startdrag(x, y)
	 end
	 if last == 1 and stat(34) == 0 then
	  bombs:stopdrag()
	 end
	 last = stat(34)
	end,
	draw = function()
		spr(_spr,stat(32)-8,stat(33),2,2)
	end
}
-->8
-- bombs --
bombs = {list={}}
_tile_rel = {
 [0] = {
  kill = 5,
  goal = 1,
 },
 [1] = {
  kill = 1,
  goal = 5,
 },
}

function bombs:init()
 bombs.list = {}
end

function bombs:update()
 -- spawn a new one
 if t%90 == 0 then
  add(self.list, bomb:new(64-4, 10))
 end
 
 -- move all bombs
 for b in all(self.list) do
  b:update()
 end
end

function bombs:draw()
 --draw in reverse order so that
 --older bombs get drawn on top 
 --as they wil explode sooner 
 for i = #self.list,1, -1 do
  b = self.list[i]
  b:draw()
 end
end

function bombs:isbomb(x, y)
  for b in all(self.list) do
   if b._upd != b.walk and collide(x,y,b.x,b.y) then
    return true
   end
  end
  return false
end

function bombs:startdrag(x, y)
  for b in all(self.list) do
   if b._upd == b.explosive and collide(x,y,b.x,b.y) then
    b._upd=(b.drag)
    b.mox = x-b.x
    b.moy = y-b.y
    return
   end
  end
end

function bombs:stopdrag(x, y)
 for b in all(self.list) do
   if b._upd == b.drag then
    -- bomb got droped
    local kill_flag = _tile_rel[b.col].kill
    local goal_flag = _tile_rel[b.col].goal
    
    if overlap_a(b.x,b.y,kill_flag) then
     gameover()
     return
    end
    
    if overlap_a(b.x,b.y,goal_flag) then
     score+=1
     sfx(1)
     b._upd=(b.walk)
    else
     b._upd=(b.explosive)
    end
    
   end
  end
end
-->8
-- bomb --
bomb = {
 x=0, 
 y=0, 
 vx=0,
 vy=0,
 mox=0,
 moy=0,
 col=0
}

function bomb:_calc_speed()
 phi = rnd(2 * 3.1415)
 speed = 0.1
 self.vx = speed * cos(phi)
 self.vy = speed * sin(phi)
end

function bomb:new(x,y)
 o = {}
 o.x = x
 o.y = y
 self.__index = self
 setmetatable(o, self)
 o:_calc_speed()
 o._upd=(o.explosive)
 o.col=flr(rnd(2))
 return o
end

function bomb:on_wall()
 return overlap_a(self.x, self.y, 0)
end

function bomb:avoid_wall()
 local vec_x = 0
 local vec_y = 0
 if overlap(self.x, self.y,0) then
  vec_x += 1
  vec_y += 1
 end
 if overlap(self.x+8, self.y,0) then
  vec_x += -1
  vec_y += 1
 end
 if overlap(self.x, self.y+8,0) then
  vec_x += 1
  vec_y += -1
 end
 if overlap(self.x+8, self.y+8,0) then
  vec_x += -1
  vec_y += -1
 end
  
 vec_x = mid(-1, vec_x, 1)
 vec_y = mid(-1, vec_y, 1)
 if vec_x != 0 then
  self.vx = abs(self.vx) * vec_x
 end
 if vec_y != 0 then
  self.vy = abs(self.vy) * vec_y
 end
end

function bomb:walk()
 if overlap_p(self.x+self.vx, self.y+self.vy, 0) then
  self:avoid_wall()
 else
	 if overlap_p(self.x+self.vx,self.y+self.vy, 0) then
		 if overlap_a(self.x + self.vx, self.y, 0) then
		  self.vx *= -1
		 end
		 if overlap_a(self.x, self.y + self.vy, 0) then
		  self.vy *= -1
		 end
	 end
 end
 
 if self.x <= 0 or self.x >= 120 then
  self.vx *= -1
 end
 

 self.x += self.vx
 self.y += self.vy
end

function bomb:explosive()
 if self:on_wall() then
  self:avoid_wall()
 else
	 if overlap_a(self.x + self.vx, self.y, 0) then
	  self.vx *= -1
	 end
	 if overlap_a(self.x, self.y + self.vy, 0) then
	  self.vy *= -1
	 end
 end
 
 if self.x <= 0 or self.x >= 120 then
  self.vx *= -1
 end
 if self.y > 120 then
  self.vy *= -1
 end

 self.x += self.vx
 self.y += self.vy
end

function bomb:drag()
 mx,my,mb = mouse.state()
 self.x = mid(mx - self.mox, 0, 120)
 self.y = mid(my - self.moy, 8, 120)
end

function bomb:update()
 self._upd(self)
end

function bomb:draw()
 --print(mget(self.x/8, self.y/8) , self.x, self.y-8, 2)
 --print(self:on_wall(), self.x, self.y-8, 11)
 --print(self._upd == self.walk, self.x, self.y-16, 11)
 spr((t/15 % 2) + 2 + (16 * self.col), self.x,self.y, 1, 1, self.vx > 0)
end
-->8
-- documentation--
--[[
in the sprites the colors mean:
red: a kind of wall
orange: where the pink bombs go
purple: where the black bombs go

--]]
-->8
-- utils --
function overlap(x,y,flag)
 val=mget(x/8, y/8)
 return fget(val, flag)
end

function overlap_a(x,y,flag)
 return 
  overlap(x,y,flag) or
  overlap(x+8,y,flag) or
  overlap(x,y+8,flag) or
  overlap(x+8,y+8,flag)
end

function overlap_p(x,y,flag)
 return 
  overlap(x+4,y+4,flag)
end

function collide(mx,my,bx,by)
 return 
  mx >= bx and
  mx <= bx + 8 and
  my >= by and
  my <= by + 8
end

function sign(n)
 if n < 0.1 then
  return -1
 end
 return 1
end
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000005555000055550000555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007000eeeeee00eeeeee00eeeeee0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770000e7e7ee00e7e7ee00e7e7ee0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770000e7e7ee00e7e7ee00e7e7ee0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
007007000eeeeee00eeeeee00eeeeee0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000eeee000ffeee0000eeeff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000ff00ff000000ff00ff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000005555000055550000555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000011111100111111001111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000017171100171711001717110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000017171100171711001717110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000011111100111111001111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000001111000ff1110000111ff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000ff00ff000000ff00ff00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000100000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000001710000000000000171000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000001771000000000000171101000000000001010100000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000001777100000000000171717100000000017171710000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000001777710000000001177777100000000117777710000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000001771100000000017177777100000001717777710000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000117100000000001777777100000000177777710000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000001000000000000117771000000000011777100000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000017771000000000001777100000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000001110000000000000111000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88888888a00aa00a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a00aa00a
8888888800aa00aa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000aa00aa
888888880aa00aa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000aa00aa0
88888888aa00aa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000aa00aa00
a00aa00a88888888000000000000000000000000000000000000000000006666666600000000000000000000000000000000000000000000a00aa00a00000000
00aa00aa8888888800000000000000000000000000000000000000000000555555550000000000000000000000000000000000000000000000aa00aa00000000
0aa00aa0888888880000000000000000000000000000000000000000000077777777000000000000000000000000000000000000000000000aa00aa000000000
aa00aa0088888888000000000000000000000000000000000000000000005555555500000000000000000000000000000000000000000000aa00aa0000000000
66666666a00aa00aa00aa00aa00a8888000000000000000000000000666677777777666600000000000000000000000000000000a00aa00aa00aa00aa00a0000
6666666600aa00aa00aa00aa00aa888800000000000000000000000066665555555566660000000000000000000000000000000000aa00aa00aa00aa00aa0000
666666660aa00aa00aa00aa00aa088880000000000000000000000006666777777776666000000000000000000000000000000000aa00aa00aa00aa00aa00000
66666666aa00aa00aa00aa00aa008888000000000000000000000000666666666666666600000000000000000000000000000000aa00aa00aa00aa00aa000000
66666666a00a88888888a00aa00a8888000000000000000000000000666666666666666600000000000000000000000000000000a00a00000000a00aa00a0000
6666666600aa8888888800aa00aa888800000000000000000000000066666666666666660000000000000000000000000000000000aa0000000000aa00aa0000
666666660aa0888888880aa00aa088880000000000000000000000006666666666666666000000000000000000000000000000000aa0000000000aa00aa00000
66666666aa0088888888aa00aa008888000000000000000000000000666666666666666600000000000000000000000000000000aa0000000000aa00aa000000
a00aa00aa00a88888888a00a8888a00a000000000000000000000000666666666666666600000000000000000000000000000000a00a00000000a00a0000a00a
00aa00aa00aa8888888800aa888800aa00000000000000000000000066666666666666660000000000000000000000000000000000aa0000000000aa000000aa
0aa00aa00aa0888888880aa088880aa00000000000000000000000006666666666666666000000000000000000000000000000000aa0000000000aa000000aa0
aa00aa00aa0088888888aa008888aa00000000000000000000000000666666666666666600000000000000000000000000000000aa0000000000aa000000aa00
a00aa00aa00aa00aa00aa00a8888a00a000000000000000000000000666655555555666600000000000000000000000000000000a00aa00aa00aa00a0000a00a
00aa00aa00aa00aa00aa00aa888800aa00000000000000000000000066667777777766660000000000000000000000000000000000aa00aa00aa00aa000000aa
0aa00aa00aa00aa00aa00aa088880aa00000000000000000000000006666555555556666000000000000000000000000000000000aa00aa00aa00aa000000aa0
aa00aa00aa00aa00aa00aa008888aa00000000000000000000000000666677777777666600000000000000000000000000000000aa00aa00aa00aa000000aa00
00000000111111118888888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000111111118888888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000111111118888888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000111111118888888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000111111118888888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000111111118888888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000111111118888888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000111111118888888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001010000000000010100000000000101000101010000000000000000000101010101010100000001010000000001010120010200000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
7171717171717147487171717171717100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5050505050505057585050505050505000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5050505050505050505050505050505000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5050505050505050505050505050505000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5050505050505050505050505050505000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4141415250505050505050505d4f4f4f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7272726350505050505050505f70707000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7272726350505050505050505f70707000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7272726350505050505050505f70707000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7272726350505050505050505f70707000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7272726350505050505050505f70707000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040406250505050505050506d4e4e4e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5050505050505050505050505050505000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5050505050505050505050505050505000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5050505050505050505050505050505000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5050505050505067685050505050505000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
001000000c043101000c0000c0000c0430c00000000000000c043000000c0000c0000c0430c00000000000000c043000000c0000c0000c0430c00000000000000c043000000c0000c0000c0430c0000000000000
000300002b7503475034740347303472034710347103220032000010000200002000010000100000000000000f500105001250000000000000000000000000000000000000000000000000000000000000000000

-- disquiet0410: op audio (organ version)

engine.name = 'ShepardOrgan'

local tlps = include 'otis/lib/tlps'

local root = 33
local tones = {}
local N_TONES = 5
--local tone_volts = {}
local notes = { 1, 3, 2, 4, 3, 5, 4, 6, 5, 7, 6, 8, 7, 9 }
local N_NOTES = #notes
local tran = { 0, 3, 6, 9, 12, 15, 18, 21, 24, 27 }
local N_TRAN = #tran

local vrate = { 0.3, 0.17, 0.125, 0.26 }
local vtune = { -6, -3, -6, -3 }
local vpan = { -0.8, 0.2, 0.2, 0.8 }
local vnote = { 0, 2, 4, 8 }
local vtran = { 1, 1, 1, 1 }
--local vrep = { 0, 0, 0, 0 }
local vstate = { false, false, false, false }

local r
local m
local rate = 0.16 -- 2.2 --0.12

local oct1 = 0
local oct2 = 0

local g = grid.connect()
local pattern = {
  1, 1, 1, 1, 1, 1,
  1, 1, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0
}
local N_STEPS = #pattern
local shift = { 0, 4, 7, 11 }

local jump_probability = 0

function init()
  print('init')

  for t=1,N_TONES do
    table.insert(tones, math.pow(2, (t - 1) / N_TONES))
  end
  tab.print(tones)

  --local log2 = math.log(2)
  --for i=1,N_TONES do
    --tone_volts[i] = math.log(tones[i]) / log2
  --end

  --crow.output[1].action = 'pulse(0.1, 5)'
  --crow.output[2].action = 'pulse(0.1, 5)'
  --crow.output[3].action = 'pulse(0.1, 5)'
  --crow.output[4].action = 'pulse(0.1, 5)'

  for v=1,4 do
    engine.glide(v, 0.0)
    engine.mod_rate(v, vrate[v] * 6)
    engine.mod_index(v, 0.003)
    engine.octave_detune(v, vtune[v])
    engine.double_detune(v, vtune[v])
    engine.release(v, 0.02)
    engine.pan(v, vpan[v])
  end

  --TODO: parameterize:
  --[ \hz, \glide, \mod_rate, \mod_index, \gate, \attack, \release, \detune, \pan ].each({

  tlps.init()
  params:set("engine_level", 0.11)
  params:set("1speed_slew", 0.03)
  params:set("1loop_start", 1)
  params:set("1loop_end", 1 + (3.5 * rate))
  params:set("1pan", 1)
  params:set("1feedback", 0)
  params:set("1low_pass", 0.7)
  params:set("1filter_cutoff", 8419)
  params:set("1filter_q", 1.2)
  params:set("1dry_signal", 0.0)
  params:set("2speed_slew", 0.03)
  params:set("2loop_start", 1)
  params:set("2loop_end", 1 + (3.5 * rate))
  params:set("2pan", -1)
  params:set("2feedback", 0)
  params:set("2low_pass", 0.7)
  params:set("2dry_signal", 0.0)
  params:set("2filter_cutoff", 8419)
  params:set("2filter_q", 1.2)
  params:bang()
  softcut.buffer_clear()
  --softcut.level_slew_time(1, 2)
  --softcut.level_slew_time(1, 2)
  softcut.level_cut_cut(1, 2, util.dbamp(-3))
  softcut.level_cut_cut(2, 1, util.dbamp(-3))

  m = metro.init()
  m.count = 0
  m.time = rate
  m.event = tick

  m:start()
  
  r = metro.init()
  r.time = 1 / 15
  r.event = function()
    redraw()
  end
  r:start()

  gridredraw()
end

function index(i)
  return (i % N_STEPS) + 1
end

function get_step(i)
  return pattern[index(i)] > 0
end

function set_step(i, v)
  pattern[index(i)] = v
  gridredraw()
end

function set_shift(v, s)
  shift[v] = s % N_STEPS
  gridredraw()
end

function tick(stage)
  -- print(stage)

  --if stage % 2 > 0 then
    -- TODO: this gets weird when UI isn't focused
    -- screen.clear()
    -- screen.update()
    --return
  --end
  
  if stage % N_STEPS == 1 then
    if math.random(100) < jump_probability then
      oct1 = oct1 + math.random(-1, 1)
      if oct1 < -2 then
        oct1 = -2
      elseif oct1 > 2 then
        oct1 = 2
      end
      params:set("1speed", math.pow(2, oct1))
    end
    if math.random(100) < jump_probability then
      oct2 = oct2 + math.random(-1, 1)
      if oct2 < -2 then
        oct2 = -2
      elseif oct2 > 2 then
        oct2 = 2
      end
      params:set("2speed", math.pow(2, oct2))
    end
  end

  local i = stage --/ 2

  for v=1,4 do
    local old_state = vstate[v]
    vstate[v] = get_step(i - 1 - shift[v])
    if vstate[v] and not old_state then
      vnote[v] = (vnote[v] % N_NOTES) + 1
      if vnote[v] == 1 then
        --vrep[v] = (vrep[v] % 3) + 1
        --if vrep[v] == 1 then
          vtran[v] = (vtran[v] % N_TRAN) + 1
          --print('tran ' .. vtran[v])
        --end
      end
      local tone = ((notes[vnote[v]] + tran[vtran[v]] - 1) % N_TONES) + 1
      local octave = math.floor(notes[vnote[v]] / N_TONES)
      local hz = root * tones[tone] * math.pow(2, octave);
      engine.hz(v, hz)
      engine.gate(v, 1)
      --crow.output[v]()
    elseif not vstate[v] then
      engine.gate(v, 0)
    end
  end

  --m.time = rate
end

function key(n, z)
  if z == 1 then
    if n == 1 then
      softcut.level_cut_cut(1, 2, util.dbamp(-14))
      softcut.level_cut_cut(2, 1, util.dbamp(-14))
    elseif n == 2 then
      jump_probability = jump_probability - 5
      if jump_probability < 0 then
        jump_probability = 0
      end
    elseif n == 3 then
      jump_probability = jump_probability + 5
      if jump_probability > 100 then
        jump_probability = 100
      end
    end
  else
    if n == 1 then
      softcut.level_cut_cut(1, 2, util.dbamp(-3))
      softcut.level_cut_cut(2, 1, util.dbamp(-3))
    end
  end
end

function enc(n, d)
  if n == 1 then
    params:delta("1low_pass", d / 2)
    params:delta("2low_pass", d / 2)
  elseif n == 2 then
    params:delta("1filter_cutoff", d)
    params:delta("2filter_cutoff", d)
  elseif n == 3 then
    params:delta("1filter_q", d / -2)
    params:delta("2filter_q", d / -2)
  end
end

function gridredraw()

  g:all(0)
  g:refresh()

  for y=1,4 do
    for x=1,6 do
      local i = x + (6 * (y - 1)) - 1
      if get_step(i) then
        g:led(x, y, 8)
      end
    end
  end
  
  for v=1,4 do
    local shift = shift[v] + 1
    local x = (shift - 1) % 6 + 1
    local y = math.ceil(shift / 6) + 4
    print('shift ' .. v .. ': ' .. shift .. ', x: ' .. x .. ', y: ' .. y)
    g:led(x, y, 8)
  end
  --for y=1,2 do
    --for x=1,7 do
      --local i = x + (7 * (y - 1)) - 1
      --for v=1,4 do
        --if get_step(i - shift[v]) then
          --g:led(x, y + (v - 1) * 2, 8)
        --end
      --end
    --end
  --end
  g:refresh()
end

function g.key(x, y, z)
  if z == 1 then
    if x <= 6 and y <= 4 then
      local i = x - 1 + (y - 1) * 6
      if get_step(i) then
        set_step(i, 0)
      else
        set_step(i, 1)
      end
    elseif y > 4 then
      local v = y - 4
      if x == 7 then
        set_shift(v, shift[v] - 1)
      elseif x == 8 then
        set_shift(v, shift[v] + 1)
      end
    end
  end
end

function redraw()
  screen.clear()
  for v=1,4 do
    if vstate[v] then
      screen.rect(3 + (v - 1) * 32, 3, 29, 60)
      screen.level(15)
      screen.stroke()
      --screen.level(vtone[v] + 7)
      --screen.fill()
    end
  end
  screen.font_face(1)
  screen.font_size(8)
  screen.move(6, 11)
  screen.text(params:get("1low_pass"))
  screen.move(49, 34)
  screen.text_center(jump_probability .. '%')
  screen.move(92, 58)
  screen.text_right(params:get("1filter_cutoff"))
  screen.move(124, 58)
  screen.text_right(string.sub(params:get("1filter_q"), 1, 4))
  screen.update()
end

function cleanup()
  if m ~= nil then
    m:stop()
  end
end
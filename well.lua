-- Well (v1.0.7)
-- A deep audio well with 
-- circular ripples
-- @your_name
--
-- E1: Change scale
-- E2: Direction (Up/Down)
-- E3: Speed/Hold time
-- K2: Toggle mode
-- K3: Toggle sound source
-- Grid: Play + hold notes
--
-- Hold grid keys to repeat
-- Higher notes toward top

-- User adjustable parameters
local CIRCLES = 6         -- number of circles to display
local BASE_NOTE = 60      -- MIDI note number (60 = middle C)
local RIPPLE_SPEED = 0.5  -- how fast ripples spread
local RIPPLE_LIFE = 8     -- how long ripples last
local GRID_BRIGHTNESS = 15 -- maximum grid LED brightness (2-15)

engine.name = 'PolyPerc'

-- requirements
musicutil = require 'musicutil'

-- declare variables at file level
local g = grid.connect()
local grid_dirty = false
local grid_ripples = {}
local held_notes = {}
local screen_dirty = true
local show_instructions = true
local mode = 1
local screen_center_x = 64
local screen_center_y = 32
local circle_spacing = 8
local num_circles = CIRCLES
local hold_metro
local screen_metro
local grid_metro
local echo_metro
local current_echo = 1
local current_note = nil

-- grid key function
function grid.key(x, y, z)
  local pos = x .. "," .. y
  
  if z == 1 then -- key pressed
    -- create new ripple effect
    local ripple = {
      x = x,
      y = y,
      radius = 1,
      life = RIPPLE_LIFE
    }
    table.insert(grid_ripples, ripple)
    
    -- store held note
    held_notes[pos] = {x = x, y = y}
    
    -- play the note and start echo sequence
    play_note(x, y)
    
    -- start hold metro if this is the first held note
    if tab.count(held_notes) == 1 and hold_metro then
      hold_metro:start()
    end
    
  else -- key released
    -- remove held note
    held_notes[pos] = nil
    
    -- stop metro if no more held notes
    if tab.count(held_notes) == 0 and hold_metro then
      hold_metro:stop()
    end
  end
  grid_dirty = true
end

-- note playing function
function play_note(x, y)
  local note_offset = ((8-y) * 4) + (x-8)
  local note = params:get("base_note") + note_offset
  
  -- Reset echo state
  current_echo = 1
  current_note = note
  
  -- Initial note
  if params:get("sound_source") == 1 then -- PolyPerc
    engine.hz(musicutil.note_num_to_freq(note))
  end
  
  -- Start echo sequence
  echo_metro.time = params:get("echo_spacing")
  echo_metro:start()
end

-- create echo function
function create_echo()
  if current_echo <= 6 then
    local level = params:get("decay_factor") ^ (current_echo - 1)
    local pitch = current_note
    
    if params:get("direction") == 1 then -- Down
      pitch = current_note - (current_echo - 1) * get_scale_interval()
    else -- Up
      pitch = current_note + (current_echo - 1) * get_scale_interval()
    end
    
    if params:get("sound_source") == 1 then -- PolyPerc
      engine.hz(musicutil.note_num_to_freq(pitch))
    else -- Sample
      softcut.level(current_echo, level)
      softcut.rate(current_echo, musicutil.note_num_to_freq(pitch) / 440)
    end
    
    current_echo = current_echo + 1
    screen_dirty = true
  else
    echo_metro:stop()
  end
end

-- function to play held notes
function play_held_notes()
  for pos, note in pairs(held_notes) do
    play_note(note.x, note.y)
  end
end

-- initialization
function init()
  -- script state params
  params:add_group("WELL", 13)
  
  -- musical parameters
  params:add_option("scale", "Scale", {"Major", "Minor", "Pentatonic", "Chromatic"}, 1)
  params:add_option("direction", "Direction", {"Down", "Up"}, 1)
  params:add_option("sound_source", "Sound Source", {"PolyPerc", "Sample"}, 1)
  params:add_number("base_note", "Base Note", 0, 127, BASE_NOTE)
  
  -- effect parameters
  params:add_control("echo_spacing", "Echo Speed", controlspec.new(0.05, 1.0, 'lin', 0.01, 0.2, "s"))
  params:add_control("hold_interval", "Hold Time", controlspec.new(0.1, 2.0, 'lin', 0.01, 0.25, "s"))
  params:add_control("decay_factor", "Decay", controlspec.new(0.1, 0.99, 'lin', 0.01, 0.8))
  
  -- PolyPerc parameters
  params:add_control("cutoff", "Cutoff", controlspec.new(50, 5000, 'exp', 0, 1000, "Hz"))
  params:add_control("release", "Release", controlspec.new(0.1, 3.0, 'lin', 0, 0.5, "s"))
  
  -- initialize PolyPerc
  engine.release(0.5)
  engine.cutoff(1000)
  
  -- initialize softcut voices for sample playback
  softcut.reset()
  
  for i=1,6 do
    softcut.enable(i, 1)
    softcut.buffer(i, 1)
    softcut.level(i, 1.0)
    softcut.position(i, 1)
    softcut.loop(i, 1)
    softcut.loop_start(i, 1)
    softcut.loop_end(i, 5)
    softcut.play(i, 1)
    softcut.rate(i, 1.0)
    if i == 1 then
      softcut.rec(i, 1)
      softcut.level_input_cut(1, i, 1.0)
      softcut.level_input_cut(2, i, 1.0)
    end
  end
  
  -- initialize metros
  echo_metro = metro.init()
  echo_metro.event = create_echo
  echo_metro.time = params:get("echo_spacing")
  
  hold_metro = metro.init()
  hold_metro.event = play_held_notes
  hold_metro.time = params:get("hold_interval")
  
  screen_metro = metro.init()
  screen_metro.event = function()
    screen_dirty = true
    redraw()
  end
  screen_metro.time = 1/30
  screen_metro:start()
  
  grid_metro = metro.init()
  grid_metro.event = function()
    grid_dirty = true
    grid_redraw()
  end
  grid_metro.time = 1/30
  grid_metro:start()
  
  -- load default sample
  softcut.buffer_clear()
  softcut.buffer_read_mono(_path.audio.."common/cricket.wav", 0, 1, -1, 1, 1)
  
  -- initialize params
  params:bang()
end

-- cleanup on script close
function cleanup()
  if hold_metro then hold_metro:stop() end
  if screen_metro then screen_metro:stop() end
  if grid_metro then grid_metro:stop() end
  if echo_metro then echo_metro:stop() end
  softcut.reset()
end

-- screen redraw function
function redraw()
  screen.clear()
  
  if show_instructions then
    -- draw welcome screen
    screen.level(15)
    screen.move(64,15)
    screen.text_center("W E L L")
    
    screen.move(5,25)
    screen.text("K2: Toggle mode")
    screen.move(5,33)
    screen.text("K3: Toggle sound (Sample/PolyPerc)")
    
    screen.move(5,45)
    screen.text("E1: Change scale")
    screen.move(5,53)
    screen.text("E2: Direction (Up/Down)")
    screen.move(5,61)
    screen.text("E3: Speed/Hold time (by mode)")
    
    screen.move(64,40)
    screen.text_center("press K1 to continue")
  else
    -- main interface
    -- draw concentric circles
    for i=1,num_circles do
      local radius = i * circle_spacing
      local brightness = math.floor(15 / i)
      screen.level(brightness)
      screen.circle(screen_center_x, screen_center_y, radius)
      screen.stroke()
    end
    
    -- highlight active echo
    if current_echo and current_echo <= num_circles then
      screen.level(15)
      screen.circle(screen_center_x, screen_center_y, current_echo * circle_spacing)
      screen.stroke()
    end
    
    -- draw parameter info
    screen.level(15)
    screen.move(2, 60)
    screen.text(params:string("scale"))
    
    screen.move(2, 50)
    screen.text(params:string("direction"))
    
    -- show current mode and relevant parameter
    if mode == 1 then
      screen.move(70, 60)
      screen.text(string.format("spd:%.1f", params:get("echo_spacing")))
    else
      screen.move(70, 60)
      screen.text(string.format("hld:%.1f", params:get("hold_interval")))
    end
    
    -- show sound source
    screen.move(2, 40)
    screen.text(params:get("sound_source") == 1 and "PolyPerc" or "Sample")
  end
  
  screen.update()
end

-- grid redraw function
function grid_redraw()
  g:all(0)
  
  -- draw held notes
  for pos, note in pairs(held_notes) do
    g:led(note.x, note.y, GRID_BRIGHTNESS)
  end
  
  -- update and draw ripples
  for i=#grid_ripples,1,-1 do
    local r = grid_ripples[i]
    r.radius = r.radius + RIPPLE_SPEED
    r.life = r.life - 1
    
    -- draw ripple
    for x=1,16 do
      for y=1,8 do
        local dx = x - r.x
        local dy = y - r.y
        local distance = math.sqrt(dx*dx + dy*dy)
        if math.abs(distance - r.radius) < 1 then
          g:led(x, y, math.floor(r.life * 2))
        end
      end
    end
    
    -- remove dead ripples
    if r.life <= 0 then
      table.remove(grid_ripples, i)
    end
  end
  
  g:refresh()
end

-- helper functions
function get_scale_interval()
  local intervals = {
    {2,2,1,2,2,2,1}, -- major
    {2,1,2,2,1,2,2}, -- minor
    {2,2,3,2,3},     -- pentatonic
    {1,1,1,1,1,1,1,1,1,1,1,1} -- chromatic
  }
  local scale_index = params:get("scale")
  return intervals[scale_index][1]
end

-- encoder handlers
function enc(n,d)
  if n == 1 then
    params:delta("scale", d)
  elseif n == 2 then
    params:delta("direction", d)
  elseif n == 3 then
    if mode == 1 then
      params:delta("echo_spacing", d)
    else
      params:delta("hold_interval", d)
      if hold_metro then
        hold_metro.time = params:get("hold_interval")
      end
    end
  end
  screen_dirty = true
end

-- key handlers
function key(n,z)
  if n == 1 and z == 1 and show_instructions then
    show_instructions = false
    screen_dirty = true
    return
  end
  
  if z == 1 then
    if n == 2 then
      mode = mode == 1 and 2 or 1
    elseif n == 3 then
      params:delta("sound_source", 1)
    end
    screen_dirty = true
  end
end

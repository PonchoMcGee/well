-- Well
-- A deep audio well 
-- with circular ripples
-- v1.0.3 @PonchoMcGee

engine.name = 'PolyPerc'

-- requirements
musicutil = require 'musicutil'

-- initialization
function init()
  -- initialize script state
  params:add_group("WELL", 13)
  
  params:add_option("scale", "Scale", {"Major", "Minor", "Pentatonic", "Chromatic"}, 1)
  params:add_option("direction", "Direction", {"Down", "Up"}, 1)
  params:add_control("echo_spacing", "Echo Speed", controlspec.new(0.05, 1.0, 'lin', 0.01, 0.2, "s"))
  params:add_control("hold_interval", "Hold Time", controlspec.new(0.1, 2.0, 'lin', 0.01, 0.25, "s"))
  params:add_control("decay_factor", "Decay", controlspec.new(0.1, 0.99, 'lin', 0.01, 0.8))
  params:add_option("sound_source", "Sound Source", {"PolyPerc", "Sample"}, 1)
  params:add_number("base_note", "Base Note", 0, 127, 60)
  
  params:add_control("cutoff", "Cutoff", controlspec.new(50, 5000, 'exp', 0, 1000, "Hz"))
  params:add_control("release", "Release", controlspec.new(0.1, 3.0, 'lin', 0, 0.5, "s"))
  
  params:bang()
  
  -- visual state
  screen_dirty = true
  show_instructions = true
  mode = 1 -- 1 for main, 2 for secondary parameters
  
  -- held notes state
  held_notes = {}
  
  -- visual parameters
  screen_center_x = 64
  screen_center_y = 32
  circle_spacing = 8
  num_circles = 6
  
  -- initialize grid
  g = grid.connect()
  grid_dirty = true
  grid_ripples = {}
  
  -- initialize softcut for sample playback
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
  
  -- initialize PolyPerc parameters
  engine.release(params:get("release"))
  engine.cutoff(params:get("cutoff"))
  
  -- initialize metro for held notes
  hold_metro = metro.init()
  hold_metro.event = play_held_notes
  hold_metro.time = params:get("hold_interval")
  
  -- metro for screen redraw
  screen_metro = metro.init()
  screen_metro.event = function()
    if screen_dirty then
      redraw()
      screen_dirty = false
    end
  end
  screen_metro.time = 1/15
  screen_metro:start()
  
  -- metro for grid redraw
  grid_metro = metro.init()
  grid_metro.event = function()
    if grid_dirty then
      grid_redraw()
      grid_dirty = false
    end
  end
  grid_metro.time = 1/30
  grid_metro:start()
  
  -- load default sample
  softcut.buffer_clear()
  softcut.buffer_read_mono(_path.audio.."common/cricket.wav", 0, 1, -1, 1, 1)
end

-- cleanup on script close
function cleanup()
  hold_metro:stop()
  screen_metro:stop()
  grid_metro:stop()
  
  -- clear softcut
  softcut.reset()
end

-- function to play held notes
function play_held_notes()
  for pos, note in pairs(held_notes) do
    play_note(note.x, note.y)
  end
end

-- function to play a note
function play_note(x, y)
  local note_offset = ((8-y) * 4) + (x-8)
  local note = params:get("base_note") + note_offset
  
  if params:get("sound_source") == 2 then -- Sample
    local direction = params:get("direction")
    for i=1,6 do
      local delay = (i-1) * params:get("echo_spacing")
      local level = params:get("decay_factor") ^ (i-1)
      local pitch = note
      if direction == 1 then -- Down
        pitch = note - (i-1) * get_scale_interval()
      else -- Up
        pitch = note + (i-1) * get_scale_interval()
      end
      
      softcut.level(i, level)
      softcut.rate(i, musicutil.note_num_to_freq(pitch) / 440)
    end
  else -- PolyPerc
    engine.hz(musicutil.note_num_to_freq(note))
  end
end

-- screen redraw function
function redraw()
  screen.clear()
  
  if show_instructions then
    screen.level(15)
    screen.move(64,15)
    screen.text_center("W E L L")
    
    screen.move(5,25)
    screen.text("K2: Toggle mode")
    screen.move(5,33)
    screen.text("K3: Toggle sound source")
    
    screen.move(5,45)
    screen.text("E1: Change scale")
    screen.move(5,53)
    screen.text("E2: Direction (Up/Down)")
    screen.move(5,61)
    screen.text("E3: Speed/Hold time (by mode)")
    
    screen.move(64,40)
    screen.text_center("press K1 to continue")
  else
    -- draw concentric circles
    for i=1,num_circles do
      local radius = i * circle_spacing
      local brightness = math.floor(15 / i)
      screen.level(brightness)
      screen.circle(screen_center_x, screen_center_y, radius)
      screen.stroke()
    end
    
    -- draw parameter info
    screen.level(15)
    screen.move(0, 60)
    screen.text("Scale: " .. params:string("scale"))
    screen.move(0, 50)
    screen.text(params:string("direction"))
    
    -- show current mode and relevant parameter
    if mode == 1 then
      screen.move(80, 60)
      screen.text(string.format("Speed: %.2f", params:get("echo_spacing")))
    else
      screen.move(80, 60)
      screen.text(string.format("Hold: %.2f", params:get("hold_interval")))
    end
    
    -- show sound source
    screen.move(0, 40)
    screen.text(params:string("sound_source"))
  end
  
  screen.update()
end

-- grid key function
function g.key(x, y, z)
  local pos = x .. "," .. y
  
  if z == 1 then
    -- create new ripple
    local ripple = {
      x = x,
      y = y,
      radius = 1,
      life = 8
    }
    table.insert(grid_ripples, ripple)
    
    -- store held note
    held_notes[pos] = {x = x, y = y}
    
    -- play the note
    play_note(x, y)
    
    -- start metro if this is the first held note
    if tab.count(held_notes) == 1 then
      hold_metro:start()
    end
    
  else -- z == 0
    -- remove held note
    held_notes[pos] = nil
    
    -- stop metro if no more held notes
    if tab.count(held_notes) == 0 then
      hold_metro:stop()
    end
  end
  grid_dirty = true
end

-- grid redraw function
function grid_redraw()
  if g == nil then return end
  
  g:all(0)
  
  -- draw held notes
  for pos, note in pairs(held_notes) do
    g:led(note.x, note.y, 15)
  end
  
  -- update and draw ripples
  for i=#grid_ripples,1,-1 do
    local r = grid_ripples[i]
    r.radius = r.radius + 0.5
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
      hold_metro.time = params:get("hold_interval")
    end
  end
  screen_dirty = true
end

-- key handlers
function key(n,z)
  if show_instructions and n == 1 and z == 1 then
    show_instructions = false
    screen_dirty = true
    return
  end
  
  if n == 2 and z == 1 then
    mode = mode == 1 and 2 or 1
  elseif n == 3 and z == 1 then
    params:delta("sound_source", 1)
  end
  screen_dirty = true
end

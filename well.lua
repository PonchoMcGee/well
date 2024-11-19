-- Well
-- A deep audio well 
-- with circular ripples
-- v1.0.2 @PonchoMcGee
--
-- E1: Change scale
-- E2: Direction (Up/Down)
-- E3: Speed/Hold time
-- K2: Toggle mode
-- K3: Toggle sound source
-- Grid: Play + hold notes

engine.name = 'PolyPerc'

-- requirements
softcut = require 'softcut'
musicutil = require 'musicutil'

-- initialization
function init()
  -- script state
  well = {
    scale_names = {"Major", "Minor", "Pentatonic", "Chromatic"},
    current_scale = 1,
    direction = 1, -- 1 for descending, -1 for ascending
    base_note = 60,
    num_echoes = 6,
    echo_spacing = 0.2,  -- initial echo speed
    decay_factor = 0.8,
    mode = 1,  -- 1 for main, 2 for secondary parameters
    hold_interval = 0.25, -- interval for held notes (in seconds)
    use_sample = false, -- toggle between sample and PolyPerc
    show_instructions = true -- flag for welcome screen
  }
  
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
  
  -- initialize softcut
  softcut.reset()
  
  -- voice 1 for live input
  softcut.enable(1,1)
  softcut.buffer(1,1)
  softcut.level(1,1.0)
  softcut.position(1,1)
  softcut.loop(1,1)
  softcut.loop_start(1,1)
  softcut.loop_end(1,5)
  softcut.rec(1,1)
  softcut.play(1,1)
  softcut.rate(1,1.0)
  softcut.level_input_cut(1,1,1.0)
  softcut.level_input_cut(2,1,1.0)
  
  -- additional voices for echoes
  for i=2,well.num_echoes do
    softcut.enable(i,1)
    softcut.buffer(i,1)
    softcut.level(i,1.0)
    softcut.position(i,1)
    softcut.loop(i,1)
    softcut.loop_start(i,1)
    softcut.loop_end(i,5)
    softcut.play(i,1)
    softcut.rate(i,1.0)
  end
  
  -- initialize PolyPerc parameters
  engine.release(0.5)
  engine.cutoff(1000)
  
  -- initialize hold metro
  hold_metro = metro.init(play_held_notes, well.hold_interval, -1)
  
  -- start timers
  metro_grid_redraw = metro.init(grid_redraw, 1/30, -1)
  metro_grid_redraw:start()
  
  -- load default sample
  load_sample("audio/common/cricket.wav")
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
  local note = well.base_note + note_offset
  
  if well.use_sample then
    if well.direction == 1 then
      -- descending sequence
      for i=1,well.num_echoes do
        local delay = (i-1) * well.echo_spacing
        local level = well.decay_factor ^ (i-1)
        local pitch = note - (i-1) * get_scale_interval()
        
        softcut.level(i, level)
        softcut.rate(i, musicutil.note_num_to_freq(pitch) / 440)
      end
    else
      -- ascending sequence
      for i=1,well.num_echoes do
        local delay = (i-1) * well.echo_spacing
        local level = well.decay_factor ^ (i-1)
        local pitch = note + (i-1) * get_scale_interval()
        
        softcut.level(i, level)
        softcut.rate(i, musicutil.note_num_to_freq(pitch) / 440)
      end
    end
  else
    -- use PolyPerc engine
    engine.hz(musicutil.note_num_to_freq(note))
  end
end

-- screen redraw function
function redraw()
  screen.clear()
  
  if well.show_instructions then
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
    
    screen.level(15)
    screen.move(64,40)
    screen.text_center("press K1 to continue")
  else
    -- draw regular interface
    -- draw concentric circles
    for i=1,num_circles do
      local radius = i * circle_spacing
      local brightness = math.floor(15 / i)
      screen.level(brightness)
      screen.circle(screen_center_x, screen_center_y, radius)
      screen.stroke()
    end
    
    -- draw active ripples
    for i=1,well.num_echoes do
      if well.current_echo == i then
        screen.level(15)
        screen.circle(screen_center_x, screen_center_y, i * circle_spacing)
        screen.stroke()
      end
    end
    
    -- draw parameter info
    screen.level(15)
    screen.move(0, 60)
    screen.text("Scale: " .. well.scale_names[well.current_scale])
    screen.move(0, 50)
    screen.text(well.direction == 1 and "Down" or "Up")
    
    -- show current mode and relevant parameter
    if well.mode == 1 then
      screen.move(80, 60)
      screen.text(string.format("Speed: %.2f", well.echo_spacing))
    else
      screen.move(80, 60)
      screen.text(string.format("Hold: %.2f", well.hold_interval))
    end
    
    -- show sound source
    screen.move(0, 40)
    screen.text(well.use_sample and "Sample" or "PolyPerc")
  end
  
  screen.update()
end

-- grid event handling
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
end

-- grid redraw function
function grid_redraw()
  if grid_dirty then
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
end

-- helper functions
function get_scale_interval()
  local intervals = {
    {2,2,1,2,2,2,1}, -- major
    {2,1,2,2,1,2,2}, -- minor
    {2,2,3,2,3},     -- pentatonic
    {1,1,1,1,1,1,1,1,1,1,1,1} -- chromatic
  }
  return intervals[well.current_scale][1]
end

function load_sample(file)
  -- load sample into softcut buffer
  softcut.buffer_clear()
  softcut.buffer_read_mono(file, 0, 1, -1, 1, 1)
end

-- encoder handlers
function enc(n,d)
  if n == 1 then
    well.current_scale = util.clamp(well.current_scale + d, 1, #well.scale_names)
  elseif n == 2 then
    well.direction = d > 0 and 1 or -1
  elseif n == 3 then
    if well.mode == 1 then
      -- adjust echo speed
      well.echo_spacing = util.clamp(well.echo_spacing + d/100, 0.05, 1.0)
    else
      -- adjust hold interval
      well.hold_interval = util.clamp(well.hold_interval + d/100, 0.1, 2.0)
      hold_metro.time = well.hold_interval
    end
  end
  redraw()
end

-- key handlers
function key(n,z)
  if well.show_instructions and n == 1 and z == 1 then
    -- exit instructions
    well.show_instructions = false
    redraw()
    return
  end
  
  if n == 2 and z == 1 then
    -- toggle mode
    well.mode = well.mode == 1 and 2 or 1
  elseif n == 3 and z == 1 then
    -- toggle between sample and PolyPerc
    well.use_sample = not well.use_sample
  end
  redraw()
end

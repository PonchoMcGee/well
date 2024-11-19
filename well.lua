-- Well
-- A deep audio well 
-- with circular ripples
-- v1.0.0 @your_name
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

[Previous init() and other functions remain the same until redraw()]

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

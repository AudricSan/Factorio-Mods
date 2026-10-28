-- Portes de caténaire.
-- Le joueur pose un poteau (er-catenary-pole) à côté d'une voie droite. Le script détecte
-- le rail à sa gauche ou à sa droite, pose un poteau miroir (er-catenary-mirror) de l'autre
-- côté, trace la poutre au-dessus de la voie et les fils au centre de la voie. Seul ce rail
-- est alimenté : la porte ne dépasse pas la voie qu'elle enjambe.
local catenary = {}

local POLE_NAME = "er-catenary-pole"
local MIRROR_NAME = "er-catenary-mirror"

local RAIL_SEARCH_RADIUS = 5
local MIN_SIDE_DISTANCE = 1.2     -- distance minimale entre l'axe de la voie et le poteau
local MAX_SIDE_DISTANCE = 4.5
local POWER_REACH = 4             -- distance le long de la voie alimentée de part et d'autre
local POWER_SEARCH_RADIUS = 7
local WIRE_LINK_MAX = 16          -- distance maximale entre deux portes reliées par un fil
local REFRESH_RADIUS = 24

local BEAM_HEIGHT = 3.0           -- hauteur de la poutre, en cases (sommet du poteau vanilla)
local WIRE_HEIGHT = 2.2           -- hauteur du fil de contact
local TRUSS_STEP = 0.7

local STEEL = {r = 0.46, g = 0.49, b = 0.54}
local STEEL_DARK = {r = 0.3, g = 0.32, b = 0.36}
local COPPER = {r = 0.85, g = 0.5, b = 0.25}
local INSULATOR = {r = 0.6, g = 0.28, b = 0.16}

local function is_valid(entity)
  return entity and entity.valid
end

local function ensure_storage()
  storage.catenary_gates = storage.catenary_gates or {}
end

-- Orientation d'une voie droite : "vertical" (nord-sud), "horizontal" (est-ouest) ou nil.
local function track_axis(rail)
  local direction = rail.direction
  if direction == defines.direction.north or direction == defines.direction.south then
    return "vertical"
  elseif direction == defines.direction.east or direction == defines.direction.west then
    return "horizontal"
  end
  return nil
end

-- Cherche le rail droit à gauche ou à droite du poteau. Retourne le centre de la voie à la
-- hauteur du poteau, l'axe de la voie et le côté du poteau (-1 ou 1), ou nil.
local function find_track(pole)
  local rails = pole.surface.find_entities_filtered({
    type = "straight-rail",
    position = pole.position,
    radius = RAIL_SEARCH_RADIUS,
  })

  local best = nil
  for _, rail in pairs(rails) do
    local axis = track_axis(rail)
    if axis then
      local side, center
      if axis == "vertical" then
        side = pole.position.x - rail.position.x
        center = {x = rail.position.x, y = pole.position.y}
      else
        side = pole.position.y - rail.position.y
        center = {x = pole.position.x, y = rail.position.y}
      end
      local distance = math.abs(side)
      if distance >= MIN_SIDE_DISTANCE and distance <= MAX_SIDE_DISTANCE
        and (not best or distance < best.distance) then
        best = {center = center, axis = axis, side = side < 0 and -1 or 1, distance = distance}
      end
    end
  end
  return best
end

local function clear_renders(gate)
  for _, object in pairs(gate.renders) do
    if object.valid then
      object.destroy()
    end
  end
  gate.renders = {}
end

local function top(position, height)
  return {x = position.x, y = position.y - height}
end

local function add_line(gate, surface, from, to, color, width)
  gate.renders[#gate.renders + 1] = rendering.draw_line({
    color = color,
    width = width,
    from = from,
    to = to,
    surface = surface,
    render_layer = "wires",
  })
end

-- Poutre en treillis entre le sommet des deux poteaux.
local function draw_beam(gate, surface)
  local a = gate.pole.position
  local b = gate.mirror.position
  local top_a = top(a, BEAM_HEIGHT)
  local top_b = top(b, BEAM_HEIGHT)

  -- Deuxième membrure, décalée perpendiculairement à la poutre sur l'écran
  local offset_x, offset_y = 0, 0.35
  if gate.axis == "horizontal" then
    offset_x, offset_y = 0.28, 0
  end
  local low_a = {x = top_a.x + offset_x, y = top_a.y + offset_y}
  local low_b = {x = top_b.x + offset_x, y = top_b.y + offset_y}

  add_line(gate, surface, top_a, top_b, STEEL, 3)
  add_line(gate, surface, low_a, low_b, STEEL, 3)

  local dx, dy = top_b.x - top_a.x, top_b.y - top_a.y
  local length = math.sqrt(dx * dx + dy * dy)
  local steps = math.max(2, math.floor(length / TRUSS_STEP))
  for i = 0, steps - 1 do
    local t0, t1 = i / steps, (i + 1) / steps
    local from, to
    if i % 2 == 0 then
      from = {x = top_a.x + dx * t0, y = top_a.y + dy * t0}
      to = {x = low_a.x + dx * t1, y = low_a.y + dy * t1}
    else
      from = {x = low_a.x + dx * t0, y = low_a.y + dy * t0}
      to = {x = top_a.x + dx * t1, y = top_a.y + dy * t1}
    end
    add_line(gate, surface, from, to, STEEL_DARK, 1.5)
  end
end

-- Suspente et fil de contact au centre de la voie.
local function draw_contact(gate, surface)
  local center = gate.center
  local beam_point = top(center, BEAM_HEIGHT - 0.2)
  local wire_point = top(center, WIRE_HEIGHT)

  add_line(gate, surface, beam_point, wire_point, STEEL_DARK, 2)
  gate.renders[#gate.renders + 1] = rendering.draw_circle({
    color = INSULATOR,
    radius = 0.1,
    filled = true,
    target = top(center, BEAM_HEIGHT - 0.45),
    surface = surface,
    render_layer = "wires",
  })
  gate.renders[#gate.renders + 1] = rendering.draw_circle({
    color = COPPER,
    radius = 0.08,
    filled = true,
    target = wire_point,
    surface = surface,
    render_layer = "wires",
  })
end

-- Porte suivante sur la même voie, dans le sens des coordonnées croissantes.
local function next_gate(gate)
  local best = nil
  local best_distance = math.huge
  for _, other in pairs(storage.catenary_gates) do
    if other ~= gate and other.axis == gate.axis and is_valid(other.pole)
      and other.pole.surface == gate.pole.surface then
      local along, across
      if gate.axis == "vertical" then
        along = other.center.y - gate.center.y
        across = math.abs(other.center.x - gate.center.x)
      else
        along = other.center.x - gate.center.x
        across = math.abs(other.center.y - gate.center.y)
      end
      if across < 0.5 and along > 0.5 and along <= WIRE_LINK_MAX and along < best_distance then
        best = other
        best_distance = along
      end
    end
  end
  return best
end

local function draw_gate(gate)
  clear_renders(gate)
  if not is_valid(gate.pole) or not is_valid(gate.mirror) then
    return
  end
  local surface = gate.pole.surface
  draw_beam(gate, surface)
  draw_contact(gate, surface)

  local following = next_gate(gate)
  if following then
    add_line(
      gate, surface,
      top(gate.center, WIRE_HEIGHT), top(following.center, WIRE_HEIGHT),
      COPPER, 2
    )
  end
end

-- Redessine les portes proches d'une position (liaisons par fils comprises).
local function refresh_around(surface, position)
  for _, gate in pairs(storage.catenary_gates) do
    if is_valid(gate.pole) and gate.pole.surface == surface
      and math.abs(gate.pole.position.x - position.x) <= REFRESH_RADIUS
      and math.abs(gate.pole.position.y - position.y) <= REFRESH_RADIUS then
      draw_gate(gate)
    end
  end
end

local function create_gate(pole)
  local track = find_track(pole)
  if not track then
    return false
  end

  local mirror_position = {
    x = 2 * track.center.x - pole.position.x,
    y = 2 * track.center.y - pole.position.y,
  }
  local mirror = pole.surface.create_entity({
    name = MIRROR_NAME,
    position = mirror_position,
    force = pole.force,
    raise_built = false,
  })
  if not mirror then
    return false
  end
  mirror.destructible = false

  storage.catenary_gates[pole.unit_number] = {
    pole = pole,
    mirror = mirror,
    center = track.center,
    axis = track.axis,
    side = track.side,
    renders = {},
  }
  return true
end

function catenary.on_built(entity, player_index)
  ensure_storage()
  if not is_valid(entity) or entity.name ~= POLE_NAME or not entity.unit_number then
    return
  end
  if storage.catenary_gates[entity.unit_number] then
    return
  end

  if create_gate(entity) then
    refresh_around(entity.surface, entity.position)
  elseif player_index and game.get_player(player_index) then
    game.get_player(player_index).create_local_flying_text({
      text = {"er-message.catenary-no-track"},
      position = entity.position,
    })
  end
end

function catenary.on_removed(entity)
  ensure_storage()
  if not entity or not entity.unit_number then
    return
  end
  local gate = storage.catenary_gates[entity.unit_number]
  if not gate then
    return
  end

  clear_renders(gate)
  if is_valid(gate.mirror) then
    gate.mirror.destroy()
  end
  storage.catenary_gates[entity.unit_number] = nil

  if entity.valid then
    refresh_around(entity.surface, entity.position)
  end
end

-- Porte alimentant ce rail (le poteau, relié à un réseau électrique), ou nil.
function catenary.powering_pole(rail, force)
  ensure_storage()
  if not is_valid(rail) then
    return nil
  end

  local poles = rail.surface.find_entities_filtered({
    name = POLE_NAME,
    force = force,
    position = rail.position,
    radius = POWER_SEARCH_RADIUS,
  })
  for _, pole in pairs(poles) do
    local gate = storage.catenary_gates[pole.unit_number]
    if gate and pole.electric_network_id then
      local dx = rail.position.x - gate.center.x
      local dy = rail.position.y - gate.center.y
      if math.sqrt(dx * dx + dy * dy) <= POWER_REACH then
        return pole
      end
    end
  end
  return nil
end

-- Reconstruit les portes de toutes les parties, y compris celles posées avant la 0.3.4.
function catenary.rebuild_all()
  ensure_storage()
  for _, gate in pairs(storage.catenary_gates) do
    clear_renders(gate)
    if is_valid(gate.mirror) then
      gate.mirror.destroy()
    end
  end
  storage.catenary_gates = {}

  for _, surface in pairs(game.surfaces) do
    for _, pole in pairs(surface.find_entities_filtered({name = POLE_NAME})) do
      create_gate(pole)
    end
    for _, gate in pairs(storage.catenary_gates) do
      if is_valid(gate.pole) and gate.pole.surface == surface then
        draw_gate(gate)
      end
    end
  end
end

catenary.POWER_REACH = POWER_REACH

return catenary

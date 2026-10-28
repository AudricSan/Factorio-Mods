-- Portes de caténaire.
-- Le joueur pose un poteau (er-catenary-pole) à côté d'une voie. Le script trouve le point de
-- la voie le plus proche et sa direction à cet endroit (voie droite, diagonale ou courbe),
-- pose un poteau miroir (er-catenary-mirror) de l'autre côté de la voie, trace la poutre
-- au-dessus de la voie et les fils au centre de la voie. Seul ce rail, et ses voisins directs
-- sur la même voie, sont alimentés : la porte ne dépasse pas la voie qu'elle enjambe.
local catenary = {}

local POLE_NAME = "er-catenary-pole"
local MIRROR_NAME = "er-catenary-mirror"

local GROUND_RAIL_TYPES = {"straight-rail", "half-diagonal-rail", "curved-rail-a", "curved-rail-b"}

local RAIL_SEARCH_RADIUS = 7
local MIN_SIDE_DISTANCE = 1.2     -- distance minimale entre l'axe de la voie et le poteau
local MAX_SIDE_DISTANCE = 4.5
local CURVE_SAMPLES = 16
local REFINE_STEPS = 12
local POWER_DEPTH = 2             -- nombre de rails de part et d'autre qui reçoivent l'énergie
local LINK_DEPTH = 10             -- profondeur de recherche de la porte voisine sur la même voie
local POWER_SEARCH_RADIUS = 9
local SEGMENT_MARGIN = 4          -- écart maximal d'un rail au câble de caténaire pour être alimenté
local REFRESH_RADIUS = 24

local BEAM_HEIGHT = 3.0           -- hauteur de la poutre, en cases (sommet du poteau vanilla)
local WIRE_HEIGHT = 2.2           -- hauteur du fil de contact
local TRUSS_STEP = 0.7

-- Portée affichée par le mode debug (l'alimentation réelle suit la connexion des rails)
catenary.POWER_REACH = 4

-- Câble extérieur vers le réseau électrique ordinaire
local GATE_WIRE_HEIGHT = 3.1      -- accroche du câble sur le poteau de la porte (poteau moyen)
local DEFAULT_POLE_WIRE_HEIGHT = 3.0
local POLE_WIRE_HEIGHT = {
  ["small-electric-pole"] = 2.6,
  ["medium-electric-pole"] = 3.1,
  ["big-electric-pole"] = 3.9,
  ["substation"] = 3.7,
}
local FEEDER_SEGMENTS = 6
local FEEDER_SAG_BASE = 0.12
local FEEDER_SAG_PER_TILE = 0.025

local FEEDER = {r = 0.72, g = 0.43, b = 0.2}
local STEEL = {r = 0.46, g = 0.49, b = 0.54}
local STEEL_DARK = {r = 0.3, g = 0.32, b = 0.36}
local COPPER = {r = 0.85, g = 0.5, b = 0.25}
local INSULATOR = {r = 0.6, g = 0.28, b = 0.16}

local function is_valid(entity)
  return entity and entity.valid
end

local function ensure_storage()
  storage.catenary_gates = storage.catenary_gates or {}
  storage.catenary_epoch = storage.catenary_epoch or 0
end

-- Géométrie des rails ------------------------------------------------------------------

-- Direction Factorio (16 positions, 0 = nord, sens horaire) en vecteur unitaire.
local function direction_vector(direction)
  local angle = direction * math.pi / 8
  return math.sin(angle), -math.cos(angle)
end

-- Courbe de Hermite passant par les deux extrémités du rail, tangente à leur direction.
-- Elle épouse les voies droites, les diagonales et les arcs des courbes vanilla.
local function rail_curve(rail)
  local end_a = rail.get_rail_end(defines.rail_direction.front)
  local end_b = rail.get_rail_end(defines.rail_direction.back)
  if not end_a or not end_b then
    return nil
  end

  local pa, pb = end_a.location.position, end_b.location.position
  local ax, ay = direction_vector(end_a.location.direction)
  local bx, by = direction_vector(end_b.location.direction)
  local length = math.sqrt((pb.x - pa.x) ^ 2 + (pb.y - pa.y) ^ 2)
  if length < 0.01 then
    return nil
  end

  -- Pièces droites (voie droite, demi-diagonale) : la droite exacte entre les extrémités. Les
  -- directions d'extrémité sont arrondies à 22,5°, ce qui ne reflète pas la pente 1:2 réelle.
  if rail.type == "straight-rail" or rail.type == "half-diagonal-rail" then
    local chord = {x = pb.x - pa.x, y = pb.y - pa.y}
    return {p0 = pa, p1 = pb, m0 = chord, m1 = chord}
  end

  -- Courbes : les directions des extrémités pointent vers l'extérieur du rail. On entre par A en
  -- allant à l'opposé de sa direction, et on sort par B dans la sienne.
  return {
    p0 = pa, p1 = pb,
    m0 = {x = -ax * length, y = -ay * length},
    m1 = {x = bx * length, y = by * length},
  }
end

local function curve_point(curve, t)
  local t2, t3 = t * t, t * t * t
  local h00, h10, h01, h11 = 2 * t3 - 3 * t2 + 1, t3 - 2 * t2 + t, -2 * t3 + 3 * t2, t3 - t2
  return {
    x = h00 * curve.p0.x + h10 * curve.m0.x + h01 * curve.p1.x + h11 * curve.m1.x,
    y = h00 * curve.p0.y + h10 * curve.m0.y + h01 * curve.p1.y + h11 * curve.m1.y,
  }
end

local function curve_tangent(curve, t)
  local t2 = t * t
  local d00, d10, d01, d11 = 6 * t2 - 6 * t, 3 * t2 - 4 * t + 1, -6 * t2 + 6 * t, 3 * t2 - 2 * t
  local x = d00 * curve.p0.x + d10 * curve.m0.x + d01 * curve.p1.x + d11 * curve.m1.x
  local y = d00 * curve.p0.y + d10 * curve.m0.y + d01 * curve.p1.y + d11 * curve.m1.y
  local length = math.sqrt(x * x + y * y)
  if length < 1e-9 then
    return 0, 1
  end
  return x / length, y / length
end

local function squared_distance(a, b)
  return (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2
end

-- Point de la courbe le plus proche de `position` : (point, tangente unitaire, distance).
local function nearest_on_curve(curve, position)
  local best_index, best_distance = 0, math.huge
  for i = 0, CURVE_SAMPLES do
    local distance = squared_distance(curve_point(curve, i / CURVE_SAMPLES), position)
    if distance < best_distance then
      best_index, best_distance = i, distance
    end
  end

  local low = math.max(0, (best_index - 1) / CURVE_SAMPLES)
  local high = math.min(1, (best_index + 1) / CURVE_SAMPLES)
  for _ = 1, REFINE_STEPS do
    local m1 = low + (high - low) / 3
    local m2 = high - (high - low) / 3
    if squared_distance(curve_point(curve, m1), position) < squared_distance(curve_point(curve, m2), position) then
      high = m2
    else
      low = m1
    end
  end

  local t = (low + high) / 2
  local point = curve_point(curve, t)
  local tx, ty = curve_tangent(curve, t)
  return point, tx, ty, math.sqrt(squared_distance(point, position))
end

-- Rails connectés à `start`, jusqu'à `depth` rails de distance (start compris).
-- Retourne l'ensemble des unit_number et la liste des rails.
local function rails_within(start, depth)
  local visited = {}
  if not is_valid(start) or not start.unit_number then
    return visited, {}
  end

  visited[start.unit_number] = true
  local all = {start}
  local frontier = {start}
  for _ = 1, depth do
    local next_frontier = {}
    for _, rail in ipairs(frontier) do
      for _, rail_direction in pairs(defines.rail_direction) do
        for connection_name, rail_connection_direction in pairs(defines.rail_connection_direction) do
          if connection_name ~= "none" then
            local neighbour = rail.get_connected_rail({
              rail_direction = rail_direction,
              rail_connection_direction = rail_connection_direction,
            })
            if is_valid(neighbour) and neighbour.unit_number and not visited[neighbour.unit_number] then
              visited[neighbour.unit_number] = true
              next_frontier[#next_frontier + 1] = neighbour
              all[#all + 1] = neighbour
            end
          end
        end
      end
    end
    frontier = next_frontier
  end
  return visited, all
end

-- Distance entre un point et un segment.
local function distance_to_segment(point, a, b)
  local dx, dy = b.x - a.x, b.y - a.y
  local length_squared = dx * dx + dy * dy
  local t = 0
  if length_squared > 1e-9 then
    t = math.max(0, math.min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / length_squared))
  end
  local px, py = a.x + t * dx, a.y + t * dy
  return math.sqrt((point.x - px) ^ 2 + (point.y - py) ^ 2)
end

-- Cherche la voie à gauche ou à droite du poteau. Retourne le point de la voie le plus proche,
-- sa tangente (orientée de façon canonique) et le rail concerné, ou nil.
local function find_track(pole)
  local rails = pole.surface.find_entities_filtered({
    type = GROUND_RAIL_TYPES,
    position = pole.position,
    radius = RAIL_SEARCH_RADIUS,
  })

  local best = nil
  for _, rail in pairs(rails) do
    local curve = rail_curve(rail)
    if curve then
      local point, tx, ty, distance = nearest_on_curve(curve, pole.position)
      if distance >= MIN_SIDE_DISTANCE and distance <= MAX_SIDE_DISTANCE
        and (not best or distance < best.distance) then
        -- Orientation canonique : toutes les portes d'une même voie partagent le même sens
        if tx < 0 or (tx == 0 and ty < 0) then
          tx, ty = -tx, -ty
        end
        best = {center = point, tangent = {x = tx, y = ty}, rail = rail, distance = distance}
      end
    end
  end
  return best
end

-- Dessin ---------------------------------------------------------------------------------

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

-- Poutre en treillis entre le sommet des deux poteaux, perpendiculaire à la voie.
local function draw_beam(gate, surface)
  local a = gate.pole.position
  local b = gate.mirror.position
  local top_a = top(a, BEAM_HEIGHT)
  local top_b = top(b, BEAM_HEIGHT)

  -- Deuxième membrure, décalée perpendiculairement à la poutre sur l'écran
  local dx, dy = top_b.x - top_a.x, top_b.y - top_a.y
  local offset_x, offset_y = 0, 0.35
  if math.abs(dy) > math.abs(dx) then
    offset_x, offset_y = 0.28, 0
  end
  local low_a = {x = top_a.x + offset_x, y = top_a.y + offset_y}
  local low_b = {x = top_b.x + offset_x, y = top_b.y + offset_y}

  add_line(gate, surface, top_a, top_b, STEEL, 3)
  add_line(gate, surface, low_a, low_b, STEEL, 3)

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

-- Portes reliées à `gate` par un câble de cuivre (une vraie connexion électrique, qu'on peut
-- effacer avec l'outil de câble du jeu) et situées sur la même voie.
local function wire_neighbors(gate)
  local result = {}
  if not is_valid(gate.pole) or not is_valid(gate.rail) then
    return result
  end

  local connector = gate.pole.get_wire_connector(defines.wire_connector_id.pole_copper, false)
  if not connector then
    return result
  end

  local same_track = rails_within(gate.rail, LINK_DEPTH)
  for _, connection in pairs(connector.connections) do
    local owner = connection.target.owner
    if is_valid(owner) and owner.name == POLE_NAME then
      local other = storage.catenary_gates[owner.unit_number]
      if other and other.rail_unit and same_track[other.rail_unit] then
        result[#result + 1] = other
      end
    end
  end
  return result
end

-- Entités reliées à la porte par un câble de cuivre, quelles qu'elles soient.
local function wire_owners(gate)
  local owners = {}
  if not is_valid(gate.pole) then
    return owners
  end
  local connector = gate.pole.get_wire_connector(defines.wire_connector_id.pole_copper, false)
  if not connector then
    return owners
  end
  for _, connection in pairs(connector.connections) do
    local owner = connection.target.owner
    if is_valid(owner) and owner.unit_number then
      owners[#owners + 1] = owner
    end
  end
  return owners
end

-- Empreinte des liaisons d'une porte, pour détecter qu'un câble a été posé ou effacé.
local function link_signature(gate)
  local ids = {}
  for _, owner in ipairs(wire_owners(gate)) do
    ids[#ids + 1] = owner.unit_number
  end
  table.sort(ids)
  return table.concat(ids, ",")
end

-- Hauteur d'accroche du câble sur un poteau vanilla, en cases.
local function wire_attach_height(entity)
  if entity.type ~= "electric-pole" then
    return 1.0
  end
  return POLE_WIRE_HEIGHT[entity.name] or DEFAULT_POLE_WIRE_HEIGHT
end

-- Câble extérieur entre le sommet de la porte et un autre poteau, avec l'affaissement d'un
-- câble de cuivre du jeu.
local function draw_feeder(gate, surface, owner)
  local from = top(gate.pole.position, GATE_WIRE_HEIGHT)
  local to = top(owner.position, wire_attach_height(owner))
  local length = math.sqrt((to.x - from.x) ^ 2 + (to.y - from.y) ^ 2)
  local sag = FEEDER_SAG_BASE + FEEDER_SAG_PER_TILE * length

  local previous = from
  for i = 1, FEEDER_SEGMENTS do
    local t = i / FEEDER_SEGMENTS
    local point = {
      x = from.x + (to.x - from.x) * t,
      y = from.y + (to.y - from.y) * t + sag * 4 * t * (1 - t),
    }
    add_line(gate, surface, previous, point, FEEDER, 1.5)
    previous = point
  end
end

local function draw_gate(gate)
  clear_renders(gate)
  if not is_valid(gate.pole) or not is_valid(gate.mirror) then
    return
  end
  local surface = gate.pole.surface
  draw_beam(gate, surface)
  draw_contact(gate, surface)

  local same_track = is_valid(gate.rail) and rails_within(gate.rail, LINK_DEPTH) or {}
  local ids = {}
  for _, owner in ipairs(wire_owners(gate)) do
    ids[#ids + 1] = owner.unit_number
    local other = owner.name == POLE_NAME and storage.catenary_gates[owner.unit_number] or nil
    if other and other.rail_unit and same_track[other.rail_unit] then
      -- Deux portes sur la même voie : câble de caténaire au centre de la voie, tracé une
      -- seule fois par paire
      if gate.pole.unit_number < owner.unit_number then
        add_line(
          gate, surface,
          top(gate.center, WIRE_HEIGHT), top(other.center, WIRE_HEIGHT),
          COPPER, 2
        )
      end
    elseif owner.name ~= POLE_NAME or gate.pole.unit_number < owner.unit_number then
      -- Réseau électrique ordinaire, ou porte d'une autre voie : câble extérieur entre poteaux
      draw_feeder(gate, surface, owner)
    end
  end
  table.sort(ids)
  gate.link_signature = table.concat(ids, ",")
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

-- Portes -----------------------------------------------------------------------------------

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
    tangent = track.tangent,
    rail = track.rail,
    rail_unit = track.rail.unit_number,
    renders = {},
    epoch = -1,
  }
  return true
end

-- Rails alimentés par cette porte : son rail et ses voisins directs sur la même voie.
-- Recalculé quand des rails ont été posés ou retirés depuis le dernier calcul.
local function powered_rails(gate)
  if gate.epoch == storage.catenary_epoch and gate.powered then
    return gate.powered
  end

  if not is_valid(gate.rail) and is_valid(gate.pole) then
    local track = find_track(gate.pole)
    if track then
      gate.center = track.center
      gate.tangent = track.tangent
      gate.rail = track.rail
      gate.rail_unit = track.rail.unit_number
    end
  end

  -- Le rail de la porte et ses voisins directs...
  local powered = rails_within(gate.rail, POWER_DEPTH)

  -- ...et toutes les voies sous le câble de caténaire qui la relie à une autre porte
  local neighbors = wire_neighbors(gate)
  if #neighbors > 0 then
    local _, track = rails_within(gate.rail, LINK_DEPTH)
    for _, other in ipairs(neighbors) do
      for _, rail in ipairs(track) do
        if is_valid(rail) and rail.unit_number
          and distance_to_segment(rail.position, gate.center, other.center) <= SEGMENT_MARGIN then
          powered[rail.unit_number] = true
        end
      end
    end
  end

  gate.powered = powered
  gate.epoch = storage.catenary_epoch
  return gate.powered
end

-- À appeler régulièrement : détecte les câbles de caténaire posés ou effacés avec l'outil de
-- câble du jeu, redessine les portes concernées et recalcule les rails alimentés.
function catenary.poll_wires()
  ensure_storage()
  local changed = {}
  for _, gate in pairs(storage.catenary_gates) do
    if is_valid(gate.pole) and is_valid(gate.mirror) and link_signature(gate) ~= gate.link_signature then
      changed[#changed + 1] = gate
    end
  end

  if #changed > 0 then
    storage.catenary_epoch = storage.catenary_epoch + 1
    for _, gate in ipairs(changed) do
      refresh_around(gate.pole.surface, gate.pole.position)
    end
  end
end

function catenary.rails_changed()
  ensure_storage()
  storage.catenary_epoch = storage.catenary_epoch + 1
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
  if not is_valid(rail) or not rail.unit_number then
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
    if gate and pole.electric_network_id and powered_rails(gate)[rail.unit_number] then
      return pole
    end
  end
  return nil
end

-- Rails alimentés par une porte, pour le mode debug : ensemble d'unit_number.
function catenary.gate_rails(gate)
  ensure_storage()
  return powered_rails(gate)
end

-- Reconstruit les portes de toutes les parties, y compris celles posées avant la 0.3.8.
function catenary.rebuild_all()
  ensure_storage()
  for _, gate in pairs(storage.catenary_gates) do
    clear_renders(gate)
    if is_valid(gate.mirror) then
      gate.mirror.destroy()
    end
  end
  storage.catenary_gates = {}
  storage.catenary_epoch = storage.catenary_epoch + 1

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

return catenary

-- Placement des transformateurs de rail, comme une gare vanilla : le transformateur se colle
-- à la case voisine d'un rail droit orthogonal, tourné vers la voie. Sans rail à côté, la pose
-- est refusée et l'objet est rendu au joueur.
local transformer = {}

local SNAP_SEARCH_RADIUS = 4
local MIN_SIDE_DISTANCE = 1.0     -- plus près : le transformateur serait sur le rail
local MAX_SIDE_DISTANCE = 3.5
local ADJACENT_OFFSET = 1.5       -- distance entre l'axe du rail et le centre de la case voisine
local ADJACENT_TOLERANCE = 0.4
local ALONG_TOLERANCE = 1.6
local POSITION_EPSILON = 0.01

-- Distance utilisée pour retrouver les rails alimentés par un transformateur déjà posé
transformer.ADJACENT_SEARCH_RADIUS = 3

local function is_valid(entity)
  return entity and entity.valid
end

-- "vertical" (nord-sud), "horizontal" (est-ouest) ou nil pour un rail droit.
local function orthogonal_axis(rail)
  local direction = rail.direction
  if direction == defines.direction.north or direction == defines.direction.south then
    return "vertical"
  elseif direction == defines.direction.east or direction == defines.direction.west then
    return "horizontal"
  end
  return nil
end

-- Écart perpendiculaire et écart le long de la voie entre une position et un rail.
local function offsets(position, rail, axis)
  if axis == "vertical" then
    return position.x - rail.position.x, position.y - rail.position.y
  end
  return position.y - rail.position.y, position.x - rail.position.x
end

local function find_best_rail(surface, position)
  local rails = surface.find_entities_filtered({
    type = "straight-rail",
    position = position,
    radius = SNAP_SEARCH_RADIUS,
  })

  local best = nil
  local best_score = math.huge
  for _, rail in pairs(rails) do
    local axis = orthogonal_axis(rail)
    if axis then
      local side, along = offsets(position, rail, axis)
      local distance = math.abs(side)
      if distance >= MIN_SIDE_DISTANCE and distance <= MAX_SIDE_DISTANCE then
        local score = (distance - ADJACENT_OFFSET) ^ 2 + along ^ 2
        if score < best_score then
          best = {rail = rail, axis = axis, sign = side < 0 and -1 or 1}
          best_score = score
        end
      end
    end
  end
  return best
end

-- Position et orientation exactes d'une gare à côté de ce rail. Comme une gare vanilla, la
-- direction est celle dans laquelle roule un train qui a la gare à sa droite.
local function snapped_placement(position, found)
  local rail = found.rail
  if found.axis == "vertical" then
    return {x = rail.position.x + found.sign * ADJACENT_OFFSET, y = math.floor(position.y) + 0.5},
      found.sign > 0 and defines.direction.north or defines.direction.south
  end
  return {x = math.floor(position.x) + 0.5, y = rail.position.y + found.sign * ADJACENT_OFFSET},
    found.sign > 0 and defines.direction.east or defines.direction.west
end

-- Rend l'objet au joueur, ou le dépose au sol si c'est un robot ou si l'inventaire est plein.
local function refund(surface, position, name, player_index, message)
  local player = player_index and game.get_player(player_index)
  local stack = {name = name, count = 1}
  if player and player.valid then
    local inserted = player.insert(stack)
    if inserted < 1 then
      surface.spill_item_stack({position = position, stack = stack, enable_looted = false})
    end
    player.create_local_flying_text({text = {message}, position = position})
  else
    surface.spill_item_stack({position = position, stack = stack, enable_looted = false})
  end
end

-- Aligne le transformateur sur le rail voisin. Retourne l'entité à enregistrer (la même, ou une
-- nouvelle à la bonne place), ou nil si la pose est refusée.
function transformer.snap(entity, player_index)
  if not is_valid(entity) then
    return nil
  end

  local surface = entity.surface
  local original_position = {x = entity.position.x, y = entity.position.y}
  local name = entity.name
  local force = entity.force

  local found = find_best_rail(surface, original_position)
  if not found then
    entity.destroy()
    refund(surface, original_position, name, player_index, "er-message.transformer-no-track")
    return nil
  end

  local position, direction = snapped_placement(original_position, found)
  local moved = math.abs(position.x - original_position.x) > POSITION_EPSILON
    or math.abs(position.y - original_position.y) > POSITION_EPSILON
  if not moved and entity.direction == direction then
    return entity
  end

  entity.destroy()
  if not surface.can_place_entity({name = name, position = position, direction = direction, force = force}) then
    refund(surface, original_position, name, player_index, "er-message.transformer-blocked")
    return nil
  end

  return surface.create_entity({
    name = name,
    position = position,
    direction = direction,
    force = force,
    raise_built = false,
  })
end

-- Rails alimentés directement : les rails droits sur la case voisine de ce transformateur.
function transformer.adjacent_rails(entity)
  local result = {}
  local rails = entity.surface.find_entities_filtered({
    type = "straight-rail",
    position = entity.position,
    radius = transformer.ADJACENT_SEARCH_RADIUS,
  })

  for _, rail in pairs(rails) do
    local axis = orthogonal_axis(rail)
    if axis then
      local side, along = offsets(entity.position, rail, axis)
      if math.abs(math.abs(side) - ADJACENT_OFFSET) <= ADJACENT_TOLERANCE and math.abs(along) <= ALONG_TOLERANCE then
        result[#result + 1] = rail
      end
    end
  end
  return result
end

return transformer

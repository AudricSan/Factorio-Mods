local catenary = require("scripts.catenary")
local transformer_placement = require("scripts.transformer")

local LOCOMOTIVE_NAME = "er-electric-locomotive"
local CHARGER_NAME = "er-mobile-charger"
local FUEL_NAME = "er-electric-charge"
local ENGINE_BUFFER = 100000
local FLUID_WEIGHT_PER_UNIT = 0.25
local MAX_LOAD_MULTIPLIER = 1.5
local REBUILD_CHECK_INTERVAL = 30
local FORCED_REBUILD_INTERVAL = 600

local TRANSFORMER_NAMES = {
  ["er-rail-transformer-1"] = true,
  ["er-rail-transformer-2"] = true,
  ["er-rail-transformer-3"] = true,
}

local rail_types = {
  "straight-rail",
  "half-diagonal-rail",
  "curved-rail-a",
  "curved-rail-b",
}

if script.active_mods["elevated-rails"] then
  table.insert(rail_types, "rail-ramp")
  table.insert(rail_types, "elevated-straight-rail")
  table.insert(rail_types, "elevated-half-diagonal-rail")
  table.insert(rail_types, "elevated-curved-rail-a")
  table.insert(rail_types, "elevated-curved-rail-b")
end

local rail_type_set = {}
for _, rail_type in ipairs(rail_types) do
  rail_type_set[rail_type] = true
end

-- Commande /er-debug : affichage des rails alimentés et non alimentés
require("scripts.debug").setup({
  rail_types = rail_types,
  transformer_radius = transformer_placement.ADJACENT_SEARCH_RADIUS,
  gate_reach = catenary.POWER_REACH,
})

local function ensure_storage()
  storage.electrified_rail_locomotives = storage.electrified_rail_locomotives or {}
  storage.electrified_rail_chargers = storage.electrified_rail_chargers or {}
  storage.rail_transformers = storage.rail_transformers or {}
  storage.rail_power = storage.rail_power or {}
  if storage.rails_dirty == nil then
    storage.rails_dirty = true
  end
end

local function is_valid(entity)
  return entity and entity.valid
end

local function register_locomotive(entity)
  if is_valid(entity) and entity.name == LOCOMOTIVE_NAME and entity.unit_number then
    storage.electrified_rail_locomotives[entity.unit_number] = entity
  end
end

local function register_transformer(entity)
  if is_valid(entity) and TRANSFORMER_NAMES[entity.name] and entity.unit_number then
    storage.rail_transformers[entity.unit_number] = entity
    storage.rails_dirty = true
  end
end

-- Parcourt tous les rails reliés aux rails de départ (au sol et surélevés).
local function collect_connected_rails(start_rails)
  local visited = {}
  local queue = {}
  local head = 1

  for _, rail in pairs(start_rails) do
    if is_valid(rail) and rail.unit_number and not visited[rail.unit_number] then
      visited[rail.unit_number] = true
      queue[#queue + 1] = rail
    end
  end

  while head <= #queue do
    local rail = queue[head]
    head = head + 1
    for _, rail_direction in pairs(defines.rail_direction) do
      for connection_name, rail_connection_direction in pairs(defines.rail_connection_direction) do
        if connection_name ~= "none" then
          local neighbour = rail.get_connected_rail({
            rail_direction = rail_direction,
            rail_connection_direction = rail_connection_direction,
          })
          if is_valid(neighbour) and neighbour.unit_number and not visited[neighbour.unit_number] then
            visited[neighbour.unit_number] = true
            queue[#queue + 1] = neighbour
          end
        end
      end
    end
  end

  return queue
end

local function rebuild_rail_power_map()
  local power_map = {}
  local stats = {}

  for unit_number, transformer in pairs(storage.rail_transformers) do
    if is_valid(transformer) then
      -- Rails de départ : ceux de la case voisine du transformateur, comme pour une gare
      local nearby_rails = transformer_placement.adjacent_rails(transformer)
      local connected_rails = collect_connected_rails(nearby_rails)

      -- Données pour le mode debug : rails de départ et nombre de rails alimentés
      local seeds = {}
      for _, rail in pairs(nearby_rails) do
        seeds[#seeds + 1] = {x = rail.position.x, y = rail.position.y}
      end
      stats[unit_number] = {rails = #connected_rails, seeds = seeds}

      for _, rail in pairs(connected_rails) do
        local entry = power_map[rail.unit_number]
        if not entry then
          entry = {}
          power_map[rail.unit_number] = entry
        end
        entry[#entry + 1] = unit_number
      end
    else
      storage.rail_transformers[unit_number] = nil
    end
  end

  storage.rail_power = power_map
  storage.transformer_stats = stats
  storage.rails_dirty = false
end

-- Transformateur alimentant ce rail (celui qui a le plus d'énergie s'il y en a plusieurs).
local function transformer_for_rail(rail)
  if not is_valid(rail) or not rail.unit_number then
    return nil
  end
  local entry = storage.rail_power[rail.unit_number]
  if not entry then
    return nil
  end

  local best = nil
  local best_energy = -1
  for _, unit_number in ipairs(entry) do
    local transformer = storage.rail_transformers[unit_number]
    if is_valid(transformer) and transformer.energy > best_energy then
      best = transformer
      best_energy = transformer.energy
    end
  end
  return best
end

local function remove_entity(event)
  local entity = event.entity or event.created_entity
  if not entity or not entity.valid then
    return
  end

  if rail_type_set[entity.type] or TRANSFORMER_NAMES[entity.name] then
    storage.rails_dirty = true
  end
  if rail_type_set[entity.type] then
    catenary.rails_changed()
  end
  if entity.name == "er-catenary-pole" then
    catenary.on_removed(entity)
  end

  local unit_number = entity.unit_number
  if not unit_number then
    return
  end

  storage.rail_transformers[unit_number] = nil
  local charger = storage.electrified_rail_chargers[unit_number]
  if is_valid(charger) then
    charger.destroy()
  end
  storage.electrified_rail_chargers[unit_number] = nil
  storage.electrified_rail_locomotives[unit_number] = nil
end

local function register_built_entity(event)
  local entity = event.entity or event.created_entity
  if not is_valid(entity) then
    return
  end

  if entity.name == LOCOMOTIVE_NAME then
    register_locomotive(entity)
  elseif TRANSFORMER_NAMES[entity.name] then
    -- Se colle au rail voisin comme une gare, ou refuse la pose
    local placed = transformer_placement.snap(entity, event.player_index)
    if placed then
      register_transformer(placed)
    end
  elseif entity.name == "er-catenary-pole" then
    catenary.on_built(entity, event.player_index)
  elseif rail_type_set[entity.type] then
    storage.rails_dirty = true
    catenary.rails_changed()
  end
end

local function rail_under_locomotive(locomotive, train)
  local closest_rail = nil
  local closest_distance_squared = math.huge

  for _, rail in pairs(train.get_rails()) do
    if is_valid(rail) then
      local dx = rail.position.x - locomotive.position.x
      local dy = rail.position.y - locomotive.position.y
      local distance_squared = dx * dx + dy * dy
      if distance_squared < closest_distance_squared then
        closest_rail = rail
        closest_distance_squared = distance_squared
      end
    end
  end

  return closest_rail
end

local function is_elevated_rail(rail)
  return is_valid(rail)
    and (rail.type == "rail-ramp" or rail.name:find("elevated", 1, true) ~= nil)
end

local function is_powered_station(train)
  local station = train.station
  if not is_valid(station) then
    return false
  end

  local search_radius = 9
  local nearby_poles = station.surface.find_entities_filtered({
    type = "electric-pole",
    force = station.force,
    area = {
      {station.position.x - search_radius, station.position.y - search_radius},
      {station.position.x + search_radius, station.position.y + search_radius},
    },
  })

  for _, pole in pairs(nearby_poles) do
    if is_valid(pole) and pole.electric_network_id then
      local range = pole.prototype.get_supply_area_distance() or 0
      if math.abs(station.position.x - pole.position.x) <= range + 0.5
        and math.abs(station.position.y - pole.position.y) <= range + 0.5 then
        return true
      end
    end
  end
  return false
end

-- Retourne (alimenté, position de la source, transformateur éventuel).
-- Un transformateur fournit directement son énergie ; la caténaire et les gares passent par
-- une interface électrique mobile placée à la position retournée.
local function has_power_source(locomotive, train, rail)
  local transformer = transformer_for_rail(rail)
  if transformer then
    return true, nil, transformer
  end

  local power_position = is_valid(rail) and rail.position or locomotive.position

  if is_powered_station(train) then
    return true, train.station.position, nil
  end

  if is_elevated_rail(rail) then
    return false, nil, nil
  end

  -- La porte alimente uniquement le rail qu'elle enjambe. L'interface d'énergie du train est
  -- posée sur le poteau, qui est dans sa propre zone d'alimentation.
  local gate_pole = catenary.powering_pole(rail, locomotive.force)
  if gate_pole then
    return true, gate_pole.position, nil
  end
  return false, nil, nil
end

local function get_battery(locomotive)
  local grid = locomotive.grid
  if not grid then
    return nil
  end

  for _, equipment in pairs(grid.equipment) do
    if is_valid(equipment) and equipment.name:find("^er%-train%-battery%-%d+$") then
      return equipment
    end
  end
  return nil
end

local function empty_train_weight(train)
  local weight = 0
  for _, carriage in pairs(train.carriages) do
    if is_valid(carriage) then
      weight = weight + (carriage.prototype.weight or 1000)
    end
  end
  return math.max(weight, 1)
end

local function cargo_weight(train)
  local weight = 0
  for _, stack in pairs(train.get_contents()) do
    local prototype = prototypes.item[stack.name]
    local item_weight = prototype and prototype.weight
    if item_weight and item_weight > 0 then
      weight = weight + stack.count * item_weight
    else
      local stack_size = prototype and prototype.stack_size or 1
      weight = weight + stack.count / math.max(stack_size, 1) * 10
    end
  end

  for _, fluid_amount in pairs(train.get_fluid_contents()) do
    weight = weight + fluid_amount * FLUID_WEIGHT_PER_UNIT
  end
  return weight
end

local function train_load_multiplier(train)
  local ratio = cargo_weight(train) / empty_train_weight(train)
  return 1 + math.min(ratio, MAX_LOAD_MULTIPLIER - 1)
end

local function get_charger(locomotive, should_exist, position)
  local unit_number = locomotive.unit_number
  local charger = storage.electrified_rail_chargers[unit_number]

  if not should_exist then
    if is_valid(charger) then
      charger.energy = 0
      charger.destroy()
    end
    storage.electrified_rail_chargers[unit_number] = nil
    return nil
  end

  if is_valid(charger) then
    if charger.surface ~= locomotive.surface then
      charger.destroy()
      charger = nil
    else
      charger.teleport(position or locomotive.position)
    end
  end

  if not is_valid(charger) then
    charger = locomotive.surface.create_entity({
      name = CHARGER_NAME,
      position = position or locomotive.position,
      force = locomotive.force,
      raise_built = false,
    })
    if charger then
      charger.destructible = false
    end
    storage.electrified_rail_chargers[unit_number] = charger
  end
  return charger
end

local function update_locomotive(locomotive)
  if not is_valid(locomotive) or not locomotive.train or not locomotive.train.valid or not locomotive.burner then
    return
  end

  local train = locomotive.train
  local battery = get_battery(locomotive)
  local rail = rail_under_locomotive(locomotive, train)
  local powered, power_position, transformer = has_power_source(locomotive, train, rail)

  local source
  if transformer then
    get_charger(locomotive, false)
    source = transformer
  else
    source = get_charger(locomotive, powered, power_position)
  end

  local battery_energy = battery and battery.energy or 0
  local load_multiplier = train_load_multiplier(train)
  local burner = locomotive.burner
  local burning_item = burner.currently_burning
  local burner_energy = 0

  if burning_item and burning_item.name.name == FUEL_NAME then
    burner_energy = burner.remaining_burning_fuel or 0
  end

  local deficit = math.max(0, ENGINE_BUFFER - burner_energy)
  local required_energy = deficit * load_multiplier
  local network_energy = is_valid(source) and source.energy or 0
  local from_network = math.min(network_energy, required_energy)
  if from_network > 0 then
    source.energy = network_energy - from_network
  end

  local remaining_required = required_energy - from_network
  local from_battery = math.min(battery_energy, remaining_required)
  if battery and from_battery > 0 then
    battery.energy = battery_energy - from_battery
  end

  local energy_added_to_burner = (from_network + from_battery) / load_multiplier
  if energy_added_to_burner > 0 or burner_energy > 0 then
    burner.currently_burning = prototypes.item[FUEL_NAME]
    burner.remaining_burning_fuel = burner_energy + energy_added_to_burner
  end

  if battery and is_valid(source) then
    local free_capacity = math.max(0, battery.max_energy - battery.energy)
    local charge_amount = math.min(free_capacity, source.energy)
    if charge_amount > 0 then
      battery.energy = battery.energy + charge_amount
      source.energy = source.energy - charge_amount
    end
  end
end

local function update_trains()
  for unit_number, locomotive in pairs(storage.electrified_rail_locomotives) do
    if is_valid(locomotive) then
      update_locomotive(locomotive)
    else
      storage.electrified_rail_locomotives[unit_number] = nil
      local charger = storage.electrified_rail_chargers[unit_number]
      if is_valid(charger) then
        charger.destroy()
      end
      storage.electrified_rail_chargers[unit_number] = nil
    end
  end
end

local function scan_world()
  for _, surface in pairs(game.surfaces) do
    for _, locomotive in pairs(surface.find_entities_filtered({name = LOCOMOTIVE_NAME})) do
      register_locomotive(locomotive)
    end
    for transformer_name in pairs(TRANSFORMER_NAMES) do
      for _, transformer in pairs(surface.find_entities_filtered({name = transformer_name})) do
        register_transformer(transformer)
      end
    end
  end
  storage.rails_dirty = true
  catenary.rebuild_all()
end

-- Les rails électrifiés dédiés de la 0.2.x n'existent plus : on libère leurs anciennes données.
local function cleanup_legacy_storage()
  local legacy_nodes = storage.electrified_rail_power_nodes
  if legacy_nodes then
    for _, node in pairs(legacy_nodes) do
      if is_valid(node) then
        node.destroy()
      end
    end
    storage.electrified_rail_power_nodes = nil
  end
end

local function on_train_created(event)
  local train = event.train
  if not train or not train.valid then
    return
  end
  for _, carriage in pairs(train.carriages) do
    register_locomotive(carriage)
  end
end

local function on_rebuild_check()
  if storage.rails_dirty then
    rebuild_rail_power_map()
  end
  -- Câbles de caténaire posés ou effacés avec l'outil de câble du jeu
  catenary.poll_wires()
end

local function on_forced_rebuild()
  storage.rails_dirty = true
end

script.on_init(function()
  ensure_storage()
  scan_world()
end)

script.on_configuration_changed(function()
  ensure_storage()
  cleanup_legacy_storage()
  scan_world()
end)

script.on_event({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive,
}, register_built_entity)

script.on_event({
  defines.events.on_pre_player_mined_item,
  defines.events.on_robot_pre_mined,
  defines.events.on_entity_died,
  defines.events.script_raised_destroy,
}, remove_entity)

script.on_event(defines.events.on_train_created, on_train_created)
script.on_event(defines.events.on_tick, update_trains)
script.on_nth_tick(REBUILD_CHECK_INTERVAL, on_rebuild_check)
script.on_nth_tick(FORCED_REBUILD_INTERVAL, on_forced_rebuild)

-- Mode debug : /er-debug affiche, autour du joueur, les rails alimentés par un transformateur
-- (vert, cyan si plusieurs transformateurs), les rails non alimentés (rouge), la portée des
-- transformateurs et la portée des portes de caténaire.
-- Les dessins sont visibles uniquement par le joueur qui a activé le mode et expirent seuls.
local catenary = require("scripts.catenary")

local debug_view = {}

local REFRESH_TICKS = 60
local TIME_TO_LIVE = 75
local VIEW_RADIUS = 60

local TRANSFORMER_POWER_MW = {
  ["er-rail-transformer-1"] = 5,
  ["er-rail-transformer-2"] = 20,
  ["er-rail-transformer-3"] = 60,
}

local POWERED = {r = 0.1, g = 0.8, b = 0.2, a = 0.55}
local POWERED_MULTI = {r = 0.1, g = 0.75, b = 0.85, a = 0.55}
local GATE_RAIL = {r = 1, g = 0.6, b = 0.1, a = 0.55}
local UNPOWERED = {r = 0.9, g = 0.15, b = 0.1, a = 0.5}
local RANGE = {r = 1, g = 0.85, b = 0.1, a = 0.9}
local GATE_OK = {r = 1, g = 0.55, b = 0.1, a = 0.9}
local GATE_OFF = {r = 0.9, g = 0.15, b = 0.1, a = 0.9}

local rail_types = {}
local transformer_radius = 4
local gate_reach = 4

-- Dessine autour de `position`. `viewers` est la liste des joueurs qui voient les dessins
-- (nil = tout le monde).
local function draw_at(surface, position, viewers)
  local rail_power = storage.rail_power or {}
  local stats = storage.transformer_stats or {}

  -- Rails alimentés par une porte de caténaire proche
  local gate_powered = {}
  for _, gate in pairs(storage.catenary_gates or {}) do
    local pole = gate.pole
    if pole and pole.valid and pole.surface == surface
      and math.abs(gate.center.x - position.x) <= VIEW_RADIUS
      and math.abs(gate.center.y - position.y) <= VIEW_RADIUS then
      for unit_number in pairs(catenary.gate_rails(gate)) do
        gate_powered[unit_number] = true
      end
    end
  end

  local powered_count, unpowered_count = 0, 0
  local rails = surface.find_entities_filtered({
    type = rail_types,
    position = position,
    radius = VIEW_RADIUS,
  })
  for _, rail in pairs(rails) do
    local sources = rail.unit_number and rail_power[rail.unit_number]
    local color = UNPOWERED
    if sources and #sources > 0 then
      color = #sources > 1 and POWERED_MULTI or POWERED
      powered_count = powered_count + 1
    elseif rail.unit_number and gate_powered[rail.unit_number] then
      color = GATE_RAIL
      powered_count = powered_count + 1
    else
      unpowered_count = unpowered_count + 1
    end
    rendering.draw_circle({
      color = color,
      radius = 0.7,
      filled = true,
      target = rail.position,
      surface = surface,
      time_to_live = TIME_TO_LIVE,
      players = viewers,
      render_layer = "higher-object-above",
    })
  end

  local transformers = surface.find_entities_filtered({
    name = {"er-rail-transformer-1", "er-rail-transformer-2", "er-rail-transformer-3"},
    position = position,
    radius = VIEW_RADIUS * 2,
  })
  for _, transformer in pairs(transformers) do
    local transformer_stats = stats[transformer.unit_number]
    local power_mw = TRANSFORMER_POWER_MW[transformer.name] or 0

    rendering.draw_circle({
      color = RANGE,
      radius = transformer_radius,
      width = 2,
      filled = false,
      target = transformer.position,
      surface = surface,
      time_to_live = TIME_TO_LIVE,
      players = viewers,
      render_layer = "higher-object-above",
    })

    if transformer_stats then
      for _, seed in pairs(transformer_stats.seeds) do
        rendering.draw_line({
          color = RANGE,
          width = 2,
          from = transformer.position,
          to = seed,
          surface = surface,
          time_to_live = TIME_TO_LIVE,
          players = viewers,
          render_layer = "higher-object-above",
        })
      end
    end

    local buffer_percent = power_mw > 0 and math.floor(transformer.energy / (power_mw * 1e6) * 100 + 0.5) or 0
    rendering.draw_text({
      text = {
        "er-message.debug-transformer",
        power_mw,
        transformer_stats and transformer_stats.rails or 0,
        buffer_percent,
      },
      color = {r = 1, g = 1, b = 1},
      scale = 1.2,
      alignment = "center",
      target = {x = transformer.position.x, y = transformer.position.y - 3},
      surface = surface,
      time_to_live = TIME_TO_LIVE,
      players = viewers,
      render_layer = "higher-object-above",
    })
  end

  for _, gate in pairs(storage.catenary_gates or {}) do
    local pole = gate.pole
    if pole and pole.valid and pole.surface == surface
      and math.abs(gate.center.x - position.x) <= VIEW_RADIUS
      and math.abs(gate.center.y - position.y) <= VIEW_RADIUS then
      rendering.draw_circle({
        color = pole.electric_network_id and GATE_OK or GATE_OFF,
        radius = gate_reach,
        width = 2,
        filled = false,
        target = gate.center,
        surface = surface,
        time_to_live = TIME_TO_LIVE,
        players = viewers,
        render_layer = "higher-object-above",
      })
    end
  end

  rendering.draw_text({
    text = {"er-message.debug-summary", powered_count, unpowered_count},
    color = {r = 1, g = 1, b = 1},
    scale = 1.3,
    alignment = "center",
    target = {x = position.x, y = position.y - 4},
    surface = surface,
    time_to_live = TIME_TO_LIVE,
    players = viewers,
    render_layer = "higher-object-above",
  })
end

local function draw_for(player)
  draw_at(player.surface, player.position, {player})
end

local function on_refresh()
  for player_index, enabled in pairs(storage.debug_players or {}) do
    local player = game.get_player(player_index)
    if enabled and player and player.valid and player.connected then
      draw_for(player)
    end
  end
end

local function on_command(command)
  local player = command.player_index and game.get_player(command.player_index)
  if not player then
    return
  end

  storage.debug_players = storage.debug_players or {}
  local enabled = not storage.debug_players[player.index]
  storage.debug_players[player.index] = enabled

  if enabled then
    player.print({"er-message.debug-on"})
    draw_for(player)
  else
    player.print({"er-message.debug-off"})
  end
end

debug_view.draw_at = draw_at

function debug_view.setup(options)
  rail_types = options.rail_types
  transformer_radius = options.transformer_radius
  gate_reach = options.gate_reach

  commands.add_command("er-debug", {"er-message.debug-help"}, on_command)
  script.on_nth_tick(REFRESH_TICKS, on_refresh)
end

return debug_view

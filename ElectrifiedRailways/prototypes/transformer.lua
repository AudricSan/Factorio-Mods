-- Transformateurs de rail : posés à côté d'une voie, branchés au réseau électrique par un
-- poteau. Ils alimentent tous les rails connectés (voir scripts/train-power.lua).
-- Le niveau fixe la puissance maximale délivrée, partagée entre les trains du réseau de rails.
local tiers = {
  {
    level = 1,
    power = "2MW",
    ingredients = {
      {type = "item", name = "steel-plate", amount = 20},
      {type = "item", name = "copper-cable", amount = 30},
      {type = "item", name = "electronic-circuit", amount = 30},
    },
  },
  {
    level = 2,
    power = "40MW",
    ingredients = {
      {type = "item", name = "er-rail-transformer-1", amount = 2},
      {type = "item", name = "steel-plate", amount = 30},
      {type = "item", name = "copper-cable", amount = 60},
      {type = "item", name = "advanced-circuit", amount = 20},
    },
  },
  {
    level = 3,
    power = "100MW",
    ingredients = {
      {type = "item", name = "er-rail-transformer-2", amount = 3},
      {type = "item", name = "steel-plate", amount = 60},
      {type = "item", name = "copper-cable", amount = 140},
      {type = "item", name = "processing-unit", amount = 20},
    },
  },
}

-- Les graphismes sont la couche « niveau du rail » de la gare vanilla (câbles, boîtiers et
-- pied de pylône posés au sol), dans ses 4 orientations, légèrement teintée par niveau.
local train_stop = data.raw["train-stop"]["train-stop"]
local train_stop_item = data.raw.item["train-stop"]
local tier_tints = {
  {r = 0.85, g = 0.95, b = 1},
  {r = 1, g = 0.85, b = 0.65},
  {r = 1, g = 0.7, b = 0.65},
}

local directions = {"north", "east", "south", "west"}

local function tinted_rail_overlay(tint)
  local animations = table.deepcopy(train_stop.rail_overlay_animations)
  for _, direction in ipairs(directions) do
    local node = animations[direction]
    if node.layers then
      for _, layer in ipairs(node.layers) do
        if not layer.draw_as_shadow then
          layer.tint = tint
        end
      end
    elseif not node.draw_as_shadow then
      node.tint = tint
    end
  end
  return animations
end

local prototypes = {}

for index, tier in ipairs(tiers) do
  local name = "er-rail-transformer-" .. tier.level
  local icons = {{icon = "__ElectrifiedRailways__/graphics/icons/" .. name .. ".png", icon_size = 64}}
  local next_name = tiers[index + 1] and ("er-rail-transformer-" .. tiers[index + 1].level) or nil
  local buffer = (tier.power:gsub("W$", "J"))

  table.insert(prototypes, {
    type = "electric-energy-interface",
    name = name,
    icons = table.deepcopy(icons),
    flags = {"placeable-neutral", "player-creation"},
    minable = {mining_time = 0.3, result = name},
    max_health = 250,
    corpse = train_stop.corpse,
    dying_explosion = train_stop.dying_explosion,
    collision_box = train_stop.collision_box,
    selection_box = {{-0.9, -0.9}, {0.9, 0.9}},
    -- L'orientation est imposée par le script selon la voie voisine, comme pour une gare
    rotatable = false,
    fast_replaceable_group = "er-rail-transformer",
    energy_source = {
      type = "electric",
      buffer_capacity = buffer,
      usage_priority = "secondary-input",
      input_flow_limit = tier.power,
      output_flow_limit = "0W",
      drain = "0W",
    },
    energy_usage = "0W",
    energy_production = "0W",
    gui_mode = "none",
    animations = tinted_rail_overlay(tier_tints[index]),
  })

  -- Emplacement de pose : une copie de la gare, pour hériter de son système de pose (aperçu
  -- collé à la voie, orientation, un seul objet par emplacement). Dès qu'il est posé, le
  -- script le remplace par le transformateur (voir scripts/transformer.lua).
  local slot = table.deepcopy(train_stop)
  slot.name = name .. "-slot"
  slot.icons = table.deepcopy(icons)
  slot.icon = nil
  slot.icon_size = nil
  slot.icon_mipmaps = nil
  slot.minable = {mining_time = 0.3, result = name}
  slot.fast_replaceable_group = "er-rail-transformer"
  slot.next_upgrade = tiers[index + 1] and (next_name .. "-slot") or nil
  slot.factoriopedia_simulation = nil
  slot.hidden_in_factoriopedia = true
  slot.chart_name = false
  slot.animations = nil
  slot.top_animations = nil
  slot.light1 = nil
  slot.light2 = nil
  slot.rail_overlay_animations = tinted_rail_overlay(tier_tints[index])
  table.insert(prototypes, slot)

  table.insert(prototypes, {
    type = "item",
    name = name,
    icons = table.deepcopy(icons),
    subgroup = "er-catenary",
    order = "b[transformer]-" .. tier.level,
    place_result = name .. "-slot",
    stack_size = 20,
  })

  table.insert(prototypes, {
    type = "recipe",
    name = name,
    enabled = false,
    energy_required = 5 * tier.level,
    ingredients = tier.ingredients,
    results = {{type = "item", name = name, amount = 1}},
  })
end

data:extend(prototypes)

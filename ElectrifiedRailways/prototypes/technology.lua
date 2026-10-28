local function base_science_packs()
  return {
    {"automation-science-pack", 1},
    {"logistic-science-pack", 1},
    {"chemical-science-pack", 1},
  }
end

local function add_pack(packs, name)
  table.insert(packs, {name, 1})
end

local function electric_technology_icon()
  return {
    {
      icon = "__base__/graphics/technology/railway.png",
      icon_size = 256,
    },
    {
      icon = "__core__/graphics/icons/tooltips/tooltip-category-electricity.png",
      icon_size = 32,
      scale = 4,
      shift = {0, 0},
    },
  }
end

local function technology(name, prerequisites, packs, count, time, effects, order)
  return {
    type = "technology",
    name = name,
    icons = electric_technology_icon(),
    prerequisites = prerequisites,
    effects = effects,
    unit = {
      count = count,
      ingredients = packs,
      time = time,
    },
    order = order,
  }
end

local traction_packs = base_science_packs()
local battery_one_packs = base_science_packs()
add_pack(battery_one_packs, "production-science-pack")
add_pack(battery_one_packs, "utility-science-pack")

local battery_two_packs = base_science_packs()
add_pack(battery_two_packs, "production-science-pack")
add_pack(battery_two_packs, "utility-science-pack")
if mods["space-age"] then
  add_pack(battery_two_packs, "electromagnetic-science-pack")
end

local battery_three_packs = base_science_packs()
add_pack(battery_three_packs, "production-science-pack")
add_pack(battery_three_packs, "utility-science-pack")
if mods["space-age"] then
  add_pack(battery_three_packs, "electromagnetic-science-pack")
  add_pack(battery_three_packs, "cryogenic-science-pack")
else
  add_pack(battery_three_packs, "space-science-pack")
end

local electrified_rail_packs = base_science_packs()
add_pack(electrified_rail_packs, "production-science-pack")
add_pack(electrified_rail_packs, "utility-science-pack")
if mods["space-age"] then
  add_pack(electrified_rail_packs, "space-science-pack")
  add_pack(electrified_rail_packs, "metallurgic-science-pack")
  add_pack(electrified_rail_packs, "electromagnetic-science-pack")
  add_pack(electrified_rail_packs, "agricultural-science-pack")
  add_pack(electrified_rail_packs, "cryogenic-science-pack")
else
  add_pack(electrified_rail_packs, "space-science-pack")
end

local battery_one_prerequisites = {"er-electric-traction", "processing-unit"}
local battery_two_prerequisites = {"er-battery-1"}
local battery_three_prerequisites = {"er-battery-2"}
local transformer_two_prerequisites = {"er-rail-transformer-1", "electric-energy-distribution-2"}
local transformer_three_prerequisites = {"er-rail-transformer-2", "er-battery-2"}

if mods["space-age"] then
  table.insert(battery_two_prerequisites, "electromagnetic-science-pack")
  table.insert(battery_three_prerequisites, "cryogenic-science-pack")
  table.insert(transformer_three_prerequisites, "cryogenic-science-pack")
end

data:extend({
  technology(
    "er-electric-traction",
    {"railway", "electric-engine", "advanced-circuit", "battery"},
    traction_packs,
    250,
    30,
    {
      {type = "unlock-recipe", recipe = "er-electric-locomotive"},
      {type = "unlock-recipe", recipe = "er-catenary-pole"},
    },
    "e-a-a"
  ),
  technology(
    "er-battery-1",
    battery_one_prerequisites,
    battery_one_packs,
    300,
    30,
    {{type = "unlock-recipe", recipe = "er-train-battery-1"}},
    "e-a-b"
  ),
  technology(
    "er-battery-2",
    battery_two_prerequisites,
    battery_two_packs,
    500,
    30,
    {{type = "unlock-recipe", recipe = "er-train-battery-2"}},
    "e-a-c"
  ),
  technology(
    "er-battery-3",
    battery_three_prerequisites,
    battery_three_packs,
    700,
    30,
    {{type = "unlock-recipe", recipe = "er-train-battery-3"}},
    "e-a-d"
  ),
  technology(
    "er-rail-transformer-1",
    {"er-electric-traction", "electric-energy-distribution-1"},
    traction_packs,
    200,
    30,
    {{type = "unlock-recipe", recipe = "er-rail-transformer-1"}},
    "e-b-a"
  ),
  technology(
    "er-rail-transformer-2",
    transformer_two_prerequisites,
    battery_one_packs,
    400,
    30,
    {{type = "unlock-recipe", recipe = "er-rail-transformer-2"}},
    "e-b-b"
  ),
  technology(
    "er-rail-transformer-3",
    transformer_three_prerequisites,
    electrified_rail_packs,
    800,
    45,
    {{type = "unlock-recipe", recipe = "er-rail-transformer-3"}},
    "e-b-c"
  ),
})

local locomotive = table.deepcopy(data.raw.locomotive.locomotive)
locomotive.name = "er-electric-locomotive"
locomotive.icon = "__ElectrifiedRailways__/graphics/electric-locomotive.png"
locomotive.icon_size = 32
locomotive.icon_mipmaps = nil
locomotive.minable = table.deepcopy(locomotive.minable)
locomotive.minable.result = "er-electric-locomotive"
locomotive.equipment_grid = "er-electric-locomotive-grid"
locomotive.energy_source = table.deepcopy(locomotive.energy_source)
locomotive.energy_source.fuel_categories = {"er-electric-fuel"}
locomotive.energy_source.fuel_inventory_size = 0
locomotive.energy_source.burnt_inventory_size = 0

local locomotive_item = table.deepcopy(data.raw["item-with-entity-data"].locomotive)
locomotive_item.name = "er-electric-locomotive"
locomotive_item.icon = locomotive.icon
locomotive_item.icon_size = 32
locomotive_item.icon_mipmaps = nil
locomotive_item.subgroup = "er-electric-locomotive"
locomotive_item.order = "a[locomotive]"
locomotive_item.place_result = locomotive.name

local fuel_category = {
  type = "fuel-category",
  name = "er-electric-fuel",
}

local hidden_charge = {
  type = "item",
  name = "er-electric-charge",
  icon = "__base__/graphics/icons/battery.png",
  icon_size = 64,
  hidden = true,
  fuel_value = "2MJ",
  fuel_acceleration_multiplier = 1,
  fuel_top_speed_multiplier = 1,
  fuel_categories = {"er-electric-fuel"},
  stack_size = 1,
}

local mobile_charger = table.deepcopy(data.raw["electric-energy-interface"]["electric-energy-interface"])
mobile_charger.name = "er-mobile-charger"
mobile_charger.icon = "__core__/graphics/empty.png"
mobile_charger.icon_size = 1
mobile_charger.hidden = true
mobile_charger.hidden_in_factoriopedia = true
mobile_charger.selectable_in_game = false
mobile_charger.minable = nil
mobile_charger.collision_box = nil
mobile_charger.selection_box = nil
mobile_charger.collision_mask = {layers = {}, not_colliding_with_itself = true}
mobile_charger.flags = {"not-on-map", "placeable-off-grid", "not-blueprintable", "not-deconstructable"}
mobile_charger.energy_source = {
  type = "electric",
  buffer_capacity = "10MJ",
  usage_priority = "secondary-input",
  input_flow_limit = "2MW",
  output_flow_limit = "0W",
  drain = "0W",
}
mobile_charger.energy_usage = "2MW"
mobile_charger.energy_production = "0W"
mobile_charger.gui_mode = "none"
mobile_charger.picture = {
  filename = "__core__/graphics/empty.png",
  priority = "extra-high",
  width = 1,
  height = 1,
}

data:extend({
  locomotive,
  locomotive_item,
  fuel_category,
  hidden_charge,
  mobile_charger,
  {
    type = "recipe",
    name = "er-electric-locomotive",
    enabled = false,
    energy_required = 10,
    ingredients = {
      {type = "item", name = "locomotive", amount = 1},
      {type = "item", name = "electric-engine-unit", amount = 10},
      {type = "item", name = "advanced-circuit", amount = 20},
      {type = "item", name = "battery", amount = 10},
    },
    results = {{type = "item", name = "er-electric-locomotive", amount = 1}},
  },
})

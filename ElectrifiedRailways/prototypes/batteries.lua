data:extend({
  {
    type = "equipment-category",
    name = "er-train-battery",
  },
  {
    type = "equipment-grid",
    name = "er-electric-locomotive-grid",
    width = 2,
    height = 2,
    equipment_categories = {"er-train-battery"},
  },
})

local battery_tiers = {
  {tier = 1, capacity = "5MJ", battery_count = 10, processing_units = 5, engines = 2},
  {tier = 2, capacity = "19MJ", battery_count = 20, processing_units = 20, engines = 6},
  {tier = 3, capacity = "124MJ", battery_count = 60, processing_units = 40, engines = 20},
}

local equipment_prototype = data.raw["battery-equipment"]["battery-equipment"]
local item_prototype = data.raw.item["battery-equipment"]
local created = {}

for _, tier in ipairs(battery_tiers) do
  local equipment_name = "er-train-battery-" .. tier.tier
  local item_name = equipment_name

  local equipment = table.deepcopy(equipment_prototype)
  equipment.name = equipment_name
  equipment.categories = {"er-train-battery"}
  equipment.shape = {width = 2, height = 2, type = "full"}
  equipment.take_result = item_name
  equipment.energy_source = table.deepcopy(equipment.energy_source)
  equipment.energy_source.buffer_capacity = tier.capacity
  equipment.energy_source.input_flow_limit = "2MW"
  equipment.energy_source.output_flow_limit = "2MW"

  local item = table.deepcopy(item_prototype)
  item.name = item_name
  item.icon = nil
  item.icon_size = nil
  item.icon_mipmaps = nil
  item.icons = {{icon = "__ElectrifiedRailways__/graphics/icons/" .. item_name .. ".png", icon_size = 64}}
  item.place_as_equipment_result = equipment_name
  item.subgroup = "er-electric-batteries"
  item.order = "a[battery]-" .. tier.tier
  item.stack_size = 20

  table.insert(created, equipment)
  table.insert(created, item)
  table.insert(created, {
    type = "recipe",
    name = item_name,
    enabled = false,
    energy_required = 10 * tier.tier,
    ingredients = {
      {type = "item", name = "battery", amount = tier.battery_count},
      {type = "item", name = "processing-unit", amount = tier.processing_units},
      {type = "item", name = "electric-engine-unit", amount = tier.engines},
    },
    results = {{type = "item", name = item_name, amount = 1}},
  })
end

data:extend(created)

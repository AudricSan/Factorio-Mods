local base_pole = data.raw["electric-pole"]["medium-electric-pole"]
local base_item = data.raw.item["medium-electric-pole"]

-- Porte de caténaire : le joueur pose un poteau à côté de la voie. Le script trace un bras en
-- treillis jusqu'au centre de la voie et les fils au centre (voir scripts/catenary.lua). Les graphismes viennent du poteau moyen vanilla, teinté
-- acier gris pour le distinguer.
local STEEL_TINT = {r = 0.78, g = 0.82, b = 0.9}

local function tint_layers(node)
  if node.layers then
    for _, layer in ipairs(node.layers) do
      if not layer.draw_as_shadow then
        layer.tint = STEEL_TINT
      end
    end
  elseif not node.draw_as_shadow then
    node.tint = STEEL_TINT
  end
end

local pole = table.deepcopy(base_pole)
pole.name = "er-catenary-pole"
pole.minable = {mining_time = 0.2, result = "er-catenary-pole"}
pole.fast_replaceable_group = nil
pole.next_upgrade = nil
pole.maximum_wire_distance = 30
-- Zone d'alimentation minimale : seule la porte, pas les machines alentour.
pole.supply_area_distance = 1
-- Le câble de cuivre vanilla n'est pas dessiné : c'est le câble de caténaire, tracé par le
-- script au centre de la voie, qui représente la connexion électrique entre deux portes.
-- La connexion reste réelle et s'efface avec l'outil de câble du jeu.
pole.draw_copper_wires = false
pole.draw_circuit_wires = false
tint_layers(pole.pictures)

local item = table.deepcopy(base_item)
item.name = "er-catenary-pole"
item.icons = {{icon = base_item.icon, icon_size = base_item.icon_size or 64, icon_mipmaps = base_item.icon_mipmaps, tint = STEEL_TINT}}
item.icon = nil
item.icon_size = nil
item.icon_mipmaps = nil
item.subgroup = "er-catenary"
item.order = "a[catenary-pole]"
item.place_result = "er-catenary-pole"
item.stack_size = 50

pole.icons = table.deepcopy(item.icons)
pole.icon = nil
pole.icon_size = nil
pole.icon_mipmaps = nil

data:extend({
  pole,
  item,
  {
    type = "recipe",
    name = "er-catenary-pole",
    enabled = false,
    energy_required = 0.5,
    ingredients = {
      {type = "item", name = "steel-plate", amount = 2},
      {type = "item", name = "copper-cable", amount = 5},
      {type = "item", name = "iron-stick", amount = 4},
    },
    results = {{type = "item", name = "er-catenary-pole", amount = 1}},
  },
})

local MIN_TIME = 0.0011

for _, recipe in pairs(data.raw["recipe"]) do
  recipe.energy_required = MIN_TIME
end

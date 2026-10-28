# Electrified Railways — page du mod (mods.factorio.com)

## Catégorie et étiquettes

- **Catégorie** : Content (le mod ajoute une locomotive, des objets et des technologies)
- **Étiquettes** : Trains, Power, Transportation
- **Version de Factorio** : 2.1
- **Dépendances facultatives** : Space Age, Elevated Rails
- **Licence** : GPL-3.0

## Résumé (champ « Summary », une ligne)

An electric locomotive powered by catenary gates, rechargeable batteries and rail transformers.

## Description (onglet « Description », Markdown)

Electrified Railways adds electric trains to Factorio 2.1 using the normal vanilla rails: no dedicated rail, no fuel.

### Electric locomotive
- One electric locomotive with the speed and power of the vanilla locomotive (600 kW).
- A 2x2 equipment grid takes one rechargeable battery: **Battery I, II or III** (5, 19 and 124 MJ). They replace each other.
- With a battery, a loco and 3 empty wagons travel about 320, 1,230 and 8,000 tiles.
- When it runs out of energy the train stops and raises the usual "out of fuel" alert.

### Catenary gates
- Place a **catenary pole** next to any track: straight, diagonal or curved. It snaps to a fixed slot next to the rail, like a train signal, and cannot be stacked.
- A truss arm reaches the middle of the track and carries a real **double wire** (messenger wire and contact wire with droppers), drawn at the center of the track.
- Gates connect to each other and to your power grid with the game's own wire tool, up to **30 tiles apart**. Red and green circuit wires also run through the center of the track. Erase a wire and the track loses power.
- A gate powers its rail, its neighbours on the same track and every track under the wire between two gates. Ordinary electric poles do **not** power trains.

### Rail transformers
- Place a transformer next to a straight rail, like a train stop. It powers **every rail connected** to that track, ground-level and elevated, with no length limit.
- Three tiers set the power shared by all trains on the rail network: **2 MW, 40 MW and 100 MW**. Place a higher tier over a lower one to upgrade.

### Balance
- Consumption was **measured in game**: the heavier the train, the more energy it needs. Full tables (empty and loaded trains, battery range, recipes) are in the changelog and the README.
- Cargo adds up to +50% consumption.

### Debug
`/er-debug` shows which rails are powered: green for a transformer, cyan for several, orange for a gate, red for none.

### Compatibility
Works with Space Age and Elevated Rails (transformers also power elevated rails and ramps; catenary gates do not). Languages: English, French.

### Credits
The locomotive concept builds on *ElectricTrainFix* by magu5026 and the powered-rail idea on *James' Electric Trains Plus* by JamesFire. Maintained by AudricSan. GPL-3.0.

## Description courte (champ « description » de info.json, déjà en place)

A single electric locomotive powered by catenary poles, batteries, and rail transformers that power every connected rail.

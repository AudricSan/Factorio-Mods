# Electrified Railways — récapitulatif équilibrage

Version du mod : 0.3.25. Les consommations sont **mesurées en jeu** (Factorio 2.1.23, voie droite de 766 cases, locomotive vanilla dont la locomotive électrique reprend la puissance et la physique).

## 1. Puissances

| Élément | Valeur | Remarque |
| --- | --- | --- |
| Locomotive électrique | 600 kW | Puissance maximale en accélération, à vide |
| Locomotive, chargement maximal | 900 kW | Multiplicateur de chargement plafonné à ×1,5 |
| Recharge d'une batterie | 2 MW | Débit maximal sous caténaire, sur rail alimenté ou en gare alimentée |
| Transformateur I | 2 MW | Partagé entre tous les trains du réseau de rails connecté |
| Transformateur II | 40 MW | Idem |
| Transformateur III | 100 MW | Idem |
| Poteau de caténaire | 2 MW par locomotive | Alimente le rail de la porte et les voies sous le fil de contact, jusqu'à 30 cases entre deux portes |

### Locomotives en pleine puissance par transformateur

| Transformateur | Puissance | Locomotives à vide (600 kW) | Locomotives chargées (900 kW) |
| --- | --- | --- | --- |
| I | 2 MW | 3 | 2 |
| II | 40 MW | 66 | 44 |
| III | 100 MW | 166 | 111 |

## 2. Capacité des batteries

| Batterie | Capacité | Temps de recharge à 2 MW |
| --- | --- | --- |
| I | 5 MJ | 2,5 s |
| II | 19 MJ | 9,5 s |
| III | 124 MJ | 62 s |

Objectif d'équilibrage : loco + 3 wagons à vide parcourt environ 300 / 1 200 / 8 000 cases.

## 3. Consommation par poids de train

Le poids d'un train est 2 000 pour la locomotive plus 1 000 par wagon. Le chargement ne change pas la physique de Factorio : seul le multiplicateur du mod s'applique en plus.

- **Vide** : multiplicateur ×1.
- **Plein** : multiplicateur ×1,5 (plafond). Le multiplicateur vaut 1 + min(poids du chargement ÷ poids du train à vide ; 0,5). Les objets utilisent leur poids Factorio (une plaque de fer = 100), les autres sont estimés à 10 par pile, les fluides à 0,25 par unité. Dès que le chargement pèse la moitié du train vide, le plafond est atteint : 25 plaques de fer suffisent pour loco + 3 wagons.

| Composition | Poids | Énergie sur 766 cases (vide) | Énergie par case, vide | Énergie par case, plein (×1,5) | Vitesse max | Durée du trajet |
| --- | --- | --- | --- | --- | --- | --- |
| Locomotive seule | 2 000 | 7,49 MJ | 9,8 kJ | 14,7 kJ | 257 km/h | 16,5 s |
| Loco + 1 wagon | 3 000 | 8,93 MJ | 11,7 kJ | 17,5 kJ | 231 km/h | 19,0 s |
| Loco + 2 wagons | 4 000 | 10,38 MJ | 13,6 kJ | 20,4 kJ | 209 km/h | 21,2 s |
| Loco + 3 wagons | 5 000 | 11,84 MJ | 15,5 kJ | 23,3 kJ | 191 km/h | 23,5 s |
| Loco + 4 wagons | 6 000 | 13,34 MJ | 17,4 kJ | 26,1 kJ | 175 km/h | 25,8 s |
| Loco + 6 wagons | 8 000 | 16,56 MJ | 21,6 kJ | 32,4 kJ | 148 km/h | 30,7 s |
| Loco + 8 wagons | 10 000 | 20,27 MJ | 26,5 kJ | 39,8 kJ | 124 km/h | 36,5 s |

## 4. Autonomie sur batterie (en cases)

Sans caténaire ni transformateur. « Vide » = ×1, « plein » = ×1,5.

| Composition | Batt. I vide | Batt. I plein | Batt. II vide | Batt. II plein | Batt. III vide | Batt. III plein |
| --- | --- | --- | --- | --- | --- | --- |
| Locomotive seule | 511 | 341 | 1 943 | 1 295 | 12 681 | 8 454 |
| Loco + 1 wagon | 429 | 286 | 1 630 | 1 087 | 10 637 | 7 091 |
| Loco + 2 wagons | 369 | 246 | 1 402 | 935 | 9 151 | 6 100 |
| Loco + 3 wagons | 323 | 216 | 1 229 | 819 | 8 022 | 5 348 |
| Loco + 4 wagons | 287 | 191 | 1 091 | 727 | 7 120 | 4 747 |
| Loco + 6 wagons | 231 | 154 | 879 | 586 | 5 736 | 3 824 |
| Loco + 8 wagons | 189 | 126 | 718 | 479 | 4 686 | 3 124 |

## 5. Recettes de fabrication

Les recettes sont des valeurs initiales, à rééquilibrer.

| Objet | Temps | Ingrédients |
| --- | --- | --- |
| Locomotive électrique | 10 s | 1 locomotive, 10 moteurs électriques, 20 circuits avancés, 10 batteries |
| Batterie I | 10 s | 10 batteries, 5 processeurs, 2 moteurs électriques |
| Batterie II | 20 s | 20 batteries, 20 processeurs, 6 moteurs électriques |
| Batterie III | 30 s | 60 batteries, 40 processeurs, 20 moteurs électriques |
| Poteau de caténaire | 0,5 s | 4 plaques d'acier, 10 câbles de cuivre, 5 bâtons de fer |
| Transformateur I | 5 s | 20 plaques d'acier, 30 câbles de cuivre, 30 circuits électroniques |
| Transformateur II | 10 s | 2 transformateurs I, 30 plaques d'acier, 60 câbles de cuivre, 20 circuits avancés |
| Transformateur III | 15 s | 3 transformateurs II, 60 plaques d'acier, 140 câbles de cuivre, 20 processeurs |

### Coût total des transformateurs (en partant de zéro)

| Transformateur | Plaques d'acier | Câbles de cuivre | Circuits électroniques | Circuits avancés | Processeurs |
| --- | --- | --- | --- | --- | --- |
| I | 20 | 30 | 30 | – | – |
| II | 70 | 120 | 60 | 20 | – |
| III | 270 | 500 | 180 | 60 | 20 |

## 6. Technologies

| Technologie | Débloque | Coût |
| --- | --- | --- |
| Traction électrique | Locomotive, poteau de caténaire | 250 × 30 s, sciences rouge, verte et bleue |
| Batterie I | Batterie I | 300 × 30 s, + production et utilité |
| Batterie II | Batterie II | 500 × 30 s, + électromagnétique avec Space Age |
| Batterie III | Batterie III | 700 × 30 s, + cryogénique avec Space Age, spatiale sinon |
| Transformateur de rail I | Transformateur I | 200 × 30 s, sciences rouge, verte et bleue |
| Transformateur de rail II | Transformateur II | 400 × 30 s, + production et utilité |
| Transformateur de rail III | Transformateur III | 800 × 45 s, toutes les sciences (Space Age : spatiale, métallurgique, électromagnétique, agricole, cryogénique) |

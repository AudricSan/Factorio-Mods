# Electrified Railways

Electrified Railways réunit dans un seul mod Factorio 2.1 une locomotive électrique, des batteries rechargeables, des poteaux de caténaire et des transformateurs qui alimentent les rails normaux.

## Fonctionnement

- Le mod ajoute une seule locomotive électrique, avec la vitesse et la puissance de la locomotive vanilla comme base d’équilibrage.
- Sa grille d’équipement de 2×2 accepte une batterie à la fois. Les batteries I, II et III sont des améliorations de capacité qui se remplacent mutuellement.
- **Transformateur de rail** (3 niveaux) : se place comme une gare. Tu le poses près d’un rail droit, à 1 à 3 cases de son axe : il se colle automatiquement à la case voisine et se tourne vers la voie, sur les voies nord-sud comme est-ouest. Sans rail droit à côté, la pose est refusée avec un message et l’objet t’est rendu. Il se relie au réseau électrique par un poteau. Il alimente **tous les rails connectés** à cette voie, au sol comme surélevés, sans limite de longueur. Le niveau fixe la puissance maximale, partagée entre tous les trains du réseau de rails : I = 5 MW, II = 20 MW, III = 60 MW. On passe d’un niveau au suivant en posant le nouveau par-dessus.
- **Porte de caténaire** : on pose un poteau de caténaire à côté d’une voie droite, à 1 à 4 cases de son axe. Le mod détecte si le rail est à gauche ou à droite du poteau et pose automatiquement un poteau miroir de l’autre côté, avec une poutre en treillis au-dessus de la voie et les fils au centre de la voie, reliés d’une porte à la suivante. Une porte alimente le rail qu’elle enjambe et ses voisins directs, ainsi que toutes les voies qui passent sous le câble de caténaire la reliant à une autre porte. Les poteaux se relient entre eux et au réseau par des câbles de cuivre, jusqu’à 30 cases d’écart (comme un grand poteau), ce qui permet d’espacer les portes le long d’une voie. Les deux poteaux de la porte sont sélectionnables : on peut tirer un câble depuis l’un ou l’autre, ou retirer l’un des deux pour retirer toute la porte. Le câble de cuivre du jeu n’est pas dessiné sur les portes. Entre deux portes d’une même voie, c’est le câble de caténaire, au centre de la voie, qui représente la connexion. Pour relier une porte au réseau électrique ordinaire, tu tires un câble de cuivre avec l’outil de câble du jeu vers n’importe quel poteau : un câble extérieur est alors tracé du sommet du poteau de la porte à ce poteau, avec l’affaissement d’un câble du jeu. Il en va de même entre deux portes de voies différentes. C’est une vraie connexion électrique, le courant y circule et on l’efface avec l’outil de câble du jeu : la voie qui n’est plus sous un câble perd son alimentation. Seules les portes alimentent les trains : les poteaux électriques ordinaires ne comptent plus. La porte fonctionne sur les voies droites, les diagonales et dans les virages : la poutre se place perpendiculairement à la voie à l’endroit du poteau. La caténaire n’alimente pas les rails surélevés.
- Les rails sont les rails vanilla. Il n’y a plus de rail électrifié dédié.
- Les batteries se rechargent sous une caténaire, sur un rail alimenté par un transformateur ou dans une gare alimentée.
- La consommation vient de deux sources qui se cumulent. D’abord la physique de Factorio : plus le train a de wagons, plus la locomotive doit fournir d’énergie (voir le tableau mesuré). Ensuite un multiplicateur de chargement propre au mod : les objets utilisent leur poids Factorio lorsqu’il est défini, les autres sont estimés à 10 unités par pile, les fluides à 0,25 unité par unité de fluide. Ce multiplicateur est plafonné à 1,5×.
- Une locomotive à court d’énergie s’arrête et déclenche l’alerte Factorio de manque de carburant.

## Tableau de consommation (mesuré)

Ces valeurs ne sont pas des estimations : elles ont été mesurées en jeu (Factorio 2.1.23) sur une voie droite de 766 cases, avec une locomotive vanilla, dont la locomotive électrique reprend la puissance (600 kW) et la physique. Chaque trajet comprend l’accélération, la croisière et le freinage jusqu’à une gare. Le poids d’un train est 2 000 pour la locomotive plus 1 000 par wagon.

Le chargement ne modifie pas la physique : un wagon chargé de 4 000 plaques de fer donne exactement les mêmes résultats qu’un wagon vide. Seul le multiplicateur propre au mod tient compte du chargement.

### Consommation par composition de train (à vide)

| Composition      | Poids  | Énergie par trajet de 766 cases | Énergie par case | Surcoût du dernier wagon | Vitesse max atteinte | Durée du trajet |
| ---------------- | ------ | ------------------------------- | ---------------- | ------------------------ | -------------------- | --------------- |
| Locomotive seule | 2 000  | 7,49 MJ                         | 9,8 kJ           | –                        | 257 km/h             | 16,5 s          |
| Loco + 1 wagon   | 3 000  | 8,93 MJ                         | 11,7 kJ          | +1,44 MJ                 | 231 km/h             | 19,0 s          |
| Loco + 2 wagons  | 4 000  | 10,38 MJ                        | 13,6 kJ          | +1,45 MJ                 | 209 km/h             | 21,2 s          |
| Loco + 3 wagons  | 5 000  | 11,84 MJ                        | 15,5 kJ          | +1,46 MJ                 | 191 km/h             | 23,5 s          |
| Loco + 4 wagons  | 6 000  | 13,34 MJ                        | 17,4 kJ          | +1,50 MJ                 | 175 km/h             | 25,8 s          |
| Loco + 6 wagons  | 8 000  | 16,56 MJ                        | 21,6 kJ          | +1,61 MJ                 | 148 km/h             | 30,7 s          |
| Loco + 8 wagons  | 10 000 | 20,27 MJ                        | 26,5 kJ          | +1,86 MJ                 | 124 km/h             | 36,5 s          |

Le surcoût par wagon augmente avec la longueur du train, et la vitesse maximale baisse parce que la locomotive a une puissance fixe.

### Capacités des batteries

Choisies pour que le train de référence (loco + 3 wagons, à vide) parcoure environ 300, 1 200 et 8 000 cases.

| Batterie | Capacité | Cases pour loco + 3 wagons, à vide |
| -------- | -------- | ---------------------------------- |
| I        | 5 MJ     | 323                                |
| II       | 19 MJ    | 1 229                              |
| III      | 124 MJ   | 8 022                              |

### Distance parcourue sur batterie (en cases)

Calculée avec l’énergie par case ci-dessus. Le multiplicateur de chargement s’applique en plus : « à vide » correspond à ×1, « au plafond » à ×1,5.

| Composition      | Batterie I, à vide | Batterie I, au plafond | Batterie II, à vide | Batterie II, au plafond | Batterie III, à vide | Batterie III, au plafond |
| ---------------- | ------------------ | ---------------------- | ------------------- | ----------------------- | -------------------- | ------------------------ |
| Locomotive seule | 511                | 341                    | 1 943               | 1 295                   | 12 681               | 8 454                    |
| Loco + 1 wagon   | 429                | 286                    | 1 630               | 1 087                   | 10 637               | 7 091                    |
| Loco + 2 wagons  | 369                | 246                    | 1 402               | 935                     | 9 151                | 6 100                    |
| Loco + 3 wagons  | 323                | 216                    | 1 229               | 819                     | 8 022                | 5 348                    |
| Loco + 4 wagons  | 287                | 191                    | 1 091               | 727                     | 7 120                | 4 747                    |
| Loco + 6 wagons  | 231                | 154                    | 879                 | 586                     | 5 736                | 3 824                    |
| Loco + 8 wagons  | 189                | 126                    | 718                 | 479                     | 4 686                | 3 124                    |

### Locomotives alimentées par transformateur

Une locomotive en accélération complète demande 600 kW à vide, 900 kW avec le multiplicateur maximal. Nombre de locomotives en pleine puissance que chaque transformateur peut alimenter en même temps.

| Transformateur | Puissance | Locomotives à vide | Locomotives au plafond |
| -------------- | --------- | ------------------ | ---------------------- |
| I              | 5 MW      | 8                  | 5                      |
| II             | 20 MW     | 33                 | 22                     |
| III            | 60 MW     | 100                | 66                     |

## Recettes

Les recettes sont des valeurs initiales, encore ajustables.

| Objet                 | Ingrédients initiaux                                                             |
| --------------------- | -------------------------------------------------------------------------------- |
| Locomotive électrique | 1 locomotive, 10 moteurs électriques, 20 circuits avancés, 10 batteries          |
| Batterie I            | 10 batteries, 5 processeurs, 2 moteurs électriques                               |
| Batterie II           | 20 batteries, 10 processeurs, 4 moteurs électriques                              |
| Batterie III          | 40 batteries, 20 processeurs, 6 moteurs électriques                              |
| Poteau de caténaire   | 2 plaques d’acier, 5 câbles en cuivre, 4 bâtons de fer                           |
| Transformateur I      | 10 plaques d’acier, 30 câbles en cuivre, 10 circuits électroniques               |
| Transformateur II     | 1 transformateur I, 20 plaques d’acier, 60 câbles en cuivre, 10 circuits avancés |
| Transformateur III    | 1 transformateur II, 40 plaques d’acier, 120 câbles en cuivre, 10 processeurs    |

## Technologies

- **Traction électrique** : locomotive et poteau de caténaire, autour des circuits bleus.
- **Batteries I à III** : la batterie I suit les circuits bleus, les niveaux II et III arrivent avec les recherches avancées de Space Age.
- **Transformateurs de rail I à III** : le niveau I demande la distribution électrique I, le niveau II la distribution électrique II, le niveau III la batterie II. Aucune ne demande de science au prométhium.

## Débogage

La commande `/er-debug` active ou désactive un affichage autour du joueur, visible uniquement par lui :

- **Vert** : rail alimenté par un transformateur. **Cyan** : rail alimenté par plusieurs transformateurs. **Orange** : rail alimenté par une porte de caténaire. **Rouge** : rail non alimenté.
- **Cercle jaune** : zone où le transformateur cherche ses rails de départ, avec une ligne vers chacun. Un texte au-dessus indique sa puissance, le nombre de rails alimentés et son tampon d’énergie.
- **Cercle orange** : portée d’une porte de caténaire. Il devient rouge si la porte n’est reliée à aucun réseau électrique.
- Un résumé affiche le nombre de rails alimentés et non alimentés dans un rayon de 60 cases.

Quand tu poses ou retires un rail ou un transformateur, l’alimentation est recalculée sous une demi-seconde.

## Graphismes

Le poteau de caténaire reprend le poteau moyen du jeu de base, légèrement teinté cuivre. La poutre, les suspentes et les fils de la porte sont tracés par le script. Les transformateurs reprennent la partie « niveau du rail » des gares vanilla, teintée selon le niveau (bleu, orange, rouge) ; leur orientation suit la voie et ne se change pas à la main. Aucune image n’est dessinée pour le mod, sauf l’icône de la locomotive.

## Compatibilité

Space Age et Elevated Rails sont des dépendances facultatives. Un transformateur alimente aussi les rails surélevés et les rampes qui lui sont connectés, la porte de caténaire non.

## Installation

Installe uniquement le dossier `ElectrifiedRailways` dans le dossier `mods` de Factorio, ou utilise le zip créé par `build-mod.ps1` à la racine du dépôt.

## Crédits et licence

L’icône de la locomotive provient d’ElectricTrainFix de magu5026; la licence GPL-3.0 de ce mod est incluse ici et s’applique au mod fusionné. Le concept de rails alimentés s’inspire de James’ Electric Trains Plus de JamesFire. Le mod fusionné est maintenu par AudricSan.

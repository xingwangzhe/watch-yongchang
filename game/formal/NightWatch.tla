-------------------- MODULE NightWatch --------------------
EXTENDS Naturals, Integers, FiniteSets

CONSTANTS MaxHealth, MaxOil, MaxLevel, ScaleColors
ASSUME MaxHealth \in Nat \ {0}
ASSUME MaxOil \in Nat
ASSUME MaxLevel \in Nat \ {0}
ASSUME ScaleColors = {"red", "yellow", "blue", "green", "black"}

VARIABLES health, alive, oil, dark, xp, level, scales, clears
vars == <<health, alive, oil, dark, xp, level, scales, clears>>

Init ==
    /\ health = MaxHealth
    /\ alive = TRUE
    /\ oil = MaxOil
    /\ dark = (MaxOil = 0)
    /\ xp = 0
    /\ level = 1
    /\ scales = {}
    /\ clears = FALSE

TakeDamage(amount) ==
    /\ amount \in 1..3
    /\ health > 0
    /\ health' = IF health > amount THEN health - amount ELSE 0
    /\ alive' = (health' > 0)
    /\ UNCHANGED <<oil, dark, xp, level, scales, clears>>

DrainOil ==
    /\ oil > 0
    /\ oil' = oil - 1
    /\ dark' = (oil' = 0)
    /\ UNCHANGED <<health, alive, xp, level, scales, clears>>

CollectOil ==
    /\ oil < MaxOil
    /\ oil' = oil + 1
    /\ dark' = FALSE
    /\ UNCHANGED <<health, alive, xp, level, scales, clears>>

CollectEssence ==
    /\ xp < 8
    /\ xp' = IF xp + (IF dark THEN 3 ELSE 2) > 8
              THEN 8
              ELSE xp + (IF dark THEN 3 ELSE 2)
    /\ UNCHANGED <<health, alive, oil, dark, level, scales, clears>>

ChooseUpgrade ==
    /\ xp >= 4
    /\ level < MaxLevel
    /\ xp' = xp - 4
    /\ level' = level + 1
    /\ UNCHANGED <<health, alive, oil, dark, scales, clears>>

CollectScale(color) ==
    /\ color \in ScaleColors \ scales
    /\ IF Cardinality(scales) = 4
          THEN /\ scales' = {}
               /\ clears' = TRUE
          ELSE /\ scales' = scales \cup {color}
               /\ clears' = clears
    /\ UNCHANGED <<health, alive, oil, dark, xp, level>>

Next ==
    \/ \E amount \in 1..3 : TakeDamage(amount)
    \/ DrainOil
    \/ CollectOil
    \/ CollectEssence
    \/ ChooseUpgrade
    \/ \E color \in ScaleColors : CollectScale(color)

Spec == Init /\ [][Next]_vars

TypeOK ==
    /\ health \in 0..MaxHealth
    /\ alive \in BOOLEAN
    /\ oil \in 0..MaxOil
    /\ dark \in BOOLEAN
    /\ xp \in 0..8
    /\ level \in 1..MaxLevel
    /\ scales \subseteq ScaleColors
    /\ Cardinality(scales) \leq 4
    /\ clears \in BOOLEAN

HealthMatchesAlive == alive = (health > 0)
OilControlsDarkness == (oil = 0) <=> dark
FiveUniqueScalesBounded == Cardinality(scales) \leq 4
LevelNeverExceedsCap == level \leq MaxLevel

============================================================

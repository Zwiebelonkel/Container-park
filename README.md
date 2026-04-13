# 🚢 Anomaly Game – Godot 4.4 Starter
## Containerschiff Horror | PSX-Optik | Anomalie-Detection

---

## 📁 Projektstruktur

```
res://
├── scripts/
│   ├── GameManager.gd        ← Autoload-Singleton (Kern-Logik)
│   ├── RoomController.gd     ← Root der Room-Szene
│   ├── Player.gd             ← First-Person Controller
│   └── AnomalyManager.gd     ← Spawnt/Entfernt Anomalien
├── anomalies/
│   ├── BaseAnomaly.gd        ← Basisklasse (von allen erben)
│   ├── LightFlicker.gd       ← Licht flackert
│   ├── ObjectMissing.gd      ← Objekt verschwindet
│   ├── ObjectMoved.gd        ← Objekt ist verschoben
│   └── GhostObject.gd        ← Neues Objekt erscheint
├── ui/
│   └── GameUI.gd             ← HUD (Score, Buttons, Feedback)
└── assets/
    └── shaders/
        └── psx_postprocess.gdshader  ← PSX/Horror Post-Processing
```

---

## 🚀 Setup-Anleitung (Schritt für Schritt)

### 1. GameManager als Autoload einrichten

```
Projekt → Projekteinstellungen → Autoload
[+] Pfad: res://scripts/GameManager.gd
    Name: GameManager
```

### 2. Input-Map konfigurieren

```
Projekt → Projekteinstellungen → Eingabe-Map

Neue Aktionen anlegen:
  move_forward  → W / Joystick oben
  move_back     → S / Joystick unten
  move_left     → A / Joystick links
  move_right    → D / Joystick rechts
  anomaly_yes   → E / Taste 1 / Controller-B
  anomaly_no    → Q / Taste 2 / Controller-A
  look_up       → (für Controller)
  look_down     → (für Controller)
  look_left     → (für Controller)
  look_right    → (für Controller)
```

### 3. Room-Szene (room.tscn) aufbauen

```
Node3D  [RoomController.gd]
├── WorldEnvironment
│    └── Environment (PSX-Einstellungen: Glow aus, niedrige Schatten)
├── Environment/
│    ├── MainLight (OmniLight3D)  ← Wichtig für LightFlicker-Anomalie
│    ├── DirectionalLight3D
│    └── FogVolume (optional, für Atmosphäre)
├── Props/
│    ├── Barrel (MeshInstance3D mit StaticBody3D+CollisionShape3D)
│    ├── Crate  (MeshInstance3D mit StaticBody3D+CollisionShape3D)
│    └── Chair  (MeshInstance3D mit StaticBody3D+CollisionShape3D)
├── SpawnPoints/ (Node3D als Container)
│    ├── Spawn1 (Node3D) ← Position wo Anomalien erscheinen können
│    ├── Spawn2 (Node3D)
│    └── Spawn3 (Node3D)
├── PlayerStart (Marker3D) ← Startposition des Spielers
├── AnomalyManager (Node) [AnomalyManager.gd]
├── Player (CharacterBody3D) [Player.gd]
│    ├── CollisionShape3D (CapsuleShape3D)
│    └── Head (Node3D)
│         └── Camera3D
└── UI (CanvasLayer) [GameUI.gd]
     └── HUD (Control) - Ankerpunkt: Vollbild
          ├── TopBar (HBoxContainer)
          │    ├── ScoreLabel (Label)
          │    ├── StreakLabel (Label)
          │    └── TimerBar (ProgressBar, min=0, max=100, value=100)
          ├── BottomBar (HBoxContainer)
          │    ├── BtnNormal (Button) Text: "ALLES NORMAL [Q]"
          │    └── BtnAnomaly (Button) Text: "ANOMALIE! [E]"
          ├── FeedbackLabel (Label) - mittig, große Schrift
          └── GameOverPanel (Panel) - zentriert
               ├── GameOverTitle (Label) Text: "GAME OVER"
               ├── FinalScoreLabel (Label)
               └── RestartButton (Button) Text: "NOCHMAL"
```

### 4. AnomalyManager konfigurieren (Inspector)

```
AnomalyManager-Node auswählen → Inspector:
  Anomaly Scenes: [
    preload("res://anomalies/LightFlicker.tscn"),
    preload("res://anomalies/ObjectMissing.tscn"),
    preload("res://anomalies/ObjectMoved.tscn"),
    preload("res://anomalies/GhostObject.tscn")
  ]
  Spawn Points: [
    NodePath("../SpawnPoints/Spawn1"),
    NodePath("../SpawnPoints/Spawn2"),
    ...
  ]
  Room Root: NodePath("..")   ← Zeigt auf den Room-Root-Node
```

### 5. Anomalie-Szenen erstellen

Für jede Anomalie eine eigene .tscn:

**LightFlicker.tscn:**
```
Node → Script: LightFlicker.gd
  Inspector: target_light_name = "MainLight"
```

**ObjectMissing.tscn:**
```
Node → Script: ObjectMissing.gd
  Inspector: target_object_names = ["Barrel", "Crate", "Chair"]
```

**ObjectMoved.tscn:**
```
Node → Script: ObjectMoved.gd
  Inspector: target_object_names = ["Chair", "Barrel"]
```

**GhostObject.tscn:**
```
Node3D → Script: GhostObject.gd
  └── MeshInstance3D (z.B. Cylinder mit unheimlichem Material)
```

### 6. PSX-Shader einrichten (optional aber empfohlen)

```
SubViewport (aktiviere: Own World 3D = false, Transparent BG = false)
  └── Camera3D (deine Hauptkamera hierher verschieben)

SubViewportContainer (Vollbild, Layout: Anker = Vollbild)
  └── ColorRect (Vollbild)
       └── ShaderMaterial: psx_postprocess.gdshader
```

**Oder einfacher:** ColorRect als Overlay über alles legen mit dem Shader.

---

## 🎮 Spielablauf

```
GameManager.start_game()
    ↓
start_round()
    ↓
AnomalyManager spawnt (oder nicht) eine Anomalie
    ↓
Spieler erkundet den Raum
    ↓
Spieler drückt [E] = "Anomalie" oder [Q] = "Normal"
    ↓
check_answer() → richtig: nächste Runde mit Fade
              → falsch:  Game Over
```

---

## ➕ Neue Anomalie erstellen

```gdscript
# MyAnomalie.gd
extends BaseAnomaly

func _apply() -> void:
    var obj = find_in_room("MeinObjekt")
    if obj:
        obj.visible = false  # oder was auch immer

func _revert() -> void:
    var obj = find_in_room("MeinObjekt")
    if obj:
        obj.visible = true
```

Dann `MyAnomalie.tscn` erstellen, Script zuweisen, in `AnomalyManager.anomaly_scenes` eintragen. **Fertig.**

---

## 💡 Ideen für weitere Anomalien

| Anomalie | Implementierung |
|---|---|
| Schatten falsch | OmniLight3D Position verschieben |
| Tür offen | Door-Node Rotation ändern |
| Schrift anders | Label3D Text wechseln |
| Wasser-Level | MeshInstance3D Y-Position |
| Geräusch (nur Audio) | AudioStreamPlayer3D |
| Zeitverzerrung | Engine.time_scale |
| Zweites Objekt | Unsichtbares Objekt sichtbar machen |
| Textur gewechselt | material_override setzen |

---

## ⚙️ GameManager-Einstellungen (Inspector)

```
anomaly_chance: 0.5        → 50% Chance pro Runde (0.0–1.0)
rounds_to_win: 10          → nach 10 richtigen: Sieg (0 = unendlich)
time_limit_per_round: 15.0 → Sekunden pro Runde (0 = kein Limit)
```

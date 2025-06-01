from dataclasses import dataclass
from typing import List, Optional

@dataclass
class TargetMuscle:
    id: int
    name: str
    display_name: str

@dataclass
class Equipment:
    id: int
    name: str
    display_name: str

@dataclass
class Action:
    id: int
    name: str
    name_en: str
    image_url: str
    default_sets: int
    default_reps: int
    body_part_id: int
    equipment_id: int
    target_muscle_ids: List[int]
    
@dataclass
class BodyPart:
    id: int
    name: str
    display_name: str

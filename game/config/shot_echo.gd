class_name ShotEcho
extends Resource
## How a map's room answers the replicas' shots (EC1): the Shots bus's level and its reverb (Godot's
## AudioEffectReverb, the Shots bus's first effect). Every shot plays through the Shots bus (its shot, its power part,
## a silenced one's too, heard open or through cover); a map with no echo leaves that bus at 0 dB with its reverb off,
## so it sounds as it always has. The defaults are an underground station's tiled halls and platforms (the owner,
## 2026-11-12: Subway's shots "a bit more volume and reverb"): a short, bright slap and a tail of about a second,
## kept light so a replica still sounds like a toy, not a firearm.

## How much louder the shots play (dB, on the Shots bus).
@export var gain_db: float = 2.0
## The reverb's room (0 small .. 1 large) and how much of the high end each reflection loses (0 bright tiles .. 1 soft).
@export var room_size: float = 0.72
@export var damping: float = 0.35
## The stereo width of the tail (0 .. 1).
@export var spread: float = 0.9
## A high-pass on the tail (0 .. 1), so the echo doesn't boom under a motor's whir.
@export var hipass: float = 0.25
## The gap (ms) before the first reflection, and how much of it feeds back (0 .. 1).
@export var predelay_ms: float = 28.0
@export var predelay_feedback: float = 0.2
## The shot as played (dry) and its echo (wet), each 0 .. 1.
@export var dry: float = 1.0
@export var wet: float = 0.28

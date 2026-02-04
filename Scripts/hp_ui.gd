class_name HpUI extends Control

func brighten(tex: TextureRect) -> void:
	var atlas: AtlasTexture = tex.texture
	atlas.region.position.x = 0

func darken(tex: TextureRect) -> void:
	var atlas: AtlasTexture = tex.texture
	atlas.region.position.x = 16

func set_hp(hp: int):
	if hp <= 0:
		darken($HP1)
		darken($HP2)
		darken($HP3)
	elif hp == 1:
		brighten($HP1)
		darken($HP2)
		darken($HP3)
	elif hp == 2:
		brighten($HP1)
		brighten($HP2)
		darken($HP3)
	elif hp == 3:
		brighten($HP1)
		brighten($HP2)
		brighten($HP3)

extends SceneTree
const Plan = preload("res://scripts/journey/layout.gd")
const Layout = preload("res://scripts/maps/world_layout.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var atlas := Image.create(Layout.SIZE.x,Layout.SIZE.y,false,Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	var locations := {}
	var hashes := {}
	for area in Plan.ORDER:
		var view := SubViewport.new()
		view.size = Vector2i(Plan.SIZES[area]/4)
		view.disable_3d = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		view.world_2d = World2D.new()
		root.add_child(view)
		var map: Node2D = load(Plan.scene(area)).instantiate()
		view.add_child(map)
		var camera := Camera2D.new()
		camera.position = Plan.SIZES[area]*.5
		camera.zoom = Vector2.ONE*.25
		view.add_child(camera)
		camera.make_current()
		await process_frame
		await RenderingServer.frame_post_draw
		var image := view.get_texture().get_image()
		var center := image.get_pixel(image.get_width()/2,image.get_height()/2)
		if center.r+center.g+center.b<.12:
			push_error("Terrain viewport did not render "+area)
			quit(1)
			return
		image.resize(Layout.REGIONS[area].size.x,Layout.REGIONS[area].size.y,Image.INTERPOLATE_LANCZOS)
		atlas.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Layout.REGIONS[area].offset)
		hashes[Plan.scene(area)] = FileAccess.get_sha256(Plan.scene(area))
		for pair in [["EvilBart","bart"],["Boss2NPC","boss2"],["BlankKitten","blankkitten"]]:
			var npc := map.get_node_or_null("Characters/"+pair[0]) as Node2D
			if npc != null:locations[pair[1]] = {"area":area,"local_position":npc.position}
		view.queue_free()
		await process_frame
	var texture := ImageTexture.create_from_image(atlas)
	texture.set_meta("boss_locations",locations)
	texture.set_meta("source_hashes",hashes)
	var error := ResourceSaver.save(texture,"res://resources/journey/world_terrain.res",ResourceSaver.FLAG_COMPRESS)
	print("JOURNEY MAP: ",Layout.SIZE," save=",error)
	quit(0 if error==OK else 1)

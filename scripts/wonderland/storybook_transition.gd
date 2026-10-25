extends RefCounted
## Region names only. Existing licensed font; no illustrations or story text.
static func begin(curtain:ColorRect,name:String) -> ShaderMaterial:
 var material:=ShaderMaterial.new();material.shader=preload("res://shaders/wonderland_page.gdshader")
 curtain.material=material;curtain.modulate=Color.WHITE
 var label:=curtain.get_node_or_null("StorybookRegion") as Label
 if label==null:
  label=Label.new();label.name="StorybookRegion";curtain.add_child(label)
  label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
  label.add_theme_font_override("font",preload("res://assets/ui/fonts/DejaVuSerifCondensed.ttf"))
  label.add_theme_font_size_override("font_size",34);label.add_theme_color_override("font_color",Color("#462945"))
  label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 label.text=name;label.modulate.a=0;label.show()
 return material
static func finish(curtain:ColorRect) -> void:
 curtain.material=null
 var label:=curtain.get_node_or_null("StorybookRegion")
 if label!=null:label.hide()

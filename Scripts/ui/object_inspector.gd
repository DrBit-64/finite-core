extends PanelContainer
class_name ObjectInspector

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var body_label: Label = $MarginContainer/VBoxContainer/BodyLabel

func show_placeholder(message: String) -> void:
	if title_label:
		title_label.text = "对象检查器"
	if body_label:
		body_label.text = message

func inspect_node(node: Node) -> void:
	if node == null:
		show_placeholder("未选择对象")
		return

	if title_label:
		title_label.text = node.name
	if body_label:
		var lines: Array[String] = [
			"类型：%s" % node.get_class(),
			"路径：%s" % node.get_path(),
		]
		body_label.text = "\n".join(lines)

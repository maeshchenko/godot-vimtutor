extends Control

const COLS: int = 80
const ROWS: int = 24

var cursor_row: int = 0
var cursor_col: int = 0
var top_line: int = 0

var font_size := 42
var font: Font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")

var char_w: float = 0.0
var char_h: float = 0.0
var ascent: float = 0.0

var lines: Array = []

@export var fg_color: Color = Color(1, 1, 1, 1) # текст
@export var bg_color: Color = Color(0, 0, 0, 0.8) # фон
@export var status_bg: Color = Color( 0.10, 0.10, 0.10, 1) # фон статус-строки
@export var cursor_bg: Color = Color( 0.85, 0.85, 0.20, 1) # фон ячейки курсора
@export var cursor_fg: Color = Color(0, 0, 0, 1) # символ под курсором

func _load_file(path: String) -> void:
	var content := ""
	if FileAccess.file_exists(path):
		content = FileAccess.get_file_as_string(path)
		
	# Нормализация переводов строк и разбиение - в винде переносы \r\n
	content = content.replace("\r", "")
	lines = content.split("\n", false)
	if lines.is_empty():
		lines = [""]
	print("Загружено строк: ", lines.size())
	
# нужно чтобы точно знать размеры символов, чтобы дальше расчитать сетку
func resolve_font_metrics() -> void:

	var size = font.get_char_size("W".unicode_at(0), font_size) # unicode_at переводит букву в unicode-число
	char_w = size.x
	char_h = size.y
	ascent = font.get_ascent(font_size)
	print("font_size: ", font_size)
	print("char_h: ", char_h)
	print("char_w: ", char_w)
	print("ascent: ", ascent)
	print("size: ", size)

# нужно чтобы окно терминала меняло размер ровно под символьную сетку
func recalc_frame_size() -> void:
	# TextGrid -> TerminalPadding -> TerminalFrame
	var terminal_padding_container := get_parent()
	if not (terminal_padding_container is MarginContainer):
		return
		
	var terminal_frame := (terminal_padding_container as MarginContainer).get_parent()
	if terminal_frame == null:
		return
		
	var ml := (terminal_padding_container as MarginContainer).get_theme_constant("margin_left")
	var mr := (terminal_padding_container as MarginContainer).get_theme_constant("margin_right")
	var mt := (terminal_padding_container as MarginContainer).get_theme_constant("margin_top")
	var mb := (terminal_padding_container as MarginContainer).get_theme_constant("margin_bottom")
	
	var w := COLS * char_w + ml + mr # ширина всей сетки (80 символов * ширина символа) + отступы слева справа
	var h := ROWS * char_h + mt + mb
	terminal_frame.custom_minimum_size = Vector2(ceil(w), ceil(h))
	print("Vector2(ceil(w), ceil(h)): ", Vector2(ceil(w), ceil(h)))
		
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	focus_mode = FOCUS_ALL
	grab_focus()
	resolve_font_metrics()
	recalc_frame_size()
	_load_file("res://data/tutor.ru.utf-8.txt")
	queue_redraw()
	
# queue_redraw() автоматически первый раз вызовет _draw()
func _draw() -> void:
	# Фон всей области TextGrid
	draw_rect(Rect2(Vector2.ZERO, size), bg_color, true) # последний true - это filled
	if font == null:
		return
		
	var visible_rows := ROWS - 1 # последняя строка - будет статус
	
	# рисуем видимые текстовые строки 
	for i in visible_rows:
		var file_row := top_line + i
		var line_text := ""
		if file_row < lines.size():
			line_text = String(lines[file_row]) # если файл не кончился - встравляем строку из файла
			if line_text.length() > COLS:
				line_text = line_text.substr(0, COLS) # обрезка текста без переноса
				
		var row_y := i * char_h
		var y_base := row_y + ascent # текущая высота сверху. Строка * высоту буквы + поправка на хвосты-шапки
		
		# Посимвольный вывод + инверсия под курсором
		for j in line_text.length():
			var x := j * char_w
			var ch := line_text.substr(j, 1)
			
			if file_row == cursor_row and j == cursor_col:
				draw_rect(Rect2(x, i * char_h, char_w, char_h), cursor_bg, true)
				draw_string(font, Vector2(x, y_base), ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, cursor_fg)
			else:
				draw_string(font, Vector2(x, y_base), ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, fg_color)
		
		# Если идем курсором вверх-вниз и новая позиция дальше чем конец строки - ставим его после последнего символа
		if file_row == cursor_row and cursor_col >= line_text.length() and cursor_col < COLS:
			var x := cursor_col * char_w
			draw_rect(Rect2(x, row_y, char_w, char_h), cursor_bg, true)
	
	# Статус-строка, последняя снизу
	var status_y := (ROWS - 1) * char_h
	draw_rect(Rect2(0, status_y, COLS * char_w, char_h), status_bg, true)
	var status := _build_status_text()
	draw_string(font, Vector2(0, status_y + ascent), status.substr(0, COLS), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, fg_color)
	
func _build_status_text() -> String:
	var total : int = max(1, lines.size())
	var line_num : int = cursor_row + 1
	var col_num : int = cursor_col + 1
	var percent : int = int(float(line_num) / float(total) * 100)
	
	return "sample.txt " + str(line_num) + "/" + str(total) + " col " + str(col_num) + " " + str(percent) + "%"
	
func clamp_cursor() -> void:
	cursor_row = clampi(cursor_row, 0 , max(0, lines.size() - 1))
	var line_len := 0
	if cursor_row < lines.size():
		line_len = String(lines[cursor_row]).length()
	var max_col : int = min(COLS - 1, max(0, line_len - 1))
	cursor_col = clampi(cursor_col, 0, max_col)
	
func ensure_visible_vertically() -> void:
	var visible_rows := ROWS - 1 # без последней строки - она статус
	var screen_row := cursor_row - top_line
	if screen_row < 0:
		top_line = cursor_row
	elif screen_row >= visible_rows:
		top_line = cursor_row - (visible_rows - 1)
	var max_top : int = max(0, lines.size() - visible_rows)
	top_line = clampi(top_line, 0, max_top)

func move_up() -> bool:
	if cursor_row > 0:
		cursor_row -= 1
		return true
	return false
	
func move_down() -> bool:
	if cursor_row < lines.size() - 1:
		cursor_row += 1
		return true
	return false
	
func move_left() -> bool:
	if cursor_col > 0:
		cursor_col -= 1
		return true
	return false
	
func move_right() -> bool:
	cursor_col += 1
	return true
	
	
	
# --- переменные для автоповтора нажатий
var repeat_delay := 0.3 # пауза перед началом повтора
var repeat_rate := 0.05 # интервал повторов

var previous_action := "" # будет "up", "down", "left" или "right"
var repeat_timer := 0.0

func _process(delta: float) -> void:
	var action := ""
	var moved := false
		
	# стрелки
	if Input.is_action_pressed("ui_up") or Input.is_physical_key_pressed(KEY_K):
		action = "up"
	elif Input.is_action_pressed("ui_down") or Input.is_physical_key_pressed(KEY_J):
		action = "down"
	elif Input.is_action_pressed("ui_left") or Input.is_physical_key_pressed(KEY_H):
		action = "left"
	elif Input.is_action_pressed("ui_right") or Input.is_physical_key_pressed(KEY_L):
		action = "right"
	
	if action != "":
		if action != previous_action:
			# новое нажатие - сразу делаем шаг
			match action:
				"up": moved = move_up()
				"down": moved = move_down()
				"left": moved = move_left()
				"right": moved = move_right()
			previous_action = action
			repeat_timer = repeat_delay
		
		else:
			# удержание - ждем таймер
			repeat_timer -= delta
			if repeat_timer <= 0.0:
				match action:
					"up": moved = move_up()
					"down": moved = move_down()
					"left": moved = move_left()
					"right": moved = move_right()
				repeat_timer = repeat_rate
	else:
		previous_action = ""
		
	if moved:
		clamp_cursor()
		ensure_visible_vertically()
		queue_redraw()
	
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		pass
	pass
	

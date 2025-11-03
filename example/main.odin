package main

import "core:time"
import "vendor:sdl3/ttf"

import sdl_backend "backend/sdl_gpu"
import sdl "vendor:sdl3"

import ui "../"
import widgets "widgets"

PRIMARY_COLOR :: ui.Color{110, 197, 190, 255} // #6EC5BE
ON_PRIMARY_COLOR :: ui.Color{235, 219, 178, 255} // #ebdbb2

BACKGROUND_COLOR :: ui.Color{15, 20, 25, 255} // #0f1419
SURFACE_COLOR :: ui.Color{27, 31, 35, 255} // #1b1f23
ELEVATED_SURFACE_COLOR :: ui.Color{35, 40, 45, 255} // #23282d

TEXT_PRIMARY_COLOR :: ui.Color{235, 242, 249, 255} // #ebf2f9
TEXT_SECONDARY_COLOR :: ui.Color{156, 163, 170, 255} // #9ca3aa
TEXT_DISABLED_COLOR :: ui.Color{98, 104, 110, 255} // #62686e

SUCCESS_COLOR :: ui.Color{87, 217, 106, 255} // #57d96a
WARNING_COLOR :: ui.Color{255, 177, 85, 255} // #ffb155
ERROR_COLOR :: ui.Color{255, 92, 92, 255} // #ff5c5c
INFO_COLOR :: ui.Color{117, 203, 253, 255} // #75cbfd

BORDER_COLOR :: ui.Color{68, 74, 80, 255} // #444a50
DIVIDER_COLOR :: ui.Color{35, 40, 45, 255} // #23282d

assignment_string: string = ` 🔹 سورۃ الحجرات

سوال 1: سورۃ الحجرات کا تعارف / شانِ نزول

تعارف:
سورۃ الحجرات مدنی سورت ہے، اس میں 18 آیات ہیں۔ یہ سورت اسلامی معاشرت، ادب، اخلاق، اور نبی کریم ﷺ کے احترام کے بارے میں اہم تعلیمات دیتی ہے۔

شانِ نزول:
جب کچھ صحابہ کرام نبی کریم ﷺ کے حجرے کے باہر بلند آواز سے آپ ﷺ کو بلاتے تھے، تو یہ آیات نازل ہوئیں تاکہ نبی کے احترام اور آداب سکھائے جائیں۔

⸻

سوال 2: آیات 1 تا 3 – ترجمہ و متعلقہ احکام

ترجمہ:
1️⃣ اے ایمان والو! اللہ اور اس کے رسول کے آگے نہ بڑھو اور اللہ سے ڈرتے رہو، بے شک اللہ سب کچھ سنتا اور جانتا ہے۔
2️⃣ اے ایمان والو! اپنی آوازیں نبی کی آواز سے بلند نہ کرو، اور نہ ان سے بات کرتے وقت اپنی آواز کو ایسے اونچا کرو جیسے تم آپس میں کرتے ہو، کہیں تمہارے اعمال ضائع نہ ہو جائیں اور تمہیں خبر بھی نہ ہو۔
3️⃣ جو لوگ رسولِ اللہ کے سامنے اپنی آواز پست رکھتے ہیں، اللہ نے ان کے دلوں کو تقویٰ کے لیے چن لیا ہے، ان کے لیے مغفرت اور بڑا اجر ہے۔

احکام / تفسیر:
	•	نبی ﷺ کے سامنے ادب و احترام کا حکم ہے۔
	•	آپ ﷺ کے سامنے اونچی آواز میں بات کرنا گناہ ہے اور اعمال کے برباد ہونے کا اندیشہ ہے۔
	•	مؤمن کا کمال یہ ہے کہ وہ نبی ﷺ کے سامنے عاجزی اور ادب اختیار کرے۔

⸻

سوال 3: آیات 4 تا 5 – ترجمہ و متعلقہ احکام

ترجمہ:
4️⃣ جو لوگ آپ کو حجرے کے باہر سے پکارتے ہیں، ان میں سے اکثر بے عقل ہیں۔
5️⃣ اور اگر وہ صبر کرتے یہاں تک کہ آپ خود باہر تشریف لاتے تو یہ ان کے لیے بہتر ہوتا، اور اللہ بخشنے والا مہربان ہے۔

احکام / تفسیر:
	•	نبی ﷺ سے ملاقات کے آداب سکھائے گئے۔
	•	بغیر اجازت نبی کو پکارنا بے ادبی ہے۔
	•	صبر اور ادب کے ساتھ انتظار کرنا مومن کا شیوہ ہے۔

⸻

سوال 4: آیت 6 – ترجمہ و متعلقہ احکام

ترجمہ:
اے ایمان والو! اگر کوئی فاسق تمہارے پاس کوئی خبر لے کر آئے تو تحقیق کر لو، کہیں ایسا نہ ہو کہ تم نادانی میں کسی قوم کو نقصان پہنچاؤ، پھر اپنے کیے پر پچھتاؤ۔

احکام / تفسیر:
	•	خبر سن کر بغیر تحقیق کے عمل نہ کرو۔
	•	جھوٹی خبروں پر فیصلے کرنا ظلم ہے۔
	•	اسلامی اصول ہے کہ ہر بات کی تصدیق ضروری ہے۔

⸻

سوال 5: آیات 7 تا 8 – ترجمہ و متعلقہ احکام (نبی کی رائے کی اہمیت)

ترجمہ:
7️⃣ جان لو کہ تم میں رسولِ اللہ موجود ہیں، اگر وہ تمہاری بہت سی باتوں میں تمہاری بات مان لیں تو تم مشقت میں پڑ جاؤ گے، لیکن اللہ نے تمہیں ایمان کی محبت دی ہے اور کفر و نافرمانی کو تمہارے لیے ناپسندیدہ بنا دیا ہے، یہی ہدایت پانے والے ہیں۔
8️⃣ یہ اللہ کا فضل اور احسان ہے، اور اللہ سب کچھ جاننے والا، حکمت والا ہے۔

احکام / تفسیر:
	•	نبی ﷺ کی رائے سب سے برتر اور فیصلہ کن ہے۔
	•	ایمان اللہ کی نعمت اور فضل ہے۔
	•	مومن کے دل میں ایمان کی محبت اللہ ہی ڈالتا ہے۔

⸻

سوال 6: آیات 9 تا 10 – صرف ترجمہ

ترجمہ:
9️⃣ اگر دو مسلمانوں کے گروہ آپس میں لڑ پڑیں تو ان میں صلح کرا دو، اور اگر ایک زیادتی کرے تو اس سے لڑو یہاں تک کہ وہ اللہ کے حکم کی طرف لوٹ آئے، پھر اگر وہ باز آ جائے تو انصاف سے صلح کرا دو۔ بے شک اللہ انصاف پسندوں کو پسند کرتا ہے۔
🔟 ایمان والے تو بھائی بھائی ہیں، پس اپنے بھائیوں میں صلح کرا دو اور اللہ سے ڈرو تاکہ تم پر رحم کیا جائے۔

⸻

سوال 7: آیت 11 – ترجمہ و متعلقہ احکام

ترجمہ:
اے ایمان والو! نہ مرد دوسرے مردوں کا مذاق اڑائیں، ممکن ہے وہ ان سے بہتر ہوں، اور نہ عورتیں دوسری عورتوں کا مذاق اڑائیں، ممکن ہے وہ ان سے بہتر ہوں، اور ایک دوسرے کو طعنہ نہ دو، اور نہ برے القاب سے یاد کرو۔ ایمان کے بعد فسق نام بہت برا ہے، اور جو توبہ نہ کرے وہی ظالم ہیں۔

احکام / تفسیر:
	•	کسی کا مذاق اڑانا، طعنہ دینا، یا بُرے نام سے پکارنا حرام ہے۔
	•	اسلام نے عزتِ نفس کی حفاظت کا حکم دیا ہے۔
	•	مومن ہمیشہ دوسروں کی عزت کرتا ہے۔

⸻

سوال 8: آیت 12 – ترجمہ و متعلقہ احکام

ترجمہ:
اے ایمان والو! بہت زیادہ بدگمانی سے بچو، یقیناً بعض گمان گناہ ہوتے ہیں، اور تجسس نہ کرو، اور نہ کوئی کسی کی غیبت کرے۔ کیا تم پسند کرو گے کہ اپنے مردہ بھائی کا گوشت کھاؤ؟ تم اسے ناپسند کرتے ہو، اللہ سے ڈرو، یقیناً اللہ توبہ قبول کرنے والا، مہربان ہے۔

احکام / تفسیر:
	•	بدگمانی، تجسس، اور غیبت سے منع کیا گیا ہے۔
	•	غیبت مردہ بھائی کا گوشت کھانے کے برابر ہے۔
	•	مومن کو چاہیے کہ دوسروں کے عیب نہ تلاش کرے۔

⸻

سوال 9: آیت 13 – ترجمہ و متعلقہ احکام / تفسیر

ترجمہ:
اے لوگو! ہم نے تمہیں ایک مرد اور عورت سے پیدا کیا، اور تمہیں قوموں اور قبیلوں میں تقسیم کیا تاکہ تم ایک دوسرے کو پہچانو، بے شک تم میں سب سے زیادہ عزت والا وہ ہے جو سب سے زیادہ پرہیزگار ہے، یقیناً اللہ جاننے والا خبردار ہے۔

احکام / تفسیر:
	•	اسلام میں برتری نسب یا قوم سے نہیں بلکہ تقویٰ سے ہے۔
	•	سب انسان برابر ہیں، رنگ و نسل کی کوئی برتری نہیں۔
	•	اللہ کے نزدیک عزت تقویٰ سے ملتی ہے۔

⸻

🔹 سورۃ المؤمنون

سوال 1: آیات 1 تا 7 – ترجمہ و متعلقہ احکام

ترجمہ:
1️⃣ یقیناً ایمان والے کامیاب ہو گئے،
2️⃣ جو اپنی نمازوں میں خشوع رکھتے ہیں،
3️⃣ اور لغو باتوں سے منہ موڑتے ہیں،
4️⃣ اور زکوٰۃ ادا کرتے ہیں،
5️⃣ اور اپنی شرمگاہوں کی حفاظت کرتے ہیں،
6️⃣ سوائے اپنی بیویوں یا (لونڈیوں) کے،
7️⃣ پھر جو اس کے علاوہ کچھ چاہے وہ حد سے بڑھنے والا ہے۔

احکام / تفسیر:
	•	کامیاب مومن کی صفات بیان کی گئیں: خشوع، پاکیزگی، زکوٰۃ، عفت۔
	•	ایمان صرف عقیدہ نہیں بلکہ عملِ صالح بھی ضروری ہے۔
	•	زنا اور فحاشی سے بچنے کی سخت تاکید ہے۔

⸻

سوال 2: آیات 8 تا 11 – ترجمہ و متعلقہ احکام / تفسیر

ترجمہ:
8️⃣ جو اپنی امانتوں اور وعدوں کی حفاظت کرتے ہیں،
9️⃣ اور اپنی نمازوں کی پابندی کرتے ہیں،
🔟 یہی لوگ وارث ہوں گے،
11️⃣ جو فردوس کے وارث ہوں گے، وہ اس میں ہمیشہ رہیں گے۔

احکام / تفسیر:
	•	مومن امانت دار اور وعدے کا پابند ہوتا ہے۔
	•	نماز کی پابندی ایمان کی علامت ہے۔
	•	ایسے ایمان والے جنتِ فردوس کے وارث ہوں گے`

main :: proc() {
	backend_ctx := sdl_backend.init(
		"Window",
		"./backend/sdl_gpu/shaders/compiled/main.vert.sprv",
		"./backend/sdl_gpu/shaders/compiled/main.frag.sprv",
		"./backend/sdl_gpu/shaders/compiled/stencil.vert.sprv",
		"./backend/sdl_gpu/shaders/compiled/stencil.frag.sprv",
	)

	ctx := ui.init_context(250)
	ctp := &ctx
	defer ui.deinit_context(&ctx)

	ctx.measure_text_width = sdl_backend.measure_text_width
	ctx.measure_text_height = sdl_backend.measure_text_height

	ctx.mouse.double_click_timeout = time.Millisecond * 300
	ctx.mouse.long_down_timeout = time.Millisecond * 1000

	sdl_backend.init_font(&backend_ctx)
	nastaliq := sdl_backend.add_font(&backend_ctx, "./assets/NotoNastaliqUrdu-Regular.ttf", 100)

	widgets.theme.font = nastaliq
	widgets.theme.font_size = 20
	widgets.theme.container_child_gap = 8
	widgets.theme.bar_height = 8
	widgets.theme.bar_minimum_width = 64
	widgets.theme.control_size = 16

	defer sdl_backend.de_init(&backend_ctx)
	defer sdl_backend.de_init_font(&backend_ctx)

	main_container_offset: ui.Vec2f32
	slider_value: f32
	toggle_bool: bool
	switch_bool: bool
	progress: f32

	for handle_events(ctp, &backend_ctx) {
		defer free_all(context.temp_allocator)
		ui.begin_ui(ctp)
		ui.push_parent(ctp, ui.create_widget(ctp, "real root", ui.layout(ui.sizing(ui.fixed(ctx.window_size.x), ui.fixed(ctx.window_size.y)))))
		widgets.build_themes(ctp)

		ui.push_parent(
			ctp,
			ui.create_widget(
				ctp,
				"Not real root",
				ui.layout(ui.sizing(ui.grow(), ui.grow())),
				clip = ui.create_clip(ctp, ui.clip(ui.clip_none(), ui.clip_auto(50), hash = 5)),
				style = widgets.theme._container_style.default,
			),
		)
		ui.create_widget(ctp, "ISL ASSIGNMENT", ui.text(assignment_string), style = widgets.theme._label_style.default)
		ui.pop_parent(ctp)

		progress += ctx.frametime / 5

		if progress > 1 do progress = 0
		//
		// {
		// 	main_container_index, main_container_events := widgets.begin_container(
		// 		ctp,
		// 		"main container",
		// 		.Y,
		// 		{.Lock_Active, .Lock_Hover},
		// 		no_theme_hover = true,
		// 	)
		// 	main_container := ui.get_widget(ctp, main_container_index)
		// 	main_container.override = ui.create_override(
		// 		ctp,
		// 		ui.override({}, ui.offset(ui.fixed(main_container_offset.x), ui.fixed(main_container_offset.y)), {}),
		// 	)
		// 	if .Down in main_container_events[.Left] {
		// 		main_container_offset += ctx.mouse.delta
		// 	}
		//
		// 	{
		// 		widgets.button(ctp, "Button 1", "Test button")
		// 		widgets.button(ctp, "Button 2", "Test button hmmmm")
		// 		widgets.slider(ctp, "slider", "test slider", &slider_value, 5, 5000, 1, .X)
		// 		widgets.toggle(ctp, "toggle", "Toggle^2", &toggle_bool)
		// 		widgets.ui_switch(ctp, "switch", "Switch", &switch_bool)
		// 		widgets.progress_bar(ctp, "progress bar", "progress", progress)
		// 	}
		// 	widgets.end_container(ctp)
		// }

		ui.pop_parent(ctp)
		ui.end_ui(ctp)

		sdl_backend.render(&backend_ctx, &ctx)
	}
}

handle_events :: proc(ctx: ^ui.Core_Context, backend_ctx: ^sdl_backend.Backend_Context) -> bool {
	event: sdl.Event

	@(static) event_ctx: struct {
		is_left_down, is_right_down, is_middle_down: bool,
	}

	ctx.mouse.scroll = 0
	ctx.mouse.scroll_v = 0

	for sdl.PollEvent(&event) {
		#partial switch event.type {
		case .KEY_DOWN:
			if event.key.scancode == .ESCAPE {
				return false
			}
		case .QUIT:
			return false
		case .MOUSE_WHEEL:
			ctx.mouse.scroll_v.x = event.wheel.x
			ctx.mouse.scroll_v.y = event.wheel.y
			ctx.mouse.scroll = ctx.mouse.scroll_v.y
		case .MOUSE_BUTTON_DOWN:
			if event.button.button == sdl.BUTTON_LEFT {
				event_ctx.is_left_down = true
				ctx.mouse.mapped_events[.Left] += {.Pressed}
			}
			if event.button.button == sdl.BUTTON_RIGHT {
				event_ctx.is_right_down = true
				ctx.mouse.mapped_events[.Right] += {.Pressed}
			}
			if event.button.button == sdl.BUTTON_MIDDLE {
				event_ctx.is_middle_down = true
				ctx.mouse.mapped_events[.Middle] += {.Pressed}
			}
		case .MOUSE_BUTTON_UP:
			if event.button.button == sdl.BUTTON_LEFT {
				event_ctx.is_left_down = false
				ctx.mouse.mapped_events[.Left] += {.Released}
			}
			if event.button.button == sdl.BUTTON_RIGHT {
				event_ctx.is_right_down = false
				ctx.mouse.mapped_events[.Right] += {.Released}
			}
			if event.button.button == sdl.BUTTON_MIDDLE {
				event_ctx.is_middle_down = false
				ctx.mouse.mapped_events[.Middle] += {.Released}
			}
		}
	}

	if event_ctx.is_left_down {
		ctx.mouse.mapped_events[.Left] += {.Down}
	}
	if event_ctx.is_right_down {
		ctx.mouse.mapped_events[.Right] += {.Down}
	}
	if event_ctx.is_middle_down {
		ctx.mouse.mapped_events[.Middle] += {.Down}
	}

	ctx.mouse.old_position = ctx.mouse.position
	w_width, w_height: i32

	_ = sdl.GetMouseState(&ctx.mouse.position.x, &ctx.mouse.position.y)
	_ = sdl.GetWindowSize(backend_ctx.window, &w_width, &w_height)

	ctx.mouse.delta = ctx.mouse.position - ctx.mouse.old_position

	ctx.window_size.x = f32(w_width)
	ctx.window_size.y = f32(w_height)

	return true
}

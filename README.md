# منچ و تخته نرد پارسی ۳بعدی (Godot 4.7 — Mobile Portrait)

بازی سه‌بعدی کلاسیک **منچ (Ludo)** و **تخته نرد (Backgammon)** طراحی‌شده برای ابعاد موبایل عمودی (`540×960` / نسبت `9:16`) با مدل‌های سه‌بعدی ساخته‌شده در **Blender 5.2.2 LTS**، متریال‌های PBR (Normal/Roughness/Clearcoat)، افکت‌های ذره‌ای (Particles)، چت، ایموجی، لیدربورد و معماری آماده آنلاین‌سازی.

## اجرا و تست

```bash
# اجرای مستقیم بازی (پنجره عمودی موبایل)
godot --path /home/nikzad/.gemini/antigravity/scratch/mench-takhte-godot

# باز کردن در ویرایشگر گودات
godot -e --path /home/nikzad/.gemini/antigravity/scratch/mench-takhte-godot

# اجرای تست خودکار
godot --headless --path /home/nikzad/.gemini/antigravity/scratch/mench-takhte-godot res://tools/SmokeTest.tscn
```

## بازسازی مدل‌های ۳بعدی و تکسچرها

```bash
python3 tools/generate_textures_and_audio.py
blender --background --python tools/generate_3d_assets.py
```

## ساختار پروژه
- `scripts/autoload/GameState.gd` — پروفایل بازیکن، سکه، تجربه، آمار و لیدربورد (`user://save_data.json`)
- `scripts/autoload/NetworkManager.gd` — لایه آماده اتصال آنلاین (فعلاً در حالت آفلاین با شبیه‌سازی چت ربات‌ها)
- `scripts/games/VisualEffects3D.gd` — نورپردازی سالن پارسی، آسمان بازتابی، SSAO، بلوم، فرش مخملی میز و ذرات طلایی
- `scripts/games/MenchGame.gd` — موتور کامل منچ ۳بعدی (۲ تا ۴ نفره، هوش مصنوعی و چندنفره لوکال)
- `scripts/games/TakhteNardGame.gd` — موتور کامل تخته نرد ۳بعدی عمودی موبایل (با بار، جفت، جمع کردن، مارس و Undo)
- `scripts/ui/MainApp.gd` — رابط کاربری موبایل با نوار تب پایین (بازی‌ها، رتبه‌بندی، گفت‌وگو، پروفایل)

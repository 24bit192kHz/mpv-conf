<div dir="rtl">

# إعداد mpv

إعداد mpv شخصي يحتوي على: ملفات تعريف HDR، ومحمّل ترجمات عربية تلقائي (`subdl_ar`)،
وواجهة uosc، وتأثيرات shaders، والقصّ الديناميكي المعتمد على CUDA.

## التثبيت

### لينكس / ماك

```sh
curl -fSsL https://raw.githubusercontent.com/24bit192kHz/mpv-conf/master/install.sh | sh
```

### ويندوز (PowerShell)

```powershell
irm https://raw.githubusercontent.com/24bit192kHz/mpv-conf/master/install.ps1 | iex
```

يُثبَّت الإعداد في:

- لينكس/ماك: `~/.config/mpv`
- ويندوز: `%APPDATA%\mpv`

يأخذ السكربت نسخة احتياطية من مجلد mpv الموجود قبل الاستبدال.

## مفاتيح الـ API

المفاتيح **غير مضمّنة** في المستودع لأسباب أمنية. انسخ `.env.example` إلى `.env` واملأها:

| المتغيّر | الخدمة |
|---|---|
| `SUBDL_API_KEY` | SubDL — مطلوبة للترجمات |
| `TMDB_API_KEY` | TMDB — بيانات الأفلام والمسلسلات |
| `TVDB_API_KEY` | TVDB — اختياري لحلقات الأنمي |

يمكن أيضاً استخدام `script-opts/subdl_ar.conf` لتجاوز الإعدادات بأسلوب mpv.

## القصّ الديناميكي (CUDA)

يعتمد القصّ الديناميكي على محلّل بايثون داخل مجلد `cuda-crop-py`. إذا كان `uv`
متوفّراً يشغّله السكربت تلقائياً عبر `uv sync`، وإلا فشغّله يدوياً:

```sh
cd ~/.config/mpv/cuda-crop-py          # ويندوز: cd "%APPDATA%\mpv\cuda-crop-py"
uv sync
```

</div>

---

<div dir="ltr">

# mpv config (English)

Personal mpv configuration: HDR profiles, an Arabic auto-subtitle downloader (`subdl_ar`),
the uosc UI, shaders, and CUDA-backed dynamic crop.

## Install

### Linux / macOS

```sh
curl -fSsL https://raw.githubusercontent.com/24bit192kHz/mpv-conf/master/install.sh | sh
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/24bit192kHz/mpv-conf/master/install.ps1 | iex
```

Installs to `~/.config/mpv` (Linux/macOS) or `%APPDATA%\mpv` (Windows). The installer
backs up any existing mpv config folder before replacing it.

## API keys

Keys are **intentionally not committed**. Copy `.env.example` to `.env` and fill it:

| Variable | Service |
|---|---|
| `SUBDL_API_KEY` | SubDL — required for subtitles |
| `TMDB_API_KEY` | TMDB — movie/series metadata |
| `TVDB_API_KEY` | TVDB — optional, for anime episodes |

`script-opts/subdl_ar.conf` is also supported for mpv-style overrides.

## Dynamic crop (CUDA)

Dynamic crop uses the Python analyzer in `cuda-crop-py/`. The installer runs `uv sync`
automatically when `uv` is available; otherwise:

```sh
cd ~/.config/mpv/cuda-crop-py          # Windows: cd "%APPDATA%\mpv\cuda-crop-py"
uv sync
```

</div>

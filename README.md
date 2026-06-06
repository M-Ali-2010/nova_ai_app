div align="center">

# ✨ Nova AI Studio

### AI-генерация изображений и видео — прямо в кармане

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?style=for-the-badge&logo=dart)](https://dart.dev/)
[![Replicate](https://img.shields.io/badge/Powered_by-Replicate_AI-purple?style=for-the-badge)](https://replicate.com/)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android-black?style=for-the-badge)](https://flutter.dev/)

**Nova AI Studio** — мобильное приложение для генерации AI-контента. Введи промпт — получи изображение или видео за секунды.

</div>

---

## 🎨 О проекте

Nova AI Studio — Flutter-приложение на базе Replicate API для генерации высококачественных изображений и видео по текстовым промптам. Тёмный glassmorphism интерфейс, галерея работ, история генераций.

### Что умеет

- 🖼 **Генерация изображений** — Stable Diffusion XL по тексту
- 🎬 **Генерация видео** — Zeroscope v2 XL из промпта
- 🌌 **Explore** — лента вдохновения и популярных промптов
- 🖼 **Галерея** — все работы в одном месте
- 👤 **Профиль** — статистика и настройки
- 💾 **Локальное хранение** — история через SharedPreferences

---

## 🛠 Стек

```
Фреймворк  →  Flutter 3.x / Dart 3.0+
AI Backend →  Replicate API (REST)
Модели     →  Stable Diffusion XL (img) · Zeroscope v2 XL (video)
Хранение   →  SharedPreferences (локально)
Медиа      →  video_player ^2.8.6
Шрифты     →  Google Fonts
HTTP       →  http ^1.2.1
```

---

## 🚀 Быстрый старт

### Требования

- Flutter SDK `>=3.0.0`
- Dart `>=3.0.0 <4.0.0`
- API ключ [Replicate](https://replicate.com/)

### Установка

```bash
git clone https://github.com/M-Ali-2010/nova_ai_app.git
cd nova_ai_app
flutter pub get
flutter run
```

### Настройка ключа

`lib/api_config.dart`:

```dart
class ApiConfig {
  static const String apiKey = "r8_ВАШ_КЛЮЧ";
  static const String baseUrl = "https://api.replicate.com/v1/predictions";

  static const String imageVersion =
      "39ed52f2a78e934b3ba6e2a89f5b1c712de7dfea535525255b1aa35c5565e08b";

  static const String videoVersion =
      "9f747673945c62801b13b84701c783929c0ee784e4748ec062204894dda1a351";
}
```

> ⚠️ Не коммить API ключ! Используй `.env` или Flutter Flavors для продакшена.

---

## 📁 Структура

```
nova_app/
├── lib/
│   ├── main.dart          # Всё приложение
│   └── api_config.dart    # Replicate конфиг
├── assets/
│   └── icon.png
├── android/
├── ios/
└── pubspec.yaml
```

### Экраны

| Экран | Описание |
|---|---|
| `SplashScreen` | Анимированный сплэш |
| `HomeScreen` | Главная, быстрый доступ |
| `GeneratorScreen` | Генерация img/video |
| `ExploreScreen` | Лента вдохновения |
| `GalleryScreen` | Галерея работ |
| `ProfileScreen` | Профиль и статистика |

---

## 🎯 Машина состояний генерации

```
idle → queued → processing → succeeded ✓
                           → failed    ✗
                           → cancelled
```

---

## 🎨 Дизайн-система

```dart
_bg0      = Color(0xFF010108)  // фон
_electric = Color(0xFF8B7FFF)  // фиолетовый акцент
_rose     = Color(0xFFE8547A)  // розовый акцент
_emerald  = Color(0xFF3DD68C)  // зелёный (успех)
_amber    = Color(0xFFE8A854)  // оранжевый
// + Glassmorphism: _glass1 = Color(0x12FFFFFF)
```

---

## 🔮 Роадмап

- [x] Генерация изображений (SDXL)
- [x] Генерация видео (Zeroscope)
- [x] Галерея + локальное хранение
- [x] Glassmorphism UI + анимации
- [ ] Firebase Auth + облачное хранение
- [ ] Sharing функционал
- [ ] Prompt Templates
- [ ] App Store / Google Play

---

<div align="center">

**Сделано с ❤️ в Ташкенте · Flutter + Replicate AI**

[GitHub](https://github.com/M-Ali-2010/nova_ai_app) · [Telegram](https://t.me/Jrkhnv777)

</div>

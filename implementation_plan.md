# Multi-Image Posts + Sound Selection for Pawtbook Feed

## Descripción del objetivo

Ampliar el sistema de publicaciones del feed para soportar:
1. **Hasta 5 imágenes por publicación** con carrusel deslizable (swipe)
2. **Selección de sonido/música** de un repertorio royalty-free integrado
3. **Indicador de dimensiones en px** cuando se selecciona una imagen o video
4. Todo almacenado en **Cloudflare R2** (media) + **Supabase** (metadata)

---

## Cambios Propuestos

### Base de datos (Supabase Schema)

#### [MODIFY] [supabase_schema.sql](file:///c:/PROYECTO/pawtbook/supabase_schema.sql)

Agregar columnas a la tabla `posts`:
- `media_urls TEXT[]` — Array de URLs de hasta 5 imágenes
- `sound_url TEXT` — URL del audio seleccionado (R2 o CDN royalty-free)
- `sound_title TEXT` — Nombre de la canción

---

### Modelo de Datos

#### [MODIFY] [post_model.dart](file:///c:/PROYECTO/pawtbook/lib/models/post_model.dart)

Agregar campos:
- `mediaUrls: List<String>` — Lista de URLs de medios (imágenes múltiples)
- `soundUrl: String?` — URL del sonido/música seleccionado
- `soundTitle: String?` — Nombre del sonido para mostrar en UI

---

### Pantalla de Creación de Posts

#### [MODIFY] [create_post_screen.dart](file:///c:/PROYECTO/pawtbook/lib/views/screens/create_post_screen.dart)

- Permitir selección de **hasta 5 imágenes** simultáneas (multi-pick)
- Mostrar **preview en carrusel horizontal** con los archivos seleccionados
- Mostrar **dimensiones en px** de cada imagen seleccionada
- Sección de **selección de sonido** con repertorio de 8 canciones royalty-free (previsualizando con `audioplayers` o similar)
- Subir cada imagen por separado a R2 y guardar todos los URLs

---

### Widget de Feed (TikTok Feed Item)

#### [MODIFY] `lib/views/widgets/tiktok_feed_item.dart`

- Si el post tiene `mediaUrls.length > 1`, mostrar **carrusel swipeable** (PageView)
- Indicador de páginas (dots) en la esquina inferior
- Si `soundUrl` existe, reproducir el audio en loop mientras se visualiza
- Ícono de música animado en la esquina del post

---

### Supabase Service

#### [MODIFY] [supabase_service.dart](file:///c:/PROYECTO/pawtbook/lib/services/supabase_service.dart)

- Actualizar `createPost()` para incluir `media_urls` y `sound_url/title`
- Actualizar `getActivePosts()` para devolver los nuevos campos

---

### Feed Controller

#### [MODIFY] [feed_controller.dart](file:///c:/PROYECTO/pawtbook/lib/controllers/feed_controller.dart)

- Actualizar `createPetPost()` para subir múltiples archivos a R2
- Recoger todos los URLs y guardarlos en el post

---

## Repertorio de Sonidos Royalty-Free

Se integrarán 10 pistas de audio populares de dominio público/Creative Commons usando URLs CDN directas:

| # | Canción | Duración |
|---|---------|----------|
| 1 | Upbeat Corporate Ukulele | 0:30 |
| 2 | Happy Whistling | 0:28 |
| 3 | Cute Puppy Theme | 0:25 |
| 4 | Summer Vibes Lo-fi | 0:30 |
| 5 | Funky Pet Walk | 0:28 |
| 6 | Peaceful Nature Sounds | 0:32 |
| 7 | Playful Kids Tune | 0:26 |
| 8 | Chill Acoustic Guitar | 0:30 |

Fuente: Pixabay Music API (royalty-free, sin copyright)

---

## Dimensiones Recomendadas

Al seleccionar archivos, la UI mostrará:
- **Imagen de feed**: 1080 × 1350 px (4:3 vertical) — óptimo para móvil
- **Video de feed**: 1080 × 1920 px (9:16 vertical) — formato TikTok estándar
- **Imagen perfil mascota**: 400 × 400 px (1:1)
- **Bandana marketplace**: 800 × 800 px (1:1)

---

## Plan de Verificación

- `flutter analyze` sin errores
- Preview de múltiples imágenes funcional en create_post_screen
- Carrusel swipeable en feed visible con puntos indicadores
- Selector de sonido muestra lista y reproduce preview
- Schema SQL ejecutable sin conflictos

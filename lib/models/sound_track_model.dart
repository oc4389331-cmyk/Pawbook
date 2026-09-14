// ── Royalty-Free Sound Model & Catalog ───────────────────────────────────────
class SoundTrack {
  final String id;
  final String title;
  final String artist;
  final String duration;
  final String emoji;
  final String url;

  const SoundTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    required this.emoji,
    required this.url,
  });
}

const List<SoundTrack> royaltyFreeSoundsCatalog = [
  SoundTrack(
    id: 'upbeat_ukulele',
    title: 'Upbeat Corporate Ukulele',
    artist: 'Pixabay Music',
    duration: '0:30',
    emoji: '🎸',
    url: 'https://cdn.pixabay.com/download/audio/2022/01/18/audio_d0c6ff1fbc.mp3',
  ),
  SoundTrack(
    id: 'happy_whistling',
    title: 'Happy Whistling',
    artist: 'Pixabay Music',
    duration: '0:28',
    emoji: '🎵',
    url: 'https://cdn.pixabay.com/download/audio/2022/03/15/audio_c8c8a73467.mp3',
  ),
  SoundTrack(
    id: 'cute_puppy_theme',
    title: 'Cute Puppy Theme',
    artist: 'Pixabay Music',
    duration: '0:25',
    emoji: '🐶',
    url: 'https://cdn.pixabay.com/download/audio/2023/03/06/audio_9f39c52fc9.mp3',
  ),
  SoundTrack(
    id: 'summer_vibes_lofi',
    title: 'Summer Vibes Lo-fi',
    artist: 'Pixabay Music',
    duration: '0:30',
    emoji: '🌅',
    url: 'https://cdn.pixabay.com/download/audio/2022/05/27/audio_1808fbf07a.mp3',
  ),
  SoundTrack(
    id: 'funky_pet_walk',
    title: 'Funky Pet Walk',
    artist: 'Pixabay Music',
    duration: '0:28',
    emoji: '🕺',
    url: 'https://cdn.pixabay.com/download/audio/2022/10/25/audio_946b86c912.mp3',
  ),
  SoundTrack(
    id: 'peaceful_nature',
    title: 'Peaceful Nature Sounds',
    artist: 'Pixabay Music',
    duration: '0:32',
    emoji: '🌿',
    url: 'https://cdn.pixabay.com/download/audio/2022/03/10/audio_270f49571d.mp3',
  ),
  SoundTrack(
    id: 'playful_kids',
    title: 'Playful Kids Tune',
    artist: 'Pixabay Music',
    duration: '0:26',
    emoji: '🎉',
    url: 'https://cdn.pixabay.com/download/audio/2023/01/11/audio_9f7b614a66.mp3',
  ),
  SoundTrack(
    id: 'chill_acoustic',
    title: 'Chill Acoustic Guitar',
    artist: 'Pixabay Music',
    duration: '0:30',
    emoji: '🎶',
    url: 'https://cdn.pixabay.com/download/audio/2022/08/03/audio_2dde668d05.mp3',
  ),
  SoundTrack(
    id: 'sunny_morning',
    title: 'Sunny Morning Whistle',
    artist: 'Pixabay Music',
    duration: '0:29',
    emoji: '☀️',
    url: 'https://cdn.pixabay.com/download/audio/2022/01/18/audio_d0c6ff1fbc.mp3',
  ),
  SoundTrack(
    id: 'energetic_doggy',
    title: 'Energetic Doggy Run',
    artist: 'Pixabay Music',
    duration: '0:27',
    emoji: '🐾',
    url: 'https://cdn.pixabay.com/download/audio/2023/03/06/audio_9f39c52fc9.mp3',
  ),
];

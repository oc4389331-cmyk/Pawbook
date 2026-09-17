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
    id: 'sound_1',
    title: 'Upbeat Energy Beat',
    artist: 'Pawtbook Audio',
    duration: '0:16',
    emoji: '🎸',
    url: 'sounds/sound_1.wav',
  ),
  SoundTrack(
    id: 'sound_2',
    title: 'Happy Acoustic Groove',
    artist: 'Pawtbook Audio',
    duration: '0:16',
    emoji: '🎵',
    url: 'sounds/sound_2.wav',
  ),
  SoundTrack(
    id: 'sound_3',
    title: 'Cute Puppy Melody',
    artist: 'Pawtbook Audio',
    duration: '0:16',
    emoji: '🐶',
    url: 'sounds/sound_3.wav',
  ),
  SoundTrack(
    id: 'sound_4',
    title: 'Summer Lo-Fi Chill',
    artist: 'Pawtbook Audio',
    duration: '0:16',
    emoji: '🌅',
    url: 'sounds/sound_4.wav',
  ),
  SoundTrack(
    id: 'sound_5',
    title: 'Funky Pet Walk',
    artist: 'Pawtbook Audio',
    duration: '0:16',
    emoji: '🕺',
    url: 'sounds/sound_5.wav',
  ),
  SoundTrack(
    id: 'sound_6',
    title: 'Peaceful Nature Ambient',
    artist: 'Pawtbook Audio',
    duration: '0:16',
    emoji: '🌿',
    url: 'sounds/sound_6.wav',
  ),
  SoundTrack(
    id: 'sound_7',
    title: 'Playful Kids & Pets',
    artist: 'Pawtbook Audio',
    duration: '0:16',
    emoji: '🎉',
    url: 'sounds/sound_7.wav',
  ),
  SoundTrack(
    id: 'sound_8',
    title: 'Sunny Morning Whistle',
    artist: 'Pawtbook Audio',
    duration: '0:16',
    emoji: '☀️',
    url: 'sounds/sound_8.wav',
  ),
  SoundTrack(
    id: 'sound_9',
    title: 'Energetic Doggy Run',
    artist: 'Pawtbook Audio',
    duration: '0:16',
    emoji: '🐾',
    url: 'sounds/sound_9.wav',
  ),
  SoundTrack(
    id: 'sound_10',
    title: 'Cosmic Solana Chill',
    artist: 'Pawtbook Audio',
    duration: '0:16',
    emoji: '⚡',
    url: 'sounds/sound_10.wav',
  ),
];

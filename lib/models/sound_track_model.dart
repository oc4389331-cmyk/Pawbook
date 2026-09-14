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
    id: 'soundhelix_1',
    title: 'Upbeat Energy Beat',
    artist: 'Pawtbook Audio',
    duration: '0:30',
    emoji: '🎸',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
  ),
  SoundTrack(
    id: 'soundhelix_2',
    title: 'Happy Acoustic Groove',
    artist: 'Pawtbook Audio',
    duration: '0:28',
    emoji: '🎵',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
  ),
  SoundTrack(
    id: 'soundhelix_3',
    title: 'Cute Puppy Melody',
    artist: 'Pawtbook Audio',
    duration: '0:25',
    emoji: '🐶',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
  ),
  SoundTrack(
    id: 'soundhelix_4',
    title: 'Summer Lo-Fi Chill',
    artist: 'Pawtbook Audio',
    duration: '0:30',
    emoji: '🌅',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
  ),
  SoundTrack(
    id: 'soundhelix_5',
    title: 'Funky Pet Walk',
    artist: 'Pawtbook Audio',
    duration: '0:28',
    emoji: '🕺',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
  ),
  SoundTrack(
    id: 'soundhelix_6',
    title: 'Peaceful Nature Ambient',
    artist: 'Pawtbook Audio',
    duration: '0:32',
    emoji: '🌿',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
  ),
  SoundTrack(
    id: 'soundhelix_7',
    title: 'Playful Kids & Pets',
    artist: 'Pawtbook Audio',
    duration: '0:26',
    emoji: '🎉',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3',
  ),
  SoundTrack(
    id: 'soundhelix_8',
    title: 'Sunny Morning Whistle',
    artist: 'Pawtbook Audio',
    duration: '0:29',
    emoji: '☀️',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
  ),
  SoundTrack(
    id: 'soundhelix_9',
    title: 'Energetic Doggy Run',
    artist: 'Pawtbook Audio',
    duration: '0:27',
    emoji: '🐾',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3',
  ),
  SoundTrack(
    id: 'soundhelix_10',
    title: 'Cosmic Solana Chill',
    artist: 'Pawtbook Audio',
    duration: '0:30',
    emoji: '⚡',
    url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3',
  ),
];

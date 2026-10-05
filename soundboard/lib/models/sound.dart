/// A sound stored in the device's sound collection.
class Sound {
  final String id;
  final String name;
  final String audioData;

  const Sound({required this.id, required this.name, required this.audioData});

  factory Sound.fromMap(String id, Map<String, dynamic> data) => Sound(
    id: id,
    name: data['name'] as String? ?? 'Unknown',
    audioData: data['url'] as String? ?? '',
  );
}

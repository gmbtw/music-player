import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

class MusicSearchPage extends StatefulWidget {
  const MusicSearchPage({super.key});

  @override
  State<MusicSearchPage> createState() => _MusicSearchPageState();
}

class _MusicSearchPageState extends State<MusicSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  String _searchError = '';

  // Аудиоплеер
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingUrl;
  bool _isAudioPlaying = false;
  Duration _playbackPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;
  double _audioVolume = 0.7;

  @override
  void initState() {
    super.initState();
    _setupAudioListeners();
  }

  void _setupAudioListeners() {
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      setState(() {
        _isAudioPlaying = state == PlayerState.playing;
      });
    });

    _audioPlayer.onPositionChanged.listen((Duration position) {
      setState(() {
        _playbackPosition = position;
      });
    });

    _audioPlayer.onDurationChanged.listen((Duration duration) {
      setState(() {
        _audioDuration = duration;
      });
    });

    _audioPlayer.setVolume(_audioVolume);
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final String searchQuery = _searchController.text.trim();
    if (searchQuery.isEmpty) {
      setState(() {
        _searchError = 'Введите поисковый запрос';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _searchResults = [];
      _searchError = '';
    });

    try {
      final Uri apiUrl = Uri.parse(
          'https://itunes.apple.com/search?term=${Uri.encodeComponent(searchQuery)}&entity=song&limit=20'
      );

      final http.Response response = await http.get(apiUrl);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        setState(() {
          _searchResults = responseData['results'] ?? [];
          if (_searchResults.isEmpty) {
            _searchError = 'Ничего не найдено';
          }
        });
      } else {
        setState(() {
          _searchError = 'Ошибка сервера: ${response.statusCode}';
        });
      }
    } catch (error) {
      setState(() {
        _searchError = 'Ошибка подключения: $error';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _controlAudio(String audioUrl) async {
    if (_currentlyPlayingUrl == audioUrl && _isAudioPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_currentlyPlayingUrl != audioUrl) {
        await _audioPlayer.stop();
        _currentlyPlayingUrl = audioUrl;
        await _audioPlayer.play(UrlSource(audioUrl));
      } else {
        await _audioPlayer.resume();
      }
      await _audioPlayer.setVolume(_audioVolume);
    }
  }

  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
    setState(() {
      _playbackPosition = Duration.zero;
      _currentlyPlayingUrl = null;
    });
  }

  Future<void> _seekAudio(double seconds) async {
    final Duration newPosition = Duration(seconds: seconds.toInt());
    await _audioPlayer.seek(newPosition);
  }

  Future<void> _adjustVolume(double volumeLevel) async {
    setState(() {
      _audioVolume = volumeLevel;
    });
    await _audioPlayer.setVolume(volumeLevel);
  }

  String _formatDuration(Duration duration) {
    final String minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final String seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildSearchSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Название песни или исполнитель...',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _searchError = '';
                          });
                        },
                      ),
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  onPressed: _performSearch,
                  child: const Icon(Icons.search, size: 28),
                  mini: true,
                ),
              ],
            ),
            if (_searchError.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _searchError,
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_isLoading) {
      return const Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Ищем музыку...'),
            ],
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.music_note,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _searchError.isEmpty ? 'Начните поиск музыки' : _searchError,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.separated(
        itemCount: _searchResults.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final Map<String, dynamic> track = _searchResults[index];
          final String? previewUrl = track['previewUrl'];
          final String artworkUrl = track['artworkUrl100'] ?? '';
          final String trackName = track['trackName'] ?? 'Без названия';
          final String artistName = track['artistName'] ?? 'Неизвестный исполнитель';
          final String collectionName = track['collectionName'] ?? '';

          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                artworkUrl,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.music_note, color: Colors.grey[600]),
                ),
              ),
            ),
            title: Text(
              trackName,
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  artistName,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (collectionName.isNotEmpty)
                  Text(
                    collectionName,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            trailing: previewUrl != null
                ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _currentlyPlayingUrl == previewUrl && _isAudioPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: Colors.deepPurple,
                    size: 32,
                  ),
                  onPressed: () => _controlAudio(previewUrl),
                ),
                IconButton(
                  icon: const Icon(Icons.stop_circle, size: 28),
                  color: Colors.grey,
                  onPressed: _stopAudio,
                ),
              ],
            )
                : const Icon(Icons.volume_off, color: Colors.grey), // ИСПРАВЛЕНО: volume_off вместо no_sound
          );
        },
      ),
    );
  }

  Widget _buildAudioControls() {
    if (_currentlyPlayingUrl == null) return const SizedBox();

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Прогресс воспроизведения
            Row(
              children: [
                Text(_formatDuration(_playbackPosition)),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _playbackPosition.inSeconds.toDouble(),
                    min: 0,
                    max: _audioDuration.inSeconds.toDouble() > 0
                        ? _audioDuration.inSeconds.toDouble()
                        : 30,
                    onChanged: _seekAudio,
                    activeColor: Colors.deepPurple,
                  ),
                ),
                const SizedBox(width: 12),
                Text(_formatDuration(_audioDuration)),
              ],
            ),
            const SizedBox(height: 12),

            // Управление громкостью
            Row(
              children: [
                const Icon(Icons.volume_down, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _audioVolume,
                    min: 0,
                    max: 1,
                    divisions: 10,
                    onChanged: _adjustVolume,
                    activeColor: Colors.deepPurple,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.volume_up, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Музыкальный поиск',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              // Навигация на страницу профиля
              Navigator.pushNamed(context, '/profile');
            },
            tooltip: 'Профиль',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSearchSection(),
            const SizedBox(height: 16),
            _buildResultsSection(),
            _buildAudioControls(),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../theme/app_colors.dart';

/// Video de una publicación, como en Instagram o Facebook:
///  - Se reproduce solo (sin sonido) cuando la persona lo tiene en pantalla.
///  - Se pausa solo cuando sale de la pantalla.
///  - Respeta la forma del video (horizontal o vertical) sin recortarlo.
///  - Tocar el video lo pausa o lo reanuda; el botón de la bocina pone sonido.
///
/// Los navegadores solo dejan reproducir videos automáticamente si están
/// en silencio, por eso empiezan sin sonido.
class VideoPostPlayer extends StatefulWidget {
  const VideoPostPlayer({super.key, required this.url, this.colors});

  final String url;
  final List<Color>? colors; // degradado mientras carga

  @override
  State<VideoPostPlayer> createState() => _VideoPostPlayerState();
}

class _VideoPostPlayerState extends State<VideoPostPlayer> {
  VideoPlayerController? _controller;
  bool _loading = false;
  bool _error = false;
  bool _muted = true;
  bool _visible = false;
  bool _pausedByUser = false;

  Future<void> _init() async {
    if (_controller != null || _loading) return;
    final uri = Uri.tryParse(widget.url);
    if (uri == null) return;
    setState(() {
      _loading = true;
      _error = false;
    });
    final c = VideoPlayerController.networkUrl(uri);
    try {
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0);
      if (!mounted) {
        await c.dispose();
        return;
      }
      c.addListener(_onTick);
      setState(() {
        _controller = c;
        _loading = false;
      });
      if (_visible && !_pausedByUser) await c.play();
    } catch (_) {
      await c.dispose();
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  void _onVisibility(VisibilityInfo info) {
    if (!mounted) return;
    final f = info.visibleFraction;
    if (f >= 0.6) {
      _visible = true;
      final c = _controller;
      if (c == null) {
        _init();
      } else if (!c.value.isPlaying && !_pausedByUser) {
        c.play();
      }
    } else if (f < 0.25) {
      _visible = false;
      _pausedByUser = false; // al volver a verlo, vuelve a reproducirse solo
      final c = _controller;
      if (c != null && c.value.isPlaying) c.pause();
    }
  }

  void _toggle() {
    final c = _controller;
    if (c == null) {
      _init();
      return;
    }
    if (c.value.isPlaying) {
      c.pause();
      _pausedByUser = true;
    } else {
      c.play();
      _pausedByUser = false;
    }
  }

  void _toggleMute() {
    final c = _controller;
    if (c == null) return;
    setState(() => _muted = !_muted);
    c.setVolume(_muted ? 0 : 1);
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey('video-${widget.url}'),
      onVisibilityChanged: _onVisibility,
      child: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0;
        final c = _controller;
        if (c == null) return _placeholder(w);

        final v = c.value;
        final ratio = v.aspectRatio > 0 ? v.aspectRatio : 16 / 9;
        // Misma regla que las fotos: entre 4:5 (vertical) y 1.91:1 (horizontal),
        // llenando el ancho sin franjas negras.
        final shown = ratio.clamp(0.8, 1.91);
        final height = w / shown;
        return GestureDetector(
          onTap: _toggle,
          child: SizedBox(
            width: w,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: v.size.width > 0 ? v.size.width : w,
                      height: v.size.height > 0 ? v.size.height : height,
                      child: VideoPlayer(c),
                    ),
                  ),
                ),
                if (!v.isPlaying && _pausedByUser)
                  const Center(child: _RoundIcon(icon: Icons.play_arrow_rounded, size: 64)),
                if (v.isBuffering && v.isPlaying)
                  const Center(
                    child: SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    ),
                  ),
                Positioned(
                  right: 10,
                  bottom: 12,
                  child: _MuteButton(muted: _muted, onTap: _toggleMute),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: VideoProgressIndicator(
                    c,
                    allowScrubbing: true,
                    padding: EdgeInsets.zero,
                    colors: const VideoProgressColors(
                      playedColor: AppColors.sky,
                      bufferedColor: Color(0x55FFFFFF),
                      backgroundColor: Color(0x22FFFFFF),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  /// Mientras carga: un recuadro con el color del negocio (sin botón de play).
  Widget _placeholder(double w) {
    final colors = widget.colors ?? const [AppColors.teal, AppColors.blue];
    return GestureDetector(
      onTap: _error ? _init : null,
      child: Container(
        width: w,
        height: w * 9 / 16,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colors.first, colors.length > 1 ? colors[1] : AppColors.deep],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: _error
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, color: Colors.white, size: 36),
                  SizedBox(height: 6),
                  Text('No se pudo cargar el video. Toca para reintentar.',
                      style: TextStyle(color: Colors.white)),
                ],
              )
            : const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              ),
      ),
    );
  }
}

class _MuteButton extends StatelessWidget {
  const _MuteButton({required this.muted, required this.onTap});

  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x88000000),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0x55000000),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.6),
    );
  }
}

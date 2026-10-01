import 'package:flutter/material.dart';

class VoiceWaveButton extends StatefulWidget {
  final bool isListening;
  final VoidCallback onTap;
  final double soundLevel;

  const VoiceWaveButton({
    super.key,
    required this.isListening,
    required this.onTap,
    this.soundLevel = 0.0,
  });

  @override
  State<VoiceWaveButton> createState() => _VoiceWaveButtonState();
}

class _VoiceWaveButtonState extends State<VoiceWaveButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isListening = widget.isListening;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          final scale = isListening ? _scaleAnimation.value : 1.0;

          return Stack(
            alignment: Alignment.center,
            children: [
              // Dış parıltı dalgası
              if (isListening) ...[
                Container(
                  width: 140 * scale,
                  height: 140 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                Container(
                  width: 115 * scale,
                  height: 115 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary.withValues(alpha: 0.35),
                  ),
                ),
              ],
              // Ana Buton
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isListening
                        ? [Colors.redAccent, Colors.deepOrangeAccent]
                        : [
                            theme.colorScheme.primary,
                            theme.colorScheme.tertiary,
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isListening
                              ? Colors.redAccent
                              : theme.colorScheme.primary)
                          .withValues(alpha: 0.4),
                      blurRadius: isListening ? 25 : 12,
                      spreadRadius: isListening ? 4 : 2,
                    ),
                  ],
                ),
                child: Icon(
                  isListening ? Icons.mic : Icons.mic_none_rounded,
                  size: 44,
                  color: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:math';

class FlyAction {
  final IconData icon;
  final VoidCallback onTap;
  final String label;
  FlyAction({required this.icon, required this.onTap, required this.label});
}

class FlyMenu extends StatefulWidget {
  final List<FlyAction> actions;
  final bool showLabels;

  const FlyMenu({super.key, required this.actions, this.showLabels = false});

  @override
  State<FlyMenu> createState() => _FlyMenuState();
}

class _FlyMenuState extends State<FlyMenu> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isOpen = false;
  Offset _position = const Offset(300, 600);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      _isOpen ? _controller.forward() : _controller.reverse();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    bool isLeft = _position.dx < size.width / 2;

    // Дефинираме голяма интерактивна зона (250x250), за да не излизат бутоните от нея
    return Positioned(
      left: _position.dx - 125,
      top: _position.dy - 125,
      child: SizedBox(
        width: 250,
        height: 250,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Под-бутони (Ветрило)
            if (_isOpen || !_controller.isDismissed)
              ...List.generate(widget.actions.length, (index) {
                return _buildAnimatedChild(index, isLeft);
              }),
            
            // Главен бутон (Център на 250x250 зоната)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) {
                if (!_isOpen) {
                  setState(() {
                    _position += details.delta;
                  });
                }
              },
              onTap: _toggle,
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Colors.deepPurple,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
                  ],
                ),
                child: AnimatedRotation(
                  duration: const Duration(milliseconds: 250),
                  turns: _isOpen ? 0.125 : 0,
                  child: const Icon(Icons.add, color: Colors.white, size: 28),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedChild(int index, bool isLeft) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Ъгли за ветрило (Хоризонтално разпъване)
        double startAngle = isLeft ? -pi / 3 : 4 * pi / 3;
        double totalSweep = isLeft ? 2 * pi / 3 : -2 * pi / 3;
        
        double angleStep = widget.actions.length > 1 
            ? totalSweep / (widget.actions.length - 1) 
            : 0;
        
        double currentAngle = widget.actions.length > 1 
            ? startAngle + (index * angleStep)
            : (isLeft ? 0 : pi);

        double dist = _controller.value * 100;
        double x = cos(currentAngle) * dist;
        double y = sin(currentAngle) * dist;

        return Transform.translate(
          offset: Offset(x, y),
          child: Opacity(
            opacity: _controller.value,
            child: Transform.scale(
              scale: 0.5 + (_controller.value * 0.5),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque, // Спира клика да не минава под бутона
                onTap: () {
                  if (_isOpen) {
                    _toggle();
                    widget.actions[index].onTap();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(10.0), // По-голяма зона за докосване
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.showLabels && !isLeft) _buildLabel(widget.actions[index].label),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade400,
                          shape: BoxShape.circle,
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: Icon(widget.actions[index].icon, color: Colors.white, size: 22),
                      ),
                      if (widget.showLabels && isLeft) _buildLabel(widget.actions[index].label),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
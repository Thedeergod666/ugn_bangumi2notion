import 'package:flutter/material.dart';

class BatchImportDebugRibbon extends StatelessWidget {
  const BatchImportDebugRibbon({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: IgnorePointer(
        child: SizedBox(
          width: 84,
          height: 84,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                right: 0,
                child: Transform.rotate(
                  angle: 0.785398,
                  child: Container(
                    width: 100,
                    height: 24,
                    color: const Color(0xFFB00020),
                    alignment: Alignment.center,
                    child: const Text(
                      'DEBUG',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

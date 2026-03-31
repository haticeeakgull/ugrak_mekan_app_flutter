import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class BadgeAlert {
  static void show(BuildContext context, String title, String? iconUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: _buildContent(context, title, iconUrl),
        );
      },
    );
  }

  static Widget _buildContent(
    BuildContext context,
    String title,
    String? iconUrl,
  ) {
    return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F0),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 15,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "✨ Yeni Bir Rozet! ✨",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8D6E63),
                ),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(15),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: iconUrl != null && iconUrl.isNotEmpty
                    ? Image.network(
                        iconUrl,
                        width: 70,
                        height: 70,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.workspace_premium,
                              size: 70,
                              color: Colors.orange,
                            ),
                      )
                    : const Icon(
                        Icons.workspace_premium,
                        size: 70,
                        color: Colors.orange,
                      ),
              ),

              const SizedBox(height: 20),

              Text(
                "Tebrikler!",
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),

              const SizedBox(height: 8),

              Text(
                "'$title'",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                "Başarın profilinde parlamaya başladı.",
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Harika!"),
                ),
              ),
            ],
          ),
        )
        .animate()
        .scale(duration: 450.ms, curve: Curves.easeOutBack)
        .fadeIn(duration: 300.ms);
  }
}

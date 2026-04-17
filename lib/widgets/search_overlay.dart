import 'package:flutter/material.dart';

class SearchOverlay extends StatefulWidget {
  final List<String> vibeler;
  final List<String> semtler;
  final Function(
    String? il,
    List<String> ilceler,
    List<String> vibeler,
    String dogalDil,
  )
  onSearch;

  const SearchOverlay({
    super.key,
    required this.vibeler,
    required this.semtler,
    required this.onSearch,
  });

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  int _currentStep = 0;
  String? _secilenIl;
  List<String> _tempIlceler = [];
  List<String> _tempVibeler = [];
  final TextEditingController _aiController = TextEditingController();

  final List<Map<String, String>> _iller = [
    {"ad": "İstanbul", "ikon": "🏙️"},
    {"ad": "Ankara", "ikon": "🏛️"},
    {"ad": "İzmir", "ikon": "🌊"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white.withOpacity(0.98),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Mekan Keşfet",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildStepCard(
                  step: 0,
                  title: "Neresi?",
                  subtitle: _secilenIl ?? "Şehir seçin",
                  content: _buildCitySelection(),
                ),
                _buildStepCard(
                  step: 1,
                  title: "Detaylar",
                  subtitle:
                      "${_tempIlceler.length} İlçe • ${_tempVibeler.length} Tarz",
                  content: _buildDetailSelection(),
                ),
                _buildStepCard(
                  step: 2,
                  title: "Özel Bir İsteğin Var mı?",
                  subtitle: _aiController.text.isEmpty
                      ? "AI Destekli Arama"
                      : "İsteğin alındı ✨",
                  content: _buildAIInput(),
                ),
              ],
            ),
          ),
          _buildBottomAction(),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required int step,
    required String title,
    required String subtitle,
    required Widget content,
  }) {
    bool isExpanded = _currentStep == step;
    return GestureDetector(
      onTap: () => setState(() => _currentStep = step),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isExpanded ? Colors.deepOrange : Colors.grey.shade200,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (!isExpanded)
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
              ],
            ),
            if (isExpanded) ...[const SizedBox(height: 16), content],
          ],
        ),
      ),
    );
  }

  Widget _buildCitySelection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: _iller.map((il) {
        bool isSelected = _secilenIl == il['ad'];
        return GestureDetector(
          onTap: () => setState(() => _secilenIl = il['ad']),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.deepOrange.shade50
                      : Colors.grey.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.deepOrange : Colors.transparent,
                  ),
                ),
                child: Text(il['ikon']!, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(height: 8),
              Text(
                il['ad']!,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDetailSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Popüler Tarzlar",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: widget.vibeler.map((v) {
            bool isSelected = _tempVibeler.contains(v);
            return FilterChip(
              label: Text(v),
              selected: isSelected,
              onSelected: (val) {
                setState(
                  () => val ? _tempVibeler.add(v) : _tempVibeler.remove(v),
                );
              },
              selectedColor: Colors.deepOrange.shade100,
              checkmarkColor: Colors.deepOrange,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAIInput() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Colors.deepOrange.withOpacity(0.05),
            Colors.orange.withOpacity(0.02),
          ],
        ),
      ),
      child: TextField(
        controller: _aiController,
        maxLines: 2,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: "Buraya hayalindeki mekanı yaz, gerisini Uğrak halletsin ✨",
          prefixIcon: const Icon(
            Icons.auto_awesome,
            color: Colors.deepOrange,
            size: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.deepOrange.withOpacity(0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => setState(() {
              _secilenIl = null;
              _tempIlceler = [];
              _tempVibeler = [];
              _aiController.clear();
            }),
            child: const Text(
              "Temizle",
              style: TextStyle(
                color: Colors.black,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              widget.onSearch(
                _secilenIl,
                _tempIlceler,
                _tempVibeler,
                _aiController.text,
              );
              Navigator.pop(context);
            },
            icon: const Icon(Icons.search),
            label: const Text("Aramayı Başlat"),
          ),
        ],
      ),
    );
  }
}

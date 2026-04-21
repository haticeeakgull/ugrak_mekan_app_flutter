import 'package:flutter/material.dart';
import '../../services/explore_service.dart';
import '../../views/user_profile_screen.dart';

class FriendsSearchWidget extends StatefulWidget {
  final VoidCallback onSearchClosed;
  final FocusNode focusNode;
  const FriendsSearchWidget({
    super.key,
    required this.onSearchClosed,
    required this.focusNode,
  });

  @override
  State<FriendsSearchWidget> createState() => _FriendsSearchWidgetState();
}

class _FriendsSearchWidgetState extends State<FriendsSearchWidget> {
  final TextEditingController _controller = TextEditingController();
  final ExploreService _service = ExploreService();
  List<Map<String, dynamic>> _results = [];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Column(
          children: [
            Material(
              elevation: 10,
              borderRadius: BorderRadius.circular(30),
              child: TextField(
                controller: _controller,
                focusNode: widget.focusNode,
                onChanged: _performSearch,
                decoration: InputDecoration(
                  hintText: "Arkadaşlarını keşfet...",
                  prefixIcon: const Icon(
                    Icons.search,
                    color: const Color(0xFF346739),
                  ),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSearch,
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
            if (_results.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 10),
                  ],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: const Color(0xFF346739),
                      child: Icon(Icons.person, color: Colors.white, size: 20),
                    ),
                    title: Text(_results[index]['username'] ?? "Anonim"),
                    onTap: () {
                      _clearSearch();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => UserProfileScreen(
                            targetUserId: _results[index]['id'],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _performSearch(String q) async {
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    final users = await _service.searchUsers(q);
    setState(() => _results = users);
  }

  void _clearSearch() {
    _controller.clear();
    widget.focusNode.unfocus();
    setState(() => _results = []);
    widget.onSearchClosed();
  }
}

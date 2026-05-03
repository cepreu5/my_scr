import 'package:flutter/material.dart';

class TagScrollFilter extends StatelessWidget {
  final List<String> allTags;
  final List<String> selectedTags;
  final Function(List<String>) onSelectionChanged;

  const TagScrollFilter({
    super.key,
    required this.allTags,
    required this.selectedTags,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (allTags.isEmpty) return const SizedBox.shrink();

    // Сортираме етикетите така, че избраните да са най-отпред
    final List<String> sortedTags = List.from(allTags);
    sortedTags.sort((a, b) {
      bool aSelected = selectedTags.contains(a);
      bool bSelected = selectedTags.contains(b);
      if (aSelected && !bSelected) return -1;
      if (!aSelected && bSelected) return 1;
      return a.compareTo(b);
    });

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.0),
            child: Icon(Icons.label, size: 20, color: Colors.black54),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sortedTags.length,
              itemBuilder: (context, index) {
                final tag = sortedTags[index];
                final isSelected = selectedTags.contains(tag);

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(tag, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    onSelected: (selected) {
                      List<String> newList = List.from(selectedTags);
                      if (selected) {
                        newList.add(tag);
                      } else {
                        newList.remove(tag);
                      }
                      onSelectionChanged(newList);
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    showCheckmark: true,
                    selectedColor: Colors.blue.withOpacity(0.2),
                    checkmarkColor: Colors.blue,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
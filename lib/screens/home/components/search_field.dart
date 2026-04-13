import 'package:flutter/material.dart';

import 'search_state.dart';

class SearchField extends StatelessWidget {
  const SearchField({super.key});

  @override
  Widget build(BuildContext context) {
    final state = SearchState.of(context);

    return Form(
      child: TextFormField(
        controller: state?.controller,
        onChanged: state?.onChanged,
        style: const TextStyle(
          color: Color(0xFF111827),
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: searchOutlineInputBorder,
          enabledBorder: searchOutlineInputBorder,
          focusedBorder: focusedSearchOutlineInputBorder,
          hintText: 'Search products',
          hintStyle: const TextStyle(
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF1B3A68),
          ),
          suffixIcon: (state?.controller.text.isNotEmpty ?? false)
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: Color(0xFF1B3A68),
                  ),
                  onPressed: () {
                    state?.controller.clear();
                    state?.onChanged('');
                  },
                )
              : null,
        ),
      ),
    );
  }
}

const searchOutlineInputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(12)),
  borderSide: BorderSide(color: Color(0xFFB7C4D6), width: 1.5),
);

const focusedSearchOutlineInputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(12)),
  borderSide: BorderSide(color: Color(0xFF1B3A68), width: 2),
);

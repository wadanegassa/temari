import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/models/subject.dart';
import '../../../shared/widgets/temari_button.dart';
import '../../../shared/widgets/temari_text_field.dart';
import '../../auth/providers/auth_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../providers/subjects_provider.dart';

const _subjectHexes = [
  '#4F7FFF',
  '#7C3AED',
  '#059669',
  '#D97706',
  '#DB2777',
  '#0891B2',
  '#65A30D',
  '#EA580C',
];

class CreateSubjectScreen extends ConsumerStatefulWidget {
  const CreateSubjectScreen({super.key});

  @override
  ConsumerState<CreateSubjectScreen> createState() => _CreateSubjectScreenState();
}

class _CreateSubjectScreenState extends ConsumerState<CreateSubjectScreen> {
  final _name = TextEditingController();
  int _colorIndex = 0;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final uid = ref.read(authControllerProvider).effectiveUserId;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(AppStrings.get('create_subject', lang)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TemariTextField(
            controller: _name,
            hint: AppStrings.get('subject_name', lang),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(AppColors.subjectColors.length, (i) {
              final c = AppColors.subjectColors[i];
              final sel = _colorIndex == i;
              return GestureDetector(
                onTap: () => setState(() => _colorIndex = i),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: sel ? AppColors.primary : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          TemariButton(
            label: AppStrings.get('save', lang),
            onPressed: () async {
              final hex = _subjectHexes[_colorIndex];
              final s = Subject.create(
                userId: uid,
                name: _name.text.trim().isEmpty ? 'Subject' : _name.text.trim(),
                colorHex: hex,
              );
              await ref.read(subjectRepositoryProvider).save(s);
              if (!mounted) return;
              context.pop();
            },
          ),
        ],
      ),
    );
  }
}

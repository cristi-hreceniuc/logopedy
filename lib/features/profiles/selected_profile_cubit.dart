// lib/features/profiles/selected_profile_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

class SelectedProfileCubit extends Cubit<int?> {
  SelectedProfileCubit() : super(null);

  void set(int? id) => emit(id);
  void clear() => emit(null);

  bool get hasValue => state != null;
}
